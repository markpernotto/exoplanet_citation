import { useEffect, useRef, useState } from 'react';
import type { PlanetDetail, PlanetSummary } from '../api';
import { planetVisual, starColor } from '../procedural';
import { useSvgZoomPan, type ViewBox } from '../lib/useSvgZoomPan';

type Props = { planet: PlanetDetail; siblings?: PlanetSummary[] | null };

// Animation time in seconds, pausable. When `running` is false, t freezes at
// its current value; when running resumes, t picks up from where it left off
// (rather than jumping ahead by the duration of the pause).
// Respects prefers-reduced-motion: returns 0 forever (planet pinned at periapsis).
function useAnimationTime(running: boolean): number {
  const [t, setT] = useState(0);
  const accumulatedRef = useRef(0);
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    if (!running) return;
    const startWall = performance.now();
    let raf: number;
    const tick = (now: number) => {
      setT(accumulatedRef.current + (now - startWall) / 1000);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      // Bank the elapsed time so the next run resumes from here.
      accumulatedRef.current += (performance.now() - startWall) / 1000;
    };
  }, [running]);
  return t;
}

// Solve Kepler's equation M = E - e·sin(E) for E by Newton-Raphson iteration.
// Converges to ~1e-15 in 5-8 iterations for any e < ~0.95. We clamp eccentricity
// upstream so this is always well-behaved.
function solveKeplerEquation(meanAnomaly: number, eccentricity: number): number {
  let E = meanAnomaly;
  for (let i = 0; i < 8; i++) {
    const f = E - eccentricity * Math.sin(E) - meanAnomaly;
    const fp = 1 - eccentricity * Math.cos(E);
    E -= f / fp;
  }
  return E;
}

// Map real orbital period (in days) → wall-clock animation duration (seconds).
// Logarithmic so all orbits feel watchable: 0.1d→5s, 1d→7s, 10d→11s,
// 100d→15s, 1000d→19s, 10000d→23s. Capped at 5..30 seconds.
function orbitAnimationSeconds(periodDays: number | null): number {
  if (periodDays == null || periodDays <= 0) return 12;
  return Math.max(5, Math.min(30, Math.log10(Math.max(0.1, periodDays)) * 4 + 7));
}

function formatPeriod(days: number): string {
  if (days < 1) return `${(days * 24).toFixed(1)} hr`;
  if (days < 365) return `${days.toFixed(1)} days`;
  return `${(days / 365.25).toFixed(2)} yr`;
}

export default function PlanetCard({ planet, siblings }: Props) {
  const [paused, setPaused] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const t = useAnimationTime(!paused);
  const visual = planetVisual(planet.pl_eqt, planet.pl_dens, planet.pl_rade);
  const star = starColor(null, planet.st_teff);

  // ESC key closes the expanded view; lock body scroll while open.
  useEffect(() => {
    if (!expanded) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setExpanded(false);
    };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [expanded]);

  // Orbit parameters from the data, with safe defaults.
  const period = planet.pl_orbper;
  const eccentricity = Math.max(0, Math.min(0.95, planet.pl_orbeccen ?? 0));
  const animSec = orbitAnimationSeconds(period);

  // Mean anomaly progresses linearly with time; eccentric anomaly does not.
  // If we have no period data, pin the planet at periapsis (M=0) instead of
  // animating — animating a planet without an orbit path looks broken.
  const M = period != null ? (2 * Math.PI * t) / animSec : 0;
  const E = solveKeplerEquation(M, eccentricity);

  // Sizing — uses real radius data so planet/star ratio reflects reality.
  // 1 solar radius ≈ 109 Earth radii, so a Jupiter (12 R⊕) around a Sun-like
  // star is ~9× smaller than its host. Naïve scaling rendered them at 1:1.
  // Fix: derive starRadius from st_rad (compressed via power 0.4 so giants
  // don't blot out the canvas), then size the planet as a fraction of the
  // star using the actual planet/star radius ratio, sqrt-compressed so tiny
  // planets stay visible and large ratios don't get clipped.
  const SOLAR_TO_EARTH_RADII = 109.2;
  const stRad = planet.st_rad ?? 1.0;
  const starRadius = Math.max(8, Math.min(40, 26 * Math.pow(Math.max(0.05, stRad), 0.4)));
  const planetRadius = (() => {
    if (planet.pl_rade == null) return Math.max(5, starRadius * 0.3);
    const ratio = planet.pl_rade / (stRad * SOLAR_TO_EARTH_RADII);
    return Math.max(5, Math.min(22, starRadius * Math.sqrt(Math.max(0, ratio)) * 1.2));
  })();

  // Orbit sizing: scale up so periapsis always clears the star, no upper cap
  // on the orbit size. ViewBox grows to fit the full orbit. For very-eccentric
  // orbits (HD 80606 b's e=0.93 produces an orbit ~12× wider than a circular
  // one of the same star), the SVG itself becomes wider — capturing the full
  // dramatic range of the planet's path.
  const minPeriapsisClearance = starRadius + planetRadius + 8;
  const naturalA = 100;
  const xPadding = 35;
  const orbitSemiMajor = Math.max(
    naturalA,
    minPeriapsisClearance / Math.max(0.05, 1 - eccentricity),
  );

  const sqrtOneMinusE2 = Math.sqrt(1 - eccentricity * eccentricity);
  const orbitSemiMinor = orbitSemiMajor * sqrtOneMinusE2;
  const apoapsisDistance = orbitSemiMajor * (1 + eccentricity);
  const periapsisDistance = orbitSemiMajor * (1 - eccentricity);

  // ViewBox: focus on right-of-center, apoapsis fits to its left, periapsis
  // to its right, equal padding both sides.
  const viewBoxWidth = Math.max(320, apoapsisDistance + periapsisDistance + 2 * xPadding);
  const viewBoxHeight = Math.max(340, 2 * orbitSemiMinor + 100);
  const focusX = apoapsisDistance + xPadding;
  const focusY = viewBoxHeight / 2 - 5;
  const ellipseCx = focusX - orbitSemiMajor * eccentricity;
  const ellipseCy = focusY;

  // Planet position. E=0 = periapsis (right, closest); E=π = apoapsis (left, farthest).
  const planetX = focusX + orbitSemiMajor * (Math.cos(E) - eccentricity);
  const planetY = focusY + orbitSemiMinor * Math.sin(E);

  // Dayside lighting always faces the star (physically correct).
  const dx = focusX - planetX;
  const dy = focusY - planetY;
  const dist = Math.hypot(dx, dy) || 1;
  const litX = 50 + (dx / dist) * 30;
  const litY = 50 + (dy / dist) * 30;

  const id = planet.pl_name.replace(/[^a-zA-Z0-9]/g, '_');

  const singleNaturalVB: ViewBox = { x: 0, y: 0, w: viewBoxWidth, h: viewBoxHeight };

  const singleOrbitContent = (
      <>
        <defs>
          {/* Star: hot bright nucleus → full color → soft outer */}
          <radialGradient id={`star-${id}`} cx="38%" cy="38%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
            <stop offset="35%" stopColor={star} stopOpacity="1" />
            <stop offset="100%" stopColor={star} stopOpacity="0.9" />
          </radialGradient>
          <radialGradient id={`corona-${id}`} cx="50%" cy="50%">
            <stop offset="0%" stopColor={star} stopOpacity="0.5" />
            <stop offset="35%" stopColor={star} stopOpacity="0.2" />
            <stop offset="100%" stopColor={star} stopOpacity="0" />
          </radialGradient>

          {/* Planet: dayside facing the star, nightside opposite */}
          <radialGradient id={`planet-${id}`} cx={`${litX}%`} cy={`${litY}%`}>
            <stop offset="0%" stopColor="rgba(255,255,255,0.35)" />
            <stop offset="25%" stopColor={visual.fillColor} stopOpacity="1" />
            <stop offset="75%" stopColor={visual.fillColor} stopOpacity="0.95" />
            <stop offset="100%" stopColor="rgba(0,0,0,0.55)" />
          </radialGradient>

          {visual.bodyType !== 'uncertain' && (
            <radialGradient id={`haze-${id}`} cx="50%" cy="50%">
              <stop offset="85%" stopColor={visual.fillColor} stopOpacity="0" />
              <stop offset="98%" stopColor={visual.fillColor} stopOpacity="0.45" />
              <stop offset="100%" stopColor={visual.fillColor} stopOpacity="0" />
            </radialGradient>
          )}

          {visual.bodyType === 'gas_giant' && (
            <linearGradient id={`bands-${id}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%"   stopColor="rgba(255,255,255,0.00)" />
              <stop offset="14%"  stopColor="rgba(255,255,255,0.12)" />
              <stop offset="30%"  stopColor="rgba(0,0,0,0.14)" />
              <stop offset="44%"  stopColor="rgba(255,255,255,0.10)" />
              <stop offset="58%"  stopColor="rgba(0,0,0,0.12)" />
              <stop offset="74%"  stopColor="rgba(255,255,255,0.10)" />
              <stop offset="90%"  stopColor="rgba(0,0,0,0.10)" />
              <stop offset="100%" stopColor="rgba(255,255,255,0.00)" />
            </linearGradient>
          )}

          {visual.glow && (
            <radialGradient id={`glow-${id}`} cx="50%" cy="50%">
              <stop offset="0%" stopColor={visual.fillColor} stopOpacity="0.55" />
              <stop offset="60%" stopColor={visual.fillColor} stopOpacity="0.18" />
              <stop offset="100%" stopColor={visual.fillColor} stopOpacity="0" />
            </radialGradient>
          )}

          <clipPath id={`planet-clip-${id}`}>
            <circle cx={planetX} cy={planetY} r={planetRadius} />
          </clipPath>
        </defs>

        {/* The orbit ellipse — Kepler's first law: ellipse with star at one focus.
            Always shown so every planet has a visible orbital path, even if we
            don't have period/animation data for it. */}
        <ellipse
          cx={ellipseCx}
          cy={ellipseCy}
          rx={orbitSemiMajor}
          ry={orbitSemiMinor}
          fill="none"
          stroke={star}
          strokeOpacity="0.28"
          strokeWidth="1"
          strokeDasharray="2,4"
          vectorEffect="non-scaling-stroke"
        />
        {period == null && (
          <text x={focusX} y={focusY - orbitSemiMinor - 18} textAnchor="middle"
                fill="#9099aa" fontSize="11" fontFamily="-apple-system, sans-serif" opacity="0.6">
            no orbital data — orbit shape is symbolic
          </text>
        )}

        {/* Host star at the focus, with corona */}
        <circle cx={focusX} cy={focusY} r={starRadius * 2.6} fill={`url(#corona-${id})`} />
        <circle cx={focusX} cy={focusY} r={starRadius} fill={`url(#star-${id})`}>
          <title>Host star: {planet.hostname} ({planet.st_spectype ?? 'spectral type unknown'})</title>
        </circle>

        {/* Planet — order: glow halo → body → bands → atmospheric haze */}
        {visual.glow && (
          <circle cx={planetX} cy={planetY} r={planetRadius + 8} fill={`url(#glow-${id})`} />
        )}
        <circle cx={planetX} cy={planetY} r={planetRadius} fill={`url(#planet-${id})`}>
          <title>{visual.description}</title>
        </circle>
        {visual.bodyType === 'gas_giant' && (
          <rect
            x={planetX - planetRadius}
            y={planetY - planetRadius}
            width={planetRadius * 2}
            height={planetRadius * 2}
            fill={`url(#bands-${id})`}
            clipPath={`url(#planet-clip-${id})`}
          />
        )}
        {visual.bodyType !== 'uncertain' && (
          <circle cx={planetX} cy={planetY} r={planetRadius + 1} fill={`url(#haze-${id})`} />
        )}

        {/* Star name label, fixed at focus */}
        <text x={focusX} y={focusY + starRadius + 22} textAnchor="middle"
              fill="#9099aa" fontSize="11" fontFamily="-apple-system, sans-serif">
          {planet.hostname}
        </text>
      </>
  );

  const orbitSvg = (
    <svg viewBox={`0 0 ${viewBoxWidth} ${viewBoxHeight}`} width="100%" style={{ display: 'block' }} role="img"
         aria-label={`Animated visualization of ${planet.pl_name} orbiting host star ${planet.hostname}`}>
      {singleOrbitContent}
    </svg>
  );

  // Multi-planet system view: data + content for use inside the modal, only
  // when we have at least one sibling with a known semi-major axis. Orbits are
  // scaled to true AU — astronomically faithful, so a hot Jupiter at 0.05 AU
  // really does become a dot next to a cold Jupiter at 5 AU. The user can
  // scroll to zoom in on the inner system in the modal.
  const multiOrbit = (() => {
    const sibsWithOrbits = (siblings ?? []).filter((s) => s.pl_orbsmax != null);
    if (sibsWithOrbits.length === 0) return null;
    if (planet.pl_orbsmax == null) return null;

    type Orbiter = {
      key: string;
      name: string;
      isPrimary: boolean;
      a: number;
      e: number;
      period: number | null;
      eqt: number | null;
      dens: number | null;
      rade: number | null;
    };

    const orbiters: Orbiter[] = [
      {
        key: id,
        name: planet.pl_name,
        isPrimary: true,
        a: planet.pl_orbsmax,
        e: Math.max(0, Math.min(0.95, planet.pl_orbeccen ?? 0)),
        period: planet.pl_orbper,
        eqt: planet.pl_eqt,
        dens: planet.pl_dens,
        rade: planet.pl_rade,
      },
      ...sibsWithOrbits.map((s) => ({
        key: s.pl_name.replace(/[^a-zA-Z0-9]/g, '_'),
        name: s.pl_name,
        isPrimary: false,
        a: s.pl_orbsmax as number,
        e: Math.max(0, Math.min(0.95, s.pl_orbeccen ?? 0)),
        period: s.pl_orbper,
        eqt: s.pl_eqt,
        dens: null as number | null,
        rade: s.pl_rade,
      })),
    ];

    // Canvas extents in AU: leftward extent = max apoapsis, rightward extent = max periapsis.
    // (All orbits oriented with periapsis on the +x side; we don't have
    // argument-of-periapsis data to do anything more honest about orientation.)
    const maxApoAU = Math.max(...orbiters.map((o) => o.a * (1 + o.e)));
    const maxPeriAU = Math.max(...orbiters.map((o) => o.a * (1 - o.e)));
    const maxMinorAU = Math.max(...orbiters.map((o) => o.a * Math.sqrt(1 - o.e * o.e)));

    const targetWidth = 1400;
    const xPad = 60;
    const yPad = 60;
    const pxPerAU = (targetWidth - 2 * xPad) / (maxApoAU + maxPeriAU);
    const focusX = xPad + maxApoAU * pxPerAU;
    const viewBoxHeight = Math.max(420, 2 * maxMinorAU * pxPerAU + 2 * yPad);
    const focusY = viewBoxHeight / 2;

    // Pre-compute per-orbiter geometry + visuals.
    const drawn = orbiters.map((o) => {
      const animSec = orbitAnimationSeconds(o.period);
      const M = o.period != null ? (2 * Math.PI * t) / animSec : 0;
      const E = solveKeplerEquation(M, o.e);
      const orbitA = o.a * pxPerAU;
      const orbitB = orbitA * Math.sqrt(1 - o.e * o.e);
      const ellipseCx = focusX - orbitA * o.e;
      const planetX = focusX + orbitA * (Math.cos(E) - o.e);
      const planetY = focusY + orbitB * Math.sin(E);
      // Planet pixel size: same sqrt-compressed ratio used by single-planet view.
      const radPx = (() => {
        if (o.rade == null) return Math.max(4, starRadius * 0.25);
        const ratio = o.rade / (stRad * SOLAR_TO_EARTH_RADII);
        return Math.max(4, Math.min(20, starRadius * Math.sqrt(Math.max(0, ratio)) * 1.2));
      })();
      const vis = planetVisual(o.eqt, o.dens, o.rade);
      const dx = focusX - planetX;
      const dy = focusY - planetY;
      const dist = Math.hypot(dx, dy) || 1;
      const litX = 50 + (dx / dist) * 30;
      const litY = 50 + (dy / dist) * 30;
      return { o, ellipseCx, orbitA, orbitB, planetX, planetY, radPx, vis, litX, litY };
    });

    const naturalVB: ViewBox = { x: 0, y: 0, w: targetWidth, h: viewBoxHeight };
    const content = (
      <>
        <defs>
          <radialGradient id={`star-multi-${id}`} cx="38%" cy="38%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
            <stop offset="35%" stopColor={star} stopOpacity="1" />
            <stop offset="100%" stopColor={star} stopOpacity="0.9" />
          </radialGradient>
          <radialGradient id={`corona-multi-${id}`} cx="50%" cy="50%">
            <stop offset="0%" stopColor={star} stopOpacity="0.5" />
            <stop offset="35%" stopColor={star} stopOpacity="0.2" />
            <stop offset="100%" stopColor={star} stopOpacity="0" />
          </radialGradient>
          {drawn.map((d) => (
            <radialGradient key={`pg-${d.o.key}`} id={`planet-multi-${d.o.key}`} cx={`${d.litX}%`} cy={`${d.litY}%`}>
              <stop offset="0%" stopColor="rgba(255,255,255,0.35)" />
              <stop offset="25%" stopColor={d.vis.fillColor} stopOpacity="1" />
              <stop offset="75%" stopColor={d.vis.fillColor} stopOpacity="0.95" />
              <stop offset="100%" stopColor="rgba(0,0,0,0.55)" />
            </radialGradient>
          ))}
        </defs>

        {/* Orbits — primary brighter, siblings dimmer.
            Non-scaling stroke so they stay crisp at high zoom. */}
        {drawn.map((d) => (
          <ellipse
            key={`orb-${d.o.key}`}
            cx={d.ellipseCx}
            cy={focusY}
            rx={d.orbitA}
            ry={d.orbitB}
            fill="none"
            stroke={star}
            strokeOpacity={d.o.isPrimary ? 0.45 : 0.18}
            strokeWidth={d.o.isPrimary ? 1.25 : 1}
            strokeDasharray={d.o.isPrimary ? '3,4' : '2,5'}
            vectorEffect="non-scaling-stroke"
          />
        ))}

        {/* Star at the shared focus */}
        <circle cx={focusX} cy={focusY} r={starRadius * 2.6} fill={`url(#corona-multi-${id})`} />
        <circle cx={focusX} cy={focusY} r={starRadius} fill={`url(#star-multi-${id})`}>
          <title>Host star: {planet.hostname} ({planet.st_spectype ?? 'spectral type unknown'})</title>
        </circle>

        {/* Planets */}
        {drawn.map((d) => (
          <g key={`pl-${d.o.key}`}>
            {d.o.isPrimary && (
              <circle cx={d.planetX} cy={d.planetY} r={d.radPx + 5} fill="none"
                      stroke="var(--accent, #6cf)" strokeOpacity="0.7" strokeWidth="1"
                      vectorEffect="non-scaling-stroke" />
            )}
            <circle cx={d.planetX} cy={d.planetY} r={d.radPx} fill={`url(#planet-multi-${d.o.key})`}>
              <title>{d.o.name} — {d.vis.description}</title>
            </circle>
            <text
              x={d.planetX}
              y={d.planetY + d.radPx + 13}
              textAnchor="middle"
              fill={d.o.isPrimary ? '#cfd6e4' : '#7d8595'}
              fontSize="10"
              fontFamily="-apple-system, sans-serif"
              opacity={d.o.isPrimary ? 0.95 : 0.7}
            >
              {d.o.name}
            </text>
          </g>
        ))}

        <text x={focusX} y={focusY + starRadius + 22} textAnchor="middle"
              fill="#9099aa" fontSize="11" fontFamily="-apple-system, sans-serif">
          {planet.hostname}
        </text>
      </>
    );
    return { naturalVB, content, count: orbiters.length };
  })();

  // Modal SVG: identical content as the inline card (or the multi-system view
  // when siblings have orbits), wrapped with viewBox-driven zoom + drag pan.
  // Hook is always called (rules-of-hooks); it self-disables when !expanded.
  const modalSvgRef = useRef<SVGSVGElement>(null);
  const modalNaturalVB = multiOrbit?.naturalVB ?? singleNaturalVB;
  const modalContent = multiOrbit?.content ?? singleOrbitContent;
  const zoomPan = useSvgZoomPan(modalSvgRef, modalNaturalVB, expanded);
  const modalSvg = (
    <svg
      ref={modalSvgRef}
      viewBox={zoomPan.viewBox}
      width="100%"
      style={{
        display: 'block',
        cursor: zoomPan.isZoomed ? 'grab' : 'default',
        userSelect: 'none',
        touchAction: 'none',
      }}
      role="img"
      aria-label={multiOrbit
        ? `Animated visualization of the ${planet.hostname} system: ${multiOrbit.count} planets, scroll to zoom and drag to pan`
        : `Animated visualization of ${planet.pl_name} orbiting host star ${planet.hostname}`}
      {...zoomPan.handlers}
    >
      {modalContent}
    </svg>
  );

  const cardContent = (
    <>
      <div
        className="planet-svg-wrapper"
        onPointerEnter={() => setPaused(true)}
        onPointerLeave={() => setPaused(false)}
      >
        {orbitSvg}
        <button
          type="button"
          className="expand-btn-corner"
          onClick={() => setExpanded(true)}
          title="Expand to a larger view"
          aria-label="Expand to a larger view"
        >
          ⛶
        </button>
      </div>

      <p style={{ margin: '0.75rem 0 0', fontSize: '0.9rem', color: 'var(--fg)', lineHeight: 1.5 }}>
        {visual.description}
      </p>

      <div className="orbit-legend">
        <div className="metric-item">
          <div className="metric-row">
            <span className="metric-label">Period</span>
            <span className="metric-value">{period != null ? formatPeriod(period) : 'unknown'}</span>
          </div>
          <p className="metric-explain">how long it takes the planet to complete one orbit around its star</p>
        </div>

        <div className="metric-item">
          <div className="metric-row">
            <span className="metric-label">Distance</span>
            <span className="metric-value">
              {planet.pl_orbsmax != null ? `${planet.pl_orbsmax.toFixed(3)} AU` : 'unknown'}
            </span>
          </div>
          <p className="metric-explain">average distance from the host star (1 AU = Earth–Sun distance, about 93 million miles)</p>
        </div>

        <div className="metric-item">
          <div className="metric-row">
            <span className="metric-label">Eccentricity</span>
            <span className="metric-value">{eccentricity.toFixed(2)} — {describeEccentricity(eccentricity)}</span>
          </div>
          <p className="metric-explain">how stretched the orbit is. 0 = perfect circle, closer to 1 = more extreme ellipse. Highly eccentric orbits make the planet swing close to the star then slingshot far away</p>
        </div>
      </div>

      <p style={{ margin: '0.75rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
        The planet's motion follows <strong>Kepler's laws</strong>: faster near periapsis (closest approach), slower near apoapsis (farthest).
        {' '}Animation pace is logarithmic in real period — a 1-day orbit takes ~6 seconds, a multi-year orbit takes ~25.
        {' '}Sizes are not to scale; real stars are ~9–100× larger than their planets.
      </p>
    </>
  );

  return (
    <>
      <div className="card">{cardContent}</div>

      {expanded && (
        <div className="planet-card-modal" role="dialog" aria-modal="true" aria-label={`${planet.pl_name} expanded view`}>
          <div className="planet-card-modal-backdrop" onClick={() => setExpanded(false)} />
          <div className={`planet-card-modal-inner${multiOrbit ? ' multi' : ''}`}>
            <button
              type="button"
              className="modal-close-btn"
              onClick={() => setExpanded(false)}
              title="Close (Esc)"
              aria-label="Close"
            >
              ✕
            </button>
            <div className="modal-zoom-hint" aria-live="polite">
              {zoomPan.isZoomed
                ? <>{zoomPan.zoomLevel.toFixed(1)}× · drag to pan · <button type="button" className="zoom-reset-link" onClick={zoomPan.reset}>reset</button></>
                : <>scroll to zoom · double-click to reset</>}
            </div>
            {modalSvg}
            {multiOrbit && (
              <p style={{ margin: '0.75rem 1rem 0', fontSize: '0.8rem', color: 'var(--fg-muted)', lineHeight: 1.5, textAlign: 'center' }}>
                The full <strong>{planet.hostname}</strong> system, orbits drawn to true scale in AU.
                {' '}<span style={{ color: 'var(--accent, #6cf)' }}>◯</span> marks <strong>{planet.pl_name}</strong>.
                {' '}Inner planets really are this much smaller and closer than the outer ones —
                scroll-zoom into the inner system to see them clearly.
              </p>
            )}
          </div>
        </div>
      )}
    </>
  );
}

function describeEccentricity(e: number): string {
  if (e < 0.05) return 'nearly circular';
  if (e < 0.2) return 'slightly elliptical';
  if (e < 0.5) return 'moderately elliptical';
  if (e < 0.8) return 'highly elliptical';
  return 'extremely elliptical';
}
