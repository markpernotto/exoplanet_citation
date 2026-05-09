import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';

type Feed = {
  title: string;
  description: string;
  pattern: string;
  example: string;
  notes?: string;
};

const FEEDS: Feed[] = [
  {
    title: 'Everything',
    description: 'Every newly confirmed planet, every removal, and every Tier-A parameter revision across the catalog. Site-wide firehose.',
    pattern: '/api/rss',
    example: '/api/rss',
    notes: 'Accepts an optional ?days=N parameter (1–365, default 30) to widen or narrow the window.',
  },
  {
    title: 'A single planet',
    description: 'Surfaced changes for one planet only. Useful when you care about parameter refinements to a specific world.',
    pattern: '/api/rss/planet/{pl_name}',
    example: '/api/rss/planet/TRAPPIST-1%20e',
    notes: 'pl_name uses the canonical NASA Exoplanet Archive form (spaces → %20).',
  },
  {
    title: 'A whole system',
    description: 'Every planet orbiting a given host star. New planets discovered in the system show up automatically.',
    pattern: '/api/rss/system/{hostname}',
    example: '/api/rss/system/TRAPPIST-1',
  },
  {
    title: 'A discoverer',
    description: "Surfaced changes for every planet whose discovery paper lists this person as a co-author. Track an astronomer's portfolio over time.",
    pattern: '/api/rss/author/{author_name}',
    example: '/api/rss/author/Gillon%2C%20M.',
    notes: 'author_name matches the ADS format exactly: "Lastname, F. M." — commas encoded as %2C.',
  },
];

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  function copy() {
    navigator.clipboard.writeText(value).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }).catch(() => {});
  }
  return (
    <button
      onClick={copy}
      style={{
        background: 'var(--bg-elev)',
        border: '1px solid var(--border)',
        color: 'var(--fg)',
        padding: '0.25rem 0.55rem',
        fontSize: '0.78rem',
        cursor: 'pointer',
        borderRadius: '3px',
        fontFamily: 'inherit',
      }}
    >
      {copied ? 'Copied!' : 'Copy URL'}
    </button>
  );
}

export default function Feeds() {
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  const origin = typeof window !== 'undefined' ? window.location.origin : 'https://exoplanet-citation.vercel.app';

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <Link to={`/${themeQuery}`}>← back</Link>
      </p>
      <h1 style={{ margin: '0 0 0.4rem' }}>Subscribe by RSS</h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)', fontSize: '0.9rem', maxWidth: '52ch' }}>
        Four feed shapes — pick whichever scope fits how you read.
        Every feed surfaces only meaningful changes (newly confirmed planets,
        removals, and revisions to the six Tier-A high-value parameters).
        Sub-tolerance noise is filtered out.
      </p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {FEEDS.map((feed) => {
          const fullUrl = `${origin}${feed.example}`;
          return (
            <div key={feed.pattern} className="card" style={{ padding: '1rem 1.1rem' }}>
              <h2 style={{ margin: '0 0 0.4rem', fontSize: '1.05rem' }}>{feed.title}</h2>
              <p style={{ margin: '0 0 0.65rem', fontSize: '0.88rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                {feed.description}
              </p>
              <div style={{ margin: '0 0 0.5rem', fontSize: '0.82rem' }}>
                <span style={{ color: 'var(--fg-muted)' }}>Pattern: </span>
                <code style={{ background: 'var(--bg-elev)', padding: '0.1rem 0.35rem', borderRadius: '2px' }}>
                  {feed.pattern}
                </code>
              </div>
              <div style={{ display: 'flex', gap: '0.55rem', alignItems: 'center', flexWrap: 'wrap', margin: '0 0 0.45rem' }}>
                <a href={feed.example} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.82rem', wordBreak: 'break-all' }}>
                  {fullUrl}
                </a>
                <CopyButton value={fullUrl} />
              </div>
              {feed.notes && (
                <p style={{ margin: '0.35rem 0 0', fontSize: '0.78rem', color: 'var(--fg-muted)', lineHeight: 1.5 }}>
                  {feed.notes}
                </p>
              )}
            </div>
          );
        })}
      </div>

      <div style={{ marginTop: '1.5rem', fontSize: '0.82rem', color: 'var(--fg-muted)', maxWidth: '60ch', lineHeight: 1.55 }}>
        <p style={{ margin: '0 0 0.5rem' }}>
          <strong style={{ color: 'var(--fg)' }}>Refresh cadence:</strong>{' '}
          all feeds advertise a 24-hour TTL because the underlying data only updates once per night when the
          NASA Exoplanet Archive snapshot diff runs (06:00 UTC).
        </p>
        <p style={{ margin: '0 0 0.5rem' }}>
          <strong style={{ color: 'var(--fg)' }}>What's surfaced vs. logged:</strong>{' '}
          NEW + REMOVED events are always surfaced. PARAMETER_CHANGE is surfaced only for
          the six Tier-A fields (discoverymethod, disc_year, disc_facility, pl_orbper,
          pl_rade, pl_bmasse). Tier-B field changes are logged in <code>discovery_changes</code>{' '}
          but kept out of feeds so subscribers don't drown in noise.
        </p>
        <p style={{ margin: 0 }}>
          <strong style={{ color: 'var(--fg)' }}>Discoverability:</strong>{' '}
          every planet, system, and author detail page also includes its own RSS link in
          the page subtitle, so you can browse to a target and grab its feed without
          memorizing a URL pattern.
        </p>
      </div>
    </>
  );
}
