-- Kepler-51 deep dive (manual literature review, 2026-05-23). Kepler-51 b/c/d are
-- "super-puffs" -- Neptune-sized but only a few Earth masses, densities < 0.1
-- g/cm3 (already in the catalog); e is a normal denser 4th planet (2024). Their
-- atmospheres are featureless: high-altitude hazes hide any molecular features.
-- That is the value-add here -- non-detections, not molecule lists, and no clean
-- derived scalar beyond the catalog (the large H/He envelope is only one of
-- several hypotheses). Values read from the cited papers; bibcodes verified via
-- ADS. Citations linked role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Libby-Roberts et al. 2020 (HST/WFC3) -- featureless transmission spectra for
--     b and d (no water features > 0.6 scale heights); high-altitude aerosol layer.
--   Libby-Roberts et al. 2026 (JWST/NIRSpec-PRISM) -- d's 0.6-5.3 um spectrum is a
--     featureless sloped line: a low-metallicity atmosphere with submicron hazes
--     (1-100 ubar), or possibly a tilted ring.
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('Kepler-51 b', 'H2O', 'ruled_out', 'HST/WFC3', '2020AJ....159...57L', NULL,
     'Libby-Roberts et al. 2020. Featureless WFC3 transmission spectrum (no water features '
     'above 0.6 scale heights); a high-altitude aerosol/haze layer (P < 3 mbar) on this '
     'super-puff (density < 0.1 g/cm3).'),
    ('Kepler-51 d', 'H2O', 'ruled_out', 'JWST/NIRSpec', '2026AJ....171..221L', NULL,
     'Libby-Roberts et al. 2026. JWST/NIRSpec-PRISM (0.6-5.3 um) spectrum is a featureless '
     'sloped line: a low-metallicity atmosphere with high-altitude submicron hazes (1-100 '
     'ubar), or possibly a tilted ring. HST was also featureless (Libby-Roberts et al. 2020).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
