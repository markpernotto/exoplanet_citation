import { Link, Route, Routes } from 'react-router-dom';
import SearchBar from './components/SearchBar';
import Home from './pages/Home';
import PlanetDetail from './pages/PlanetDetail';

export default function App() {
  return (
    <div className="layout">
      <header className="site">
        <div className="site-header-row">
          <h1><Link to="/">exoplanet_citation</Link></h1>
          <span className="tagline">a public catalog of confirmed exoplanets and the papers that announced them</span>
        </div>
        <SearchBar />
      </header>

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
