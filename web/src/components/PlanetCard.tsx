import type { PlanetDetail } from '../api';
import { planetVisual, starColor } from '../procedural';

type Props = { planet: PlanetDetail };

export default function PlanetCard({ planet }: Props) {
  const visual = planetVisual(planet.pl_eqt, planet.pl_dens, planet.pl_rade);
  const star = starColor(null, planet.st_teff);

  // Size scaling: log-ish so a Hot Jupiter (~12 Earth radii) and Earth (1) both visible
  const planetRadius = planet.pl_rade != null
    ? Math.max(15, Math.min(70, 18 + Math.log2(Math.max(0.5, planet.pl_rade)) * 12))
    : 30;

  return (
    <div className="card">
      <svg viewBox="0 0 240 240" width="100%" style={{ display: 'block', margin: '0 auto' }}>
        {/* Host star (smaller, top-left) */}
        <circle cx="40" cy="40" r="22" fill={star} opacity="0.95">
          <title>Host star: {planet.hostname} ({planet.st_spectype ?? 'spectral type unknown'})</title>
        </circle>
        <circle cx="40" cy="40" r="22" fill="none" stroke={star} strokeOpacity="0.3" strokeWidth="6" />

        {/* Planet (centered, dominant) */}
        {visual.glow && (
          <circle cx="120" cy="130" r={planetRadius + 8} fill={visual.fillColor} opacity="0.25" />
        )}
        <circle cx="120" cy="130" r={planetRadius} fill={visual.fillColor}>
          <title>{visual.description}</title>
        </circle>
      </svg>
      <p style={{ margin: '0.5rem 0 0', fontSize: '0.85rem', color: 'var(--fg-muted)' }}>
        {visual.description}
      </p>
      <p style={{ margin: '0.25rem 0 0', fontSize: '0.75rem', color: 'var(--fg-muted)' }}>
        Computed from <code>pl_eqt</code>, <code>pl_dens</code>, <code>pl_rade</code>, and host <code>st_teff</code>.
        Not a photograph — this is a visualization of the measurements.
      </p>
    </div>
  );
}
