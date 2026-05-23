-- WASP-107 b atmosphere deep dive (manual literature review, 2026-05-23). The
-- low-density warm Neptune ("super-puff", ~740 K) is one of the most thoroughly
-- characterised exoplanet atmospheres. Values read from the cited papers; bibcodes
-- verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Spake et al. 2018 (HST/WFC3)            -- He at 4.5 sigma: the first helium
--     detection in any exoplanet, tracing the eroding/escaping atmosphere.
--   Kreidberg et al. 2018 (HST)             -- first H2O detection (6.5 sigma),
--     high-altitude condensates, metallicity < 30x solar (3 sigma upper limit).
--   Dyrek et al. 2024 (JWST/MIRI)           -- photochemical SO2 and a thick
--     silicate-cloud layer (first SO2 at such a low temperature); no CH4 in MIRI.
--   Sing et al. 2024 (JWST/NIRSpec)         -- CH4 detected but strongly depleted,
--     revealing the core mass and vigorous vertical mixing.
--   Welbanks et al. 2024 (HST + JWST NIRCam/MIRI panchromatic) -- H2O (21 sigma),
--     CH4 (5 sigma), CO (7 sigma), plus CO2; a high internal heat flux and large core.
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-107 b', 'He', 'detected', 'HST/WFC3', '2018Natur.557...68S', 4.5,
     'Spake et al. 2018. First detection of helium in an exoplanet atmosphere; the '
     'metastable He 10830 line traces the eroding/escaping upper atmosphere.'),
    ('WASP-107 b', 'H2O', 'detected', 'JWST/NIRCam+MIRI', '2024Natur.630..836W', 21.0,
     'Welbanks et al. 2024, panchromatic HST+JWST spectrum (21 sigma). First detected '
     'by Kreidberg et al. 2018 (HST, 6.5 sigma).'),
    ('WASP-107 b', 'CH4', 'detected', 'JWST/NIRSpec', '2024Natur.630..831S', NULL,
     'Sing et al. 2024. Methane detected but strongly depleted, revealing the core '
     'mass and vigorous vertical mixing (~5 sigma in the Welbanks et al. 2024 '
     'panchromatic spectrum; not seen in the Dyrek et al. 2024 MIRI bandpass).'),
    ('WASP-107 b', 'CO', 'detected', 'JWST/NIRCam+MIRI', '2024Natur.630..836W', 7.0,
     'Welbanks et al. 2024, panchromatic spectrum (7 sigma).'),
    ('WASP-107 b', 'CO2', 'detected', 'JWST/NIRSpec', '2024Natur.630..831S', NULL,
     'Sing et al. 2024 and Welbanks et al. 2024. CO2 in the JWST transmission spectrum.'),
    ('WASP-107 b', 'SO2', 'detected', 'JWST/MIRI', '2024Natur.625...51D', NULL,
     'Dyrek et al. 2024. Photochemically-produced SO2 (MIRI), alongside a thick '
     'silicate-cloud layer; the first SO2 detected at a temperature this low (~740 K).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
