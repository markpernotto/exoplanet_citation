-- 51 Eridani b deep dive (manual literature review, 2026-05-23). A cold (~675 K),
-- young (~20 Myr) directly-imaged Jupiter -- the first imaged planet with a
-- clearly methane-dominated, Jupiter-like spectrum (unlike the L-dwarf-like
-- HR 8799 planets). Molecule detections go to planet_atmospheres; the
-- temperature/metallicity/luminosity scalars go to planet_derived_measurements.
-- Values read from the cited papers; bibcodes verified via ADS. Citations linked
-- role='characterization' in etl/seed_followup_citations.py.
--
--   Macintosh et al. 2015 (Gemini/GPI; discovery) -- strong CH4 + H2O; Teff 600-750 K.
--   Rajan et al. 2017 (GPI + NIRC2, 1-5 um) -- partly cloudy; Teff 605-737 K,
--     log(L/Lsun) = -5.83 to -5.93, consistent with cold-start core accretion.
--   Samland et al. 2017 (VLT/SPHERE) -- cloudy-model retrieval: highly super-solar
--     [Fe/H] = 1.0 +/- 0.1 dex (Rajan preferred ~solar; the metallicity is model-dependent).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('51 Eri b', 'CH4', 'detected', 'Gemini/GPI', '2015Sci...350...64M', NULL,
     'Macintosh et al. 2015. Strong methane absorption (GPI near-IR) - the first directly-imaged '
     'planet with a clearly methane-dominated, Jupiter-like spectrum.'),
    ('51 Eri b', 'H2O', 'detected', 'Gemini/GPI', '2015Sci...350...64M', NULL,
     'Macintosh et al. 2015. Strong water-vapor absorption in the GPI near-IR spectrum.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('51 Eri b', 'effective_temperature', 675, 75, 75, 'K', 'atmosphere fit',
     '2015Sci...350...64M',
     'Macintosh et al. 2015: Teff 600-750 K (Rajan et al. 2017 refines to 605-737 K). A cold, '
     'methane-bearing young Jupiter (~20 Myr host).'),
    ('51 Eri b', 'metallicity', 1.0, 0.1, 0.1, 'dex', 'cloudy-atmosphere retrieval (SPHERE)',
     '2017A&A...603A..57S',
     'Samland et al. 2017. Highly super-solar [Fe/H] = 1.0 +/- 0.1 dex from cloudy-model fits. '
     'NB Rajan et al. 2017 (GPI) preferred ~solar metallicity; the value is model-dependent.'),
    ('51 Eri b', 'bolometric_luminosity', -5.88, 0.05, 0.05, 'log_Lsun', 'SED fit',
     '2017AJ....154...10R',
     'Rajan et al. 2017. log(L/Lsun) = -5.83 to -5.93; one of the only directly-imaged planets '
     'consistent with cold-start formation (core accretion, core mass 15-127 M_earth).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
