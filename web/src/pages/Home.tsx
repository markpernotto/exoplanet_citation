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
      // Dedupe by pl_name when appending. Defends against duplicate appends
      // from React StrictMode (which intentionally re-runs effects in dev),
      // pagination boundary edge cases, or any future double-fire.
      setItems((prev) => {
        const seen = new Set(prev.map((p) => p.pl_name));
        const fresh = resp.results.filter((p) => !seen.has(p.pl_name));
        return [...prev, ...fresh];
      });
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
    const noPlanets = searchResults !== null && searchResults.total === 0;
    const bothLoaded = searchResults !== null && authorResults !== null;
    // Show discoverers only when there are no planet matches — as a fallback, not a parallel track.
    const showAuthors = noPlanets && authorResults && authorResults.length > 0;
    return (
      <>
        <section>
          <h2>
            {searchResults
              ? <>Search results — {searchResults.total} planet{searchResults.total === 1 ? '' : 's'} matching "{query}"</>
              : <>Searching for "{query}"…</>}
          </h2>
          {error && <div className="error">Error: {error}</div>}
          {searchResults && searchResults.total > 0 && (
            <PlanetGrid results={searchResults.results} />
          )}
          {bothLoaded && noPlanets && !showAuthors && (
            <div className="empty">
              No planets matched "{query}". Try a partial name like "Kepler-22" or a discoverer like "Marcy".
            </div>
          )}
        </section>

        {showAuthors && (
          <section>
            <h2>No planets matched — did you mean a discoverer?</h2>
            <div className="card" style={{ padding: '0.85rem 1rem' }}>
              <ol style={{ margin: 0, padding: '0 0 0 1.4rem', display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                {authorResults!.map((a) => (
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
          <a href="/api/rss" title="Subscribe to all exoplanet changes" style={{ marginLeft: '0.75rem', fontSize: '0.72rem', fontWeight: 'normal', color: 'var(--fg-muted)', textTransform: 'none', letterSpacing: 0 }}>RSS</a>
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
  'triple-star': {
    label: 'Triple-star skies',
    description: 'Planets in systems with three (or more) stars where the companions sit close enough to read as obvious second and third suns. Distinct from circumbinary above: here the planet orbits one star and the others appear as bright fixed companions at the system periphery.',
    systems: [
      { name: 'GJ 229',      representative: 'GJ 229 A c',      tagline: 'Triple system with BOTH companions just 27 AU and 53 AU away — they\'re tight enough to look like nearby planets in the scene view, three suns crowding the inner sky.' },
      { name: 'GJ 667 C',    representative: 'GJ 667 C c',      tagline: 'Three stars, three planets. Planet c sits in the habitable zone of the C dwarf; the inner A+B pair appears as a single bright sun ~290 AU away.' },
      { name: '16 Cyg B',    representative: '16 Cyg B b',      tagline: 'Three-star system with the famously eccentric Jupiter around B. Companion A is a bright sun 815 AU off; C is a more distant pair.' },
      { name: 'WD 1856+534', representative: 'WD 1856+534 b',   tagline: 'Planet orbiting a white dwarf in a triple system — two M-dwarf companions at ~1000 AU. Confirmed survivor of its star\'s death.' },
      { name: 'TOI-4336 A',  representative: 'TOI-4336 A b',    tagline: 'Triple where companion B reads as a near-equal second sun at 141 AU; C is a distant bright dot at 2,200 AU.' },
    ],
  },
  'eccentric': {
    label: 'Weird orbits',
    description: 'Planets with wildly elongated orbits OR measured non-coplanar architectures. In the system view eccentric orbits draw as stretched ellipses; tilted ones lean visibly out of the disk plane. Both are unusual — most systems are nearly flat and nearly circular.',
    systems: [
      { name: 'ups And',    representative: 'ups And d',    tagline: 'Mutual inclination 30° between planets c and d — the famous non-coplanar architecture. The orbits visibly criss-cross in the 3D view.' },
      { name: '55 Cnc',     representative: '55 Cnc e',     tagline: 'Inner planet e is tilted 17° relative to b — that\'s steep enough to see clearly in the system view alongside its 18-hour lava-world orbit.' },
      { name: 'Kepler-419', representative: 'Kepler-419 c', tagline: 'Mutual inclination 9° between b and c, measured from transit-timing variations — subtle but visible tilt.' },
      { name: 'bet Pic',    representative: 'bet Pic b',    tagline: 'Two directly-imaged super-Jupiters with measured 3° mutual inclination — subtle but precise, the angle came from astrometric tracking of both planets over a decade.' },
      { name: 'GJ 876',     representative: 'GJ 876 e',     tagline: 'Four-planet resonant system with measured tilts up to 2.5°. Each planet leans a touch out of the disk plane — not dramatic, but the architecture is real.' },
      { name: 'HD 20782',   representative: 'HD 20782 b',   tagline: 'Eccentricity 0.96 — the most elongated planetary orbit in the confirmed catalog.' },
      { name: 'HD 80606',   representative: 'HD 80606 b',   tagline: 'Eccentricity 0.93 — a scorching close pass to its star every 111 days, then a long cold arc away.' },
      { name: 'GJ 3222',    representative: 'GJ 3222 b',    tagline: 'Eccentricity 0.93 on an 11-day orbit — the rare combination of extreme ecc AND extreme proximity. Tidal forces should have circularized this orbit long ago. They didn\'t.' },
      { name: 'HR 5183',    representative: 'HR 5183 b',    tagline: 'Eccentricity 0.84 across an 18 AU, 74-year orbit — sweeps from inside Earth\'s orbit out past Saturn. Sometimes called the "Bouncing Jupiter."' },
      { name: 'HD 26161',   representative: 'HD 26161 b',   tagline: 'Eccentricity 0.92 on a 30-year orbit — periapsis closer than Earth, apoapsis past Saturn. One of the longest-baseline radial-velocity discoveries.' },
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
  'galactic-tour': {
    label: 'Different skies',
    description: 'Hand-picked vantages that span the galaxy. Open the 3D scene on each — the per-host star projection, Milky Way band, dust lanes, spiral arms, and even Andromeda all shift with distance and direction from Earth. From Proxima the sky is almost ours; from the bulge it\'s a different universe.',
    systems: [
      { name: 'Proxima Centauri',    representative: 'Proxima Cen b',         tagline: '4.2 light-years from Earth, near the galactic plane — virtually our sky, just with Sol added as another bright star.' },
      { name: '51 Pegasi',           representative: '51 Peg b',              tagline: '50 light-years from Earth at high galactic latitude — the Milky Way band tilts and Sol becomes a faint dot. Also: first exoplanet ever found around a sun-like star (1995).' },
      { name: 'Kepler-186',          representative: 'Kepler-186 f',          tagline: '579 light-years into the Kepler field, near the galactic plane — local stars rearrange, the Milky Way runs in a different direction.' },
      { name: 'WASP-12',             representative: 'WASP-12 b',             tagline: '1,394 light-years toward the galactic anti-center, well off the plane — Milky Way band hangs on one side of the sky; the host star is being tidally torn apart.' },
      { name: 'MOA-2007-BLG-192L',   representative: 'MOA-2007-BLG-192L b',   tagline: '7,046 light-years toward the galactic bulge — disk-to-bulge transition. Galactic center is now bright in foreground.' },
      { name: 'OGLE-2005-BLG-390L',  representative: 'OGLE-2005-BLG-390L b',  tagline: '21,500 light-years — on the bulge edge. The nickname "Hoth" suggests the vibe: cold, distant, surrounded by dense stars.' },
      { name: 'SWEEPS-4',            representative: 'SWEEPS-4 b',            tagline: '28,000 light-years — deep inside the galactic bulge. The galactic center fills a hemisphere with warm haze and spiral arms loop overhead.' },
    ],
  },
  'best-for-3d': {
    label: 'Best for 3D scene',
    description: 'Hand-picked planets where the 3D scene shines — multi-planet systems, dramatic suns, resolved binary companions, or just spectacular geometry. Open one and click "View in 3D" on the detail page; works on Quest 3 in WebXR.',
    systems: [
      { name: 'TRAPPIST-1',      representative: 'TRAPPIST-1 e',   tagline: '7 rocky planets packed inside Mercury\'s orbit around a deep-red M-dwarf. The dramatic flat system.' },
      { name: 'Kepler-90',       representative: 'Kepler-90 i',    tagline: '8 planets — same count as our solar system. Coplanar, spread across true AU scale.' },
      { name: 'Kepler-11',       representative: 'Kepler-11 g',    tagline: '6 sub-Neptunes in a famously flat configuration tighter than Venus\'s orbit.' },
      { name: '55 Cnc',          representative: '55 Cnc e',       tagline: '5 planets including a 18-hour-year lava world; the M-dwarf companion star is visible at ~1000 AU.' },
      { name: 'HR 8799',         representative: 'HR 8799 b',      tagline: '4 directly imaged super-Jupiters at 15-70 AU — the canonical "outer system" view.' },
      { name: 'Kepler-16',       representative: 'Kepler-16 b',    tagline: 'Original Tatooine planet — circumbinary, two suns dancing at the system center.' },
      { name: 'HD 80606',        representative: 'HD 80606 b',     tagline: 'Eccentricity 0.93 — press play and watch the planet whip through periastron, sun nearly doubling in size.' },
      { name: 'WASP-12',         representative: 'WASP-12 b',      tagline: 'Hot Jupiter with the sun filling 36° of sky. Surface view here is the "stars are huge" wow.' },
      { name: 'KELT-9',          representative: 'KELT-9 b',       tagline: 'Searing blue-white A-type star, the hottest known planet. Surface view is uncomfortable.' },
      { name: 'Proxima Centauri', representative: 'Proxima Cen b', tagline: 'Closest exoplanet to Earth (4.2 ly), around the closest star to us. M-dwarf red sun.' },
      { name: 'KOI-351 / Kepler-90', representative: 'Kepler-90 i', tagline: 'Same as Kepler-90 above — 8-planet flat system with measured orbital architecture.' },
      { name: '51 Peg',          representative: '51 Peg b',       tagline: 'First exoplanet around a sun-like star. Single planet, but historically loaded.' },
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
              {p.cb_flag !== 1 && (p.sy_snum ?? 0) >= 2 && (
                <span className="pill pill-binary" title={`Planet orbits one star in a ${p.sy_snum}-star system; companion star(s) visible in the sky`}>
                  {p.sy_snum === 2 ? 'binary system' : `${p.sy_snum}-star system`}
                </span>
              )}
              {(p.sy_pnum ?? 0) > 1 && <span className="pill pill-multi">{p.sy_pnum}-planet system</span>}
              {p.gaia_dr3_id && <span className="pill pill-gaia">Gaia DR3</span>}
              {p.has_measured_geometry && (
                <span className="pill pill-geometry" title="Mutual inclinations between sibling planets have been measured — the 3D scene shows the real architecture">
                  measured 3D
                </span>
              )}
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

