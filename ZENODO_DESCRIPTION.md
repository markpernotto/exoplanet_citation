# Exoplanet Citation Atlas

A public, daily-refreshed open-source data warehouse linking the NASA Exoplanet Archive's confirmed exoplanets to the scientific papers that announced them and (where available) to the follow-up literature characterizing them.

- **Citation coverage at 100%** via a four-tier resolver: NASA ADS bibcode, arXiv API, ADS title search, and a manual triage queue.
- **Gaia DR3 host-star enrichment** for all enrichable hosts.
- **Value-added enrichment** harvested from the discovery and follow-up literature: per-planet atmospheres (`planet_atmospheres`), scalar derived measurements (`planet_derived_measurements`), and inner-binary parameters (`binary_companions` with the `manual` provenance backfill).
- **FastAPI service** over the warehouse with automatic Swagger docs.
- **React + Three.js + WebXR frontend** at https://exoplanetcitation.space with per-vantage starfield reprojection of ~1.4M Gaia stars.

The v0.1.2 release accompanies the Research Note of the AAS titled *An Audit of `cb_flag = 1` Entries in the NASA Exoplanet Archive Composite-Parameters Table*, and serves as the citable snapshot of the per-host data record in `docs/cb_flag_audit.md`.

**Repository:** https://github.com/markpernotto/exoplanet_citation  (package identifier: `exoplanet_citation`)

**Live data product:** https://exoplanetcitation.space

**License:** MIT (code).
