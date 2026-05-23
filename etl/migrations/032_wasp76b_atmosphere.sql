-- WASP-76 b atmosphere deep dive (manual literature review, 2026-05-23). The
-- "it rains iron" ultra-hot Jupiter (Teq ~2230 K) had no curated atom/molecule
-- detections. Values read from the cited papers; bibcodes verified via ADS.
-- Citations linked role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py. The signature iron day-night asymmetry is also
-- recorded as a terminator wind velocity in planet_derived_measurements.
--
--   Ehrenreich et al. 2020 (VLT/ESPRESSO) -- neutral Fe with a day-night
--     asymmetry (blueshifted -11 km/s on the evening limb, absent at the morning
--     terminator): iron condenses on the cooler nightside.
--   Tabernero et al. 2021 (VLT/ESPRESSO)  -- the atomic inventory Li (first
--     detection), Na (9.2 sigma), Mg, Ca II, Mn, K, Fe; Ti/Cr/Ni/TiO/VO/ZrO not
--     detected (cold-trap).
--   Pelletier et al. 2023 (Gemini/MAROON-X) -- VO, with a sharp onset of
--     cold-trapping at the limb.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-76 b', 'Fe', 'detected', 'VLT/ESPRESSO', '2020Natur.580..597E', NULL,
     'Ehrenreich et al. 2020. Neutral iron with a day-night asymmetry (blueshifted '
     '-11 km/s on the evening/trailing limb, absent at the morning terminator): iron '
     'condenses on the cooler nightside ("it rains iron").'),
    ('WASP-76 b', 'Li', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', NULL,
     'Tabernero et al. 2021 (ESPRESSO, R~140,000). First detection of lithium on WASP-76 b.'),
    ('WASP-76 b', 'Na', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', 9.2,
     'Tabernero et al. 2021. Neutral sodium, the strongest atomic detection (9.2 sigma).'),
    ('WASP-76 b', 'Mg', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', 2.8,
     'Tabernero et al. 2021. Neutral magnesium (2.8 sigma, the weakest of the inventory).'),
    ('WASP-76 b', 'Ca II', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', NULL,
     'Tabernero et al. 2021. Singly-ionised calcium.'),
    ('WASP-76 b', 'Mn', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', NULL,
     'Tabernero et al. 2021. Neutral manganese.'),
    ('WASP-76 b', 'K', 'detected', 'VLT/ESPRESSO', '2021A&A...646A.158T', NULL,
     'Tabernero et al. 2021. Neutral potassium.'),
    ('WASP-76 b', 'VO', 'detected', 'Gemini/MAROON-X', '2023Natur.619..491P', NULL,
     'Pelletier et al. 2023. Vanadium oxide, with evidence for a sharp onset of cold-trapping at the limb.'),
    ('WASP-76 b', 'TiO', 'ruled_out', 'VLT/ESPRESSO', '2021A&A...646A.158T', NULL,
     'Tabernero et al. 2021. TiO not detected (1 sigma upper limit ~6 ppm); Ti also '
     'undetected, consistent with a cold-trap removing titanium from the gas phase (as on WASP-121 b).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-76 b', 'terminator_wind_velocity', -11, 0.7, 0.7, 'km_s', 'Fe absorption blueshift (ESPRESSO)',
     '2020Natur.580..597E',
     'Ehrenreich et al. 2020. Blueshift of the neutral-Fe absorption on the trailing/evening '
     'limb, attributed to planetary rotation plus a dayside-to-nightside wind; the morning '
     'limb shows no Fe (condensed out) - the "iron rain" asymmetry.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
