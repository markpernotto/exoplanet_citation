import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { api, type PlanetSummary, type PlanetsListResponse, type StatsResponse } from '../api';

const PAGE_SIZE = 100;

export default function Home() {
  const location = useLocation();
  const params = new URLSearchParams(location.search);
  const query = params.get('q') ?? '';

  const [searchResults, setSearchResults] = useState<PlanetsListResponse | null>(null);
  const [stats, setStats] = useState<StatsResponse | null>(null);
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

  // Catalog stats — load once
  useEffect(() => {
    api.stats().then(setStats).catch(() => {});
  }, []);

  // Reset when switching between search and default modes
  useEffect(() => {
    setError(null);
    setSearchResults(null);
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

  // Search mode: fetch once on query change
  useEffect(() => {
    if (!query) return;
    api.planetsList({ q: query, limit: 50 })
      .then(setSearchResults)
      .catch((e) => setError(e.message));
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
    return (
      <section>
        <h2>
          {searchResults
            ? <>Search results — {searchResults.total} match{searchResults.total === 1 ? '' : 'es'} for "{query}"</>
            : <>Searching for "{query}"…</>}
        </h2>
        {error && <div className="error">Error: {error}</div>}
        {searchResults && searchResults.total === 0 && (
          <div className="empty">
            No planets matched "{query}". Try a partial planet name like "Kepler-22"
            or a host star name like "Proxima".
          </div>
        )}
        {searchResults && searchResults.total > 0 && (
          <PlanetGrid results={searchResults.results} />
        )}
      </section>
    );
  }

  // ── DEFAULT MODE: catalog stats + infinite-scroll recent discoveries ─────
  return (
    <>
      {stats && (
        <section>
          <h2>Catalog</h2>
          <div className="card">
            <p style={{ margin: 0 }}>
              <strong>{stats.total_planets.toLocaleString()}</strong> confirmed exoplanets
              {stats.latest_snapshot ? <> · last refreshed {stats.latest_snapshot}</> : null}
              {' · '}top discovery method <strong>{topKey(stats.discoveries_by_method)}</strong>
            </p>
          </div>
        </section>
      )}

      <section>
        <h2>
          Most recently confirmed
          {total != null && <> <span style={{ color: 'var(--fg-muted)', fontWeight: 'normal', fontSize: '0.75rem' }}>
            ({items.length.toLocaleString()} of {total.toLocaleString()})
          </span></>}
        </h2>

        {items.length > 0 && <PlanetGrid results={items} />}

        {error && <div className="error">Error: {error}</div>}
        {loading && <div className="loading">Loading more…</div>}
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

function PlanetGrid({ results }: { results: PlanetSummary[] }) {
  const location = useLocation();
  const from = location.pathname + location.search;
  return (
    <div className="discoveries-list">
      {results.map((p) => (
        <Link
          key={p.pl_name}
          className="discovery-item"
          to={`/planets/${encodeURIComponent(p.pl_name)}`}
          state={{ from }}
        >
          <span className="badge PARAMETER_CHANGE">{p.disc_year ?? '—'}</span>
          <div>
            <div className="pl-name">{p.pl_name}</div>
            <div className="summary">
              {p.hostname}
              {p.discoverymethod && <> · {p.discoverymethod}</>}
              {p.disc_facility && <> · {p.disc_facility}</>}
            </div>
          </div>
          <div className="when">
            {p.pl_rade != null && <>{p.pl_rade.toPrecision(3)} R⊕</>}
          </div>
        </Link>
      ))}
    </div>
  );
}

function topKey(d: Record<string, number>): string {
  const entries = Object.entries(d);
  if (!entries.length) return '—';
  return entries.sort((a, b) => b[1] - a[1])[0][0];
}
