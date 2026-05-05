import { Link, Route, Routes } from 'react-router-dom';
import Home from './pages/Home';
import PlanetDetail from './pages/PlanetDetail';

export default function App() {
  return (
    <div className="layout">
      <header className="site">
        <h1><Link to="/">exoplanet_citation</Link></h1>
        <span className="tagline">a public catalog of confirmed exoplanets and the papers that announced them</span>
      </header>

      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/planets/:plName" element={<PlanetDetail />} />
        <Route path="*" element={<NotFound />} />
      </Routes>

      <footer className="site">
        <p style={{ margin: 0 }}>
          Built as part of <a href="https://facetbuild.llc">Facet Build, LLC</a>.
          {' '}<a href="https://github.com/markpernotto/exoplanet_citation">Source on GitHub</a>
          {' · '}<a href="/docs">API docs</a>
        </p>
        <p style={{ margin: '0.5rem 0 0', fontSize: '0.8rem' }}>
          Data from the <a href="https://exoplanetarchive.ipac.caltech.edu/">NASA Exoplanet Archive</a>,
          {' '}operated by Caltech under contract with NASA.
        </p>
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
