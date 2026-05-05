import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, type PlanetDetail as PlanetDetailType, type PlanetHistoryResponse } from '../api';
import PlanetCard from '../components/PlanetCard';

export default function PlanetDetail() {
  const { plName = '' } = useParams<{ plName: string }>();
  const [planet, setPlanet] = useState<PlanetDetailType | null>(null);
  const [history, setHistory] = useState<PlanetHistoryResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setPlanet(null);
    setError(null);
    api.planetDetail(plName).then(setPlanet).catch((e) => setError(e.message));
    api.planetHistory(plName).then(setHistory).catch(() => {});
  }, [plName]);

  if (error) {
    return (
      <div className="error">
        <p style={{ margin: 0 }}>{error}</p>
        <p style={{ margin: '0.5rem 0 0' }}><Link to="/">← back to home</Link></p>
      </div>
    );
  }

  if (!planet) return <div className="loading">Loading {plName}…</div>;

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <Link to="/">← back</Link>
      </p>
      <h1 style={{ margin: '0 0 0.25rem' }}>{planet.pl_name}</h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)' }}>
        Orbiting <strong>{planet.hostname}</strong>
        {planet.st_spectype && <> ({planet.st_spectype})</>}
        {planet.disc_year && <> · discovered {planet.disc_year}</>}
        {planet.discoverymethod && <> · {planet.discoverymethod}</>}
      </p>

      <div className="planet-detail">
        <PlanetCard planet={planet} />

        <div>
          <section>
            <h2>Stat card</h2>
            <div className="card">
              <dl className="stat-grid">
                {fmtRow('Distance from Earth', planet.sy_dist, 'parsec', planet.sy_dist != null ? `(${(planet.sy_dist * 3.26).toFixed(1)} ly)` : '')}
                {fmtRow('Distance from host star', planet.pl_orbsmax, 'AU')}
                {fmtRow('Orbital period', planet.pl_orbper, 'days')}
                {fmtRow('Eccentricity', planet.pl_orbeccen, '')}
                {fmtRow('Radius', planet.pl_rade, 'Earth radii')}
                {fmtRow('Mass', planet.pl_bmasse, 'Earth masses')}
                {fmtRow('Density', planet.pl_dens, 'g/cc')}
                {fmtRow('Equilibrium temperature', planet.pl_eqt, 'K')}
                {fmtRow('Insolation flux', planet.pl_insol, '× Earth')}
                {fmtRow('Star Teff', planet.st_teff, 'K')}
                {fmtRow('Star radius', planet.st_rad, 'solar radii')}
                {fmtRow('Star mass', planet.st_mass, 'solar masses')}
                {planet.gaia_dr3_id && (
                  <>
                    <dt>Gaia DR3</dt>
                    <dd style={{ fontSize: '0.85rem' }}>{planet.gaia_dr3_id}</dd>
                  </>
                )}
              </dl>
            </div>
          </section>

          <section>
            <h2>Sky position</h2>
            <div className="card">
              <p style={{ margin: 0 }}>
                {planet.ra != null && planet.dec != null ? (
                  <>RA <code>{planet.ra.toFixed(4)}°</code> · Dec <code>{planet.dec.toFixed(4)}°</code></>
                ) : (
                  <span style={{ color: 'var(--fg-muted)' }}>Not available</span>
                )}
              </p>
              <p style={{ margin: '0.5rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
                Galactic positioning view coming in Phase 2 (with Gaia DR3 enrichment).
              </p>
            </div>
          </section>

          <section>
            <h2>Discovery</h2>
            <div className="card">
              {planet.disc_facility && <p style={{ margin: '0 0 0.5rem' }}><strong>Facility:</strong> {planet.disc_facility}</p>}
              {planet.disc_telescope && <p style={{ margin: '0 0 0.5rem' }}><strong>Telescope:</strong> {planet.disc_telescope}</p>}
              {planet.disc_instrument && <p style={{ margin: '0 0 0.5rem' }}><strong>Instrument:</strong> {planet.disc_instrument}</p>}
              {planet.disc_refname && (
                <p style={{ margin: 0, fontSize: '0.9rem' }}>
                  <strong>Reference:</strong> <span style={{ color: 'var(--fg-muted)' }}>{planet.disc_refname}</span>
                </p>
              )}
              <p style={{ margin: '0.75rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
                Citation graph (DOI / arXiv resolution) coming in Phase 2.
              </p>
            </div>
          </section>
        </div>
      </div>

      <section style={{ marginTop: '2rem' }}>
        <h2>Change history</h2>
        {!history && <div className="loading">Loading history…</div>}
        {history && history.change_count === 0 && (
          <div className="empty">No change events recorded yet for this planet.</div>
        )}
        {history && history.change_count > 0 && (
          <table className="history-table">
            <thead>
              <tr>
                <th>When</th>
                <th>Type</th>
                <th>Field</th>
                <th>Tier</th>
                <th>Summary</th>
              </tr>
            </thead>
            <tbody>
              {history.changes.map((c) => (
                <tr key={c.change_id}>
                  <td>{new Date(c.observed_at).toLocaleString()}</td>
                  <td><span className={`badge ${c.change_type}`}>{c.change_type}</span></td>
                  <td>{c.field_name ?? '—'}</td>
                  <td>{c.field_tier ? <span className={`tier-badge tier-${c.field_tier}`}>{c.field_tier}</span> : '—'}</td>
                  <td>{c.diff_summary ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  );
}

function fmtRow(label: string, value: number | null, unit: string, suffix = '') {
  if (value == null) return null;
  return (
    <>
      <dt>{label}</dt>
      <dd>
        {Number.isInteger(value) ? value : value.toPrecision(4)}
        {unit && <span style={{ color: 'var(--fg-muted)' }}> {unit}</span>}
        {suffix && <span style={{ color: 'var(--fg-muted)', fontSize: '0.85rem' }}> {suffix}</span>}
      </dd>
    </>
  );
}
