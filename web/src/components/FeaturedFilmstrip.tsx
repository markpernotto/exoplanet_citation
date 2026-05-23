import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { COLLECTIONS, type Collection } from '../lib/collections';

// From-scratch, accessible horizontal filmstrip (no carousel library):
//   - native CSS scroll-snap for the row, responsive card widths via clamp()
//   - cards are real <Link>s, so they are in the tab order and keyboard-operable
//   - prev/next buttons page the row and disable at the ends
//   - smooth scroll, but instant when prefers-reduced-motion is set; no autoplay
// Cards link to /collections/:key. Images live at web/public/featured/<key>.jpg;
// a missing image (or a typographic collection) falls back to a labeled tile.
// Module-level so the scroll position survives back-navigation remounts within
// the SPA session (resets only on a full page reload). Lets the user return from
// a collection to the same spot in the filmstrip instead of scrolled to the start.
let savedScrollLeft = 0;

export default function FeaturedFilmstrip() {
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  const scrollerRef = useRef<HTMLDivElement>(null);
  const [atStart, setAtStart] = useState(true);
  const [atEnd, setAtEnd] = useState(false);

  const updateEdges = () => {
    const el = scrollerRef.current;
    if (!el) return;
    setAtStart(el.scrollLeft <= 1);
    setAtEnd(el.scrollLeft + el.clientWidth >= el.scrollWidth - 1);
  };
  // Save on every scroll; restore on mount before paint so there's no flash of
  // scrolled-to-start when coming back from a collection.
  const handleScroll = () => {
    const el = scrollerRef.current;
    if (el) savedScrollLeft = el.scrollLeft;
    updateEdges();
  };
  useLayoutEffect(() => {
    const el = scrollerRef.current;
    if (el) el.scrollLeft = savedScrollLeft;
    updateEdges();
  }, []);
  useEffect(() => {
    const onResize = () => updateEdges();
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  const page = (dir: 1 | -1) => {
    const el = scrollerRef.current;
    if (!el) return;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    el.scrollBy({ left: dir * Math.round(el.clientWidth * 0.85), behavior: reduce ? 'auto' : 'smooth' });
  };

  const arrowStyle = (disabled: boolean): CSSProperties => ({
    background: 'var(--bg-elev)', color: disabled ? 'var(--fg-muted)' : 'var(--fg)',
    border: '1px solid var(--border)', borderRadius: 4, width: 30, height: 30,
    cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.4 : 1,
    fontSize: '1.1rem', lineHeight: 1,
  });

  return (
    <section aria-labelledby="featured-heading" style={{ marginBottom: '2rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem', marginBottom: '0.75rem' }}>
        <h2 id="featured-heading" style={{ margin: 0 }}>Featured collections</h2>
        <div style={{ display: 'flex', gap: '0.35rem' }}>
          <button type="button" onClick={() => page(-1)} disabled={atStart} aria-label="Scroll collections left" style={arrowStyle(atStart)}>‹</button>
          <button type="button" onClick={() => page(1)} disabled={atEnd} aria-label="Scroll collections right" style={arrowStyle(atEnd)}>›</button>
        </div>
      </div>

      <div
        ref={scrollerRef}
        onScroll={handleScroll}
        role="region"
        aria-label="Featured collections, scroll horizontally"
        tabIndex={0}
        style={{
          display: 'flex', gap: '1rem', overflowX: 'auto',
          scrollSnapType: 'x mandatory', scrollPaddingLeft: '1rem',
          paddingBottom: '0.6rem',
        }}
      >
        {COLLECTIONS.map((c) => (
          <Link
            key={c.key}
            to={`/collections/${c.key}${themeQuery}`}
            style={{
              flex: '0 0 clamp(240px, 30%, 340px)', scrollSnapAlign: 'start',
              border: '1px solid var(--border)', borderRadius: 8, overflow: 'hidden',
              background: 'var(--bg-elev)', color: 'var(--fg)', textDecoration: 'none',
              display: 'flex', flexDirection: 'column',
            }}
          >
            <CardMedia collection={c} />
            <div style={{ padding: '0.7rem 0.85rem' }}>
              <strong style={{ display: 'block', fontSize: '0.92rem' }}>{c.label}</strong>
              <span style={{ display: 'block', marginTop: '0.2rem', fontSize: '0.8rem', color: 'var(--fg-muted)', lineHeight: 1.45 }}>
                {c.tagline}
              </span>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

function CardMedia({ collection }: { collection: Collection }) {
  const [failed, setFailed] = useState(false);
  const showFallback = collection.kind === 'typographic' || failed;

  if (showFallback) {
    return (
      <div
        aria-hidden
        style={{
          aspectRatio: '16 / 9', display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: '0.75rem', textAlign: 'center', fontWeight: 600, fontSize: '0.95rem',
          color: 'var(--fg-muted)', background: 'linear-gradient(135deg, var(--bg-elev), var(--bg))',
          borderBottom: '1px solid var(--border)',
        }}
      >
        {collection.label}
      </div>
    );
  }

  return (
    <img
      src={`/featured/${collection.key}.jpg`}
      alt={`${collection.label}, featured visualization`}
      onError={() => setFailed(true)}
      style={{ width: '100%', aspectRatio: '16 / 9', objectFit: 'cover', display: 'block', borderBottom: '1px solid var(--border)' }}
    />
  );
}
