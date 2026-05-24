-- kappa Andromedae b deep dive (manual literature review, 2026-05-23). A young
-- "super-Jupiter" imaged at 55 au from the B9-type star kap And -- a benchmark object
-- right at the planet/brown-dwarf boundary (catalog mass ~17 Mjup; a planetary
-- ~13 Mjup if the young <50 Myr age holds, heavier if the system is older, as Hinkley
-- 2013 argued at ~220 Myr). It is an early-L, dusty, low-gravity atmosphere (~2000 K).
-- The value-add is the moderate-resolution K-band characterization: resolved H2O and
-- CO lines, plus the effective temperature, a slightly subsolar metallicity, and a
-- near-solar C/O ratio -- a composition like the host star that points to rapid
-- formation (gravitational instability). Molecules -> planet_atmospheres; scalars ->
-- planet_derived_measurements. Values read from the cited paper; bibcode verified via
-- ADS. Citation linked role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Carson et al. 2013 (Subaru/HiCIAO, SEEDS; discovery) -- "super-Jupiter" at 55 au.
--   Hinkley et al. 2013 (P1640) / Bonnefoy et al. 2014 (Keck+LBTI SED) -- early-L,
--     Teff ~2000 K, low gravity; debated age/mass (planet vs light brown dwarf).
--   Wilcomb et al. 2020 (Keck/OSIRIS, R~4000 K-band) -- resolved H2O + CO; Teff =
--     1950-2150 K, log g = 3.5-4.5, [M/H] = -0.2 to 0.0, C/O = 0.70 +0.09/-0.24
--     (host-like composition -> rapid formation / gravitational instability).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('kap And b', 'H2O', 'detected', 'Keck/OSIRIS', '2020AJ....160..207W', NULL,
     'Wilcomb et al. 2020. Resolved water lines in the moderate-resolution (R~4000) K-band '
     'OSIRIS spectrum, fit with a young planetary-mass PHOENIX model grid (MCMC forward model).'),
    ('kap And b', 'CO', 'detected', 'Keck/OSIRIS', '2020AJ....160..207W', NULL,
     'Wilcomb et al. 2020. Resolved CO lines in the same R~4000 K-band spectrum; with H2O these '
     'constrain the C/O ratio to 0.70 +0.09/-0.24 (broadly solar).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('kap And b', 'effective_temperature', 2050, 100, 100, 'K', 'K-band spectrum (forward model)',
     '2020AJ....160..207W',
     'Wilcomb et al. 2020: Teff = 1950-2150 K (range; midpoint here) with log g = 3.5-4.5, '
     'consistent with earlier ~2000 K estimates (Hinkley 2013, Bonnefoy 2014) and the favored '
     'young (<50 Myr) age. An early-L, dusty, low-gravity atmosphere.'),
    ('kap And b', 'metallicity', -0.10, 0.10, 0.10, 'dex', 'K-band spectrum (forward model)',
     '2020AJ....160..207W',
     'Wilcomb et al. 2020: [M/H] = -0.2 to 0.0 dex (slightly subsolar; midpoint here). Together '
     'with the near-solar C/O this implies a host-like composition, consistent with formation '
     'by gravitational instability.'),
    ('kap And b', 'C/O', 0.70, 0.09, 0.24, 'ratio', 'K-band spectrum (forward model)',
     '2020AJ....160..207W',
     'Wilcomb et al. 2020: C/O = 0.70 +0.09/-0.24 (broadly solar). A composition like the host '
     'star suggests a rapid formation process; pinning down the formation channel needs the '
     'C/O of kap And A itself.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
