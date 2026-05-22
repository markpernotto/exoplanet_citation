# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Tagged releases are published under
[GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases),
and each mints a version-specific
[Zenodo](https://doi.org/10.5281/zenodo.20191479) DOI for citation.

## [Unreleased]

_Nothing yet._

## [0.1.2] - 2026-05-21

### Added

- **Citations & references on planet pages**: the planet detail page now renders
  every non-discovery citation (follow-up, prior detection, characterization)
  grouped by role, each with its `contribution` tag (e.g. binary masses,
  distance), so the papers the audit drew data from are credited in the UI and
  not only in the database. The `/api/planets/{name}/publications` response now
  includes `contribution`.
- **Old-discovery data harvest** (manual literature deep dive): the catalog's
  oldest systems were held at discovery-only depth. Added landmark atmosphere
  detections to `planet_atmospheres` for HD 209458 b (Na, H, CO, H2O), 51 Peg b (H2O),
  HD 189733 b (Na, H2O, CO), and 55 Cnc e (CO2/CO, tentative); refined the ups And c/d
  mutual inclination to the published 29.9 +/- 1.0 deg; backfilled wide stellar-companion separations for HD 189733 (216 AU) and ups And (750 AU); and linked the source
  papers as `characterization` / `follow_up` citations (migration 015 plus
  `etl/seed_followup_citations.py`). All values verified against ADS.
- **Landmark JWST/HST atmosphere detections**: curated molecule detections added
  to `planet_atmospheres` for WASP-39 b (CO2 at 26σ, SO2), WASP-96 b (Na), and
  K2-18 b (CH4, CO2), with citations (migration 016). The tentative K2-18 b DMS
  signal is deliberately excluded.

### Fixed

- Paper titles, abstracts, and discovery references on the planet page now render
  as clean text. ADS / NASA strings carry HTML markup (`<SUB>`/`<SUP>` tags and
  entities like `&amp;` / `&gt;` / accented-character escapes) that previously
  showed raw; a `plainText` helper decodes entities and strips tags before
  display.

## [0.1.1] - 2026-05-21

Changes since v0.1.0 (2026-05-14).

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
