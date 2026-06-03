import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { api, type ChangeRecord, type PlanetSummary, type PlanetsListResponse, type TopAuthor } from '../api';
import LoadingBar from '../components/LoadingBar';
import FeaturedFilmstrip from '../components/FeaturedFilmstrip';

const PAGE_SIZE = 100;

export default function Home() {
  const location = useLocation();
  const params = new URLSearchParams(location.search);
  const query = params.get('q') ?? '';
  const themeParam = params.get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  const [searchResults, setSearchResults] = useState<PlanetsListResponse | null>(null);
  const [recent, setRecent] = useState<RecentFeed | null>(null);
  const [authorResults, setAuthorResults] = useState<TopAuthor[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Infinite-scroll state for the default (non-search) mode
  const [items, setItems] = useState<PlanetSummary[]>([]);
  const [total, setTotal] = useState<number | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);

  // Refs to avoid stale closures inside loadMore + IntersectionObserver
  const offsetRef = useRef(0);
  const hasMoreRef = useRef(true);
  const loadingRef = useRef(false);

  // Reset when switching between search and default modes
  useEffect(() => {
    setError(null);
    setSearchResults(null);
    setAuthorResults(null);
    setItems([]);
    setTotal(null);
    setHasMore(true);
    offsetRef.current = 0;
    hasMoreRef.current = true;
    loadingRef.current = false;
    setLoading(false);
  }, [query]);

  // "Recently added" feed (default mode only). Show ONLY the latest pipeline
  // run's changes, keyed off latest_snapshot (the newest snapshot_date), not the
  // latest day that happened to have changes. So when the newest run is quiet the
  // section hides, instead of persisting the last non-empty run for up to 14 days.
  // Useful physical revisions become a quiet line; bookkeeping churn is filtered.
  useEffect(() => {
    if (query) { setRecent(null); return; }
    let cancelled = false;
    api.discoveriesLatest(14).then(async (r) => {
      const asOf = r.latest_snapshot;
      const run = asOf ? r.changes.filter((c) => c.source_snapshot_date === asOf) : [];
      if (!asOf || run.length === 0) {
        if (!cancelled) setRecent({ asOf: asOf ?? '', newPlanets: [], revisions: [], removed: [] });
        return;
      }
      const newNames = run.filter((c) => c.change_type === 'NEW').map((c) => c.pl_name);
      const revisions = run.filter((c) => c.change_type === 'PARAMETER_CHANGE' && !!USEFUL_FIELDS[c.field_name ?? '']);
      const removed = run.filter((c) => c.change_type === 'REMOVED').map((c) => c.pl_name);
      const newPlanets = (await Promise.all(
        newNames.map((n) =>
          api.planetsList({ q: n, limit: 10 })
            .then((res) => res.results.find((p) => p.pl_name === n) ?? null)
            .catch(() => null),
        ),
      )).filter((p): p is PlanetSummary => p !== null);
      if (!cancelled) setRecent({ asOf, newPlanets, revisions, removed });
    }).catch(() => {});
    return () => { cancelled = true; };
  }, [query]);

  const loadMore = useCallback(async () => {
    if (loadingRef.current || !hasMoreRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    try {
      const resp = await api.planetsRecent(PAGE_SIZE, offsetRef.current);
      // Dedupe by pl_name when appending. Defends against duplicate appends
      // from React StrictMode (which intentionally re-runs effects in dev),
      // pagination boundary edge cases, or any future double-fire.
      setItems((prev) => {
        const seen = new Set(prev.map((p) => p.pl_name));
        const fresh = resp.results.filter((p) => !seen.has(p.pl_name));
        return [...prev, ...fresh];
      });
      setTotal(resp.total);
      offsetRef.current += resp.results.length;
      if (resp.results.length === 0 || offsetRef.current >= resp.total) {
        hasMoreRef.current = false;
        setHasMore(false);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      hasMoreRef.current = false;
      setHasMore(false);
    } finally {
      loadingRef.current = false;
      setLoading(false);
    }
  }, []);

  // Search mode: fetch planets + authors in parallel on query change.
  // Authors endpoint requires q.length >= 2 (server-side Pydantic constraint);
  // skip it for single-character queries to avoid a 422 in DevTools noise.
  useEffect(() => {
    if (!query) return;
    api.planetsList({ q: query, limit: 50 })
      .then(setSearchResults)
      .catch((e) => setError(e.message));
    if (query.length >= 2) {
      api.authorsSearch(query)
        .then((r) => setAuthorResults(r.authors))
        .catch(() => setAuthorResults([]));
    } else {
      setAuthorResults([]);
    }
  }, [query]);

  // Default mode: kick off the first page
  useEffect(() => {
    if (query) return;
    loadMore();
  }, [query, loadMore]);

  // IntersectionObserver on the bottom sentinel
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    if (query) return; // not in search mode
    const node = sentinelRef.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) loadMore();
        }
      },
      { rootMargin: '400px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [query, loadMore, items.length]);

  // ── SEARCH MODE ──────────────────────────────────────────────────────────
  if (query) {
    const noPlanets = searchResults !== null && searchResults.total === 0;
    const bothLoaded = searchResults !== null && authorResults !== null;
    // Show discoverers only when there are no planet matches — as a fallback, not a parallel track.
    const showAuthors = noPlanets && authorResults && authorResults.length > 0;
    return (
      <>
        <section>
          <h2>
            {searchResults
              ? <>Search results — {searchResults.total} planet{searchResults.total === 1 ? '' : 's'} matching "{query}"</>
              : <>Searching for "{query}"…</>}
          </h2>
          {error && <div className="error">Error: {error}</div>}
          {searchResults && searchResults.total > 0 && (
            <PlanetGrid results={searchResults.results} />
          )}
          {bothLoaded && noPlanets && !showAuthors && (
            <div className="empty">
              No planets matched "{query}". Try a partial name like "Kepler-22" or a discoverer like "Marcy".
            </div>
          )}
        </section>

        {showAuthors && (
          <section>
            <h2>No planets matched — did you mean a discoverer?</h2>
            <div className="card" style={{ padding: '0.85rem 1rem' }}>
              <ol style={{ margin: 0, padding: '0 0 0 1.4rem', display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                {authorResults!.map((a) => (
                  <li key={a.author} style={{ fontSize: '0.9rem' }}>
                    <SearchAuthorLink author={a.author} />
                    <span style={{ color: 'var(--fg-muted)', marginLeft: '0.5rem' }}>
                      {a.planet_count.toLocaleString()} planet{a.planet_count === 1 ? '' : 's'}
                    </span>
                  </li>
                ))}
              </ol>
            </div>
          </section>
        )}
      </>
    );
  }

  // ── DEFAULT MODE: infinite-scroll recent discoveries ─────────────────────
  return (
    <>
      <FeaturedFilmstrip />

      <RecentChanges recent={recent} themeQuery={themeQuery} />

      <section>
        <h2>
          Most recently confirmed
          {total != null && <> <span style={{ color: 'var(--fg-muted)', fontWeight: 'normal', fontSize: '0.75rem' }}>
            ({items.length.toLocaleString()} of {total.toLocaleString()})
          </span></>}
          <a href="/api/rss" title="Subscribe to all exoplanet changes" style={{ marginLeft: '0.75rem', fontSize: '0.72rem', fontWeight: 'normal', color: 'var(--fg-muted)', textTransform: 'none', letterSpacing: 0 }}>RSS</a>
        </h2>

        {items.length > 0 && <PlanetGrid results={items} />}

        {error && <div className="error">Error: {error}</div>}
        <LoadingBar loading={loading} />
        {!hasMore && !loading && items.length > 0 && (
          <p style={{ color: 'var(--fg-muted)', fontSize: '0.85rem', textAlign: 'center', margin: '1.5rem 0 0' }}>
            That's all {items.length.toLocaleString()} planets in the catalog.
          </p>
        )}

        {/* Sentinel: when this scrolls into view, load the next page */}
        {hasMore && <div ref={sentinelRef} aria-hidden style={{ height: 1 }} />}
      </section>
    </>
  );
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function fmtDay(ymd: string): string {
  if (!ymd) return '';
  const [, m, d] = ymd.split('-').map(Number);
  return `${MONTHS[m - 1]} ${d}`;
}

// Physical-measurement fields worth surfacing as "updates". Everything else
// (disc_year corrections, refname edits, IDs) is bookkeeping churn and is
// filtered out so the feed only ever shows changes a reader would care about.
const USEFUL_FIELDS: Record<string, string> = {
  pl_bmasse: 'mass',
  pl_rade: 'radius',
  pl_orbper: 'orbital period',
  pl_orbsmax: 'orbital distance',
  pl_orbeccen: 'eccentricity',
  pl_eqt: 'equilibrium temp',
  pl_dens: 'density',
  pl_insol: 'insolation',
};

type RecentFeed = {
  asOf: string;
  newPlanets: PlanetSummary[];
  revisions: ChangeRecord[];
  removed: string[];
};

// "Recently added": the latest pipeline run, shown above "Most recently
// confirmed" (which it does not replace). New planets render as real catalog
// cards via PlanetGrid; useful physical revisions and removals are quiet lines.
// Renders nothing when the latest run produced no meaningful changes.
function RecentChanges({ recent, themeQuery }: { recent: RecentFeed | null; themeQuery: string }) {
  if (!recent) return null;
  const { asOf, newPlanets, revisions, removed } = recent;
  if (newPlanets.length === 0 && revisions.length === 0 && removed.length === 0) return null;

  // Group revisions by planet so one planet with two changed fields reads as
  // "Name (mass, radius)" instead of two separate entries.
  const revByPlanet = new Map<string, string[]>();
  for (const r of revisions) {
    const label = USEFUL_FIELDS[r.field_name ?? ''] ?? 'updated';
    const arr = revByPlanet.get(r.pl_name) ?? [];
    if (!arr.includes(label)) arr.push(label);
    revByPlanet.set(r.pl_name, arr);
  }

  return (
    <section>
      <h2>
        Recently added
        {asOf && (
          <span style={{ marginLeft: '0.6rem', color: 'var(--fg-muted)', fontWeight: 'normal', fontSize: '0.75rem' }}>
            {fmtDay(asOf)}
          </span>
        )}
        <a href="/api/rss" title="Subscribe to all exoplanet changes" style={{ marginLeft: '0.75rem', fontSize: '0.72rem', fontWeight: 'normal', color: 'var(--fg-muted)', textTransform: 'none', letterSpacing: 0 }}>RSS</a>
      </h2>

      {newPlanets.length > 0 && <PlanetGrid results={newPlanets} />}

      {revByPlanet.size > 0 && (
        <p style={{ margin: '0.6rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
          Also updated:{' '}
          {[...revByPlanet.entries()].map(([name, labels], i) => (
            <span key={name}>
              {i > 0 && ', '}
              <Link to={`/planets/${encodeURIComponent(name)}${themeQuery}`} style={{ color: 'var(--fg-muted)' }}>{name}</Link>
              {` (${labels.join(', ')})`}
            </span>
          ))}
        </p>
      )}

      {removed.length > 0 && (
        <p style={{ margin: '0.3rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
          Removed: {removed.join(', ')}
        </p>
      )}
    </section>
  );
}

function SearchAuthorLink({ author }: { author: string }) {
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  return <Link to={`/authors/${encodeURIComponent(author)}${themeQuery}`}>{author}</Link>;
}

function PlanetGrid({ results }: { results: PlanetSummary[] }) {
  const location = useLocation();
  const from = location.pathname + location.search;
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  return (
    <div className="discoveries-list">
      {results.map((p) => (
        <Link
          key={p.pl_name}
          className="discovery-item"
          to={`/planets/${encodeURIComponent(p.pl_name)}${themeQuery}`}
          state={{ from }}
        >
          <span className="badge PARAMETER_CHANGE">{p.disc_year ?? '—'}</span>
          <div>
            <div className="pl-name">
              {p.pl_name}
              {p.cb_flag === 1 && <span className="pill pill-cb">circumbinary</span>}
              {p.cb_flag !== 1 && (p.sy_snum ?? 0) >= 2 && (
                <span className="pill pill-binary" title={`Planet orbits one star in a ${p.sy_snum}-star system; companion star(s) visible in the sky`}>
                  {p.sy_snum === 2 ? 'binary system' : `${p.sy_snum}-star system`}
                </span>
              )}
              {(p.sy_pnum ?? 0) > 1 && <span className="pill pill-multi">{p.sy_pnum}-planet system</span>}
              {p.gaia_dr3_id && <span className="pill pill-gaia">Gaia DR3</span>}
              {p.has_measured_geometry && (
                <span className="pill pill-geometry" title="Mutual inclinations between sibling planets have been measured — the 3D scene shows the real architecture">
                  measured 3D
                </span>
              )}
            </div>
            <div className="summary">
              {p.hostname}
              {p.discoverymethod && <> · {p.discoverymethod}</>}
              {p.disc_facility && <> · {p.disc_facility}</>}
            </div>
          </div>
          <div className="when">
            {p.pl_rade != null && <div>{p.pl_rade.toPrecision(3)} R⊕</div>}
            {p.disc_paper_citations != null && (
              <div style={{ fontSize: '0.72rem', color: 'var(--fg-muted)', marginTop: p.pl_rade != null ? '0.2rem' : undefined }}>
                {p.disc_paper_citations.toLocaleString()} cited
              </div>
            )}
          </div>
        </Link>
      ))}
    </div>
  );
}

