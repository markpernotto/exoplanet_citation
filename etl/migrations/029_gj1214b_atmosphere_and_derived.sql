-- GJ 1214 b deep dive (manual literature review, 2026-05-23). The archetype
-- sub-Neptune is famously featureless in transmission (high-altitude aerosols), so
-- its value-add is a mix: a JWST phase curve that finally constrained the bulk
-- atmosphere, plus tentative molecules seen above the haze. Molecule detections go
-- to planet_atmospheres; the phase-curve scalars (albedo, day/night temperatures)
-- go to planet_derived_measurements. Values read from the cited papers; bibcodes
-- verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Kreidberg et al. 2014 (HST/WFC3) -- the featureless transmission spectrum:
--     high-altitude clouds, ruling out a cloud-free low-metallicity atmosphere.
--   Kempton et al. 2023 (JWST/MIRI thermal phase curve) -- >3 sigma absorption on
--     both day and night sides, most likely H2O; Bond albedo 0.51 +/- 0.06;
--     dayside/nightside brightness temperatures 553 +/- 9 / 437 +/- 19 K; a
--     high-metallicity atmosphere under a thick reflective haze.
--   Schlawin et al. 2024 (JWST/NIRSpec, 2.8-5.1 um) -- tentative CO2 + CH4 above
--     the aerosols (a model with both preferred over featureless at 3.3-3.6 sigma
--     across two pipelines; low S/N, needs confirmation).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('GJ 1214 b', 'H2O', 'detected', 'JWST/MIRI', '2023Natur.620...67K', 3.0,
     'Kempton et al. 2023. Most likely cause of the >3 sigma absorption seen in both '
     'the dayside and nightside MIRI phase-curve spectra of this high-metallicity atmosphere.'),
    ('GJ 1214 b', 'CO2', 'tentative', 'JWST/NIRSpec', '2024ApJ...974L..33S', NULL,
     'Schlawin et al. 2024. CO2 + CH4 signatures above the aerosols (2.8-5.1 um); a model '
     'with both is preferred over a featureless spectrum at 3.3-3.6 sigma (two pipelines). '
     'Low S/N, needs confirmation.'),
    ('GJ 1214 b', 'CH4', 'tentative', 'JWST/NIRSpec', '2024ApJ...974L..33S', NULL,
     'Schlawin et al. 2024. CH4 + CO2 signatures above the aerosols (2.8-5.1 um); a model '
     'with both is preferred over a featureless spectrum at 3.3-3.6 sigma (two pipelines). '
     'Low S/N, needs confirmation.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 1214 b', 'bond_albedo', 0.51, 0.06, 0.06, 'dimensionless', 'JWST/MIRI phase curve',
     '2023Natur.620...67K',
     'Kempton et al. 2023. High Bond albedo from the global thermal emission - a '
     'reflective atmosphere blanketed by thick clouds or haze.'),
    ('GJ 1214 b', 'dayside_temperature', 553, 9, 9, 'K', 'JWST/MIRI phase curve (brightness temp)',
     '2023Natur.620...67K',
     'Kempton et al. 2023. Dayside average brightness temperature from the MIRI phase curve.'),
    ('GJ 1214 b', 'nightside_temperature', 437, 19, 19, 'K', 'JWST/MIRI phase curve (brightness temp)',
     '2023Natur.620...67K',
     'Kempton et al. 2023. Nightside average brightness temperature; the modest day-night '
     'contrast indicates efficient heat redistribution.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
