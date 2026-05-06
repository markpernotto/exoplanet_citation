import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { api, type PlanetsListResponse, type StatsResponse } from '../api';

export default function Home() {
  const location = useLocation();
  const params = new URLSearchParams(location.search);
  const query = params.get('q') ?? '';

  const [searchResults, setSearchResults] = useState<PlanetsListResponse | null>(null);
  const [recent, setRecent] = useState<PlanetsListResponse | null>(null);
  const [stats, setStats] = useState<StatsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Catalog stats — load once
  useEffect(() => {
    api.stats().then(setStats).catch(() => {});
  }, []);

  // Search OR recent — depending on whether ?q= is set
  useEffect(() => {
    setError(null);
    if (query) {
      setSearchResults(null);
      api.planetsList({ q: query, limit: 50 })
        .then(setSearchResults)
        .catch((e) => setError(e.message));
    } else {
      setRecent(null);
      api.planetsRecent(100)
        .then(setRecent)
        .catch((e) => setError(e.message));
    }
  }, [query]);

  // ── SEARCH MODE ──────────────────────────────────────────────────────────
  if (query) {
    return (
      <>
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
      </>
    );
  }

  // ── DEFAULT MODE: catalog + recent discoveries ───────────────────────────
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
        <h2>Most recently confirmed</h2>
        {error && <div className="error">Error loading planets: {error}</div>}
        {!error && !recent && <div className="loading">Loading…</div>}
        {recent && recent.total === 0 && (
          <div className="empty">No planets in the catalog yet.</div>
        )}
        {recent && recent.total > 0 && (
          <>
            <p style={{ color: 'var(--fg-muted)', fontSize: '0.85rem', margin: '0 0 0.75rem' }}>
              Showing the {recent.results.length} most recently confirmed of {recent.total.toLocaleString()},
              {' '}newest discovery year first.
            </p>
            <PlanetGrid results={recent.results} />
          </>
        )}
      </section>
    </>
  );
}

function PlanetGrid({ results }: { results: import('../api').PlanetSummary[] }) {
  return (
    <div className="discoveries-list">
      {results.map((p) => (
        <Link key={p.pl_name} className="discovery-item" to={`/planets/${encodeURIComponent(p.pl_name)}`}>
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
