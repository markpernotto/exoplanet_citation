import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, type DiscoveriesResponse, type StatsResponse } from '../api';

export default function Home() {
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
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
    if (q) navigate(`/planets/${encodeURIComponent(q)}`);
  }

  return (
    <>
      <form className="search-bar" onSubmit={handleSearch}>
        <input
          type="text"
          placeholder='Try a planet name like "Kepler-22 b" or "TRAPPIST-1 e"'
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button type="submit">Search</button>
      </form>

      {stats && (
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
              <a key={c.change_id} className="discovery-item" href={`/planets/${encodeURIComponent(c.pl_name)}`}>
                <span className={`badge ${c.change_type}`}>{c.change_type}</span>
                <div>
                  <div className="pl-name">{c.pl_name}</div>
                  <div className="summary">{c.diff_summary ?? ''}</div>
                </div>
                <div className="when">{formatDate(c.observed_at)}</div>
              </a>
            ))}
          </div>
        )}
      </section>
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
