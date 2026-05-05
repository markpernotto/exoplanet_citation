import type { PlanetDetail } from '../api';
import { planetVisual, starColor } from '../procedural';

type Props = { planet: PlanetDetail };

export default function PlanetCard({ planet }: Props) {
  const visual = planetVisual(planet.pl_eqt, planet.pl_dens, planet.pl_rade);
  const star = starColor(null, planet.st_teff);

  // Sizing. We keep this symbolic, not true-scale: a real star is typically
  // ~100,000× larger than its planet, which would make the planet a single
  // pixel. We pick visually-pleasing radii and disclose the scale below.
  const planetRadius = planet.pl_rade != null
    ? Math.max(38, Math.min(85, 40 + Math.log2(Math.max(0.5, planet.pl_rade)) * 12))
    : 55;
  const starRadius = 26;

  // Per-instance gradient IDs so multiple cards on a page don't collide.
  const id = planet.pl_name.replace(/[^a-zA-Z0-9]/g, '_');

  // Star "lit center" position
  const starCx = 56;
  const starCy = 64;
  // Planet center
  const planetCx = 140;
  const planetCy = 180;

  // Light source for the planet: lit hemisphere faces the star
  const lightAngle = Math.atan2(starCy - planetCy, starCx - planetCx);
  const litX = 50 + 30 * Math.cos(lightAngle);
  const litY = 50 + 30 * Math.sin(lightAngle);

  return (
    <div className="card">
      <svg viewBox="0 0 280 320" width="100%" style={{ display: 'block' }} role="img" aria-label={`Procedural visualization of ${planet.pl_name} and host star ${planet.hostname}`}>
        <defs>
          {/* Star: hot bright core → full surface color → soft edge */}
          <radialGradient id={`star-${id}`} cx="38%" cy="38%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
            <stop offset="35%" stopColor={star} stopOpacity="1" />
            <stop offset="100%" stopColor={star} stopOpacity="0.9" />
          </radialGradient>

          {/* Stellar corona: extends well beyond the disc, fades to nothing */}
          <radialGradient id={`corona-${id}`} cx="50%" cy="50%">
            <stop offset="0%" stopColor={star} stopOpacity="0.55" />
            <stop offset="35%" stopColor={star} stopOpacity="0.22" />
            <stop offset="100%" stopColor={star} stopOpacity="0" />
          </radialGradient>

          {/* Planet shading: lit hemisphere on the side facing the host star,
              limb darkening on the opposite edge. Position computed above. */}
          <radialGradient id={`planet-${id}`} cx={`${litX}%`} cy={`${litY}%`}>
            <stop offset="0%" stopColor="rgba(255,255,255,0.35)" />
            <stop offset="25%" stopColor={visual.fillColor} stopOpacity="1" />
            <stop offset="75%" stopColor={visual.fillColor} stopOpacity="0.95" />
            <stop offset="100%" stopColor="rgba(0,0,0,0.55)" />
          </radialGradient>

          {/* Atmospheric haze on the limb (only for non-uncertain planets) */}
          {visual.bodyType !== 'uncertain' && (
            <radialGradient id={`haze-${id}`} cx="50%" cy="50%">
              <stop offset="85%" stopColor={visual.fillColor} stopOpacity="0" />
              <stop offset="98%" stopColor={visual.fillColor} stopOpacity="0.45" />
              <stop offset="100%" stopColor={visual.fillColor} stopOpacity="0" />
            </radialGradient>
          )}

          {/* Gas-giant cloud banding: horizontal stripes via linear gradient */}
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

          {/* Hot-planet thermal glow halo */}
          {visual.glow && (
            <radialGradient id={`glow-${id}`} cx="50%" cy="50%">
              <stop offset="0%"   stopColor={visual.fillColor} stopOpacity="0.55" />
              <stop offset="60%"  stopColor={visual.fillColor} stopOpacity="0.18" />
              <stop offset="100%" stopColor={visual.fillColor} stopOpacity="0" />
            </radialGradient>
          )}

          {/* Clip the cloud bands to a circle so they only render on the planet */}
          <clipPath id={`planet-clip-${id}`}>
            <circle cx={planetCx} cy={planetCy} r={planetRadius} />
          </clipPath>
        </defs>

        {/* Faint orbital arc connecting star to planet, for spatial context */}
        <path
          d={`M ${starCx + starRadius - 4},${starCy + 6} Q ${(starCx + planetCx) / 2 - 20},${planetCy - 30} ${planetCx - planetRadius + 4},${planetCy - 4}`}
          fill="none"
          stroke={star}
          strokeOpacity="0.18"
          strokeWidth="1"
          strokeDasharray="3,5"
        />

        {/* HOST STAR */}
        <circle cx={starCx} cy={starCy} r={starRadius * 2.6} fill={`url(#corona-${id})`} />
        <circle cx={starCx} cy={starCy} r={starRadius} fill={`url(#star-${id})`}>
          <title>Host star: {planet.hostname} ({planet.st_spectype ?? 'spectral type unknown'})</title>
        </circle>
        <text x={starCx} y={starCy + starRadius + 22} textAnchor="middle" fill="#9099aa" fontSize="11" fontFamily="-apple-system, sans-serif">
          {planet.hostname}
        </text>
        <text x={starCx} y={starCy + starRadius + 35} textAnchor="middle" fill="#9099aa" fontSize="9" fontFamily="-apple-system, sans-serif" opacity="0.7">
          host star
        </text>

        {/* PLANET — order matters: glow → body → bands → atmospheric haze */}
        {visual.glow && (
          <circle cx={planetCx} cy={planetCy} r={planetRadius + 16} fill={`url(#glow-${id})`} />
        )}
        <circle cx={planetCx} cy={planetCy} r={planetRadius} fill={`url(#planet-${id})`}>
          <title>{visual.description}</title>
        </circle>
        {visual.bodyType === 'gas_giant' && (
          <rect
            x={planetCx - planetRadius}
            y={planetCy - planetRadius}
            width={planetRadius * 2}
            height={planetRadius * 2}
            fill={`url(#bands-${id})`}
            clipPath={`url(#planet-clip-${id})`}
          />
        )}
        {visual.bodyType !== 'uncertain' && (
          <circle cx={planetCx} cy={planetCy} r={planetRadius + 1} fill={`url(#haze-${id})`} />
        )}
        <text x={planetCx} y={planetCy + planetRadius + 22} textAnchor="middle" fill="#e8eaf0" fontSize="13" fontFamily="-apple-system, sans-serif" fontWeight="600">
          {planet.pl_name}
        </text>
        <text x={planetCx} y={planetCy + planetRadius + 36} textAnchor="middle" fill="#9099aa" fontSize="10" fontFamily="-apple-system, sans-serif" opacity="0.7">
          planet
        </text>
      </svg>

      <p style={{ margin: '0.75rem 0 0', fontSize: '0.9rem', color: 'var(--fg)', lineHeight: 1.5 }}>
        {visual.description}
      </p>
      <p style={{ margin: '0.6rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
        <strong>Sizes are not to scale</strong> — real stars are roughly 100,000× larger than their planets.
        {' '}This is a stylized rendering of the relationship.
        {' '}Color and shading are computed from <code>pl_eqt</code>, <code>pl_dens</code>, <code>pl_rade</code>, and host <code>st_teff</code>.
        {' '}Not a photograph.
      </p>
    </div>
  );
}
