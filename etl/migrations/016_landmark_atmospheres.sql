-- Landmark JWST/HST-era atmosphere detections (manual literature review,
-- 2026-05-21). These famous transiting planets had no curated molecule
-- detections in planet_atmospheres. Values read from the cited papers (bibcodes
-- verified via ADS); citations linked as role='characterization' in
-- etl/seed_followup_citations.py.
--
--   WASP-39 b: first definitive CO2 in an exoplanet (JWST ERS, 26 sigma) and the
--              first unambiguous photochemical product (SO2).
--   WASP-96 b: the complete pressure-broadened sodium profile (cloud-free).
--   K2-18 b:   CH4 and CO2 in the H2-rich atmosphere of a candidate Hycean world
--              (the tentative DMS signal is deliberately not recorded).
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-39 b', 'CO2', 'detected', 'JWST/NIRSpec', '2023Natur.614..649J', 26.0,
     'JWST Transiting Exoplanet ERS Team 2023. First definitive CO2 in an exoplanet '
     'atmosphere; prominent 4.3 um feature at 26 sigma (NIRSpec PRISM transmission, '
     '3.0-5.5 um).'),
    ('WASP-39 b', 'SO2', 'detected', 'JWST/NIRSpec', '2023Natur.617..483T', 4.5,
     'Tsai et al. 2023. First unambiguous photochemical product in an exoplanet '
     'atmosphere; 4.05 um SO2 feature (NIRSpec PRISM 2.7 sigma, G395H 4.5 sigma), '
     'produced by oxidation of sulfur freed from H2S photochemistry.'),
    ('WASP-96 b', 'Na', 'detected', 'VLT/FORS2', '2018Natur.557..526N', NULL,
     'Nikolov et al. 2018. First complete pressure-broadened sodium profile in an '
     'exoplanet (cloud-free hot Saturn); absolute Na abundance log eps_Na = 6.9.'),
    ('K2-18 b', 'CH4', 'detected', 'JWST/NIRISS+NIRSpec', '2023ApJ...956L..13M', 5.0,
     'Madhusudhan et al. 2023. Methane at 5 sigma in the H2-rich atmosphere of a '
     'candidate Hycean world (0.9-5.2 um); resolves the missing-methane problem for '
     'temperate sub-Neptunes. The tentative DMS signal in the same data is NOT '
     'recorded here.'),
    ('K2-18 b', 'CO2', 'detected', 'JWST/NIRISS+NIRSpec', '2023ApJ...956L..13M', 3.0,
     'Madhusudhan et al. 2023. Carbon dioxide at 3 sigma alongside CH4; the NH3 '
     'non-detection is consistent with an ocean under a temperate H2-rich atmosphere.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
