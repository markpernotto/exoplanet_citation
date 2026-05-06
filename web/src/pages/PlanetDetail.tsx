import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { api, type HostStarGaia, type PlanetDetail as PlanetDetailType, type PlanetHistoryResponse, type PlanetsListResponse } from '../api';
import GalaxyMap from '../components/GalaxyMap';
import PlanetCard from '../components/PlanetCard';
import { collectFacts } from '../lib/derived';

export default function PlanetDetail() {
  const { plName = '' } = useParams<{ plName: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  // The `from` state is set by links on Home.tsx when navigating in-app, so
  // we know exactly where to return on "back" (preserving any search query).
  const from = (location.state as { from?: string } | null)?.from;

  const [planet, setPlanet] = useState<PlanetDetailType | null>(null);
  const [hostStar, setHostStar] = useState<HostStarGaia | null>(null);
  const [history, setHistory] = useState<PlanetHistoryResponse | null>(null);
  const [siblings, setSiblings] = useState<PlanetsListResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  function goBack(e: React.MouseEvent) {
    e.preventDefault();
    if (from) {
      navigate(from);
    } else if (window.history.length > 1) {
      navigate(-1);
    } else {
      navigate('/');
    }
  }

  useEffect(() => {
    setPlanet(null);
    setSiblings(null);
    setHostStar(null);
    setError(null);
    api.planetDetail(plName).then(setPlanet).catch((e) => setError(e.message));
    api.planetHistory(plName).then(setHistory).catch(() => {});
    api.planetHostStar(plName).then(setHostStar).catch(() => {});
  }, [plName]);

  // Once we have the planet, fetch siblings (other planets with same hostname)
  useEffect(() => {
    if (!planet) return;
    api.systemPlanets(planet.hostname).then(setSiblings).catch(() => {});
  }, [planet]);

  if (error) {
    const isNotFound = error.startsWith('404');
    return (
      <>
        <p style={{ margin: '0 0 1rem' }}>
          <Link to="/">← back</Link>
        </p>
        {isNotFound ? (
          <>
            <h1 style={{ margin: '0 0 0.5rem' }}>Planet not found</h1>
            <div className="empty">
              <p>No planet named <code>{plName}</code> in the catalog.</p>
              <p style={{ marginTop: '0.5rem' }}>
                The catalog uses canonical names from the NASA Exoplanet Archive, like
                {' '}<code>Kepler-22 b</code>, <code>TRAPPIST-1 e</code>, or <code>Proxima Cen b</code>
                {' '}— with the trailing lowercase letter. Try the search bar from
                {' '}<Link to="/">the home page</Link> for partial matches.
              </p>
            </div>
          </>
        ) : (
          <div className="error">{error}</div>
        )}
      </>
    );
  }

  if (!planet) return <div className="loading">Loading {plName}…</div>;

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <a href={from || '/'} onClick={goBack}>← back{from && from.includes('q=') ? ' to search' : ''}</a>
      </p>
      <h1 style={{ margin: '0 0 0.25rem' }}>{planet.pl_name}</h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)' }}>
        Orbiting <strong>{planet.hostname}</strong>
        {planet.cb_flag === 1 && (
          <span style={{ display: 'inline-block', fontSize: '0.7rem', fontWeight: 700, padding: '0.1rem 0.45rem', borderRadius: '3px', background: 'var(--tier-b)', color: '#0b0d12', marginLeft: '0.45rem', verticalAlign: 'middle', letterSpacing: '0.04em' }}>circumbinary</span>
        )}
        {planet.st_spectype && <> ({planet.st_spectype})</>}
        {planet.disc_year && <> · discovered {planet.disc_year}</>}
        {planet.discoverymethod && <> · {planet.discoverymethod}</>}
      </p>

      <div className="planet-detail">
        <div className="planet-detail-left">
          <PlanetCard planet={planet} siblings={siblings?.results.filter((s) => s.pl_name !== planet.pl_name) ?? null} bp_rp={hostStar?.bp_rp} />
          <HostStarCard planet={planet} />
        </div>

        <div>
          <section>
            <h2>Stat card</h2>
            <div className="card">
              <dl className="stat-grid">
                {fmtRow('Distance from host star', planet.pl_orbsmax, 'AU')}
                {fmtRow('Orbital period', planet.pl_orbper, 'days')}
                {fmtRow('Eccentricity', planet.pl_orbeccen, '')}
                {fmtRow('Radius', planet.pl_rade, 'Earth radii')}
                {fmtRow('Mass', planet.pl_bmasse, 'Earth masses')}
                {fmtRow('Density', planet.pl_dens, 'g/cc')}
                {fmtRow('Equilibrium temperature', planet.pl_eqt, 'K')}
                {fmtRow('Insolation flux', planet.pl_insol, '× Earth')}
                {planet.gaia_dr3_id && (
                  <>
                    <dt>Gaia DR3</dt>
                    <dd style={{ fontSize: '0.85rem' }}>{planet.gaia_dr3_id}</dd>
                  </>
                )}
              </dl>
            </div>
          </section>

          <BeyondBasicsCard planet={planet} />

          <SystemSiblingsSection planet={planet} siblings={siblings} />

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
              {(() => {
                const pc = hostStar?.distance_gspphot_pc ?? (planet.sy_dist ?? null);
                if (pc == null) return null;
                const ly = pc * 3.2616;
                return (
                  <p style={{ margin: '0.5rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
                    {ly < 100
                      ? <><strong>{ly.toFixed(1)} light-years</strong> away ({pc.toFixed(1)} pc)</>
                      : ly < 10000
                      ? <><strong>{Math.round(ly).toLocaleString()} light-years</strong> away ({Math.round(pc).toLocaleString()} pc)</>
                      : <><strong>{(ly / 1000).toFixed(1)}k light-years</strong> away ({Math.round(pc).toLocaleString()} pc)</>
                    }
                    {hostStar?.distance_gspphot_pc != null && <> · via Gaia DR3</>}
                  </p>
                );
              })()}
              {planet.ra != null && planet.dec != null && (() => {
                const pc = hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? null;
                if (pc == null) return null;
                return <GalaxyMap ra={planet.ra} dec={planet.dec} distPc={pc} hostname={planet.hostname} />;
              })()}
            </div>
          </section>

          <section>
            <h2>Discovery</h2>
            <div className="card">
              {planet.disc_facility && <p style={{ margin: '0 0 0.5rem' }}><strong>Facility:</strong> {planet.disc_facility}</p>}
              {planet.disc_telescope && <p style={{ margin: '0 0 0.5rem' }}><strong>Telescope:</strong> {planet.disc_telescope}</p>}
              {planet.disc_instrument && <p style={{ margin: '0 0 0.5rem' }}><strong>Instrument:</strong> {planet.disc_instrument}</p>}
              {planet.disc_refname && (() => {
                const ref = parseDiscRefname(planet.disc_refname);
                return (
                  <p style={{ margin: 0, fontSize: '0.9rem' }}>
                    <strong>Reference:</strong>{' '}
                    {ref.url ? (
                      <a href={ref.url} target="_blank" rel="noopener noreferrer">{ref.text}</a>
                    ) : (
                      <span style={{ color: 'var(--fg-muted)' }}>{ref.text}</span>
                    )}
                  </p>
                );
              })()}
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

function HostStarCard({ planet }: { planet: PlanetDetailType }) {
  const facts = collectStarFacts(planet);
  const spectralInfo = describeSpectralClass(planet.st_spectype);
  // st_lum is log10(L/L☉) per NASA Exoplanet Archive convention.
  const linearLum = planet.st_lum != null ? Math.pow(10, planet.st_lum) : null;
  const hzInner = linearLum != null ? Math.sqrt(linearLum) : null;
  const hzOuter = hzInner != null ? hzInner * 1.4 : null;
  if (facts.length === 0 && !spectralInfo && hzInner == null) return null;
  return (
    <section style={{ marginTop: '1rem' }}>
      <h2>Host star — {planet.hostname}</h2>
      <div className="card">
        {spectralInfo && (
          <p style={{ margin: '0 0 0.85rem', color: 'var(--fg)', lineHeight: 1.5 }}>
            <strong>{spectralInfo.label}</strong> — {spectralInfo.summary}
          </p>
        )}
        {(facts.length > 0 || hzInner != null) && (
          <div className="beyond-basics">
            {facts.map((f) => (
              <div key={f.label} className="metric-item">
                <div className="metric-row">
                  <span className="metric-label">{f.label}</span>
                  <span className="metric-value">{f.value}</span>
                </div>
                {f.explain && <p className="metric-explain">{f.explain}</p>}
              </div>
            ))}
            {hzInner != null && hzOuter != null && (
              <div className="metric-item">
                <div className="metric-row">
                  <span className="metric-label">Habitable zone (estimated)</span>
                  <span className="metric-value">{hzInner.toFixed(2)}–{hzOuter.toFixed(2)} AU</span>
                </div>
                <p className="metric-explain">
                  Distance range where an Earth-like planet could host liquid water on its surface.
                  Computed from luminosity (HZ_inner ≈ √(L/L☉) AU). Brighter stars push the zone outward.
                  {planet.pl_orbsmax != null && (() => {
                    const where =
                      planet.pl_orbsmax < hzInner ? 'inside' :
                      planet.pl_orbsmax > hzOuter ? 'beyond' : 'within';
                    return <> {planet.pl_name} orbits at {planet.pl_orbsmax.toFixed(3)} AU — {where} the zone.</>;
                  })()}
                </p>
              </div>
            )}
          </div>
        )}
        <p style={{ margin: '0.85rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>
          <strong>Composition</strong> — like nearly all main-sequence stars, {planet.hostname} is mostly hydrogen
          (~73% by mass) and helium (~25%), with the remaining ~2% being heavier elements (collectively called
          "metals" in astronomy, even when they're carbon, oxygen, or neon). What really distinguishes one star
          from another is its mass and temperature, which set its color, brightness, and lifespan.
        </p>
      </div>
    </section>
  );
}

function BeyondBasicsCard({ planet }: { planet: PlanetDetailType }) {
  const facts = collectFacts(planet);
  if (facts.length === 0) return null;
  return (
    <section style={{ marginTop: '1rem' }}>
      <h2>Beyond the basics</h2>
      <div className="card">
        <div className="beyond-basics">
          {facts.map((f) => (
            <div key={f.label} className="metric-item">
              <div className="metric-row">
                <span className="metric-label">{f.label}</span>
                <span className="metric-value">{f.value}</span>
              </div>
              {f.explain && <p className="metric-explain">{f.explain}</p>}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function SystemSiblingsSection({ planet, siblings }: { planet: PlanetDetailType; siblings: PlanetsListResponse | null }) {
  if (!siblings) return null;
  const others = siblings.results.filter((p) => p.pl_name !== planet.pl_name);
  if (others.length === 0) return null;
  return (
    <section>
      <h2>System ({siblings.total} planet{siblings.total === 1 ? '' : 's'} around {planet.hostname})</h2>
      <div className="card">
        <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
          Other planets confirmed orbiting <strong>{planet.hostname}</strong>:
        </p>
        <ul className="siblings-list">
          {others.map((s) => (
            <li key={s.pl_name}>
              <Link to={`/planets/${encodeURIComponent(s.pl_name)}`}>{s.pl_name}</Link>
              <span className="muted">
                {s.discoverymethod && <> · {s.discoverymethod}</>}
                {s.disc_year != null && <> · {s.disc_year}</>}
                {s.pl_rade != null && <> · {s.pl_rade.toPrecision(3)} R⊕</>}
                {s.pl_orbper != null && <> · {s.pl_orbper.toFixed(1)} day orbit</>}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

// Spectral class is the leading letter of the MK type string ("G2 V", "M5.5 V", etc).
// Cover OBAFGKM main-sequence + the L/T/Y brown-dwarf classes since the catalog
// includes some directly imaged sub-stellar companions.
function describeSpectralClass(spectype: string | null): { label: string; summary: string } | null {
  if (!spectype) return null;
  const cleaned = spectype.trim();
  const ch = cleaned.charAt(0).toUpperCase();
  const summaries: Record<string, string> = {
    O: 'extremely hot blue giant — rare, massive, and short-lived (only millions of years).',
    B: 'hot blue-white star — massive and luminous, like Rigel or Spica.',
    A: 'hot white star — examples include Sirius and Vega.',
    F: 'yellow-white star, somewhat hotter and brighter than the Sun.',
    G: 'yellow main-sequence star — the same class as our Sun.',
    K: 'orange dwarf — smaller and cooler than the Sun, but very long-lived (tens of billions of years).',
    M: 'red dwarf — by far the most common type of star in the galaxy. Small, dim, and capable of burning for trillions of years.',
    L: 'very cool sub-stellar object on the brown-dwarf borderline.',
    T: 'brown dwarf — never massive enough to ignite hydrogen fusion; cools slowly over its lifetime.',
    Y: 'ultra-cool brown dwarf, with surface temperatures approaching room temperature.',
  };
  const summary = summaries[ch];
  if (!summary) return { label: cleaned, summary: 'spectral class outside the standard MK system.' };
  return { label: `${ch}-type (${cleaned})`, summary };
}

function collectStarFacts(p: PlanetDetailType): { label: string; value: string; explain?: string }[] {
  const facts: { label: string; value: string; explain?: string }[] = [];
  if (p.st_teff != null) {
    const ratio = p.st_teff / 5778;
    facts.push({
      label: 'Effective temperature',
      value: `${p.st_teff.toFixed(0)} K`,
      explain: `${ratio < 0.95 ? 'Cooler than' : ratio > 1.05 ? 'Hotter than' : 'Comparable to'} the Sun (5,778 K) — about ${Math.round(ratio * 100)}% of solar.`,
    });
  }
  if (p.st_rad != null) {
    facts.push({
      label: 'Radius',
      value: `${p.st_rad.toPrecision(3)} R☉`,
      explain: `${p.st_rad < 0.95 ? 'Smaller than' : p.st_rad > 1.05 ? 'Larger than' : 'About the size of'} the Sun (1 R☉ ≈ 696,000 km).`,
    });
  }
  if (p.st_mass != null) {
    facts.push({
      label: 'Mass',
      value: `${p.st_mass.toPrecision(3)} M☉`,
      explain: `${p.st_mass < 0.95 ? 'Less massive than' : p.st_mass > 1.05 ? 'More massive than' : 'Roughly the mass of'} the Sun. Mass sets fusion rate — heavier stars burn hot and die young.`,
    });
  }
  if (p.st_lum != null) {
    const linear = Math.pow(10, p.st_lum);
    const valueStr =
      linear < 0.001 ? `${(linear * 1000).toPrecision(3)} mL☉` :
      linear < 100 ? `${linear.toPrecision(3)} L☉` :
      `${linear.toExponential(2)} L☉`;
    facts.push({
      label: 'Luminosity',
      value: valueStr,
      explain: `Total power output relative to the Sun. ${linear < 0.5 ? 'Far dimmer than' : linear < 1.5 ? 'Comparable to' : 'Brighter than'} the Sun.`,
    });
  }
  const dist = p.sy_dist ?? p.st_dist;
  if (dist != null) {
    const ly = dist * 3.26;
    facts.push({
      label: 'Distance from Earth',
      value: `${ly.toFixed(1)} ly`,
      explain: `(${dist.toFixed(2)} parsecs) — light from this star takes about ${ly.toFixed(0)} years to reach us.`,
    });
  }
  return facts;
}

// pscomppars's disc_refname embeds anchor markup like:
//   `<a refstr=NAEF_ET_AL__2001 href=https://ui.adsabs.harvard.edu/abs/... target=ref> Naef et al. 2001 </a>`
// Parse out the URL and visible text. Return plain text + null URL if it
// doesn't match the expected pattern.
function parseDiscRefname(raw: string): { text: string; url: string | null } {
  if (!raw) return { text: '', url: null };
  const match = raw.match(/href=([^\s>]+)[^>]*>\s*([^<]+?)\s*<\/a>/i);
  if (!match) return { text: raw.replace(/<[^>]+>/g, '').trim(), url: null };
  return { text: match[2].trim(), url: match[1] };
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
