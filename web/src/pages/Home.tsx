import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, type DiscoveriesResponse, type PlanetsListResponse, type StatsResponse } from '../api';

export default function Home() {
  const [query, setQuery] = useState('');
  const [searchResults, setSearchResults] = useState<PlanetsListResponse | null>(null);
  const [searchLoading, setSearchLoading] = useState(false);
  const [discoveries, setDiscoveries] = useState<DiscoveriesResponse | null>(null);
  const [stats, setStats] = useState<StatsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.discoveriesLatest(30).then(setDiscoveries).catch((e) => setError(e.message));
    api.stats().then(setStats).catch(() => {});
  }, []);

  function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    const q = query.trim();
    if (!q) {
      setSearchResults(null);
      return;
    }
    setSearchLoading(true);
    api.planetsList({ q, limit: 20 })
      .then(setSearchResults)
      .catch((err) => setError(err.message))
      .finally(() => setSearchLoading(false));
  }

  function clearSearch() {
    setQuery('');
    setSearchResults(null);
  }

  return (
    <>
      <form className="search-bar" onSubmit={handleSearch}>
        <input
          type="text"
          placeholder='Try "Kepler-22", "TRAPPIST", "Proxima", or any partial planet/host name'
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button type="submit">Search</button>
        {searchResults && (
          <button type="button" onClick={clearSearch} style={{ background: 'transparent', color: 'var(--fg-muted)', border: '1px solid var(--border)' }}>
            Clear
          </button>
        )}
      </form>

      {searchResults && (
        <section>
          <h2>Search results — {searchResults.total} match{searchResults.total === 1 ? '' : 'es'} for "{query}"</h2>
          {searchLoading && <div className="loading">Searching…</div>}
          {searchResults.total === 0 && (
            <div className="empty">
              No planets matched "{query}". Try a partial planet name like "Kepler-22"
              or a host star name like "Proxima".
            </div>
          )}
          {searchResults.total > 0 && (
            <div className="discoveries-list">
              {searchResults.results.map((p) => (
                <Link key={p.pl_name} className="discovery-item" to={`/planets/${encodeURIComponent(p.pl_name)}`}>
                  <span className="badge PARAMETER_CHANGE">{p.discoverymethod ?? '—'}</span>
                  <div>
                    <div className="pl-name">{p.pl_name}</div>
                    <div className="summary">
                      {p.hostname}
                      {p.disc_year != null && <> · discovered {p.disc_year}</>}
                      {p.disc_facility && <> · {p.disc_facility}</>}
                    </div>
                  </div>
                  <div className="when">
                    {p.pl_rade != null && <>{p.pl_rade.toPrecision(3)} R⊕</>}
                  </div>
                </Link>
              ))}
              {searchResults.total > searchResults.results.length && (
                <p style={{ color: 'var(--fg-muted)', fontSize: '0.85rem', marginTop: '0.5rem' }}>
                  Showing first {searchResults.results.length} of {searchResults.total}. Refine your query for more specific results.
                </p>
              )}
            </div>
          )}
        </section>
      )}

      {!searchResults && stats && (
        <section>
          <h2>Catalog</h2>
          <div className="card">
            <p style={{ margin: 0 }}>
              <strong>{stats.total_planets.toLocaleString()}</strong> confirmed exoplanets,
              {' '}drawn from <strong>{stats.total_snapshots}</strong> daily snapshots
              {stats.earliest_snapshot && stats.latest_snapshot ? (
                <> ({stats.earliest_snapshot} → {stats.latest_snapshot})</>
              ) : null}.
              Top discovery method: <strong>{topKey(stats.discoveries_by_method)}</strong>.
            </p>
          </div>
        </section>
      )}

      {!searchResults && (
        <section>
          <h2>Recent discoveries (last 30 days)</h2>
          {error && <div className="error">Error loading discoveries: {error}</div>}
          {!error && !discoveries && <div className="loading">Loading…</div>}
          {discoveries && discoveries.changes.length === 0 && (
            <div className="empty">
              No surfaced changes in the last {discoveries.window_days} days.
              The pipeline ran successfully but the upstream data didn't change.
              That's normal — the NASA Exoplanet Archive updates roughly weekly.
            </div>
          )}
          {discoveries && discoveries.changes.length > 0 && (
            <div className="discoveries-list">
              {discoveries.changes.map((c) => (
                <Link key={c.change_id} className="discovery-item" to={`/planets/${encodeURIComponent(c.pl_name)}`}>
                  <span className={`badge ${c.change_type}`}>{c.change_type}</span>
                  <div>
                    <div className="pl-name">{c.pl_name}</div>
                    <div className="summary">{c.diff_summary ?? ''}</div>
                  </div>
                  <div className="when">{formatDate(c.observed_at)}</div>
                </Link>
              ))}
            </div>
          )}
        </section>
      )}
    </>
  );
}

function topKey(d: Record<string, number>): string {
  const entries = Object.entries(d);
  if (!entries.length) return '—';
  return entries.sort((a, b) => b[1] - a[1])[0][0];
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}
