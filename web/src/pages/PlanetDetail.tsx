import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { api, type BinaryCompanion, type DerivedMeasurementRow, type DiscoveryPaper, type HostStarGaia, type PlanetAtmosphereResponse, type PlanetDetail as PlanetDetailType, type PlanetHistoryResponse, type PlanetPublication, type PlanetsListResponse, type SySnumAudit } from '../api';
import GalaxyMap from '../components/GalaxyMap';
import LoadingBar from '../components/LoadingBar';
import PlanetCard from '../components/PlanetCard';
import { collectFacts } from '../lib/derived';
import { formatMass, formatRadius, formatTemperature, humanizeHours, useUnitsMode, type Formatted, type UnitsMode } from '../lib/units';
import { plainText } from '../lib/html';
import { fmtMeasure, isCompositionQuantity, quantityLabel } from '../lib/composition';

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
  const [sySnumAudit, setSySnumAudit] = useState<SySnumAudit | null>(null);
  const [atmosphere, setAtmosphere] = useState<PlanetAtmosphereResponse | null>(null);
  const [derived, setDerived] = useState<DerivedMeasurementRow[] | null>(null);
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
    setSySnumAudit(null);
    setAtmosphere(null);
    setDerived(null);
    setError(null);
    api.planetDetail(plName).then(setPlanet).catch((e) => setError(e.message));
    api.planetHistory(plName).then(setHistory).catch(() => {});
    api.planetHostStar(plName).then(setHostStar).catch(() => {});
    api.planetPaper(plName).then(setPaper).catch(() => {});
    api.planetPublications(plName).then((r) => setPublications(r.publications)).catch(() => {});
    api.planetCompanions(plName).then(setCompanions).catch(() => {});
    // 404 = no disagreement on file (common case), swallow silently.
    api.planetSySnumAudit(plName).then(setSySnumAudit).catch(() => {});
    api.planetAtmosphere(plName).then(setAtmosphere).catch(() => {});
    api.derivedMeasurements(plName).then((r) => setDerived(r.rows)).catch(() => {});
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
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '1rem', flexWrap: 'wrap' }}>
        <div style={{ minWidth: 0 }}>
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
        </div>
        <div style={{ flexShrink: 0 }}>
          <UnitsToggle mode={unitsMode} setMode={setUnitsMode} />
        </div>
      </div>

      <div className="planet-detail">
        <div className="planet-detail-left">
          <PlanetCard
            planet={planet}
            siblings={siblings?.results.filter((s) => s.pl_name !== planet.pl_name) ?? null}
            bp_rp={hostStar?.bp_rp}
            companions={companions ?? undefined}
            distancePc={hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? planet.distance_manual_pc ?? null}
          />
          <HostStarCard planet={planet} sectionDelay={4000} />
        </div>

        <div>
          <section>
            <h2>Stat card</h2>
            <div className="card">
              <dl className="stat-grid">
                {fmtRow('Distance from host star', planet.pl_orbsmax, 'AU', '', 0)}
                {fmtRowDisplay('Orbital period', humanizeHours(planet.pl_orbper != null ? planet.pl_orbper * 24 : null), 1)}
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

          <BeyondBasicsCard planet={planet} unitsMode={unitsMode} sectionDelay={2200} />

          <SystemSiblingsSection planet={planet} siblings={siblings} />

          <CompanionsSection planet={planet} companions={companions} hostStar={hostStar} sySnumAudit={sySnumAudit} />

          <AtmosphereSection planet={planet} atmosphere={atmosphere} />

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
                const pc = hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? planet.distance_manual_pc ?? null;
                if (pc == null) return null;
                const ly = pc * 3.2616;
                const isManual = hostStar?.distance_gspphot_pc == null && planet.sy_dist == null && planet.distance_manual_pc != null;
                return (
                  <p style={{ margin: '0.5rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
                    {ly < 100
                      ? <><strong>{ly.toFixed(1)} light-years</strong> away ({pc.toFixed(1)} pc)</>
                      : ly < 10000
                      ? <><strong>{Math.round(ly).toLocaleString()} light-years</strong> away ({Math.round(pc).toLocaleString()} pc)</>
                      : <><strong>{(ly / 1000).toFixed(1)}k light-years</strong> away ({Math.round(pc).toLocaleString()} pc)</>
                    }
                    {hostStar?.distance_gspphot_pc != null && <> · via Gaia DR3</>}
                    {isManual && (
                      <> · literature distance{planet.distance_manual_source && (
                        <> (<a
                          href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(planet.distance_manual_source)}/abstract`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title={`Source on NASA ADS: ${planet.distance_manual_source}`}
                        >{planet.distance_manual_source}</a>)</>
                      )}</>
                    )}
                  </p>
                );
              })()}
              {planet.ra != null && planet.dec != null && (() => {
                const pc = hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? planet.distance_manual_pc ?? null;
                if (pc == null) return null;
                return <GalaxyMap ra={planet.ra} dec={planet.dec} distPc={pc} hostname={planet.hostname} />;
              })()}
            </div>
          </section>

          <DiscoverySection planet={planet} paper={paper} publications={publications} sectionDelay={1200} />

          <CompositionSection rows={derived} />

          <ReferencesSection publications={publications} />
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
  // Dedupe — the underlying /api/planets/{name}/publications query uses array_agg without
  // DISTINCT, so a planet linked to one publication via multiple planet_publications rows
  // (e.g. role 'announce' AND role 'follow-up') shows up twice. React then warns about
  // duplicate keys.
  const coPlanets = (() => {
    if (!paper || !publications) return [];
    const match = publications.find((p) => p.bibcode === paper.bibcode);
    if (!match?.co_planets) return [];
    return Array.from(new Set(match.co_planets));
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
                  {plainText(paper.title) || paper.bibcode}
                </a>
              ) : (plainText(paper.title) || paper.bibcode)}
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
              const abstract = plainText(paper.abstract);
              const truncated = abstract.length > LIMIT;
              const displayText = abstractExpanded || !truncated
                ? abstract
                : abstract.slice(0, LIMIT).trimEnd() + '…';
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
              {adsUrl && <a href={adsUrl} target="_blank" rel="noopener noreferrer">ADS</a>}
              {paper.doi && (
                <a href={`https://doi.org/${paper.doi}`} target="_blank" rel="noopener noreferrer">DOI</a>
              )}
              {paper.arxiv_id && (
                <a href={`https://arxiv.org/abs/${paper.arxiv_id}`} target="_blank" rel="noopener noreferrer">arXiv</a>
              )}
            </div>
          </div>
        ) : ref ? (
          <p style={{ margin: 0, fontSize: '0.9rem' }}>
            <strong>Reference:</strong>{' '}
            {ref.url ? (
              <a href={ref.url} target="_blank" rel="noopener noreferrer">{plainText(ref.text)}</a>
            ) : (
              <span style={{ color: 'var(--fg-muted)' }}>{plainText(ref.text)}</span>
            )}
          </p>
        ) : null}
      </div>
    </section>
  );
}

// Literature-derived scalar properties (planet_derived_measurements): interior
// composition, elemental abundances, metal budgets. Renders nothing for planets
// with no curated measurements. Source paper is also in the citation graph below.
function CompositionSection({ rows }: { rows: DerivedMeasurementRow[] | null }) {
  // Filter to actual composition-type quantities — dynamical rows (obliquity,
  // rotation, etc.) appear on the scene page, not in this section.
  const compositionRows = rows?.filter((r) => isCompositionQuantity(r.quantity)) ?? null;
  if (!compositionRows || compositionRows.length === 0) return null;
  const adsUrl = (b: string) => `https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(b)}/abstract`;
  return (
    <section style={{ marginTop: '2rem' }}>
      <h2>Composition &amp; abundances</h2>
      <div className="card">
        <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>
          Literature-derived values, each with its asymmetric uncertainty, the modelling assumption it
          depends on, and the source paper. Interior fractions are degenerate with water content;
          abundances are relative to solar.
        </p>
        <table className="history-table">
          <thead>
            <tr>
              <th scope="col">Property</th>
              <th scope="col">Value</th>
              <th scope="col">Model</th>
              <th scope="col">Source</th>
            </tr>
          </thead>
          <tbody>
            {compositionRows.map((r, i) => (
              // The DB PK is (pl_name, quantity, bibcode), so multiple rows
              // for the same quantity from different papers are allowed.
              // Include bibcode (or row index when bibcode is null) so React
              // does not collide keys and re-use the wrong rows.
              <tr key={`${r.quantity}|${r.bibcode ?? i}`}>
                <td title={r.curator_note ?? undefined}>{quantityLabel(r.quantity)}</td>
                <td style={{ whiteSpace: 'nowrap' }}>{fmtMeasure(r)}</td>
                <td style={{ color: 'var(--fg-muted)', fontSize: '0.85rem' }}>{r.model ?? ''}</td>
                <td>{r.bibcode ? <a href={adsUrl(r.bibcode)} target="_blank" rel="noopener noreferrer" title={r.bibcode}>ADS</a> : ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

// Non-discovery publications grouped by role. These credit the papers the audit
// drew data from beyond the discovery announcement, honoring the rule that any
// data point harvested from an additional paper must also cite that paper.
const REFERENCE_ROLE_META: { role: string; label: string; blurb: string }[] = [
  { role: 'characterization', label: 'Characterization', blurb: 'measured parameters this catalog drew from' },
  { role: 'prior_detection', label: 'Prior detection', blurb: 'reported the planet or its host before the discovery paper' },
  { role: 'follow_up', label: 'Follow-up', blurb: 'refined or confirmed the discovery' },
];

function ReferencesSection({ publications }: { publications: PlanetPublication[] | null }) {
  const location = useLocation();
  const themeQuery = (() => { const t = new URLSearchParams(location.search).get('theme'); return t ? `?theme=${t}` : ''; })();
  if (!publications) return null;
  const refs = publications.filter((p) => p.role !== 'discovery');
  if (refs.length === 0) return null;

  const known = new Set(REFERENCE_ROLE_META.map((m) => m.role));
  const groups = REFERENCE_ROLE_META
    .map((meta) => ({ ...meta, items: refs.filter((p) => p.role === meta.role) }))
    .filter((g) => g.items.length > 0);
  // Surface any unexpected role rather than silently dropping it.
  const extra = refs.filter((p) => !known.has(p.role));
  if (extra.length > 0) groups.push({ role: 'other', label: 'Other', blurb: 'additional linked publications', items: extra });

  return (
    <section style={{ marginTop: '2rem' }}>
      <h2>Citations &amp; references</h2>
      <p style={{ margin: '0 0 1rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.55, maxWidth: '60ch' }}>
        Papers beyond the discovery announcement that this catalog draws data from. Each is credited for what it contributed.
      </p>
      {groups.map((g) => (
        <div key={g.role} style={{ marginBottom: '1.25rem' }}>
          <h3 style={{ margin: '0 0 0.5rem', fontSize: '0.95rem' }}>
            {g.label}{' '}
            <span style={{ fontWeight: 400, fontSize: '0.8rem', color: 'var(--fg-muted)' }}>· {g.blurb}</span>
          </h3>
          {g.items.map((p) => <ReferenceCard key={`${p.pub_id}-${p.role}`} pub={p} themeQuery={themeQuery} />)}
        </div>
      ))}
    </section>
  );
}

function ReferenceCard({ pub, themeQuery }: { pub: PlanetPublication; themeQuery: string }) {
  const [authorsExpanded, setAuthorsExpanded] = useState(false);
  const [abstractExpanded, setAbstractExpanded] = useState(false);
  const adsUrl = pub.bibcode ? `https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(pub.bibcode)}/abstract` : null;
  const meta = [pub.journal, pub.pub_date?.slice(0, 4)].filter(Boolean).join(' · ');

  return (
    <div className="card" style={{ marginBottom: '0.6rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', alignItems: 'flex-start' }}>
        <p style={{ margin: '0 0 0.25rem', fontWeight: 600, fontSize: '0.92rem', lineHeight: 1.4 }}>
          {adsUrl ? (
            <a href={adsUrl} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--fg)' }}>
              {plainText(pub.title) || pub.bibcode}
            </a>
          ) : (plainText(pub.title) || pub.bibcode || 'Untitled')}
        </p>
        {pub.contribution && (
          <span style={{ flexShrink: 0, fontSize: '0.72rem', color: 'var(--fg-muted)', border: '1px solid var(--border)', borderRadius: '999px', padding: '0.1rem 0.5rem', whiteSpace: 'nowrap' }}>
            {pub.contribution.replace(/_/g, ' ')}
          </span>
        )}
      </div>

      {pub.authors.length > 0 && (() => {
        const PREVIEW = 5;
        const shown = authorsExpanded ? pub.authors : pub.authors.slice(0, PREVIEW);
        const hidden = pub.authors.length - PREVIEW;
        return (
          <p style={{ margin: '0 0 0.35rem', fontSize: '0.82rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
            {shown.map((author, i) => (
              <span key={author}>
                {i > 0 && ', '}
                <Link to={`/authors/${encodeURIComponent(author)}${themeQuery}`} style={{ color: 'var(--fg-muted)' }}>
                  {author}
                </Link>
              </span>
            ))}
            {!authorsExpanded && hidden > 0 && (
              <>
                {', '}
                <button onClick={() => setAuthorsExpanded(true)} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.82rem', color: 'var(--accent)' }}>
                  +{hidden} more
                </button>
              </>
            )}
            {authorsExpanded && hidden > 0 && (
              <>
                {' '}
                <button onClick={() => setAuthorsExpanded(false)} style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)' }}>
                  show less
                </button>
              </>
            )}
          </p>
        );
      })()}

      {(meta || pub.citation_count != null) && (
        <p style={{ margin: '0 0 0.5rem', fontSize: '0.8rem', color: 'var(--fg-muted)' }}>
          {meta}
          {pub.citation_count != null && (
            <>{meta ? ' · ' : ''}<strong style={{ color: 'var(--fg)' }}>{pub.citation_count.toLocaleString()}</strong> citations</>
          )}
        </p>
      )}

      {pub.abstract && (() => {
        const LIMIT = 300;
        const abstract = plainText(pub.abstract);
        const truncated = abstract.length > LIMIT;
        const displayText = abstractExpanded || !truncated
          ? abstract
          : abstract.slice(0, LIMIT).trimEnd() + '…';
        return (
          <div style={{ margin: '0 0 0.6rem' }}>
            <p style={{ margin: 0, fontSize: '0.82rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>{displayText}</p>
            {truncated && (
              <button onClick={() => setAbstractExpanded((e) => !e)} style={{ background: 'none', border: 'none', padding: '0.2rem 0', cursor: 'pointer', fontSize: '0.8rem', color: 'var(--accent)', marginTop: '0.2rem' }}>
                {abstractExpanded ? 'show less' : 'show more…'}
              </button>
            )}
          </div>
        );
      })()}

      <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', fontSize: '0.8rem' }}>
        {adsUrl && <a href={adsUrl} target="_blank" rel="noopener noreferrer">ADS</a>}
        {pub.doi && <a href={`https://doi.org/${pub.doi}`} target="_blank" rel="noopener noreferrer">DOI</a>}
        {pub.arxiv_id && <a href={`https://arxiv.org/abs/${pub.arxiv_id}`} target="_blank" rel="noopener noreferrer">arXiv</a>}
      </div>
    </div>
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

function BeyondBasicsCard({ planet, unitsMode, sectionDelay = 0 }: { planet: PlanetDetailType; unitsMode: UnitsMode; sectionDelay?: number }) {
  const facts = collectFacts(planet, unitsMode);
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
  planet, companions, hostStar, sySnumAudit,
}: {
  planet: PlanetDetailType;
  companions: BinaryCompanion[] | null;
  hostStar: HostStarGaia | null;
  sySnumAudit: SySnumAudit | null;
}) {
  // The audit-only case: NASA EA reports multiplicity that primary literature
  // doesn't support (e.g. HD 113337), so there are zero companion rows but
  // we still want to surface our disagreement. Render the section with just
  // the audit footnote.
  if ((!companions || companions.length === 0) && !sySnumAudit) return null;
  const distance_pc = hostStar?.distance_gspphot_pc ?? planet.sy_dist ?? planet.distance_manual_pc ?? null;
  const hasCompanions = (companions ?? []).length > 0;
  return (
    <section>
      <h2>System stars</h2>
      <div className="card">
        {hasCompanions ? (
          <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
            {planet.cb_flag === 1 ? (
              <>
                <strong>{planet.pl_name}</strong> is circumbinary — it orbits the close{' '}
                <strong>{planet.hostname}</strong> inner pair, not a single primary star.
                {' '}{companions!.length === 1
                  ? 'One additional stellar component is recorded'
                  : `${companions!.length} additional stellar components are recorded`}
                {' '}in this system; the inner-binary partner is one of them.
              </>
            ) : (
              <>
                <strong>{planet.pl_name}</strong> orbits the primary star <strong>{planet.hostname}</strong> only.
                {' '}{companions!.length === 1
                  ? 'One additional stellar component is recorded'
                  : `${companions!.length} additional stellar components are recorded`}
                {' '}in this system — they sit far enough from the planet's orbit not to disturb it,
                but they're part of the same gravitationally bound family.
              </>
            )}
          </p>
        ) : (
          <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
            <strong>{planet.pl_name}</strong> orbits the primary star <strong>{planet.hostname}</strong>.
            No additional stellar components are characterized in the primary literature.
          </p>
        )}
        {sySnumAudit && (
          <div
            style={{
              margin: '0 0 0.75rem',
              padding: '0.6rem 0.75rem',
              borderLeft: '3px solid var(--tier-b)',
              background: 'rgba(255, 200, 100, 0.05)',
              fontSize: '0.78rem',
              color: 'var(--fg-muted)',
              lineHeight: 1.55,
            }}
          >
            <strong style={{ color: 'var(--fg)', display: 'block', marginBottom: '0.2rem' }}>
              Disagreement with NASA Exoplanet Archive
            </strong>
            NASA EA reports <code>sy_snum = {sySnumAudit.nasa_ea_sy_snum}</code> for this system;
            this atlas records <code>{sySnumAudit.supported_sy_snum}</code> based on primary
            literature. {sySnumAudit.rationale}
            <div style={{ marginTop: '0.4rem' }}>
              <span style={{ marginRight: '0.3rem' }}>Cited:</span>
              {sySnumAudit.source_bibcodes.map((b, i) => (
                <span key={b}>
                  {i > 0 && ', '}
                  <a
                    href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(b)}/abstract`}
                    target="_blank"
                    rel="noopener noreferrer"
                    title={`Source on NASA ADS: ${b}`}
                  >{b}</a>
                </span>
              ))}
            </div>
          </div>
        )}
        {hasCompanions && (
        <ul className="siblings-list">
          {companions!.map((c) => {
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
                  {c.inner_binary
                    ? <> · <span style={{ color: 'var(--accent)' }}>inner-binary partner</span> ({planet.pl_name} orbits both)</>
                    : (
                      <>
                        {sepAU != null && <> · ~{sepAU >= 10 ? sepAU.toFixed(0) : sepAU.toFixed(1)} AU projected</>}
                        {c.position_angle_deg != null && <> · PA {c.position_angle_deg.toFixed(0)}°</>}
                        {insideOrbit && <> · <span style={{ color: 'var(--tier-b)' }}>inside {planet.pl_name}'s orbit</span></>}
                      </>
                    )}
                  {c.source_catalog && <> · {c.source_catalog}</>}
                  {c.source_bibcode && (
                    <> · <a
                      href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(c.source_bibcode)}/abstract`}
                      target="_blank"
                      rel="noopener noreferrer"
                      title={`Source paper on NASA ADS: ${c.source_bibcode}`}
                    >{c.source_bibcode}</a></>
                  )}
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
        )}
        {hasCompanions && (
          <p style={{ margin: '0.75rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
            "Projected" separation is what we measure on the sky (angular separation × system distance).
            The true 3D distance is at least this — possibly more, depending on the unknown line-of-sight component.
          </p>
        )}
      </div>
    </section>
  );
}

function AtmosphereSection({
  planet, atmosphere,
}: {
  planet: PlanetDetailType;
  atmosphere: PlanetAtmosphereResponse | null;
}) {
  if (!atmosphere) return null;
  const { observations, detections } = atmosphere;
  if (observations.length === 0 && detections.length === 0) return null;
  return (
    <section>
      <h2>Atmosphere</h2>
      <div className="card">
        <p style={{ margin: '0 0 0.75rem', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
          Atmospheric work that has been done on <strong>{planet.pl_name}</strong>.
          Each entry links to its source paper on NASA ADS.
        </p>
        {detections.length > 0 && (
          <div style={{ marginBottom: observations.length > 0 ? '1rem' : 0 }}>
            <h3 style={{ margin: '0 0 0.4rem', fontSize: '0.95rem' }}>
              Molecule detections ({detections.length})
            </h3>
            <ul className="siblings-list">
              {detections.map((d) => (
                <li key={`${d.molecule}|${d.bibcode ?? ''}`}>
                  <strong>{d.molecule}</strong>
                  <span className="muted">
                    {' · '}<span style={{
                      color: d.detection === 'detected'
                        ? 'var(--accent)'
                        : d.detection === 'tentative'
                          ? 'var(--tier-b)'
                          : 'var(--fg-muted)'
                    }}>{d.detection}</span>
                    {d.instrument && <> · {d.instrument}</>}
                    {d.confidence_sigma != null && <> · {d.confidence_sigma.toFixed(1)}σ</>}
                    {d.bibcode && (
                      <> · <a
                        href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(d.bibcode)}/abstract`}
                        target="_blank"
                        rel="noopener noreferrer"
                        title={`Source paper on NASA ADS: ${d.bibcode}`}
                      >{d.bibcode}</a></>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
        {observations.length > 0 && (
          <div>
            <h3 style={{ margin: '0 0 0.4rem', fontSize: '0.95rem' }}>
              Observation campaigns ({observations.length})
            </h3>
            <ul className="siblings-list">
              {observations.map((o, i) => (
                <li key={`${o.bibcode ?? i}|${o.instrument ?? ''}|${o.spec_type ?? ''}`}>
                  <strong>{o.instrument ?? o.facility ?? 'Observation'}</strong>
                  <span className="muted">
                    {o.spec_type && <> · {o.spec_type}</>}
                    {o.facility && o.facility !== o.instrument && <> · {o.facility}</>}
                    {o.min_wavelength_um != null && o.max_wavelength_um != null && (
                      <> · {o.min_wavelength_um.toFixed(2)}-{o.max_wavelength_um.toFixed(2)} μm</>
                    )}
                    {o.bibcode && (
                      <> · <a
                        href={`https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(o.bibcode)}/abstract`}
                        target="_blank"
                        rel="noopener noreferrer"
                        title={`Source paper on NASA ADS: ${o.bibcode}`}
                      >{o.bibcode}</a></>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
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
