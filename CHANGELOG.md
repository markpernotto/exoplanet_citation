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
- **PDS 70 deep dive** (manual literature review): the only confirmed *forming*
  planets, caught accreting inside their disk gap. No molecule detections (dusty
  accreting young giants), so the value-add is in `planet_derived_measurements`
  (migration 033): PDS 70 b's H-alpha mass-accretion rate (~1e-8 M_Jup/yr, Wagner
  2018) and PDS 70 c's resolved circumplanetary-disk dust mass (~0.031 M_earth,
  Benisty 2021), the two near a 2:1 resonance. Three `characterization` citations
  added (Wagner 2018, Haffert 2019, Benisty 2021); bibcodes verified against ADS.
  Opens an "extremes" set (forming / dying / record-holding planets).
- **WASP-12 b deep dive** (manual literature review): a hot Jupiter measurably
  spiraling into its star. `planet_derived_measurements` (migration 034) gets the
  orbital decay rate (-29 +/- 2 ms/yr, Yee 2020) and decay timescale (3.2 Myr to
  destruction, Patra 2017); `planet_atmospheres` gets H2O (Kreidberg 2015) and
  exospheric Mg II from its escaping, Roche-lobe-overflowing atmosphere (Fossati
  2010). Four `characterization` citations added; bibcodes verified against ADS.
- **KELT-9 b deep dive** (manual literature review): the hottest known planet
  (dayside ~4600 K, A0 host). 13 `planet_atmospheres` rows (migration 035) - the
  first-ever Fe / Fe II / Ti II detection in any exoplanet (Hoeijmakers 2018), a
  full metal/ion zoo (Na, Mg, Cr II, Sc II, Y II; Hoeijmakers 2019), an escaping H
  envelope (Yan & Henning 2018), and tentative Ca/Cr/Co/Sr II - plus the dayside
  temperature in `planet_derived_measurements`. Too hot for molecules. Three
  `characterization` citations; bibcodes verified against ADS.
- **Kepler-1520 b deep dive** (manual literature review): a Mercury-sized rocky
  planet catastrophically evaporating with a comet-like dust tail.
  `planet_derived_measurements` (migration 036) gets the mass-loss rate
  (~1 M_earth/Gyr), evaporation timescale (~0.2 Gyr), and present-day mass
  (<=0.02 M_earth, possibly a naked iron core; Rappaport 2012, Perez-Becker &
  Chiang 2013, van Werkhoven 2014). No curated atmosphere (the obscuring material
  is mineral dust). Rappaport 2012 - the actual 2012 discovery, predating the
  warehouse's Morton 2016 validation cite - is credited as a `prior_detection`;
  two `characterization` citations also added. Bibcodes verified against ADS.
- **TOI-849 b deep dive** (manual literature review): the "exposed core" - the
  remnant core of a giant planet in the hot-Neptune desert (39 M_earth, Earth-like
  density). `planet_derived_measurements` (migration 037) records its H/He envelope
  fraction (<=3.9% of the planet mass; Armstrong 2020), which quantifies the
  stripped-core nature. Completes a five-system "extremes" set (PDS 70, WASP-12 b,
  KELT-9 b, Kepler-1520 b, TOI-849 b).
- **51 Eri b deep dive** (manual literature review): a cold (~675 K), young
  directly-imaged Jupiter - the first imaged planet with a methane-dominated
  spectrum. `planet_atmospheres` gets CH4 + H2O (Macintosh 2015);
  `planet_derived_measurements` (migration 038) gets the effective temperature,
  a super-solar metallicity ([Fe/H] = 1.0; Samland 2017, with a noted model
  tension vs Rajan 2017's ~solar), and a cold-start-consistent luminosity (Rajan
  2017). Two `characterization` citations added; bibcodes verified against ADS.
- **Kepler-51 deep dive** (manual literature review): the "cotton-candy"
  super-puffs (densities below 0.1 g/cm3). The value-add is non-detections: both
  Kepler-51 b and d have featureless transmission spectra hidden by high-altitude
  hazes, so `planet_atmospheres` (migration 039) records H2O as `ruled_out` for
  each - b from HST/WFC3 (Libby-Roberts 2020) and d from JWST/NIRSpec-PRISM
  (Libby-Roberts 2026, a featureless sloped line). Three `characterization`
  citations added; bibcodes verified against ADS.
- **WASP-18 b deep dive** (manual literature review): the benchmark ultra-hot
  Jupiter for dayside *thermal inversions*. `planet_atmospheres` (migration 040)
  records H2O detected in emission (JWST/NIRISS, >6 sigma; Coulombe 2023, the
  band-flip that proves the stratosphere), CO as tentative (Sheppard 2017, with
  Arcangeli 2018's competing H- interpretation noted), and TiO/VO as inconclusive
  (the still-open question of what optical absorber drives the inversion).
  `planet_derived_measurements` gets a solar metallicity (M/H = 1.03x solar;
  Coulombe 2023, resolving an earlier high-metallicity claim) and a ~2900 K
  dayside temperature (Arcangeli 2018). Three `characterization` citations added;
  bibcodes verified against ADS.
- **HIP 65426 b deep dive** (manual literature review): the first exoplanet imaged
  by JWST (and the first direct detection beyond 5 um). A young, dusty,
  L-dwarf-like super-Jupiter at 92 au, so the value-add is characterization
  scalars: a VLT/SINFONI K-band spectrum (Petrus 2021) sets the effective
  temperature (1560 K), a solar metallicity, and a C/O upper limit (<=0.55,
  pointing to core accretion beyond the snowline), and the JWST 2-16 um SED
  (Carter 2023) gives a model-independent bolometric luminosity and a refined mass
  (7.1 Mjup, vs the catalog's older ~9 Mjup). `planet_atmospheres` (migration 041)
  also records the H2O and CO K-band carriers. Two `characterization` citations
  added; bibcodes verified against ADS. Completes a four-system user-flagged
  fast-follow set (51 Eri b, Kepler-51, WASP-18 b, HIP 65426 b).
- **Directly-imaged young giants deep dive** (manual literature review, migrations
  042-046): the companion set to the imaged work already done (HR 8799, bet Pic,
  51 Eri b, HIP 65426 b). GJ 504 b, the first T-dwarf-type imaged planet (CH4 +
  superstellar metallicity; Skemer 2016). kappa And b, a planet/brown-dwarf-boundary
  super-Jupiter with resolved H2O + CO and a host-like C/O (Wilcomb 2020). 2M1207 b
  (catalog `2MASS J12073346-3932539 b`), the first directly-imaged exoplanet, which
  is methane-poor: CH4 absent and CO weak despite its cool temperature, confirmed by
  JWST (Luhman 2023) and explained by Barman 2011. AB Pic b, a boundary companion
  with its first C/O ratio and projected spin (Palma-Bifani 2023). HD 95086 b, an
  extremely red, dust-dominated planet in a debris-disk gap with a featureless cloudy
  spectrum (De Rosa 2016). Molecules go to `planet_atmospheres`; temperatures,
  metallicities, C/O ratios and spins to `planet_derived_measurements`. Six
  `characterization` citations added; bibcodes verified against ADS.
- **PSR B1257+12 deep dive** (manual literature review): the first confirmed
  planetary system around any star (Wolszczan & Frail 1992). The catalog already
  carries the true masses of the two Earth-mass planets c and d but never cited
  their source, so this credits Konacki & Wolszczan 2003 (true masses + orbital
  inclinations from the planets' mutual perturbations) and Wolszczan 1994 (which
  confirmed c and d via their 3:2-resonance perturbations), and records the orbital
  inclinations (53 and 47 deg, near-coplanar) in `planet_derived_measurements`
  (migration 047). Bibcodes verified against ADS. First of a 1990s foundational
  cohort.
- **tau Boo b deep dive** (manual literature review): the first non-transiting
  planet to be atmospherically characterized, by high-resolution spectroscopy that
  also breaks the m sin i degeneracy. `planet_atmospheres` (migration 048) records
  CO (Brogi 2012), water (Lockwood 2014, with the strong depletion found by
  Pelletier 2021 noted), and a CH4 upper limit; `planet_derived_measurements`
  records the orbital inclination (44.5 deg, giving the 5.95 Mjup true mass the
  catalog already uses) and a Jupiter-like C/H (5.85x solar). Three
  `characterization` citations added; bibcodes verified against ADS.
- **16 Cyg B b and HD 168443 citation enrichment** (1990s cohort): for these RV
  systems the discovery orbits are already in the catalog, so the value-add is
  follow-up provenance. 16 Cyg B b's record eccentricity (~0.65) is credited to the
  two 1997 papers (Holman, Touma & Tremaine; Mazeh, Krymolowski & Rosenfeld) that
  trace it to Kozai-Lidov forcing by the companion star 16 Cyg A. HD 168443 b and c
  (a planet plus a brown dwarf) are linked to Reffert & Quirrenbach 2011, whose
  re-reduced HIPPARCOS astrometry confirms c as a brown dwarf. Bibcodes verified
  against ADS.
- **HD 168443 c astrometric true mass** (migration 049): from Reffert & Quirrenbach
  2011's HIPPARCOS orbit, `planet_derived_measurements` records the true mass of the
  outer companion (30.3 Mjup, vs the RV minimum of 18.1), firmly a brown dwarf. Its
  citation is upgraded to `characterization`; the inner planet b (not astrometrically
  detected) stays a `follow_up`.
- **1990s foundational cohort closed** (provenance audit, basis for a Research Note):
  an exhaustive follow-up audit of 11 systems discovered 1992-1999 (47 UMa, 16 Cyg B,
  70 Vir, tau Boo, rho CrB, HD 168443, HD 187123, HD 210277, HD 217107, PSR B1257+12,
  PSR B1620-26). All 11 carried only their discovery citation despite decades of
  follow-up; the audit recovered 20 post-discovery citations (mean 1.8/system) and, in
  two systems, true masses the archive displays but never cited (PSR B1257+12 c/d via
  Konacki & Wolszczan 2003; tau Boo b via Brogi et al. 2012). The last three systems
  (HD 187123 b, HD 210277 b, HD 217107 b) are closed out here with `follow_up` citations.
- **Wild Orbits deep dive begun** (extreme-eccentricity planets): HD 80606 b (e=0.93),
  whose Spitzer 8-um light curve caught its dayside flash-heating from ~800 K to
  ~1500 K in six hours through periastron (Laughlin et al. 2009), recorded as a peak
  `dayside_temperature` (migration 056). Its extreme eccentricity is credited to Kozai
  migration from the binary companion HD 80607 (Wu & Murray 2003). One
  `characterization` plus one `follow_up` citation added. Two further
  extreme-eccentricity systems are credited to their landmark characterizations:
  HD 20782 b, the most eccentric known (e~0.96; Kane et al. 2016), and nu Oct A b, a
  retrograde planet in a tight binary whose companion turned out to be a white dwarf
  (Cheng et al. 2025); that white dwarf (nu Oct B) is added to `binary_companions`
  (migration 057). HD 4113 b (e=0.90) is a hierarchical triple whose imaged cold T9
  brown-dwarf companion (HD 4113 C; Teff 500-600 K; Cheetham et al. 2018) is added to
  `binary_companions` (migration 058). `follow_up` / `characterization` citations added.
- **Tilted & Tumbling deep dive** (spin-orbit-misaligned planets): promotes obliquity
  out of the raw NASA EA rows into the cited, usable `planet_derived_measurements`
  layer. WASP-17 b, the first retrograde planet, gets its sky-projected obliquity
  (lambda = -148.5 deg; Triaud et al. 2010; migration 051). WASP-33 b, a retrograde
  ultra-hot Jupiter around a hot A-star above the Kraft break, gets both its projected
  (251 deg) and true (108 deg) obliquity (Collier Cameron et al. 2010; migration 052).
  K2-290 c, a warm Jupiter on a polar/retrograde orbit (true obliquity 124 deg; Hjorth
  et al. 2021; migration 053), is the theme's primordial-disk case: both planets are
  coplanar but tilted from a "backward-spinning" star, pointing to a tipped disk rather
  than scattering. HAT-P-7 b adds a near-polar case (true obliquity 86 deg; Winn et al.
  2009; migration 054), one of the first misaligned hot Jupiters ever found, and
  WASP-79 b a polar one (lambda = -95 deg; Brown et al. 2017; migration 055). Five
  `characterization` citations added (contribution=obliquity), one per system.
- **GJ 86 b white-dwarf companion provenance** (migration 050): GJ 86 b is a hot
  Jupiter whose wide companion GJ 86 B is a white dwarf (the first found orbiting an
  exoplanet host star). The companion was already in `binary_companions` from SIMBAD
  but uncited, so its `source_bibcode` is set to Mugrauer & Neuhauser 2005 (the
  white-dwarf confirmation), and a `characterization` citation links the planet to that
  paper. Bibcode verified against ADS.
- **rho CrB b confirmed as a planet** (1990s cohort): an old HIPPARCOS astrometric
  result had suggested rho CrB b might be a low-mass star seen nearly face-on
  (~170 Mjup). The four-planet architecture (Noyes 1997; Fulton 2016; Brewer 2023)
  refutes that, so b stands as a ~1.1 Mjup hot Jupiter and the stellar mass was not
  recorded. Brewer et al. 2023 added as a `follow_up`; bibcode verified against ADS.
- **1990s cohort light citation pass**: post-discovery follow-ups for the
  lower-yield systems (none had a Gaia DR3 astrometric orbit or a recordable true
  mass). 47 UMa b and c link to Gregory & Fischer 2010 (the joint three-planet
  dynamical solution); 70 Vir b and HD 222582 b link to Reffert & Quirrenbach 2011
  (astrometric mass upper limits confirming substellar companions). HD 217107 was
  already fully cited. Four `follow_up` citations added; bibcodes verified against ADS.
- **Unit labels for literature-derived measurements** ([composition.ts](web/src/lib/composition.ts)):
  the display map now covers Jupiter masses and the other units that previously
  rendered as raw snake_case (`M_jup` -> M♃, `km_s` -> km/s, `log_Lsun` -> log L⊙,
  the per-time mass-loss/decay units), matching the existing `M_earth` -> M⊕.
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
