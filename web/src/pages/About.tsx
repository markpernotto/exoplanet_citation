import { Link, useLocation } from 'react-router-dom';

export default function About() {
  const location = useLocation();
  const themeParam = new URLSearchParams(location.search).get('theme');
  const themeQuery = themeParam ? `?theme=${themeParam}` : '';

  return (
    <>
      <p style={{ margin: '0 0 1rem' }}>
        <Link to={`/${themeQuery}`}>← back</Link>
      </p>

      <h1 style={{ margin: '0 0 0.4rem' }}>Exoplanet Citation Atlas</h1>
      <p style={{
        margin: '0 0 2rem',
        fontSize: '1rem',
        color: 'var(--fg-muted)',
        lineHeight: 1.55,
      }}>
        Linking every confirmed exoplanet to its discovery papers, atmospheric
        observations, and full stellar architecture, in one open-source view.
      </p>

      <section>
        <h2>Why this exists</h2>
        <p style={{ lineHeight: 1.65, fontSize: '0.95rem' }}>
          Exoplanet science is spread across canonical archives that each do
          their part well. The <a href="https://exoplanetarchive.ipac.caltech.edu/" target="_blank" rel="noopener noreferrer">NASA Exoplanet Archive</a> curates
          confirmed-planet parameters. <a href="https://ui.adsabs.harvard.edu/" target="_blank" rel="noopener noreferrer">NASA ADS</a> indexes
          the literature. <a href="https://www.cosmos.esa.int/web/gaia/dr3" target="_blank" rel="noopener noreferrer">Gaia DR3</a> supplies
          stellar astrometry, photometry, and color information. The <a href="http://www.astro.gsu.edu/wds/" target="_blank" rel="noopener noreferrer">Washington
          Double Star Catalog</a> records visual stellar multiplicity.
        </p>
        <p style={{ lineHeight: 1.65, fontSize: '0.95rem' }}>
          Researchers, educators, and proposal writers asking system-level
          questions (what was the discovery paper, has the atmosphere been
          observed, what other stars are bound to the host, what does the
          architecture look like at scale) have had to query several of these
          services in parallel. The Atlas brings them together into a single
          per-object view, so a planet page can answer the cross-cutting
          question in one place.
        </p>
      </section>

      <section style={{ marginTop: '2rem' }}>
        <h2>About</h2>
        <p style={{ lineHeight: 1.65, fontSize: '0.95rem' }}>
          The Atlas is built and maintained by <strong>Mark Pernotto</strong>,
          an independent researcher with a BA in Computer Science and a Master
          of Library and Information Science (MLIS) including a Certificate of
          Advanced Studies in Digital Libraries. The project is developed at
          {' '}<a href="https://facetbuild.llc" target="_blank" rel="noopener noreferrer">Facet Build, LLC</a>.
        </p>
        <dl style={{
          margin: '1rem 0 0',
          display: 'grid',
          gridTemplateColumns: 'auto 1fr',
          gap: '0.4rem 1rem',
          fontSize: '0.9rem',
        }}>
          <dt style={{ color: 'var(--fg-muted)' }}>Source code</dt>
          <dd style={{ margin: 0 }}>
            <a href="https://github.com/markpernotto/exoplanet_citation" target="_blank" rel="noopener noreferrer">
              github.com/markpernotto/exoplanet_citation
            </a>
          </dd>
          <dt style={{ color: 'var(--fg-muted)' }}>License</dt>
          <dd style={{ margin: 0 }}>MIT</dd>
          <dt style={{ color: 'var(--fg-muted)' }}>Citable via Zenodo</dt>
          <dd style={{ margin: 0 }}>
            <a
              href="https://doi.org/10.5281/zenodo.20191479"
              target="_blank"
              rel="noopener noreferrer"
            >
              <img
                src="https://zenodo.org/badge/1228082575.svg"
                alt="DOI 10.5281/zenodo.20191479"
                style={{ verticalAlign: 'middle' }}
              />
            </a>
          </dd>
          <dt style={{ color: 'var(--fg-muted)' }}>Contact</dt>
          <dd style={{ margin: 0 }}>
            <a href="mailto:mark@pernotto.com">mark@pernotto.com</a>
          </dd>
        </dl>
      </section>

      <section style={{ marginTop: '2rem' }}>
        <h2>Methods and roadmap</h2>
        <p style={{ lineHeight: 1.65, fontSize: '0.95rem' }}>
          The Atlas snapshot-ingests the NASA Exoplanet Archive's
          confirmed-planet table, joins it to Gaia DR3 host astrometry, and
          pulls discovery papers and citation history from NASA ADS.
          Atmospheric observation campaigns and molecule detections are
          aggregated from published sources. The 3D scene viewer renders each
          system at true linear orbital scale, applies measured mutual
          inclinations where available, and generates per-vantage starfields
          from Gaia DR3 sources.
        </p>
        <p style={{ margin: '1rem 0 0.4rem', lineHeight: 1.65, fontSize: '0.95rem' }}>
          Two data-quality observations from the v0.1 release worth noting
          publicly:
        </p>
        <ol style={{ lineHeight: 1.65, fontSize: '0.9rem', paddingLeft: '1.2rem' }}>
          <li style={{ margin: '0 0 0.6rem' }}>
            The WDS to NEA join, when projected separation is computed as
            angular separation times system distance, places some entries at
            tens to hundreds of thousands of AU from the host. This release
            applies a 25,000 AU threshold to filter the likely line-of-sight
            coincidences from the rendered scene. These are flagged for
            ongoing conversation with the upstream catalog maintainers, not
            presented as corrections.
          </li>
          <li>
            A handful of hierarchical systems carry an NEA <code>cb_flag</code>
            {' '}value of 1 (circumbinary) where the planet may instead orbit
            one star in a wider pair. Tracked here for the same kind of
            ongoing discussion.
          </li>
        </ol>
        <p style={{ margin: '1rem 0 0', lineHeight: 1.65, fontSize: '0.95rem' }}>
          <strong>Planned for upcoming releases:</strong> per-planet infrared
          observation integration, shareable 3D scene URLs, expanded citation
          graph views, and continued data-quality audits.
        </p>
      </section>

      <p style={{
        marginTop: '2.5rem',
        fontSize: '0.78rem',
        color: 'var(--fg-muted)',
        lineHeight: 1.5,
        borderTop: '1px solid var(--border)',
        paddingTop: '1rem',
      }}>
        Exoplanet Citation Atlas is an independent research project by Mark
        Pernotto, built at Facet Build, LLC. Open source under the MIT
        License.
      </p>
    </>
  );
}
