import { useEffect, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { api, type AuthorPlanet, type AuthorResponse } from '../api';
import LoadingBar from '../components/LoadingBar';

export default function AuthorDetail() {
  const { authorName = '' } = useParams<{ authorName: string }>();
  const decoded = decodeURIComponent(authorName);
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';
  const from = (location.state as { from?: string } | null)?.from;

  const [data, setData] = useState<AuthorResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setData(null);
    setError(null);
    api.authorDetail(decoded).catch((e: Error) => setError(e.message)).then((r) => {
      if (r) setData(r);
    });
  }, [decoded]);

  const adsSearchUrl = `https://ui.adsabs.harvard.edu/search/q=author%3A%22${encodeURIComponent(decoded)}%22`;

  if (error) {
    const isNotFound = error.startsWith('404');
    return (
      <>
        <p style={{ margin: '0 0 1rem' }}>
          <Link to={from ?? `/${themeQuery}`}>← back</Link>
        </p>
        {isNotFound ? (
          <div className="empty">
            <p>No confirmed discoveries found for <strong>{decoded}</strong>.</p>
            <p style={{ marginTop: '0.5rem' }}>
              Author names must match the ADS format exactly (e.g. "Butler, R. Paul").{' '}
              <a href={adsSearchUrl} target="_blank" rel="noopener noreferrer">Search ADS directly →</a>
            </p>
          </div>
        ) : (
          <div className="error">{error}</div>
        )}
      </>
    );
  }

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <Link to={from ?? `/${themeQuery}`}>← back</Link>
      </p>
      <h1 style={{ margin: '0 0 0.2rem' }}>{decoded}</h1>
      <p style={{ margin: '0 0 1.5rem', color: 'var(--fg-muted)', fontSize: '0.9rem' }}>
        {data ? (
          <>
            <strong style={{ color: 'var(--fg)' }}>{data.planet_count}</strong> confirmed exoplanet{data.planet_count === 1 ? '' : 's'} as co-author of discovery paper
            {' · '}
            <a href={adsSearchUrl} target="_blank" rel="noopener noreferrer">ADS author search →</a>
          </>
        ) : 'Loading…'}
      </p>

      <LoadingBar loading={!data} />

      {data && <PlanetsByPaper planets={data.planets} themeQuery={themeQuery} />}
    </>
  );
}

function PlanetsByPaper({ planets, themeQuery }: { planets: AuthorPlanet[]; themeQuery: string }) {
  // Group planets by bibcode so multi-planet papers appear together
  const papers = new Map<string, { planets: AuthorPlanet[] }>();
  for (const p of planets) {
    if (!papers.has(p.bibcode)) papers.set(p.bibcode, { planets: [] });
    papers.get(p.bibcode)!.planets.push(p);
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      {[...papers.values()].map(({ planets: group }) => {
        const rep = group[0];
        const adsUrl = `https://ui.adsabs.harvard.edu/abs/${encodeURIComponent(rep.bibcode)}/abstract`;
        const doiUrl = rep.doi ? `https://doi.org/${rep.doi}` : null;
        const arxivUrl = rep.arxiv_id ? `https://arxiv.org/abs/${rep.arxiv_id}` : null;
        return (
          <div key={rep.bibcode} className="card" style={{ padding: '0.85rem 1rem' }}>
            <p style={{ margin: '0 0 0.15rem', fontWeight: 600, fontSize: '0.92rem', lineHeight: 1.4 }}>
              <a href={adsUrl} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--fg)' }}>
                {rep.paper_title ?? rep.bibcode}
              </a>
            </p>
            <p style={{ margin: '0 0 0.6rem', fontSize: '0.8rem', color: 'var(--fg-muted)' }}>
              {[rep.journal, rep.pub_date?.slice(0, 4)].filter(Boolean).join(' · ')}
              {rep.citation_count != null && (
                <> · <strong style={{ color: 'var(--fg)' }}>{rep.citation_count.toLocaleString()}</strong> citations</>
              )}
            </p>
            <ul style={{ margin: '0 0 0.65rem', padding: '0 0 0 1rem', display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
              {group.map((p) => (
                <li key={p.pl_name} style={{ fontSize: '0.88rem' }}>
                  <Link to={`/planets/${encodeURIComponent(p.pl_name)}${themeQuery}`}>
                    {p.pl_name}
                  </Link>
                  <span style={{ color: 'var(--fg-muted)' }}>
                    {p.hostname && p.hostname !== p.pl_name.replace(/ [a-z]$/, '') && <> · {p.hostname}</>}
                    {p.disc_year != null && <> · {p.disc_year}</>}
                    {p.discoverymethod && <> · {p.discoverymethod}</>}
                  </span>
                </li>
              ))}
            </ul>
            <div style={{ display: 'flex', gap: '0.65rem', fontSize: '0.8rem' }}>
              <a href={adsUrl} target="_blank" rel="noopener noreferrer">ADS →</a>
              {doiUrl && <a href={doiUrl} target="_blank" rel="noopener noreferrer">DOI →</a>}
              {arxivUrl && <a href={arxivUrl} target="_blank" rel="noopener noreferrer">arXiv →</a>}
            </div>
          </div>
        );
      })}
    </div>
  );
}
