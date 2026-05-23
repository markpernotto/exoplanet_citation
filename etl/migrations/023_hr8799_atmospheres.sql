-- HR 8799 atmosphere deep dive (manual literature review, 2026-05-23). The four
-- directly-imaged giant planets had no curated molecule detections despite a
-- decade-plus of high-contrast spectroscopy. Unlike TRAPPIST-1 (non-detections),
-- these are genuine 'detected' molecules, so they also drive the 3D scene's
-- atmosphere tint. Values read from the cited papers; bibcodes verified via ADS.
-- Citations linked as role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
-- Sources:
--   Konopacky et al. 2013 (Keck/OSIRIS) -- first spectrally-resolved CO + H2O in
--     a directly-imaged planet: HR 8799 c.
--   Barman et al. 2015 (Keck/OSIRIS) -- simultaneous H2O + CH4 + CO in HR 8799 b.
--   Xuan et al. 2026 (JWST/NIRSpec IFU, 2.85-5.3 um) -- per-planet detections with
--     significances from their Table 3 (CCF S/N stored in confidence_sigma). CO,
--     CH4, H2O are detected throughout; CO2, H2S, 13CO, C18O, NH3 attributed per
--     planet per that table; abundances imply accretion of solids plus
--     metal-enriched gas. Notable per-planet specifics: H2S is detected in b/c/d
--     but NOT in e (S/N < 2); NH3 only in b; for b, C18O/HDO/HCN are only
--     tentative (low CCF S/N; HCN is not favored by the Bayesian model comparison,
--     d ln B = -0.5).
--
-- Imaging/photometry campaigns (e.g. Boccaletti et al. 2024, JWST/MIRI) are in
-- planet_atmospheric_observations and are not molecule-detection sources.
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    -- HR 8799 b (Barman 2015 for the main carbon/oxygen species; Xuan 2026 for the rest)
    ('HR 8799 b', 'CO',   'detected',  'Keck/OSIRIS',  '2015ApJ...804...61B', NULL,
     'Barman et al. 2015 (Keck/OSIRIS): simultaneous H2O, CH4, CO in HR 8799 b.'),
    ('HR 8799 b', 'CH4',  'detected',  'Keck/OSIRIS',  '2015ApJ...804...61B', NULL,
     'Barman et al. 2015 (Keck/OSIRIS): simultaneous H2O, CH4, CO in HR 8799 b.'),
    ('HR 8799 b', 'H2O',  'detected',  'Keck/OSIRIS',  '2015ApJ...804...61B', NULL,
     'Barman et al. 2015 (Keck/OSIRIS): simultaneous H2O, CH4, CO in HR 8799 b.'),
    ('HR 8799 b', 'CO2',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 20.0,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 20.0.'),
    ('HR 8799 b', 'H2S',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 17.2,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 17.2.'),
    ('HR 8799 b', '13CO', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 8.1,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Carbon isotopologue; Table 3 CCF S/N = 8.1.'),
    ('HR 8799 b', 'NH3',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 4.3,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). NH3 detected only in HR 8799 b (coolest planet); Table 3 CCF S/N = 4.3.'),
    ('HR 8799 b', 'C18O', 'tentative', 'JWST/NIRSpec', '2026ApJ..1000...27X', 3.4,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Oxygen isotopologue, tentative in b; Table 3 CCF S/N = 3.4.'),
    ('HR 8799 b', 'HDO',  'tentative', 'JWST/NIRSpec', '2026ApJ..1000...27X', 3.0,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Tentative (their Appendix E); Table 3 CCF S/N = 3.0.'),
    ('HR 8799 b', 'HCN',  'tentative', 'JWST/NIRSpec', '2026ApJ..1000...27X', 2.2,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Tentative (their Appendix E); Table 3 CCF S/N = 2.2 and the Bayesian model comparison does not favor it (d ln B = -0.5).'),
    -- HR 8799 c (Konopacky 2013 for CO/H2O; Xuan 2026 for the rest)
    ('HR 8799 c', 'CO',   'detected',  'Keck/OSIRIS',  '2013Sci...339.1398K', NULL,
     'Konopacky et al. 2013 (Keck/OSIRIS): first spectrally-resolved CO and H2O in a directly-imaged planet (HR 8799 c).'),
    ('HR 8799 c', 'H2O',  'detected',  'Keck/OSIRIS',  '2013Sci...339.1398K', NULL,
     'Konopacky et al. 2013 (Keck/OSIRIS): first spectrally-resolved CO and H2O in a directly-imaged planet (HR 8799 c).'),
    ('HR 8799 c', 'CH4',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 c', 'CO2',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 28.5,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 28.5.'),
    ('HR 8799 c', 'H2S',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 11.2,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 11.2.'),
    ('HR 8799 c', '13CO', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 23.6,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Carbon isotopologue; Table 3 CCF S/N = 23.6.'),
    ('HR 8799 c', 'C18O', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 7.8,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Oxygen isotopologue; Table 3 CCF S/N = 7.8.'),
    -- HR 8799 d (all Xuan 2026)
    ('HR 8799 d', 'CO',   'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 d', 'CH4',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 d', 'H2O',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 d', 'CO2',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 21.0,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 21.0.'),
    ('HR 8799 d', 'H2S',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 5.8,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 5.8.'),
    ('HR 8799 d', '13CO', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 21.4,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Carbon isotopologue; Table 3 CCF S/N = 21.4.'),
    ('HR 8799 d', 'C18O', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 7.5,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Oxygen isotopologue; Table 3 CCF S/N = 7.5.'),
    -- HR 8799 e (all Xuan 2026; H2S and C18O NOT detected here)
    ('HR 8799 e', 'CO',   'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected. e was also the first exoplanet detected by optical interferometry (GRAVITY 2019).'),
    ('HR 8799 e', 'CH4',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 e', 'H2O',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', NULL,
     'Xuan et al. 2026 (JWST/NIRSpec IFU); detected.'),
    ('HR 8799 e', 'CO2',  'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 7.4,
     'Xuan et al. 2026 (JWST/NIRSpec IFU), Table 3 CCF S/N = 7.4.'),
    ('HR 8799 e', '13CO', 'detected',  'JWST/NIRSpec', '2026ApJ..1000...27X', 5.8,
     'Xuan et al. 2026 (JWST/NIRSpec IFU). Carbon isotopologue; Table 3 CCF S/N = 5.8. H2S and C18O are NOT detected in e (S/N < 2).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
