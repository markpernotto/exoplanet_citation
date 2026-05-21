# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Tagged releases are published under
[GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases),
and each mints a version-specific
[Zenodo](https://doi.org/10.5281/zenodo.20191479) DOI for citation.

## [Unreleased]

Changes since v0.1.0 (2026-05-14). Target version: v0.1.1.

### Added

- **Circumbinary (`cb_flag`) audit** of all 54 `cb_flag=1` planets across 44
  host systems, reviewed against their discovery and follow-up literature and
  recorded per host in `docs/cb_flag_audit.md` (the public data record).
- **Inner-binary enrichment**: component masses, radii, periods, and
  eccentricities harvested from the discovery papers and seeded into
  `binary_companions`, with an `inner_binary` flag separating the tight
  P-type-defining pair from wide visual companions
  (`etl/seed_inner_binaries.py`, migration 011).
- **Multi-role citation graph**: `prior_detection` and `characterization` roles
  plus a `contribution` column recording what each cited paper supplied
  (migrations 013 and 014; `etl/seed_followup_citations.py`), so every enriched
  data point is traceable to the paper it came from. Author and metadata
  backfill for the hand-seeded citations via
  `etl/enrich_publication_metadata.py`.
- **Literature distances** for hosts that both Gaia and the archive miss
  (`host_distances_manual`, migration 012).
- **Imperial / metric units toggle** on planet detail pages (SI vs Earth radii
  / kilometers / miles), persisted in `localStorage` (PR #12).
- **This CHANGELOG**, plus a `.gitignore` guard for the in-preparation Research
  Note draft.

### Changed

- **Citation coverage reached 100%** (6,287 / 6,287 planets) via the final
  hand-resolve pass over the historical edge cases the automated resolver
  could not reach.
- **3D scene polish** (PR #13): starfield render fixes, default resolution
  tuned (8K to 6K), scene-URL sharing improvements, and corrections to the
  curated / multi-star "feature systems" lists on the landing page.
- **Project framing** shifted from mirroring the NASA Exoplanet Archive to
  auditing and adding value to it; the README roadmap was restructured away
  from the phase-based plan.

### Fixed

- Outer-orbit sun appearance in the system view.
- Non-finite inputs no longer break the unit formatters.
- Deterministic row ordering for Gaia data in the `/companions` LATERAL
  subquery and the `host_stars_gaia` query (stable tie-breakers).
- Assorted frontend build issues.

## [0.1.0] - 2026-05-14

First tagged release: the nightly ETL pipeline (extract, load, dbt,
field-tier-aware diff, publish), the citation-graph resolver (four tiers: ADS
bibcode, arXiv API, ADS title, manual queue), Gaia DR3 host-star enrichment, the
FastAPI service, and the React + Three.js + WebXR frontend including the 3D scene
viewer, retro display themes, and the per-vantage starfield rasterizer. Predates
this changelog; see the git history for detail. Subsequent versions are listed
under [GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases).
