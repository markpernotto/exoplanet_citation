import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { api, type BinaryCompanion, type DiscoveryPaper, type HostStarGaia, type PlanetDetail as PlanetDetailType, type PlanetHistoryResponse, type PlanetPublication, type PlanetsListResponse } from '../api';
import GalaxyMap from '../components/GalaxyMap';
import LoadingBar from '../components/LoadingBar';
import PlanetCard from '../components/PlanetCard';
import { collectFacts } from '../lib/derived';
import { formatMass, formatRadius, formatTemperature, useUnitsMode, type Formatted, type UnitsMode } from '../lib/units';

export default function PlanetDetail() {
  const { plName = '' } = useParams<{ plName: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  // The `from` state is set by links on Home.tsx when navigating in-app, so
  // we know exactly where to return on "back" (preserving any search query).
  const from = (location.state as { from?: string } | null)?.from;
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  const [planet, setPlanet] = useState<PlanetDetailType | null>(null);
  const [hostStar, setHostStar] = useState<HostStarGaia | null>(null);
  const [history, setHistory] = useState<PlanetHistoryResponse | null>(null);
  const [siblings, setSiblings] = useState<PlanetsListResponse | null>(null);
  const [paper, setPaper] = useState<DiscoveryPaper | null>(null);
  const [publications, setPublications] = useState<PlanetPublication[] | null>(null);
  const [companions, setCompanions] = useState<BinaryCompanion[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [unitsMode, setUnitsMode] = useUnitsMode();

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
    setPaper(null);
    setPublications(null);
    setCompanions(null);
    setError(null);
    api.planetDetail(plName).then(setPlanet).catch((e) => setError(e.message));
    api.planetHistory(plName).then(setHistory).catch(() => {});
    api.planetHostStar(plName).then(setHostStar).catch(() => {});
    api.planetPaper(plName).then(setPaper).catch(() => {});
    api.planetPublications(plName).then((r) => setPublications(r.publications)).catch(() => {});
    api.planetCompanions(plName).then(setCompanions).catch(() => {});
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
          <Link to={from ?? `/${themeQuery}`}>← back</Link>
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
                {' '}<Link to={`/${themeQuery}`}>the home page</Link> for partial matches.
              </p>
            </div>
          </>
        ) : (
          <div className="error">{error}</div>
        )}
      </>
    );
  }

  if (!planet) return <LoadingBar loading={true} />;

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <a href={from || '/'} onClick={goBack}>← back{from && from.includes('q=') ? ' to search' : ''}</a>
      </p>
      <h1 style={{ margin: '0 0 0.25rem', display: 'flex', alignItems: 'baseline', gap: '0.6rem', flexWrap: 'wrap' }}>
        {planet.pl_name}
        {planet.ra != null && planet.dec != null && (
          <Link
            to={`/planets/${encodeURIComponent(plName)}/scene${themeQuery}`}
            style={{ fontSize: '0.7rem', fontWeight: 600, padding: '0.15rem 0.5rem', borderRadius: 3, background: 'var(--accent)', color: '#0b0d12', textDecoration: 'none', letterSpacing: '0.04em', textTransform: 'uppercase' }}
            title="Open the experimental 3D scene viewer"
          >
            View in 3D ↗
          </Link>
        )}
      </h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)' }}>
        Orbiting <strong>{planet.hostname}</strong>
        {planet.cb_flag === 1 && (
          <span style={{ display: 'inline-block', fontSize: '0.7rem', fontWeight: 700, padding: '0.1rem 0.45rem', borderRadius: '3px', background: 'var(--tier-b)', color: '#0b0d12', marginLeft: '0.45rem', verticalAlign: 'middle', letterSpacing: '0.04em' }}>circumbinary</span>
        )}
        {planet.st_spectype && <> ({planet.st_spectype})</>}
        {planet.disc_year && <> · discovered {planet.disc_year}</>}
        {planet.discoverymethod && <> · {planet.discoverymethod}</>}
        <span style={{ marginLeft: '0.75rem', fontSize: '0.78rem' }}>
          <a href={`/api/rss/planet/${encodeURIComponent(planet.pl_name)}`} title={`RSS: updates to ${planet.pl_name}`} style={{ color: 'var(--fg-muted)' }}>RSS</a>
          {' · '}
          <a href={`/api/rss/system/${encodeURIComponent(planet.hostname)}`} title={`RSS: all ${planet.hostname} system updates`} style={{ color: 'var(--fg-muted)' }}>{planet.hostname} system</a>
        </span>
      </p>

      <div className="planet-detail">
        <div className="planet-detail-left">
          <PlanetCard
            planet={planet}
            siblings={siblings?.results.filter((s) => s.pl_name !== planet.pl_name) ?? null}
            bp_rp={hostStar?.bp_rp}
            companions={companions ?? undefined}
            distancePc={hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? null}
          />
          <HostStarCard planet={planet} sectionDelay={4000} />
        </div>

        <div>
          <section>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
              <h2 style={{ margin: 0 }}>Stat card</h2>
              <UnitsToggle mode={unitsMode} setMode={setUnitsMode} />
            </div>
            <div className="card">
              <dl className="stat-grid">
                {fmtRow('Distance from host star', planet.pl_orbsmax, 'AU', '', 0)}
                {fmtRow('Orbital period', planet.pl_orbper, 'days', '', 1)}
                {fmtRow('Eccentricity', planet.pl_orbeccen, '', '', 2)}
                {fmtRowDisplay('Radius', formatRadius(planet.pl_rade, unitsMode), 3)}
                {fmtRowDisplay('Mass', formatMass(planet.pl_bmasse, unitsMode), 4)}
                {fmtRow('Density', planet.pl_dens, 'g/cc', '', 5)}
                {fmtRowDisplay('Equilibrium temperature', formatTemperature(planet.pl_eqt, unitsMode), 6)}
                {fmtRow('Insolation flux', planet.pl_insol, '× Earth', '', 7)}
                {planet.gaia_dr3_id && (
                  <>
                    <dt>Gaia DR3</dt>
                    <dd style={{ fontSize: '0.85rem' }}>{planet.gaia_dr3_id}</dd>
                  </>
                )}
              </dl>
            </div>
          </section>

          <BeyondBasicsCard planet={planet} sectionDelay={2200} />

          <SystemSiblingsSection planet={planet} siblings={siblings} />

          <CompanionsSection planet={planet} companions={companions} hostStar={hostStar} />

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

          <DiscoverySection planet={planet} paper={paper} publications={publications} sectionDelay={1200} />
        </div>
      </div>

      <section style={{ marginTop: '2rem' }}>
        <h2>Change history</h2>
        <LoadingBar loading={!history} />
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

function DiscoverySection({ planet, paper, publications, sectionDelay = 0 }: { planet: PlanetDetailType; paper: DiscoveryPaper | null; publications: PlanetPublication[] | null; sectionDelay?: number }) {
  const [abstractExpanded, setAbstractExpanded] = useState(false);
  const [authorsExpanded, setAuthorsExpanded] = useState(false);
  const [coPlanetsExpanded, setCoPlanetsExpanded] = useState(false);
  const location = useLocation();
  const themeQuery = (() => { const t = new URLSearchParams(location.search).get('theme'); return t ? `?theme=${t}` : ''; })();
  const ref = planet.disc_refname ? parseDiscRefname(planet.disc_refname) : null;
  const adsUrl = paper
    ? `https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(paper.bibcode)}/abstract`
    : ref?.url ?? null;
  // Find the publication that matches the discovery paper bibcode and pull its sibling planets.
  const coPlanets = (() => {
    if (!paper || !publications) return [];
    const match = publications.find((p) => p.bibcode === paper.bibcode);
    return match?.co_planets ?? [];
  })();
  const hasMeta = !!(planet.disc_facility || planet.disc_telescope || planet.disc_instrument);

  return (
    <section>
      <h2>Discovery</h2>
      <div className="card">
        {planet.disc_facility && <p style={{ margin: '0 0 0.35rem' }}><strong>Facility:</strong> {planet.disc_facility}</p>}
        {planet.disc_telescope && <p style={{ margin: '0 0 0.35rem' }}><strong>Telescope:</strong> {planet.disc_telescope}</p>}
        {planet.disc_instrument && <p style={{ margin: '0 0 0.75rem' }}><strong>Instrument:</strong> {planet.disc_instrument}</p>}

        {paper ? (
          <div style={{ borderTop: hasMeta ? '1px solid var(--border)' : undefined, paddingTop: hasMeta ? '0.75rem' : undefined }}>
            <p style={{ margin: '0 0 0.25rem', fontWeight: 600, fontSize: '0.95rem', lineHeight: 1.4 }}>
              {adsUrl ? (
                <a href={adsUrl} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--fg)' }}>
                  {paper.title ?? paper.bibcode}
                </a>
              ) : (paper.title ?? paper.bibcode)}
            </p>

            {paper.authors.length > 0 && (() => {
              const PREVIEW = 5;
              const shown = authorsExpanded ? paper.authors : paper.authors.slice(0, PREVIEW);
              const hidden = paper.authors.length - PREVIEW;
              return (
                <p style={{ margin: '0 0 0.35rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
                  {shown.map((author, i) => (
                    <span key={author}>
                      {i > 0 && ', '}
                      <Link
                        to={`/authors/${encodeURIComponent(author)}${themeQuery}`}
                        style={{ color: 'var(--fg-muted)' }}
                      >
                        {author}
                      </Link>
                    </span>
                  ))}
                  {!authorsExpanded && hidden > 0 && (
                    <>
                      {', '}
                      <button
                        onClick={() => setAuthorsExpanded(true)}
                        style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.85rem', color: 'var(--accent)' }}
                      >
                        +{hidden} more
                      </button>
                    </>
                  )}
                  {authorsExpanded && hidden > 0 && (
                    <>
                      {' '}
                      <button
                        onClick={() => setAuthorsExpanded(false)}
                        style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)' }}
                      >
                        show less
                      </button>
                    </>
                  )}
                </p>
              );
            })()}

            <p style={{ margin: '0 0 0.6rem', fontSize: '0.82rem', color: 'var(--fg-muted)' }}>
              {[paper.journal, paper.pub_date?.slice(0, 4)].filter(Boolean).join(' · ')}
              {paper.citation_count != null && (
                <> · <strong style={{ color: 'var(--fg)' }}>{paper.citation_count.toLocaleString()}</strong> citations</>
              )}
            </p>

            {coPlanets.length > 0 && (() => {
              const PREVIEW = 6;
              const shown = coPlanetsExpanded ? coPlanets : coPlanets.slice(0, PREVIEW);
              const hidden = coPlanets.length - PREVIEW;
              return (
                <p style={{ margin: '0 0 0.6rem', fontSize: '0.82rem', color: 'var(--fg-muted)' }}>
                  This paper also announced{coPlanets.length === 1 ? '' : ` ${coPlanets.length}`}{' '}
                  {coPlanets.length === 1 ? '' : 'other planets'}:{' '}
                  {shown.map((name, i) => (
                    <span key={name}>
                      <Link to={`/planets/${encodeURIComponent(name)}${themeQuery}`}>{name}</Link>
                      {i < shown.length - 1 ? ', ' : ''}
                    </span>
                  ))}
                  {hidden > 0 && !coPlanetsExpanded && (
                    <>
                      {' '}
                      <button
                        onClick={() => setCoPlanetsExpanded(true)}
                        style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)' }}
                      >
                        … +{hidden} more
                      </button>
                    </>
                  )}
                  {coPlanetsExpanded && hidden > 0 && (
                    <>
                      {' '}
                      <button
                        onClick={() => setCoPlanetsExpanded(false)}
                        style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)' }}
                      >
                        show less
                      </button>
                    </>
                  )}
                </p>
              );
            })()}

            {paper.abstract && (() => {
              const LIMIT = 300;
              const truncated = paper.abstract.length > LIMIT;
              const displayText = abstractExpanded || !truncated
                ? paper.abstract
                : paper.abstract.slice(0, LIMIT).trimEnd() + '…';
              return (
                <div style={{ margin: '0 0 0.75rem' }}>
                  <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>
                    {abstractExpanded
                      ? displayText
                      : <TypewriterText text={displayText} startDelay={sectionDelay + 300} />}
                  </p>
                  {truncated && (
                    <button
                      onClick={() => setAbstractExpanded((e) => !e)}
                      style={{ background: 'none', border: 'none', padding: '0.2rem 0', cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)', marginTop: '0.2rem' }}
                    >
                      {abstractExpanded ? 'show less' : 'show more…'}
                    </button>
                  )}
                </div>
              );
            })()}

            <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', fontSize: '0.82rem' }}>
              {adsUrl && <a href={adsUrl} target="_blank" rel="noopener noreferrer">ADS →</a>}
              {paper.doi && (
                <a href={`https://doi.org/${paper.doi}`} target="_blank" rel="noopener noreferrer">DOI →</a>
              )}
              {paper.arxiv_id && (
                <a href={`https://arxiv.org/abs/${paper.arxiv_id}`} target="_blank" rel="noopener noreferrer">arXiv →</a>
              )}
            </div>
          </div>
        ) : ref ? (
          <p style={{ margin: 0, fontSize: '0.9rem' }}>
            <strong>Reference:</strong>{' '}
            {ref.url ? (
              <a href={ref.url} target="_blank" rel="noopener noreferrer">{ref.text}</a>
            ) : (
              <span style={{ color: 'var(--fg-muted)' }}>{ref.text}</span>
            )}
          </p>
        ) : null}
      </div>
    </section>
  );
}

function TypewriterText({ text, startDelay, msPerWord = 80 }: { text: string; startDelay: number; msPerWord?: number }) {
  const themed = !!document.documentElement.dataset.theme;
  const [visibleCount, setVisibleCount] = useState(themed ? 0 : text.split(' ').length);

  useEffect(() => {
    if (!document.documentElement.dataset.theme) return;
    setVisibleCount(0);
    const words = text.split(' ');
    const timeouts: ReturnType<typeof setTimeout>[] = [];
    words.forEach((_, i) => {
      const t = setTimeout(() => setVisibleCount((c) => Math.max(c, i + 1)), startDelay + i * msPerWord);
      timeouts.push(t);
    });
    return () => timeouts.forEach(clearTimeout);
  }, [text, startDelay, msPerWord]);

  const words = text.split(' ');
  if (visibleCount === 0) return null;
  return <>{words.slice(0, visibleCount).join(' ')}</>;
}

function HostStarCard({ planet, sectionDelay = 0 }: { planet: PlanetDetailType; sectionDelay?: number }) {
  const facts = collectStarFacts(planet);
  const spectralInfo = describeSpectralClass(planet.st_spectype);
  // st_lum is log10(L/L☉) per NASA Exoplanet Archive convention.
  const linearLum = planet.st_lum != null ? Math.pow(10, planet.st_lum) : null;
  const hzInner = linearLum != null ? Math.sqrt(linearLum) : null;
  const hzOuter = hzInner != null ? hzInner * 1.4 : null;
  if (facts.length === 0 && !spectralInfo && hzInner == null) return null;
  const sd = `${sectionDelay}ms`;
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
            {facts.map((f, i) => {
              const rowStart = sectionDelay + i * 150;
              const explainStart = rowStart + f.value.length * 65 + 100;
              return (
                <div key={f.label} className="metric-item">
                  <div className="metric-row">
                    <span className="metric-label">{f.label}</span>
                    <span className="metric-value">
                      <span className="tw" style={{ '--tw-chars': f.value.length, '--tw-delay': i, '--section-delay': sd } as React.CSSProperties}>
                        {f.value}
                      </span>
                    </span>
                  </div>
                  {f.explain && (
                    <p className="metric-explain">
                      <TypewriterText text={f.explain} startDelay={explainStart} />
                    </p>
                  )}
                </div>
              );
            })}
            {hzInner != null && hzOuter != null && (() => {
              const hzStr = `${hzInner.toFixed(2)}–${hzOuter.toFixed(2)} AU`;
              const hzLabel = 'Habitable zone (estimated)';
              const hzRowStart = sectionDelay + facts.length * 150;
              const hzExplainStart = hzRowStart + hzStr.length * 65 + 100;
              const hzExplain = `Distance range where an Earth-like planet could host liquid water. Computed from luminosity (HZ_inner ≈ √(L/L☉) AU). Brighter stars push the zone outward.`;
              const orbText = planet.pl_orbsmax != null ? ` ${planet.pl_name} orbits at ${planet.pl_orbsmax.toFixed(3)} AU — ${planet.pl_orbsmax < hzInner ? 'inside' : planet.pl_orbsmax > hzOuter ? 'beyond' : 'within'} the zone.` : '';
              return (
              <div className="metric-item">
                <div className="metric-row">
                  <span className="metric-label">{hzLabel}</span>
                  <span className="metric-value">
                    <span className="tw" style={{ '--tw-chars': hzStr.length, '--tw-delay': facts.length, '--section-delay': sd } as React.CSSProperties}>
                      {hzStr}
                    </span>
                  </span>
                </div>
                <p className="metric-explain">
                  <TypewriterText text={hzExplain + orbText} startDelay={hzExplainStart} />
                </p>
              </div>
              );
            })()}
          </div>
        )}
        <p style={{ margin: '0.85rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>
          <strong>Composition</strong>{' — '}
          <TypewriterText
            text={`like nearly all main-sequence stars, ${planet.hostname} is mostly hydrogen (~73% by mass) and helium (~25%), with the remaining ~2% being heavier elements (collectively called "metals" in astronomy, even when they're carbon, oxygen, or neon). What really distinguishes one star from another is its mass and temperature, which set its color, brightness, and lifespan.`}
            startDelay={sectionDelay + (facts.length + (hzInner != null ? 1 : 0)) * 150 + 600}
          />
        </p>
      </div>
    </section>
  );
}

function BeyondBasicsCard({ planet, sectionDelay = 0 }: { planet: PlanetDetailType; sectionDelay?: number }) {
  const facts = collectFacts(planet);
  if (facts.length === 0) return null;
  const sd = `${sectionDelay}ms`;
  return (
    <section style={{ marginTop: '1rem' }}>
      <h2>Beyond the basics</h2>
      <div className="card">
        <div className="beyond-basics">
          {facts.map((f, i) => {
            const rowStart = sectionDelay + i * 150;
            const explainStart = rowStart + f.value.length * 65 + 100;
            return (
              <div key={f.label} className="metric-item">
                <div className="metric-row">
                  <span className="metric-label">{f.label}</span>
                  <span className="metric-value">
                    <span className="tw" style={{ '--tw-chars': f.value.length, '--tw-delay': i, '--section-delay': sd } as React.CSSProperties}>
                      {f.value}
                    </span>
                  </span>
                </div>
                {f.explain && (
                  <p className="metric-explain">
                    <TypewriterText text={f.explain} startDelay={explainStart} />
                  </p>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function CompanionsSection({
  planet, companions, hostStar,
}: {
  planet: PlanetDetailType;
  companions: BinaryCompanion[] | null;
  hostStar: HostStarGaia | null;
}) {
  if (!companions || companions.length === 0) return null;
  const distance_pc = hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? null;
  return (
    <section>
      <h2>System stars</h2>
      <div className="card">
        <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
          <strong>{planet.pl_name}</strong> orbits the primary star <strong>{planet.hostname}</strong> only.
          {' '}{companions.length === 1
            ? 'One additional stellar component is recorded'
            : `${companions.length} additional stellar components are recorded`}
          {' '}in this system — they sit far enough from the planet's orbit not to disturb it,
          but they're part of the same gravitationally bound family.
        </p>
        <ul className="siblings-list">
          {companions.map((c) => {
            const sepAU = c.separation_arcsec != null && distance_pc != null
              ? c.separation_arcsec * distance_pc
              : null;
            const desc = describeSpectralClass(c.component_spectype);
            const insideOrbit = sepAU != null && planet.pl_orbsmax != null
              && sepAU < planet.pl_orbsmax;
            return (
              <li key={c.component_designation}>
                <strong>{planet.hostname} {c.component_designation}</strong>
                <span className="muted">
                  {c.component_spectype && <> · {c.component_spectype}</>}
                  {sepAU != null && <> · ~{sepAU >= 10 ? sepAU.toFixed(0) : sepAU.toFixed(1)} AU projected</>}
                  {c.position_angle_deg != null && <> · PA {c.position_angle_deg.toFixed(0)}°</>}
                  {c.source_catalog && <> · {c.source_catalog}</>}
                  {insideOrbit && <> · <span style={{ color: 'var(--tier-b)' }}>inside {planet.pl_name}'s orbit</span></>}
                </span>
                {desc?.summary && (
                  <p style={{ margin: '0.25rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                    {desc.summary}
                  </p>
                )}
              </li>
            );
          })}
        </ul>
        <p style={{ margin: '0.75rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
          "Projected" separation is what we measure on the sky (angular separation × system distance).
          The true 3D distance is at least this — possibly more, depending on the unknown line-of-sight component.
        </p>
      </div>
    </section>
  );
}

function SystemSiblingsSection({ planet, siblings }: { planet: PlanetDetailType; siblings: PlanetsListResponse | null }) {
  const location = useLocation();
  if (!siblings) return null;
  const others = siblings.results.filter((p) => p.pl_name !== planet.pl_name);
  if (others.length === 0) return null;
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
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
              <Link to={`/planets/${encodeURIComponent(s.pl_name)}${themeQuery}`}>{s.pl_name}</Link>
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

function UnitsToggle({ mode, setMode }: { mode: UnitsMode; setMode: (m: UnitsMode) => void }) {
  const base: React.CSSProperties = {
    fontSize: '0.7rem',
    padding: '0.2rem 0.55rem',
    border: '1px solid var(--border)',
    background: 'transparent',
    color: 'var(--fg-muted)',
    cursor: 'pointer',
    letterSpacing: '0.04em',
    textTransform: 'uppercase',
  };
  const active: React.CSSProperties = { ...base, background: 'var(--accent)', color: '#0b0d12', borderColor: 'var(--accent)' };
  return (
    <div role="group" aria-label="Units" style={{ display: 'inline-flex', borderRadius: 3 }} title="Toggle units (saved in your browser)">
      <button
        type="button"
        style={mode === 'metric' ? { ...active, borderRadius: '3px 0 0 3px' } : { ...base, borderRadius: '3px 0 0 3px', borderRight: 'none' }}
        onClick={() => setMode('metric')}
        aria-pressed={mode === 'metric'}
      >
        Metric
      </button>
      <button
        type="button"
        style={mode === 'imperial' ? { ...active, borderRadius: '0 3px 3px 0' } : { ...base, borderRadius: '0 3px 3px 0' }}
        onClick={() => setMode('imperial')}
        aria-pressed={mode === 'imperial'}
      >
        Imperial
      </button>
    </div>
  );
}

function fmtRowDisplay(
  label: string,
  formatted: Formatted | null,
  rowIndex: number,
  sectionDelay = 0,
) {
  if (formatted == null) return null;
  const charCount = [formatted.value, formatted.unit, formatted.secondary].filter(Boolean).join(' ').length;
  return (
    <>
      <dt>{label}</dt>
      <dd>
        <span
          className="tw"
          style={{ '--tw-chars': charCount, '--tw-delay': rowIndex, '--section-delay': `${sectionDelay}ms` } as React.CSSProperties}
        >
          {formatted.value}
          {formatted.unit && <span style={{ color: 'var(--fg-muted)' }}> {formatted.unit}</span>}
          {formatted.secondary && <span style={{ color: 'var(--fg-muted)', fontSize: '0.85rem' }}> {formatted.secondary}</span>}
        </span>
      </dd>
    </>
  );
}

function fmtRow(label: string, value: number | null, unit: string, suffix = '', rowIndex = 0, sectionDelay = 0) {
  if (value == null) return null;
  const numStr = Number.isInteger(value) ? String(value) : value.toPrecision(4);
  const charCount = [numStr, unit, suffix].filter(Boolean).join(' ').length;
  return (
    <>
      <dt>{label}</dt>
      <dd>
        <span
          className="tw"
          style={{ '--tw-chars': charCount, '--tw-delay': rowIndex, '--section-delay': `${sectionDelay}ms` } as React.CSSProperties}
        >
          {numStr}
          {unit && <span style={{ color: 'var(--fg-muted)' }}> {unit}</span>}
          {suffix && <span style={{ color: 'var(--fg-muted)', fontSize: '0.85rem' }}> {suffix}</span>}
        </span>
      </dd>
    </>
  );
}
