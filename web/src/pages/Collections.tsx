import { useEffect, useState, type CSSProperties, type ReactNode } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { api, type AtmosphereRow, type DerivedMeasurementRow, type InnerBinaryRow, type PlanetSummary, type SystemGeometryRow, type TopAuthor } from '../api';
import { COLLECTION_BY_KEY, type Collection } from '../lib/collections';
import LoadingBar from '../components/LoadingBar';
import { fmtMeasure, quantityLabel } from '../lib/composition';

// Curated from the cb_flag audit: the three microlensing entries whose published
// solutions do not unambiguously place the planet outside both stars. (The audit
// verdict is not a queryable column, so this short list is hand-maintained.)
const CB_REVIEW_CANDIDATES = new Set([
  'KMT-2016-BLG-1337L b',
  'OGLE-2018-BLG-1700L b',
  'OGLE-2019-BLG-1470L AB c',
]);

// ~13 M_Jup deuterium-burning limit, in Earth masses (1 M_Jup ~ 317.8 M_Earth).
const BD_LIMIT_MEARTH = 4131;
const MEARTH_PER_MJUP = 317.8;
const PAGE_SIZE = 50;

// Discovery-method abbreviations (NASA EA has 11). Keeps the column narrow; the
// full name shows on hover and a key is rendered under the table.
const METHOD_ABBR: Record<string, string> = {
  'Radial Velocity': 'RV',
  'Transit': 'Tr',
  'Microlensing': 'ML',
  'Imaging': 'Im',
  'Transit Timing Variations': 'TTV',
  'Eclipse Timing Variations': 'ETV',
  'Orbital Brightness Modulation': 'OBM',
  'Pulsar Timing': 'PT',
  'Astrometry': 'Ast',
  'Pulsation Timing Variations': 'PTV',
  'Disk Kinematics': 'DK',
};

const adsUrl = (bibcode: string) => `https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(bibcode)}/abstract`;

// Planet-list collections: key -> how to fetch its members.
const PLANET_FETCHERS: Record<string, () => Promise<PlanetSummary[]>> = {
  circumbinary: () => api.planetsList({ cb_flag: 1, limit: 200 }).then((r) => r.results),
  boundary: () => api.planetsList({ min_mass: BD_LIMIT_MEARTH, limit: 200 }).then((r) => r.results),
  'multi-planet': () => api.planetsList({ sy_pnum_min: 6, limit: 200 }).then((r) => r.results),
  'triple-star': () => api.planetsList({ sy_snum_min: 3, limit: 200 }).then((r) => r.results),
  eccentric: () => api.planetsList({ min_eccen: 0.5, limit: 200 }).then((r) => r.results),
  contested: () => api.planetsList({ multi_paper: true, limit: 200 }).then((r) => r.results),
};

export default function Collections() {
  const { key = '' } = useParams<{ key: string }>();
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  const collection = COLLECTION_BY_KEY[key];

  const [members, setMembers] = useState<PlanetSummary[] | null>(null);
  const [authors, setAuthors] = useState<TopAuthor[] | null>(null);
  const [geometry, setGeometry] = useState<SystemGeometryRow[] | null>(null);
  const [innerBinaries, setInnerBinaries] = useState<Map<string, InnerBinaryRow> | null>(null);
  const [atmospheres, setAtmospheres] = useState<AtmosphereRow[] | null>(null);
  const [derived, setDerived] = useState<DerivedMeasurementRow[] | null>(null);

  useEffect(() => {
    setMembers(null);
    setAuthors(null);
    setGeometry(null);
    setInnerBinaries(null);
    setAtmospheres(null);
    setDerived(null);
    if (key === 'atmospheres') {
      api.atmospheres().then((r) => setAtmospheres(r.rows)).catch(() => setAtmospheres([]));
      return;
    }
    if (key === 'composition') {
      api.derivedMeasurements().then((r) => setDerived(r.rows)).catch(() => setDerived([]));
      return;
    }
    if (key === 'top-discoverers') {
      api.authorsTop(50).then((r) => setAuthors(r.authors)).catch(() => setAuthors([]));
      return;
    }
    if (key === 'architecture-3d') {
      api.systemGeometry().then((r) => setGeometry(r.rows)).catch(() => setGeometry([]));
      return;
    }
    const fetcher = PLANET_FETCHERS[key];
    if (fetcher) {
      fetcher().then(setMembers).catch(() => setMembers([]));
      // Circumbinary also shows the inner-binary (two-star) data, keyed by host.
      if (key === 'circumbinary') {
        api.innerBinaries()
          .then((r) => setInnerBinaries(new Map(r.rows.map((ib) => [ib.hostname, ib]))))
          .catch(() => setInnerBinaries(new Map()));
      }
    }
  }, [key]);

  if (!collection) {
    return (
      <>
        <p style={{ margin: '0 0 1rem' }}><Link to={`/${themeQuery}`}>← back</Link></p>
        <h1>Collection not found</h1>
        <p style={{ color: 'var(--fg-muted)' }}>There is no collection named "{key}".</p>
      </>
    );
  }

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}><Link to={`/${themeQuery}`}>← back</Link></p>
      <CollectionBanner collection={collection} />
      <h1 style={{ margin: '0 0 0.5rem' }}>{collection.label}</h1>
      <p style={{ margin: '0 0 1.75rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>{collection.blurb}</p>
      <CollectionBody
        collKey={key}
        members={members}
        authors={authors}
        geometry={geometry}
        innerBinaries={innerBinaries}
        atmospheres={atmospheres}
        derived={derived}
        themeQuery={themeQuery}
      />
    </>
  );
}

// Reuses the filmstrip's /featured/<key>.jpg as a wide page banner (object-fit
// cover crops the 16:9 source to a strip). Visual collections only; if the image
// is not present yet, the banner quietly removes itself.
function CollectionBanner({ collection }: { collection: Collection }) {
  const [failed, setFailed] = useState(false);
  const [hover, setHover] = useState(false);
  if (collection.kind !== 'visual' || failed) return null;
  const credit = collection.imageCredit;
  return (
    <figure
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{ position: 'relative', margin: '0 0 1.25rem', borderRadius: 10, overflow: 'hidden', border: '1px solid var(--border)' }}
    >
      <img
        src={`/featured/${collection.key}.jpg`}
        alt={`${collection.label}, featured visualization`}
        onError={() => setFailed(true)}
        style={{ width: '100%', aspectRatio: '3 / 1', objectFit: 'cover', objectPosition: 'center', display: 'block' }}
      />
      {credit && (
        <figcaption
          style={{
            position: 'absolute', left: 0, right: 0, bottom: 0,
            padding: '0.55rem 0.85rem', fontSize: '0.8rem', color: '#fff',
            background: 'linear-gradient(to top, rgba(0,0,0,0.72), transparent)',
            opacity: hover ? 1 : 0, transition: 'opacity 0.18s ease', pointerEvents: 'none',
          }}
        >
          Pictured: <strong>{credit}</strong>
        </figcaption>
      )}
    </figure>
  );
}

// Fades the data in on load. Themed-gated in CSS (.collection-reveal), so it
// matches the planet-page typewriter convention: animates only under a theme,
// instant in the default theme.
function Reveal({ children }: { children: ReactNode }) {
  return <div className="collection-reveal">{children}</div>;
}

function CollectionBody({ collKey, members, authors, geometry, innerBinaries, atmospheres, derived, themeQuery }: {
  collKey: string;
  members: PlanetSummary[] | null;
  authors: TopAuthor[] | null;
  geometry: SystemGeometryRow[] | null;
  innerBinaries: Map<string, InnerBinaryRow> | null;
  atmospheres: AtmosphereRow[] | null;
  derived: DerivedMeasurementRow[] | null;
  themeQuery: string;
}) {
  if (collKey === 'top-discoverers') return <AuthorList authors={authors} themeQuery={themeQuery} />;
  if (collKey === 'atmospheres') return <AtmosphereTable rows={atmospheres} themeQuery={themeQuery} />;
  if (collKey === 'composition') return <CompositionTable rows={derived} themeQuery={themeQuery} />;
  if (collKey === 'data-quality') return <DataQualityTable themeQuery={themeQuery} />;
  if (collKey === 'beyond-archive') return <BeyondArchiveList themeQuery={themeQuery} />;

  if (collKey === 'architecture-3d') {
    if (geometry === null) return <LoadingBar loading={true} />;
    if (geometry.length === 0) return <p style={{ color: 'var(--fg-muted)' }}>No measured architectures found.</p>;
    const systems = new Set(geometry.map((g) => g.hostname)).size;
    return (
      <Reveal>
        <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
          <strong style={{ color: 'var(--fg)' }}>{geometry.length}</strong> measured orbit inclinations across{' '}
          <strong style={{ color: 'var(--fg)' }}>{systems}</strong> systems, most misaligned first. Each is the angle
          between a planet's orbit and its system's reference plane, with the measurement method and source.
        </p>
        <GeometryTable rows={geometry} themeQuery={themeQuery} />
      </Reveal>
    );
  }

  if (PLANET_FETCHERS[collKey]) {
    if (members === null) return <LoadingBar loading={true} />;
    if (members.length === 0) return <p style={{ color: 'var(--fg-muted)' }}>No entries found.</p>;
    const candidates = collKey === 'circumbinary'
      ? members.filter((m) => CB_REVIEW_CANDIDATES.has(m.pl_name))
      : [];
    const ib = innerBinaries ?? new Map<string, InnerBinaryRow>();
    const columns = columnsFor(collKey, themeQuery, ib);
    const defaultSort = defaultSortFor(collKey);
    return (
      <Reveal>
        <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
          <strong style={{ color: 'var(--fg)' }}>{members.length}</strong> {countNoun(collKey)}.
        </p>

        {candidates.length > 0 && (
          <div className="card" style={{ margin: '0 0 1.5rem', borderColor: 'var(--tier-a)' }}>
            <strong>Flag-review candidates</strong>
            <p style={{ margin: '0.4rem 0 0.6rem', fontSize: '0.85rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>
              These (all microlensing) have published solutions that do not unambiguously place the planet
              outside both stars, the strongest candidates for a cb_flag review.
            </p>
            <ul style={{ margin: 0, paddingLeft: '1.2rem', display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
              {candidates.map((c) => (
                <li key={c.pl_name}>
                  <Link to={`/planets/${encodeURIComponent(c.pl_name)}${themeQuery}`}>{c.pl_name}</Link>
                </li>
              ))}
            </ul>
          </div>
        )}

        <PlanetTable members={members} columns={columns} defaultSort={defaultSort} legend />
      </Reveal>
    );
  }

  return (
    <p style={{ color: 'var(--fg-muted)', fontStyle: 'italic', lineHeight: 1.6 }}>
      The member list for this collection is being wired up. The page framework and description are in
      place; the data query is the next step.
    </p>
  );
}

function countNoun(collKey: string): string {
  if (collKey === 'circumbinary') return 'planets carry cb_flag = 1';
  if (collKey === 'boundary') return 'planets are at or above the ~13 M_Jup deuterium-burning limit';
  if (collKey === 'multi-planet') return 'planets in systems of six or more';
  if (collKey === 'triple-star') return 'planets in systems of three or more stars';
  if (collKey === 'eccentric') return 'planets on strongly elongated orbits (e ≥ 0.5)';
  if (collKey === 'contested') return 'planets are linked to more than one paper';
  return 'planets';
}

// ---- planet table: a small column registry so each collection picks its columns ----

type PlanetSortKey = 'pl_name' | 'hostname' | 'discoverymethod' | 'disc_year' | 'pl_bmasse' | 'pl_orbsmax' | 'pl_rade' | 'pl_orbeccen' | 'sy_pnum' | 'sy_snum' | 'disc_paper_citations';
type ColSpec = { label: string; sortKey?: PlanetSortKey; render: (m: PlanetSummary) => ReactNode };

// Each planet-list collection picks its own columns + default sort so the table
// shows the data that defines that population, not a generic planet dump.
function columnsFor(collKey: string, themeQuery: string, ib: Map<string, InnerBinaryRow>): ColSpec[] {
  switch (collKey) {
    case 'circumbinary':
      return [colPlanet(themeQuery), COL_HOST, colInnerPair(ib), COL_DISTANCE, COL_METHOD, colInnerSource(ib)];
    case 'boundary':
      return [colPlanet(themeQuery), COL_HOST, COL_MASS_JUP, COL_RADIUS, COL_METHOD, COL_YEAR];
    case 'multi-planet':
      return [colPlanet(themeQuery), COL_HOST, COL_PNUM, COL_DISTANCE, COL_METHOD, COL_YEAR];
    case 'triple-star':
      return [colPlanet(themeQuery), COL_HOST, COL_SNUM, COL_DISTANCE, COL_METHOD, COL_YEAR];
    case 'eccentric':
      return [colPlanet(themeQuery), COL_HOST, COL_ECCEN, COL_DISTANCE, COL_METHOD, COL_YEAR];
    case 'contested':
      return [colPlanet(themeQuery), COL_HOST, COL_METHOD, COL_YEAR, COL_CITATIONS];
    default:
      return [colPlanet(themeQuery), COL_HOST, COL_DISTANCE, COL_MASS_EARTH, COL_METHOD, COL_YEAR];
  }
}

function defaultSortFor(collKey: string): { key: PlanetSortKey; dir: 1 | -1 } {
  switch (collKey) {
    case 'boundary': return { key: 'pl_bmasse', dir: -1 };
    case 'multi-planet': return { key: 'sy_pnum', dir: -1 };
    case 'triple-star': return { key: 'sy_snum', dir: -1 };
    case 'eccentric': return { key: 'pl_orbeccen', dir: -1 };
    case 'contested': return { key: 'disc_paper_citations', dir: -1 };
    default: return { key: 'pl_name', dir: 1 };
  }
}

const fmtAU = (n: number) => n.toLocaleString(undefined, { maximumFractionDigits: 2 });
const fmtMsun = (n: number) => n.toLocaleString(undefined, { maximumSignificantDigits: 3 });

const colPlanet = (tq: string): ColSpec => ({
  label: 'Planet',
  sortKey: 'pl_name',
  render: (m) => <Link to={`/planets/${encodeURIComponent(m.pl_name)}${tq}`}>{m.pl_name}</Link>,
});
const COL_HOST: ColSpec = { label: 'Host', sortKey: 'hostname', render: (m) => m.hostname };
const COL_METHOD: ColSpec = {
  label: 'Method',
  sortKey: 'discoverymethod',
  render: (m) => (m.discoverymethod
    ? <span title={m.discoverymethod}>{METHOD_ABBR[m.discoverymethod] ?? m.discoverymethod}</span>
    : ''),
};
const COL_YEAR: ColSpec = { label: 'Year', sortKey: 'disc_year', render: (m) => m.disc_year ?? '' };
const COL_DISTANCE: ColSpec = { label: 'Distance (AU)', sortKey: 'pl_orbsmax', render: (m) => (m.pl_orbsmax != null ? fmtAU(m.pl_orbsmax) : '') };
const COL_MASS_EARTH: ColSpec = { label: 'Mass (M⊕)', sortKey: 'pl_bmasse', render: (m) => (m.pl_bmasse != null ? Math.round(m.pl_bmasse).toLocaleString() : '') };
const COL_MASS_JUP: ColSpec = { label: 'Mass (M_Jup)', sortKey: 'pl_bmasse', render: (m) => (m.pl_bmasse != null ? (m.pl_bmasse / MEARTH_PER_MJUP).toFixed(1) : '') };
const COL_RADIUS: ColSpec = { label: 'Radius (R⊕)', sortKey: 'pl_rade', render: (m) => (m.pl_rade != null ? m.pl_rade.toPrecision(3) : '') };
const COL_ECCEN: ColSpec = { label: 'Eccentricity', sortKey: 'pl_orbeccen', render: (m) => (m.pl_orbeccen != null ? m.pl_orbeccen.toFixed(3) : '') };
const COL_PNUM: ColSpec = { label: 'Planets in system', sortKey: 'sy_pnum', render: (m) => m.sy_pnum ?? '' };
const COL_SNUM: ColSpec = { label: 'Stars in system', sortKey: 'sy_snum', render: (m) => m.sy_snum ?? '' };
const COL_CITATIONS: ColSpec = { label: 'Discovery citations', sortKey: 'disc_paper_citations', render: (m) => (m.disc_paper_citations != null ? m.disc_paper_citations.toLocaleString() : '') };

// Inner-binary columns read the host-keyed map fetched alongside the planets.
const colInnerPair = (ib: Map<string, InnerBinaryRow>): ColSpec => ({
  label: 'Inner pair (M☉)',
  render: (m) => {
    const b = ib.get(m.hostname);
    if (!b) return '';
    const p = b.primary_mass_msun;
    const s = b.component_mass_msun;
    if (p != null && s != null) return `${fmtMsun(p)} + ${fmtMsun(s)}`;
    if (p != null) return fmtMsun(p);
    if (s != null) return fmtMsun(s);
    return '';
  },
});
const colInnerSource = (ib: Map<string, InnerBinaryRow>): ColSpec => ({
  label: 'Source',
  render: (m) => {
    const b = ib.get(m.hostname);
    return b?.source_bibcode
      ? <a href={adsUrl(b.source_bibcode)} target="_blank" rel="noopener noreferrer" title={b.source_bibcode}>ADS</a>
      : '';
  },
});

function PlanetTable({ members, columns, defaultSort, legend = false }: {
  members: PlanetSummary[];
  columns: ColSpec[];
  defaultSort: { key: PlanetSortKey; dir: 1 | -1 };
  legend?: boolean;
}) {
  const [sort, setSort] = useState(defaultSort);
  const [page, setPage] = useState(0);

  const sorted = [...members].sort((a, b) => cmpField(a[sort.key], b[sort.key]) * sort.dir);
  const totalPages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
  const pageC = Math.min(page, totalPages - 1);
  const view = sorted.slice(pageC * PAGE_SIZE, pageC * PAGE_SIZE + PAGE_SIZE);
  const onSort = (key: PlanetSortKey) => {
    setPage(0);
    setSort((s) => (s.key === key ? { key, dir: (s.dir === 1 ? -1 : 1) as 1 | -1 } : { key, dir: 1 }));
  };

  return (
    <>
      <table className="history-table">
        <thead>
          <tr>
            {columns.map((c) => (c.sortKey
              ? <SortHeader key={c.label} label={c.label} col={c.sortKey} sortKey={sort.key} sortDir={sort.dir} onSort={onSort} />
              : <th key={c.label} scope="col">{c.label}</th>))}
          </tr>
        </thead>
        <tbody>
          {view.map((m) => (
            <tr key={m.pl_name}>
              {columns.map((c) => <td key={c.label}>{c.render(m)}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
      <Pager page={pageC} totalPages={totalPages} total={sorted.length} onPage={setPage} />
      {legend && <MethodLegend members={members} />}
    </>
  );
}

function MethodLegend({ members }: { members: PlanetSummary[] }) {
  const present = [...new Set(members.map((m) => m.discoverymethod).filter((x): x is string => !!x))]
    .map((full) => ({ full, abbr: METHOD_ABBR[full] ?? full }))
    .sort((a, b) => a.abbr.localeCompare(b.abbr));
  if (present.length === 0) return null;
  return (
    <p style={{ margin: '0.6rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)' }}>
      <strong style={{ color: 'var(--fg)' }}>Method key:</strong>{' '}
      {present.map((it, i) => (
        <span key={it.full}>
          {i > 0 && ' · '}
          <strong style={{ color: 'var(--fg)' }}>{it.abbr}</strong> {it.full}
        </span>
      ))}
    </p>
  );
}

// ---- geometry table (3D architecture) ----

type GeoSortKey = 'hostname' | 'pl_name' | 'mutual_inclination_deg' | 'method';

function GeometryTable({ rows, themeQuery }: { rows: SystemGeometryRow[]; themeQuery: string }) {
  const [sort, setSort] = useState<{ key: GeoSortKey; dir: 1 | -1 }>({ key: 'mutual_inclination_deg', dir: -1 });
  const [page, setPage] = useState(0);

  const sorted = [...rows].sort((a, b) => cmpField(a[sort.key], b[sort.key]) * sort.dir);
  const totalPages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
  const pageC = Math.min(page, totalPages - 1);
  const view = sorted.slice(pageC * PAGE_SIZE, pageC * PAGE_SIZE + PAGE_SIZE);
  const onSort = (key: GeoSortKey) => {
    setPage(0);
    setSort((s) => (s.key === key ? { key, dir: (s.dir === 1 ? -1 : 1) as 1 | -1 } : { key, dir: 1 }));
  };

  return (
    <>
      <table className="history-table">
        <thead>
          <tr>
            <SortHeader label="System" col="hostname" sortKey={sort.key} sortDir={sort.dir} onSort={onSort} />
            <SortHeader label="Planet" col="pl_name" sortKey={sort.key} sortDir={sort.dir} onSort={onSort} />
            <th scope="col">Relative to</th>
            <SortHeader label="Mutual inclination" col="mutual_inclination_deg" sortKey={sort.key} sortDir={sort.dir} onSort={onSort} />
            <SortHeader label="Method" col="method" sortKey={sort.key} sortDir={sort.dir} onSort={onSort} />
            <th scope="col">Note</th>
            <th scope="col">Source</th>
          </tr>
        </thead>
        <tbody>
          {view.map((r) => (
            <tr key={`${r.hostname}-${r.pl_name}`}>
              <td>{r.hostname}</td>
              <td><Link to={`/planets/${encodeURIComponent(r.pl_name)}${themeQuery}`}>{r.pl_name}</Link></td>
              <td>{r.reference_pl_name ?? ''}</td>
              <td>{inclinationCell(r)}</td>
              <td>{r.method.replace(/_/g, ' ')}</td>
              <td style={{ color: 'var(--fg-muted)', fontSize: '0.85rem', maxWidth: '30ch' }}>
                {r.note ?? ''}
              </td>
              <td>
                {r.bibcode
                  ? <a href={adsUrl(r.bibcode)} target="_blank" rel="noopener noreferrer" title={r.bibcode}>ADS</a>
                  : ''}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <Pager page={pageC} totalPages={totalPages} total={sorted.length} onPage={setPage} />
    </>
  );
}

function inclinationCell(r: SystemGeometryRow) {
  if (r.mutual_inclination_deg == null) return '';
  if (r.mutual_inclination_deg === 0) return <span style={{ color: 'var(--fg-muted)' }}>reference plane</span>;
  const unc = r.inclination_uncertainty_deg != null ? ` ± ${r.inclination_uncertainty_deg}°` : '';
  return `${r.mutual_inclination_deg.toFixed(1)}°${unc}`;
}

// ---- shared bits ----

function SortHeader<K extends string>({ label, col, sortKey, sortDir, onSort }: {
  label: string;
  col: K;
  sortKey: K;
  sortDir: 1 | -1;
  onSort: (k: K) => void;
}) {
  const active = sortKey === col;
  return (
    <th scope="col" aria-sort={active ? (sortDir === 1 ? 'ascending' : 'descending') : 'none'}>
      <button
        type="button"
        onClick={() => onSort(col)}
        style={{ background: 'none', border: 'none', color: 'inherit', font: 'inherit', cursor: 'pointer', padding: 0, display: 'inline-flex', alignItems: 'center', gap: '0.3rem' }}
      >
        {label}
        <span aria-hidden style={{ opacity: active ? 1 : 0.3, fontSize: '0.7em' }}>
          {active ? (sortDir === 1 ? '▲' : '▼') : '↕'}
        </span>
      </button>
    </th>
  );
}

function pagerBtnStyle(disabled: boolean): CSSProperties {
  return {
    background: 'var(--bg-elev)', color: disabled ? 'var(--fg-muted)' : 'var(--fg)',
    border: '1px solid var(--border)', borderRadius: 4, padding: '0.2rem 0.6rem',
    cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.5 : 1, fontSize: '0.8rem',
  };
}

function Pager({ page, totalPages, total, onPage }: {
  page: number;
  totalPages: number;
  total: number;
  onPage: (p: number) => void;
}) {
  if (totalPages <= 1) return null;
  const start = page * PAGE_SIZE + 1;
  const end = Math.min(total, (page + 1) * PAGE_SIZE);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginTop: '0.75rem', fontSize: '0.82rem', color: 'var(--fg-muted)' }}>
      <button type="button" onClick={() => onPage(page - 1)} disabled={page === 0} aria-label="Previous page" style={pagerBtnStyle(page === 0)}>‹ prev</button>
      <span>{start}-{end} of {total}</span>
      <button type="button" onClick={() => onPage(page + 1)} disabled={page >= totalPages - 1} aria-label="Next page" style={pagerBtnStyle(page >= totalPages - 1)}>next ›</button>
    </div>
  );
}

// Compare helper: numbers numeric, strings localeCompare, nulls last.
function cmpField(av: string | number | null, bv: string | number | null): number {
  if (av == null && bv == null) return 0;
  if (av == null) return 1;
  if (bv == null) return -1;
  return typeof av === 'number' && typeof bv === 'number' ? av - bv : String(av).localeCompare(String(bv));
}

function AtmosphereTable({ rows, themeQuery }: { rows: AtmosphereRow[] | null; themeQuery: string }) {
  if (rows === null) return <LoadingBar loading={true} />;
  if (rows.length === 0) return <p style={{ color: 'var(--fg-muted)' }}>No atmospheric results found.</p>;
  const planets = new Set(rows.map((r) => r.pl_name)).size;
  const detected = rows.filter((r) => r.detection === 'detected').length;
  const ruledOut = rows.filter((r) => r.detection === 'ruled_out').length;
  return (
    <Reveal>
      <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
        <strong style={{ color: 'var(--fg)' }}>{rows.length}</strong> atmospheric results across{' '}
        <strong style={{ color: 'var(--fg)' }}>{planets}</strong> planets
        {' '}({detected} molecule {detected === 1 ? 'detection' : 'detections'}
        {ruledOut > 0 ? `, ${ruledOut} ruled out` : ''}), each with its instrument, significance, and source.
      </p>
      <table className="history-table">
        <thead>
          <tr>
            <th scope="col">Planet</th>
            <th scope="col">Molecule</th>
            <th scope="col">Detection</th>
            <th scope="col">Instrument</th>
            <th scope="col">Significance</th>
            <th scope="col">Source</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={`${r.pl_name}-${r.molecule}`}>
              <td><Link to={`/planets/${encodeURIComponent(r.pl_name)}${themeQuery}`}>{r.pl_name}</Link></td>
              <td>{r.molecule}</td>
              <td>{r.detection}</td>
              <td>{r.instrument ?? ''}</td>
              <td>{r.confidence_sigma != null ? `${r.confidence_sigma}σ` : ''}</td>
              <td>{r.bibcode ? <a href={adsUrl(r.bibcode)} target="_blank" rel="noopener noreferrer" title={r.bibcode}>ADS</a> : ''}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Reveal>
  );
}

function CompositionTable({ rows, themeQuery }: { rows: DerivedMeasurementRow[] | null; themeQuery: string }) {
  if (rows === null) return <LoadingBar loading={true} />;
  if (rows.length === 0) return <p style={{ color: 'var(--fg-muted)' }}>No derived measurements found.</p>;
  const systems = new Map<string, DerivedMeasurementRow[]>();
  for (const r of rows) {
    const k = r.hostname ?? '—';
    const arr = systems.get(k);
    if (arr) arr.push(r); else systems.set(k, [r]);
  }
  const planets = new Set(rows.map((r) => r.pl_name)).size;
  return (
    <Reveal>
      <p style={{ margin: '0 0 1.25rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
        <strong style={{ color: 'var(--fg)' }}>{rows.length}</strong> derived values across{' '}
        <strong style={{ color: 'var(--fg)' }}>{planets}</strong> planets, grouped by system. Each carries its
        asymmetric uncertainty, the modelling assumption it depends on, and the source paper.
      </p>
      {[...systems.entries()].map(([host, hostRows]) => (
        <div key={host} style={{ marginBottom: '1.5rem' }}>
          <h3 style={{ margin: '0 0 0.5rem', fontSize: '0.95rem' }}>{host}</h3>
          <table className="history-table">
            <thead>
              <tr>
                <th scope="col">Planet</th>
                <th scope="col">Property</th>
                <th scope="col">Value</th>
                <th scope="col">Model</th>
                <th scope="col">Source</th>
              </tr>
            </thead>
            <tbody>
              {hostRows.map((r) => (
                <tr key={`${r.pl_name}-${r.quantity}`}>
                  <td><Link to={`/planets/${encodeURIComponent(r.pl_name)}${themeQuery}`}>{r.pl_name}</Link></td>
                  <td title={r.curator_note ?? undefined}>{quantityLabel(r.quantity)}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>{fmtMeasure(r)}</td>
                  <td style={{ color: 'var(--fg-muted)', fontSize: '0.85rem' }}>{r.model ?? ''}</td>
                  <td>{r.bibcode ? <a href={adsUrl(r.bibcode)} target="_blank" rel="noopener noreferrer" title={r.bibcode}>ADS</a> : ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ))}
    </Reveal>
  );
}

function AuthorList({ authors, themeQuery }: { authors: TopAuthor[] | null; themeQuery: string }) {
  if (authors === null) return <LoadingBar loading={true} />;
  if (authors.length === 0) return <p style={{ color: 'var(--fg-muted)' }}>No discoverers found.</p>;
  return (
    <ol className="collection-reveal" style={{ margin: 0, paddingLeft: '1.6rem', display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
      {authors.map((a) => (
        <li key={a.author}>
          <Link to={`/authors/${encodeURIComponent(a.author)}${themeQuery}`}>{a.author}</Link>
          <span style={{ color: 'var(--fg-muted)', marginLeft: '0.5rem' }}>
            {a.planet_count.toLocaleString()} planet{a.planet_count === 1 ? '' : 's'}
          </span>
        </li>
      ))}
    </ol>
  );
}

// Hand-maintained showcase: planets where the literature deep-dives recorded data
// the catalog's core tables do not carry (atmospheric detections, derived scalars).
// Curated for range, not row count, so the set reads as a tour of what the
// value-added layer adds. `pl_name` is the link target; `label` may name a group.
type BeyondArchiveEntry = { pl_name: string; label: string; hook: string };
const BEYOND_ARCHIVE: BeyondArchiveEntry[] = [
  { pl_name: 'PDS 70 b', label: 'PDS 70 b & c',
    hook: 'The only planets ever caught in the act of forming. We record the accretion rate of b and the circumplanetary-disk dust mass of c, neither of which the core tables carry.' },
  { pl_name: 'WASP-12 b', label: 'WASP-12 b',
    hook: 'A giant planet spiraling into its star, its orbit shrinking by 29 ms per year with roughly 3.2 million years left.' },
  { pl_name: 'WASP-76 b', label: 'WASP-76 b',
    hook: 'So hot that iron condenses and falls on its nightside. We hold the 11 km/s terminator wind that revealed it, alongside its iron, lithium, and sodium inventory.' },
  { pl_name: 'KELT-9 b', label: 'KELT-9 b',
    hook: 'The hottest known planet, and the first found to contain iron and titanium. A thirteen-species inventory of metals and ions.' },
  { pl_name: 'HR 8799 b', label: 'HR 8799 b-e',
    hook: 'Four directly imaged giants with measured carbon, oxygen, nitrogen, and sulphur abundances and a heavy-element budget (b alone holds about 123 Earth masses of metals), the chemical fingerprint of how they formed.' },
  { pl_name: 'WASP-107 b', label: 'WASP-107 b',
    hook: 'The first helium ever detected in an exoplanet atmosphere, plus the sulphur-dioxide photochemistry and silicate clouds caught by JWST.' },
  { pl_name: 'Kepler-1520 b', label: 'Kepler-1520 b',
    hook: 'A small rocky world evaporating into a comet-like dust tail, shedding roughly one Earth mass of material every billion years.' },
  { pl_name: 'TOI-849 b', label: 'TOI-849 b',
    hook: 'The stripped, exposed core of a giant planet. Whatever gas envelope remains is at most 3.9 percent of its mass.' },
  { pl_name: 'tau Boo b', label: 'tau Boo b',
    hook: 'The first non-transiting planet to have its atmosphere read (carbon monoxide and water), tracked through the Doppler shift of the planet itself.' },
  { pl_name: 'bet Pic b', label: 'bet Pic b',
    hook: 'A young giant with a measured spin near 25 km/s and a carbon-to-oxygen ratio that point to formation by core accretion.' },
  { pl_name: 'L 98-59 b', label: 'L 98-59 b',
    hook: 'The first tentative detection of a volcanic, sulfur-rich atmosphere on a planet smaller than Earth, sulfur dioxide caught by JWST at about 3.6 sigma and sustained by tidal heating from the planet\'s neighbours.' },
  { pl_name: 'HD 149026 b', label: 'HD 149026 b',
    hook: 'The most metal-rich giant planet known. JWST pins its atmospheric metallicity between 59 and 276 times solar, more than four sigma above even Saturn.' },
  { pl_name: 'WASP-80 b', label: 'WASP-80 b',
    hook: 'The first definitive space-based methane detection in a transiting exoplanet, seen by JWST at greater than 6 sigma in both transmission and emission.' },
  { pl_name: 'WASP-127 b', label: 'WASP-127 b',
    hook: 'The first three-dimensional weather map of an exoplanet atmosphere. High-resolution spectroscopy resolved a supersonic 7.7 km/s equatorial jet, with poles about 175 K cooler than the morning-evening terminator.' },
  { pl_name: 'LTT 9779 b', label: 'LTT 9779 b',
    hook: 'An ultra-hot Neptune with strikingly asymmetric reflection: the western limb returns 79 percent of incoming starlight while the eastern returns 41 percent, the signature of magnesium-silicate clouds condensing on the cooler hemisphere.' },
  { pl_name: 'V1298 Tau b', label: 'V1298 Tau b',
    hook: 'A 23-million-year-old planet with the most molecule-rich atmosphere measured at this age: carbon dioxide at 35 sigma, water at 30 sigma, methane roughly 7 sigma below equilibrium, plus sulfur dioxide and carbonyl sulfide, the chemistry of a world still cooling from formation.' },
];

function BeyondArchiveList({ themeQuery }: { themeQuery: string }) {
  return (
    <Reveal>
      <p style={{ margin: '0 0 1.25rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
        <strong style={{ color: 'var(--fg)' }}>{BEYOND_ARCHIVE.length}</strong> planets where published
        follow-up work records something the catalog's core parameter tables do not. Each links to its page,
        where every value carries its source paper and instrument.
      </p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
        {BEYOND_ARCHIVE.map((e) => (
          <div key={e.pl_name} className="card">
            <Link to={`/planets/${encodeURIComponent(e.pl_name)}${themeQuery}`} style={{ fontWeight: 600 }}>{e.label}</Link>
            <p style={{ margin: '0.35rem 0 0', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.55 }}>{e.hook}</p>
          </div>
        ))}
      </div>
    </Reveal>
  );
}

// Hand-maintained from the cb_flag audit (docs/cb_flag_audit.md,
// docs/rnaas_cb_flag_audit.md): entries whose flag or cross-referenced binary
// data is suspect. The audit verdict is not a queryable column, so this list is
// curated rather than fetched. Surfaced for discussion with the upstream archives.
type DataQualityFlag = { pl_name: string; flag: string; note: string };
const DATA_QUALITY_FLAGS: DataQualityFlag[] = [
  { pl_name: 'KMT-2016-BLG-1337L b', flag: 'cb_flag review', note: 'Published microlensing solution does not unambiguously place the planet outside both stars.' },
  { pl_name: 'OGLE-2018-BLG-1700L b', flag: 'cb_flag review', note: 'Published microlensing solution does not unambiguously place the planet outside both stars.' },
  { pl_name: 'OGLE-2019-BLG-1470L AB c', flag: 'cb_flag review', note: 'Published microlensing solution does not unambiguously place the planet outside both stars.' },
  { pl_name: 'PSR B1620-26 b', flag: 'cross-reference', note: 'The four catalogued companions are crowded-field stars in globular cluster M4, not bound; the real pulsar + white-dwarf inner binary is missing.' },
  { pl_name: 'PH1 b', flag: 'cross-reference', note: 'The catalogued companion is a 170,000 AU SIMBAD entry, not the relevant body; the ~1000 AU outer binary that makes the system a quadruple is missing.' },
];

function DataQualityTable({ themeQuery }: { themeQuery: string }) {
  return (
    <Reveal>
      <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--fg-muted)', lineHeight: 1.6 }}>
        <strong style={{ color: 'var(--fg)' }}>{DATA_QUALITY_FLAGS.length}</strong> entries flagged during the
        cb_flag audit for a second look, hand-maintained from the audit notes. Surfaced for discussion with the
        upstream archives, not presented as corrections.
      </p>
      <table className="history-table">
        <thead>
          <tr>
            <th scope="col">Planet</th>
            <th scope="col">Flag</th>
            <th scope="col">Why</th>
          </tr>
        </thead>
        <tbody>
          {DATA_QUALITY_FLAGS.map((f) => (
            <tr key={f.pl_name}>
              <td><Link to={`/planets/${encodeURIComponent(f.pl_name)}${themeQuery}`}>{f.pl_name}</Link></td>
              <td style={{ whiteSpace: 'nowrap' }}>{f.flag}</td>
              <td style={{ color: 'var(--fg-muted)', fontSize: '0.85rem', maxWidth: '48ch' }}>{f.note}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Reveal>
  );
}
