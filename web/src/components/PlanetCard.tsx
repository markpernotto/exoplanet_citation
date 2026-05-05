import { useEffect, useRef, useState } from 'react';
import type { PlanetDetail } from '../api';
import { planetVisual, starColor } from '../procedural';

type Props = { planet: PlanetDetail };

// Wall-clock seconds since component mount. Updates every animation frame.
// Respects prefers-reduced-motion: returns 0 forever (planet pinned at periapsis).
function useAnimationTime(): number {
  const [t, setT] = useState(0);
  const rafRef = useRef<number | null>(null);
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const start = performance.now();
    const tick = (now: number) => {
      setT((now - start) / 1000);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
    };
  }, []);
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

export default function PlanetCard({ planet }: Props) {
  const t = useAnimationTime();
  const visual = planetVisual(planet.pl_eqt, planet.pl_dens, planet.pl_rade);
  const star = starColor(null, planet.st_teff);

  // Orbit parameters from the data, with safe defaults.
  const period = planet.pl_orbper;
  const eccentricity = Math.max(0, Math.min(0.95, planet.pl_orbeccen ?? 0));
  const animSec = orbitAnimationSeconds(period);

  // Mean anomaly progresses linearly with time; eccentric anomaly does not.
  const M = (2 * Math.PI * t) / animSec;
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

  return (
    <div className="card">
      <svg viewBox={`0 0 ${viewBoxWidth} ${viewBoxHeight}`} width="100%" style={{ display: 'block' }} role="img"
           aria-label={`Animated visualization of ${planet.pl_name} orbiting host star ${planet.hostname}`}>
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

        {/* The orbit ellipse — Kepler's first law: ellipse with star at one focus */}
        {period != null && (
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
          />
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

        {/* Orbit metadata in the corner — period and eccentricity */}
        {period != null && (
          <g>
            <text x={viewBoxWidth - 8} y="20" textAnchor="end" fill="#9099aa" fontSize="10"
                  fontFamily="-apple-system, sans-serif" opacity="0.85">
              P = {formatPeriod(period)}
            </text>
            {eccentricity > 0.05 && (
              <text x={viewBoxWidth - 8} y="34" textAnchor="end" fill="#9099aa" fontSize="10"
                    fontFamily="-apple-system, sans-serif" opacity="0.85">
                e = {eccentricity.toFixed(2)}
              </text>
            )}
          </g>
        )}
      </svg>

      <p style={{ margin: '0.75rem 0 0', fontSize: '0.9rem', color: 'var(--fg)', lineHeight: 1.5 }}>
        {visual.description}
      </p>
      <p style={{ margin: '0.6rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
        The planet's path obeys <strong>Kepler's laws</strong>: an elliptical orbit with the star
        {' '}at one focus, sweeping equal areas in equal time so the planet moves
        {' '}<strong>faster near periapsis</strong> (closest approach to the star) and slower at apoapsis.
        {' '}Animation pace is logarithmic in real period — a hot Jupiter zips around in seconds; a
        {' '}multi-year orbit takes proportionally longer. Sizes are not to scale.
        {' '}Computed from <code>pl_orbper</code>, <code>pl_orbeccen</code>, <code>pl_eqt</code>,
        {' '}<code>pl_dens</code>, <code>pl_rade</code>, and host <code>st_teff</code>.
      </p>
    </div>
  );
}
