# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Tagged releases are published under
[GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases),
and each mints a version-specific
[Zenodo](https://doi.org/10.5281/zenodo.20191479) DOI for citation.

## [Unreleased]

### Added

- **Orbital-geometry citations** (manual literature deep dive): migration 010
  bulk-seeded mutual inclinations into `system_orbital_geometry` for a cohort of
  multi-planet systems but never linked the papers the values came from, so the
  Atlas displayed measurements it did not cite. Added 72 `characterization`
  citations with a `mutual_inclination` contribution crediting each system's
  source paper across all 17 multi-planet systems of the cohort (TRAPPIST-1,
  HR 8799, GJ 876, beta Pictoris, K2-138, Kepler-9, Kepler-11, Kepler-30,
  Kepler-36, Kepler-56, Kepler-90, Kepler-186, Kepler-223, Kepler-419,
  Kepler-444, TOI-178, WASP-47) via `etl/seed_followup_citations.py`. All
  bibcodes verified against ADS; the Atlas no longer shows an orbital-geometry
  value it cannot trace to a paper.
- **TRAPPIST-1 atmosphere deep dive** (manual literature review): curated the
  JWST campaign's conclusions for the inner planets. All are atmosphere
  constraints rather than detections (no molecule has been positively detected on
  any TRAPPIST-1 planet), so `planet_atmospheres` records them with two
  non-positive `detection` states, `ruled_out` and `inconclusive`: TRAPPIST-1 b
  (bare rock vs thick-CO2-with-haze, degenerate; Greene 2023 + Ducrot 2025),
  c (thick CO2 / H2-dominated ruled out; Zieba 2023 + Radica 2025 + Rathcke 2025),
  d (flat spectrum, clear H2-dominated and trace CO2 excluded above 3 sigma;
  Piaulet-Ghorayeb 2025), and e (habitable-zone planet; H2-dominated ruled out,
  secondary atmosphere unconstrained; Espinoza 2025). Seven
  `characterization` / `atmosphere` citations added (migration 020); the
  Collections atmospheres view now distinguishes detections from ruled-out
  results. All bibcodes verified against ADS.
- **Derived-measurements layer** (new `planet_derived_measurements` table;
  migrations 022 + 024): a single, general home for any literature-derived scalar
  property (interior composition, elemental abundances, metal budget, ...) with
  asymmetric uncertainty, unit, model assumption, and source, keyed by
  `(pl_name, quantity, bibcode)` so a new result type is a new `quantity` value,
  not a new table. (It replaces the initial single-purpose
  `planet_interior_composition` table, whose rows are folded in here.) Seeded with
  TRAPPIST-1 core mass fractions and Fe/Mg ratios (Agol et al. 2021; iron-poor
  cores, dry-inner / wetter-outer volatile gradient, core-mass-fraction vs water
  degeneracy noted) and the HR 8799 planets' elemental abundances and metal budget
  - total heavy-element mass split into accreted solids vs metal-enriched gas, the
  core-accretion signature (Xuan et al. 2026, Tables 4 and 5). NASA EA already
  carries the masses, radii, and stellar parameters, so those were deliberately
  not duplicated.
- **HR 8799 atmosphere deep dive** (manual literature review): the four
  directly-imaged giant planets had no curated molecule data. Added 29 molecule
  rows to `planet_atmospheres` (migration 023; 26 detected, 3 tentative), from
  Konopacky 2013 (c: CO, H2O), Barman 2015 (b: H2O, CH4, CO), and the JWST/NIRSpec
  study Xuan et al. 2026, whose per-planet Table 3 supplies detection
  significances (stored as CCF S/N) for CO2, H2S, NH3, and the 13CO / C18O
  isotopologues - tying the planets' super-stellar metallicities to core
  accretion. Per-planet specifics from that table: H2S in b/c/d but not e, NH3
  only in b, and C18O/HDO/HCN only tentative in b. Six `characterization` /
  `atmosphere` citations added; all bibcodes verified against ADS. These are the
  first curated detections that drive the 3D scene's atmosphere tint.
- **beta Pictoris b deep dive** (manual literature review): the directly-imaged
  giant had no curated atmosphere or derived-property data. Added CO (Snellen
  2014, VLT/CRIRES) and H2O (GRAVITY 2020) to `planet_atmospheres`, and its fast
  spin (~25 km/s equatorial rotation, Snellen 2014) and C/O ratio (0.43 +/- 0.05,
  GRAVITY 2020 - low C/O with a high mass implying core accretion) to
  `planet_derived_measurements` - the first use of that table for a
  non-composition scalar (planetary spin). Two `characterization` / `atmosphere`
  citations added (migration 025); bibcodes verified against ADS.
- **GJ 876 and Kepler-11 characterization citations** (manual literature review):
  the last two of the five geometry-cohort systems, both non-atmosphere targets
  (GJ 876 is non-transiting; Kepler-11's faint host has no molecule spectroscopy),
  so the value-add is crediting their dynamical / benchmark characterization. GJ
  876 b now cites Benedict et al. 2002 (the first astrometrically-determined
  exoplanet mass), and all four planets cite Nelson et al. 2016 (the empirical
  3-D Laplace-resonance architecture); Kepler-11's six planets cite Bedell et al.
  2017 (revised benchmark masses and radii from a precise solar-twin stellar
  characterization). GJ 876 b additionally gains its astrometric inclination
  (84 +/- 6 deg, in known tension with the dynamical ~59 deg) and astrometric mass
  (1.89 +/- 0.34 M_Jup) in `planet_derived_measurements` from Benedict et al. 2002,
  the first astrometric exoplanet mass (migration 026). Kepler-11 b-f gain their
  present-day envelope/volatile fractions (H/He for c-f, peaking at ~17% on e;
  ~40% water for b, which cannot retain H/He) from Lopez et al. 2012 in
  `planet_derived_measurements` (migration 027). All bibcodes verified against ADS.
- **WASP-121 b atmosphere deep dive** (manual literature review): the benchmark
  ultra-hot Jupiter, previously discovery-cite only, now carries 13
  `planet_atmospheres` rows (migration 028) - H2O (Evans 2017, emission +
  stratosphere), VO (Evans 2018), the neutral metal inventory Na/Mg/Ca/Cr/Fe/Ni/V
  (Hoeijmakers 2020, HARPS), escaping ionised Fe II and Mg II (Sing 2019), and SiO
  at 5.2 sigma (Gapp 2025, JWST/NIRSpec), plus a TiO non-detection (the titanium
  cold-trap). Five `characterization` / `atmosphere` citations added; bibcodes
  verified against ADS. First in a JWST-era atmosphere-showcase set.
- **GJ 1214 b deep dive** (manual literature review): the archetype sub-Neptune,
  famously featureless in transmission. Added H2O (detected, >3 sigma) and
  tentative CO2 / CH4 to `planet_atmospheres`, and its JWST phase-curve scalars -
  Bond albedo 0.51 +/- 0.06 and dayside/nightside brightness temperatures
  553 / 437 K - to `planet_derived_measurements` (migration 029), from Kreidberg
  2014 (clouds), Kempton 2023 (reflective, metal-rich), and Schlawin 2024
  (tentative CO2/CH4). Three `characterization` / `atmosphere` citations added;
  bibcodes verified against ADS.
- **WASP-107 b deep dive** (manual literature review): the low-density warm
  Neptune, among the most thoroughly characterised exoplanet atmospheres. Added 6
  `planet_atmospheres` rows (migration 030) - He (Spake 2018, the first exoplanet
  helium detection, eroding atmosphere), H2O (21 sigma), CH4 (depleted, revealing
  the core mass), CO (7 sigma), CO2, and photochemical SO2 with silicate clouds -
  from the JWST-2024 trio (Dyrek, Sing, Welbanks) plus Kreidberg 2018. Five
  `characterization` / `atmosphere` citations added; bibcodes verified against ADS.
- **LHS 1140 b deep dive** (manual literature review): the temperate (226 K)
  habitable-zone super-Earth. JWST transmission ruled out a H2-rich / mini-Neptune
  atmosphere (Damiano 2024, "a potentially habitable water world"; Cadieux 2024),
  recorded as an H2 `ruled_out` row plus a `water_mass_fraction` of 9-19%
  (water-world) in `planet_derived_measurements` (migration 031). Two
  `characterization` / `atmosphere` citations added; bibcodes verified against ADS.
- **WASP-76 b deep dive** (manual literature review): the "iron rain" ultra-hot
  Jupiter. Added 9 `planet_atmospheres` rows (migration 032) - neutral Fe
  (Ehrenreich 2020, with the famous day-night condensation asymmetry), the
  ESPRESSO metal inventory Li (first detection) / Na (9.2 sigma) / Mg / Ca II / Mn
  / K (Tabernero 2021), VO (Pelletier 2023), and a TiO non-detection (cold-trap) -
  plus the iron-rain terminator wind velocity (-11 km/s) in
  `planet_derived_measurements`. Three `characterization` / `atmosphere` citations
  added; bibcodes verified against ADS. Completes a five-system JWST-era
  atmosphere-showcase set (WASP-121 b, GJ 1214 b, WASP-107 b, LHS 1140 b,
  WASP-76 b).
- **"Recently added" section on the landing page**: shows the latest pipeline
  run above "Most recently confirmed" (without replacing it). New planets render
  as the same catalog cards (`PlanetGrid`); notable physical revisions (mass,
  radius, period, etc.) appear as a quiet "Also updated" line with bookkeeping
  churn (disc_year, refnames) filtered out; removals get their own line. The
  section hides entirely when a run has no meaningful changes. Fixes the gap
  where newly ingested planets did not appear "as they come in" because the main
  catalog list sorts by NASA discovery year. Built on `/api/discoveries/latest`.

### Changed

- **TRAPPIST-1 orbital geometry refined to Agol et al. 2021** (migration 021):
  replaced the hand-curated mutual inclinations (sourced to the Gillon 2017
  discovery paper) with the measured sky-plane orbital inclinations from Agol
  et al. 2021's photodynamic fit (89.73-89.90 deg per planet). That analysis
  assumes coplanar orbits and does not fit the ascending nodes, so the stored
  values are the inclination difference from planet b (a coplanar-node lower
  bound), all consistent with coplanar within uncertainty; the per-row note
  records the caveat. Agol 2021 added as a `characterization` /
  `mutual_inclination` citation, with the Gillon 2017 citation retained as the
  paper that established the flat architecture.

### Fixed

- **Orbital-geometry provenance for Kepler-9, Kepler-11, Kepler-30, and
  Kepler-36** (migration 017): migration 010 attributed all four systems' mutual
  inclinations to Fabrycky et al. 2014, which is a statistical architecture study
  across 365 Kepler systems, not a per-system source. Repointed each
  `system_orbital_geometry.bibcode` to its true per-system paper (Kepler-11 ->
  Lissauer et al. 2013, Kepler-9 -> Borsato et al. 2014, Kepler-30 ->
  Sanchis-Ojeda et al. 2012, Kepler-36 -> Carter et al. 2012), matching the
  citations seeded above.
- **WASP-47 orbital-geometry bibcode** (migration 018): the recorded source
  `2017AJ....154..237B` did not resolve against ADS. It was a typo for
  `2017AJ....154..237V` (Vanderburg et al. 2017, "Precise Masses in the WASP-47
  System"); corrected.
- **Kepler-90 orbital-geometry keys and source** (migration 019): the system's
  geometry rows were keyed `Kepler-90 b`..`h`, but the catalog names those
  planets `KOI-351 b`..`h` (only the eighth is `Kepler-90 i`), leaving the b-h
  geometry orphaned from the catalog. Renamed the rows to the catalog form and
  repointed the source off Rowe et al. 2014 (a bulk validation paper) to Cabrera
  et al. 2014 (planets b-h) and Shallue & Vanderburg 2018 (planet i).

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
