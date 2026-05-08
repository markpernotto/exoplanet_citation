import { useSearchParams } from 'react-router-dom';

const THEMES = [
  { slug: 'phosphor-green', label: 'P1 Phosphor', screen: '#33ff33' },
  { slug: 'amber',          label: 'P3 Phosphor', screen: '#ffb000' },
  { slug: 'cga',            label: 'CGA',         screen: '#0000aa' },
  { slug: 'ega',            label: 'EGA',         screen: '#55ffff' },
  { slug: 'hgc',            label: 'HGC',         screen: '#f0f0f0' },
  { slug: 'plasma',         label: 'Plasma',      screen: '#ff6600' },
] as const;

// Tiny CRT monitor: bezel + screen + stand + base.
// viewBox sized so the visible silhouette matches the old 18×13 footprint
// roughly, leaving extra height for the stand without expanding header layout.
function MonitorIcon({ screen, active }: { screen: string; active: boolean }) {
  return (
    <svg
      viewBox="0 0 24 22"
      width="24"
      height="22"
      aria-hidden="true"
      style={{ display: 'block' }}
    >
      {/* Bezel */}
      <rect x="0.5" y="0.5" width="23" height="17" rx="1.5" fill="#1a1a1a" stroke="#3a3a3a" strokeWidth="1" />
      {/* Screen face */}
      <rect
        x="2.5"
        y="2.5"
        width="19"
        height="13"
        fill={screen}
        opacity={active ? 1 : 0.55}
      />
      {/* Power LED — only visible when active */}
      {active && (
        <circle cx="20.5" cy="16.5" r="0.6" fill="#33ff33" />
      )}
      {/* Stand */}
      <polygon points="9.5,17.5 14.5,17.5 15.5,20 8.5,20" fill="#1a1a1a" stroke="#3a3a3a" strokeWidth="0.5" />
      {/* Base */}
      <rect x="6" y="20" width="12" height="1.5" rx="0.5" fill="#1a1a1a" stroke="#3a3a3a" strokeWidth="0.5" />
    </svg>
  );
}

export default function ThemeSwitcher() {
  const [searchParams, setSearchParams] = useSearchParams();
  const current = searchParams.get('theme') ?? '';

  function toggle(slug: string) {
    const next = new URLSearchParams(searchParams);
    if (current === slug) {
      next.delete('theme');
    } else {
      next.set('theme', slug);
    }
    setSearchParams(next, { replace: true });
  }

  return (
    <div className="theme-switcher" aria-label="Retro theme switcher">
      {THEMES.map(({ slug, label, screen }) => {
        const isActive = current === slug;
        return (
          <button
            key={slug}
            className={`theme-btn${isActive ? ' active' : ''}`}
            onClick={() => toggle(slug)}
            title={label}
            aria-label={isActive ? `Deactivate ${label} theme` : `Activate ${label} theme`}
            aria-pressed={isActive}
          >
            <MonitorIcon screen={screen} active={isActive} />
          </button>
        );
      })}
    </div>
  );
}
