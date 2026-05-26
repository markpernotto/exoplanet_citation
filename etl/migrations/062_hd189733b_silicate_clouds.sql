-- HD 189733 b silicate (quartz) clouds + H2S (manual literature review, 2026-05-25).
-- Serendipitous add: while sourcing WASP-17 b's quartz paper, the user surfaced
-- Inglis et al. 2024 (2024ApJ...973L..41I), "Quartz Clouds in the Dayside Atmosphere
-- of the Quintessential Hot Jupiter HD 189733 b" (JWST MIRI/LRS dayside emission).
-- Values are the joint-eclipse petitRADTRANS free retrieval (user-pasted Table 3), as
-- log10 mass mixing ratios; firm non-detections are 99% upper limits.
--
--   H2S   detected,   log MMR -2.4 +/- 0.5
--   SiO2  detected (solid silica / QUARTZ CLOUDS), log MMR -3.6 +/- 0.7; ~8.6 um feature
--   SO2   not detected, < -4.5 (99% upper limit)
--   CO2   not detected, < -3.1 (99% upper limit)
--   H2O   re-detected at log -3.7 +/- 0.6 -- NOT re-inserted here, to preserve the
--         existing HD 189733 b H2O row's provenance (migrations 015/016: CO, H2O, Na).
--
-- Confidence is reported as a retrieved abundance, not a sigma -> confidence_sigma NULL,
-- the value kept in the note. Apply after 008_atmospheres.sql (and 015/016). Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('HD 189733 b', 'H2S', 'detected', 'JWST/MIRI-LRS', '2024ApJ...973L..41I', NULL,
     'Inglis et al. 2024 (joint dayside-emission retrieval): hydrogen sulfide, log mass mixing ratio '
     '-2.4 +/- 0.5.'),
    ('HD 189733 b', 'SiO2', 'detected', 'JWST/MIRI-LRS', '2024ApJ...973L..41I', 6.0,
     'Inglis et al. 2024: solid silica (quartz) CLOUD particles detected at 6-7 sigma (cloudy model '
     'preferred over cloud-free by dln Bayes factor > 19; Trotta 2008). Free-retrieval log MMR -3.6 +/- 0.7; '
     'a vertically-extended deck from ~1 mbar with sub-micron grains (mean log r < -4 cm). Same cloud '
     'species Grant et al. 2023 found at WASP-17 b''s terminator, here on a hot-Jupiter dayside.'),
    ('HD 189733 b', 'SO2', 'upper_limit', 'JWST/MIRI-LRS', '2024ApJ...973L..41I', NULL,
     'Inglis et al. 2024: not detected; 99% upper limit log MMR < -4.5.'),
    ('HD 189733 b', 'CO2', 'upper_limit', 'JWST/MIRI-LRS', '2024ApJ...973L..41I', NULL,
     'Inglis et al. 2024: not detected; 99% upper limit log MMR < -3.1.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
