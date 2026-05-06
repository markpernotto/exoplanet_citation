import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

export default function SearchBar() {
  const navigate = useNavigate();
  const location = useLocation();
  const [query, setQuery] = useState('');

  // Pre-fill the input based on current route:
  //   /planets/:plName → fill with plName
  //   /?q=foo         → fill with foo
  //   anything else   → empty
  useEffect(() => {
    const planetMatch = location.pathname.match(/^\/planets\/(.+)$/);
    if (planetMatch) {
      setQuery(decodeURIComponent(planetMatch[1]));
      return;
    }
    if (location.pathname === '/') {
      const params = new URLSearchParams(location.search);
      setQuery(params.get('q') ?? '');
      return;
    }
    setQuery('');
  }, [location.pathname, location.search]);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const q = query.trim();
    const next = new URLSearchParams(location.search);
    if (!q) {
      next.delete('q');
      const qs = next.toString();
      navigate(qs ? `/?${qs}` : '/');
      return;
    }
    next.set('q', q);
    navigate(`/?${next.toString()}`);
  }

  return (
    <form className="search-bar" onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder='Search a planet or host star — try "TRAPPIST", "Proxima", "Kepler-22"'
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      <button type="submit">Search</button>
    </form>
  );
}
