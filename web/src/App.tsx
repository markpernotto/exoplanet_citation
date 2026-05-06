import { useEffect } from 'react';
import { Link, Route, Routes, useLocation, useNavigationType, useSearchParams } from 'react-router-dom';
import SearchBar from './components/SearchBar';
import ThemeSwitcher from './components/ThemeSwitcher';
import Home from './pages/Home';
import PlanetDetail from './pages/PlanetDetail';

// Scroll to top whenever the user navigates forward (clicking a link or
// search-submit). Browser-back ("POP") preserves the previous scroll position
// so going back from a planet detail returns you to where you were in the
// infinite-scroll list.
const VALID_THEMES = new Set(['phosphor-green', 'amber', 'cga', 'ega', 'hgc', 'plasma']);

function ThemeApplier() {
  const [searchParams] = useSearchParams();
  const theme = searchParams.get('theme') ?? '';
  useEffect(() => {
    const root = document.documentElement;
    if (VALID_THEMES.has(theme)) {
      root.dataset.theme = theme;
    } else {
      delete root.dataset.theme;
    }
    return () => { delete root.dataset.theme; };
  }, [theme]);
  return null;
}

function ScrollToTop() {
  const { pathname, search } = useLocation();
  const navType = useNavigationType();
  useEffect(() => {
    if (navType !== 'POP') {
      window.scrollTo(0, 0);
    }
  }, [pathname, search, navType]);
  return null;
}

export default function App() {
  return (
    <>
      <ScrollToTop />
      <ThemeApplier />
      <header className="site">
        <div className="site-inner">
          <div className="site-header-row">
            <h1><Link to="/">exoplanet_citation</Link></h1>
            <span className="tagline">a public catalog of confirmed exoplanets and the papers that announced them</span>
            <ThemeSwitcher />
          </div>
          <SearchBar />
        </div>
      </header>

      <div className="layout">
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/planets/:plName" element={<PlanetDetail />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </main>

        <footer className="site">
          <div className="footer-line">
            Built as part of <a href="https://facetbuild.llc">Facet Build, LLC</a>
            {' · '}<a href="https://github.com/markpernotto/exoplanet_citation">Source on GitHub</a>
            {' · '}<a href="/docs">API docs</a>
            {' · '}Data from <a href="https://exoplanetarchive.ipac.caltech.edu/">NASA Exoplanet Archive</a>
          </div>
        </footer>
      </div>
    </>
  );
}

function NotFound() {
  return (
    <div className="empty">
      <p>That page doesn't exist.</p>
      <p><Link to="/">← back to home</Link></p>
    </div>
  );
}
