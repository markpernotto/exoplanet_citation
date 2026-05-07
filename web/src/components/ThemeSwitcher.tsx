import { useSearchParams } from 'react-router-dom';

const THEMES = [
  { slug: 'phosphor-green', label: 'P1 Phosphor' },
  { slug: 'amber',          label: 'P3 Phosphor' },
  { slug: 'cga',            label: 'CGA'         },
  { slug: 'ega',            label: 'EGA'         },
  { slug: 'hgc',            label: 'HGC'         },
  { slug: 'plasma',         label: 'Plasma'      },
] as const;

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
      {THEMES.map(({ slug, label }) => (
        <button
          key={slug}
          className={`theme-btn theme-btn--${slug}${current === slug ? ' active' : ''}`}
          onClick={() => toggle(slug)}
          title={label}
          aria-label={current === slug ? `Deactivate ${label} theme` : `Activate ${label} theme`}
          aria-pressed={current === slug}
        />
      ))}
    </div>
  );
}
