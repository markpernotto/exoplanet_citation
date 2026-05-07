import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { api, type PlanetSummary, type PlanetsListResponse, type TopAuthor } from '../api';
import LoadingBar from '../components/LoadingBar';

const PAGE_SIZE = 100;

export default function Home() {
  const location = useLocation();
  const params = new URLSearchParams(location.search);
  const query = params.get('q') ?? '';

  const [searchResults, setSearchResults] = useState<PlanetsListResponse | null>(null);
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

  const loadMore = useCallback(async () => {
    if (loadingRef.current || !hasMoreRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    try {
      const resp = await api.planetsRecent(PAGE_SIZE, offsetRef.current);
      setItems((prev) => [...prev, ...resp.results]);
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

  // Search mode: fetch planets + authors in parallel on query change
  useEffect(() => {
    if (!query) return;
    api.planetsList({ q: query, limit: 50 })
      .then(setSearchResults)
      .catch((e) => setError(e.message));
    api.authorsSearch(query)
      .then((r) => setAuthorResults(r.authors))
      .catch(() => setAuthorResults([]));
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
    const noPlanets = searchResults && searchResults.total === 0;
    const noAuthors = authorResults && authorResults.length === 0;
    const bothLoaded = searchResults !== null && authorResults !== null;
    return (
      <>
        {authorResults && authorResults.length > 0 && (
          <section>
            <h2>Discoverers matching "{query}"</h2>
            <div className="card" style={{ padding: '0.85rem 1rem' }}>
              <ol style={{ margin: 0, padding: '0 0 0 1.4rem', display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                {authorResults.map((a) => (
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

        <section>
          <h2>
            {searchResults
              ? <>Planets — {searchResults.total} match{searchResults.total === 1 ? '' : 'es'} for "{query}"</>
              : <>Searching for "{query}"…</>}
          </h2>
          {error && <div className="error">Error: {error}</div>}
          {bothLoaded && noPlanets && noAuthors && (
            <div className="empty">
              No planets or discoverers matched "{query}". Try a partial name like "Kepler-22" or "Marcy".
            </div>
          )}
          {searchResults && searchResults.total > 0 && (
            <PlanetGrid results={searchResults.results} />
          )}
        </section>
      </>
    );
  }

  // ── DEFAULT MODE: infinite-scroll recent discoveries ─────────────────────
  return (
    <>
      <FeaturedSystems />

      <section>
        <h2>
          Most recently confirmed
          {total != null && <> <span style={{ color: 'var(--fg-muted)', fontWeight: 'normal', fontSize: '0.75rem' }}>
            ({items.length.toLocaleString()} of {total.toLocaleString()})
          </span></>}
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

type FeaturedSystem = { name: string; representative: string; tagline: string };
type FeaturedCategory = { label: string; description: string; systems: FeaturedSystem[] };

const FEATURED_CATEGORIES: Record<string, FeaturedCategory> = {
  'multi-planet': {
    label: 'Multi-planet systems',
    description: 'Systems with the most known planets. The orbital view really earns its keep here — true AU scale, scroll to zoom.',
    systems: [
      { name: 'TRAPPIST-1',  representative: 'TRAPPIST-1 e',  tagline: '7 rocky planets packed inside Mercury\'s orbit around a cool red dwarf.' },
      { name: 'Kepler-90',   representative: 'Kepler-90 i',   tagline: '8 planets — same count as our solar system, hot terrestrials inside and gas giants outside.' },
      { name: 'Kepler-11',   representative: 'Kepler-11 g',   tagline: '6 sub-Neptunes pressed into a region tighter than Venus\'s orbit — densest known system.' },
      { name: '55 Cancri',   representative: '55 Cnc e',      tagline: '5 planets spanning from an 18-hour-year lava world to a 15-year-year cold gas giant.' },
      { name: 'HR 8799',     representative: 'HR 8799 b',     tagline: '4 directly imaged super-Jupiters at 15–70 AU. Extreme outer scale — pan the canvas.' },
    ],
  },
  'circumbinary': {
    label: 'Two-sun systems',
    description: 'Planets that orbit two stars simultaneously. Like Tatooine, but confirmed.',
    systems: [
      { name: 'Kepler-16',  representative: 'Kepler-16 b',  tagline: 'The original Tatooine planet. Orbits two stars every 229 days, confirmed 2011.' },
      { name: 'Kepler-47',  representative: 'Kepler-47 c',  tagline: 'Three planets orbiting two stars — the only confirmed multi-planet circumbinary system.' },
      { name: 'TOI-1338',   representative: 'TOI-1338 b',   tagline: 'A Saturn-sized planet orbiting two stars — the first circumbinary discovered by TESS.' },
    ],
  },
  'eccentric': {
    label: 'Weird orbits',
    description: 'Planets with wildly elongated orbits. In the system view these draw as stretched ellipses, not circles — which makes them look more like comets than planets.',
    systems: [
      { name: 'HD 20782',   representative: 'HD 20782 b',   tagline: 'Eccentricity 0.96 — the most elongated planetary orbit in the confirmed catalog.' },
      { name: 'HD 80606',   representative: 'HD 80606 b',   tagline: 'Eccentricity 0.93 — a scorching close pass to its star every 111 days, then a long cold arc away.' },
      { name: '16 Cyg B',   representative: '16 Cyg B b',   tagline: 'Eccentricity 0.69 — a Jupiter-mass planet whose orbit would eject Earth from our own solar system.' },
    ],
  },
  'firsts': {
    label: 'Historical firsts',
    description: 'The milestones that built exoplanet science from nothing.',
    systems: [
      { name: 'PSR B1257+12', representative: 'PSR B1257+12 b', tagline: 'The first confirmed exoplanet ever (1992) — orbiting a pulsar, not a normal star.' },
      { name: '51 Peg',       representative: '51 Peg b',       tagline: 'First planet found around a sun-like star (1995). A hot Jupiter that rewrote planetary formation theory.' },
      { name: 'HD 209458',    representative: 'HD 209458 b',    tagline: 'First transit observed (1999). First atmosphere ever detected on an exoplanet (2001).' },
      { name: 'Kepler-22',    representative: 'Kepler-22 b',    tagline: 'First Kepler planet confirmed in a habitable zone (2011). 2.4× Earth\'s radius.' },
    ],
  },
  'habitable': {
    label: 'Potentially habitable',
    description: 'Candidates where liquid water could exist on the surface. The ones worth wondering about.',
    systems: [
      { name: 'Proxima Centauri', representative: 'Proxima Cen b', tagline: 'The nearest exoplanet to Earth at 4.2 light-years, in the habitable zone of our closest stellar neighbor.' },
      { name: 'TRAPPIST-1',      representative: 'TRAPPIST-1 e',  tagline: 'Best current habitable zone candidate — rocky, Earth-mass, receiving similar starlight to Earth.' },
      { name: 'LHS 1140',        representative: 'LHS 1140 b',    tagline: 'Rocky world in a stable habitable zone around a quiet red dwarf — strong atmosphere candidate.' },
      { name: 'K2-18',           representative: 'K2-18 b',       tagline: 'Sub-Neptune with detected water vapor in its atmosphere and habitable-zone temperatures.' },
    ],
  },
  'hot-jupiters': {
    label: 'Hot Jupiters',
    description: 'Gas giants orbiting so close to their star that a "year" lasts hours or days.',
    systems: [
      { name: 'WASP-12',   representative: 'WASP-12 b',   tagline: '1.09-day year. So close to its star that tidal forces are actively shredding it apart.' },
      { name: 'KELT-9',    representative: 'KELT-9 b',    tagline: 'Surface temperature ~4000 K — hotter than many stars, with iron and titanium vapor in its atmosphere.' },
      { name: 'HD 209458', representative: 'HD 209458 b', tagline: 'The prototype hot Jupiter. Also the first exoplanet with a detected atmosphere.' },
    ],
  },
};

const CATEGORY_KEYS = Object.keys(FEATURED_CATEGORIES);
const ALL_KEYS = [...CATEGORY_KEYS, 'top-discoverers'];
const KEY_LABELS: Record<string, string> = {
  ...Object.fromEntries(CATEGORY_KEYS.map((k) => [k, FEATURED_CATEGORIES[k].label])),
  'top-discoverers': 'Top discoverers',
};

function FeaturedSystems() {
  const location = useLocation();
  const from = location.pathname + location.search;
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  const [selectedKey, setSelectedKey] = useState('');
  const [topAuthors, setTopAuthors] = useState<TopAuthor[] | null>(null);

  useEffect(() => {
    if (selectedKey === 'top-discoverers' && topAuthors === null) {
      api.authorsTop(20).then((r) => setTopAuthors(r.authors)).catch(() => {});
    }
  }, [selectedKey, topAuthors]);

  const category = selectedKey && selectedKey !== 'top-discoverers'
    ? FEATURED_CATEGORIES[selectedKey]
    : null;

  return (
    <section>
      <h2>Featured collections</h2>
      <div className="card" style={{ padding: '0.85rem 1rem 1rem' }}>
        <select className="featured-category-select" value={selectedKey} onChange={(e) => setSelectedKey(e.target.value)}>
          <option value="">Choose a collection…</option>
          {ALL_KEYS.map((key) => (
            <option key={key} value={key}>{KEY_LABELS[key]}</option>
          ))}
        </select>

        {category && (
          <>
            <p style={{ margin: '0.75rem 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              {category.description}{' '}
              Open one and click <span aria-label="expand">⛶</span> on its visualization to see the full system at true AU scale.
            </p>
            <ul className="featured-systems">
              {category.systems.map((s) => (
                <li key={s.name}>
                  <Link to={`/planets/${encodeURIComponent(s.representative)}${themeQuery}`} state={{ from }}>
                    <strong>{s.name}</strong>
                  </Link>
                  <span className="muted"> — {s.tagline}</span>
                </li>
              ))}
            </ul>
          </>
        )}

        {selectedKey === 'top-discoverers' && (
          <>
            <p style={{ margin: '0.75rem 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
              Ranked by number of confirmed exoplanets as co-author of the discovery paper.
            </p>
            {topAuthors ? (
              <ol style={{ margin: 0, padding: '0 0 0 1.4rem', display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                {topAuthors.map((a) => (
                  <li key={a.author} style={{ fontSize: '0.9rem' }}>
                    <Link to={`/authors/${encodeURIComponent(a.author)}${themeQuery}`}>
                      {a.author}
                    </Link>
                    <span className="muted"> — {a.planet_count.toLocaleString()} planet{a.planet_count === 1 ? '' : 's'}</span>
                  </li>
                ))}
              </ol>
            ) : (
              <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--fg-muted)' }}>Loading…</p>
            )}
          </>
        )}
      </div>
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
              {(p.sy_pnum ?? 0) > 1 && <span className="pill pill-multi">{p.sy_pnum}-planet system</span>}
              {p.gaia_dr3_id && <span className="pill pill-gaia">Gaia DR3</span>}
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

