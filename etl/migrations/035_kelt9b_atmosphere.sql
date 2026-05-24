-- KELT-9 b atmosphere deep dive (manual literature review, 2026-05-23). The
-- hottest known planet (dayside ~4600 K), orbiting an A0 star at ~10,170 K. Too
-- hot for molecules -- the atmosphere is atomic/ionic metals plus escaping
-- hydrogen. Values read from the cited papers; bibcodes verified via ADS.
-- Citations linked role='characterization' in etl/seed_followup_citations.py.
--
--   Hoeijmakers et al. 2018 (TNG/HARPS-N) -- the FIRST direct detection of iron
--     (Fe, Fe II) and Ti II in any exoplanet atmosphere.
--   Hoeijmakers et al. 2019 (TNG/HARPS-N spectral survey) -- adds Na, Cr II, Sc II,
--     Y II (>5 sigma) and confirms Mg, Fe, Fe II, Ti II; tentative Ca, Cr I, Co,
--     Sr II. Lines deeper than hydrostatic: an extended/outflowing envelope.
--   Yan & Henning 2018 (CARMENES, Halpha) -- extended, escaping hot hydrogen
--     envelope; dayside ~4600 K.
--   Dayside temperature from Gaudi et al. 2017 (the discovery; already a discovery cite).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('KELT-9 b', 'Fe',    'detected',  'TNG/HARPS-N', '2018Natur.560..453H', NULL,
     'Hoeijmakers et al. 2018. First direct detection of iron (neutral Fe) in any exoplanet atmosphere (cross-correlation).'),
    ('KELT-9 b', 'Fe II', 'detected',  'TNG/HARPS-N', '2018Natur.560..453H', NULL,
     'Hoeijmakers et al. 2018. First direct detection of ionised iron (Fe+) in any exoplanet atmosphere.'),
    ('KELT-9 b', 'Ti II', 'detected',  'TNG/HARPS-N', '2018Natur.560..453H', NULL,
     'Hoeijmakers et al. 2018. First direct detection of ionised titanium (Ti+) in an exoplanet atmosphere.'),
    ('KELT-9 b', 'Na',    'detected',  'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019 (HARPS-N survey). Neutral sodium, >5 sigma.'),
    ('KELT-9 b', 'Mg',    'detected',  'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Neutral magnesium (confirmed).'),
    ('KELT-9 b', 'Cr II', 'detected',  'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Singly-ionised chromium, >5 sigma.'),
    ('KELT-9 b', 'Sc II', 'detected',  'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Singly-ionised scandium, >5 sigma.'),
    ('KELT-9 b', 'Y II',  'detected',  'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Singly-ionised yttrium, >5 sigma. Lines deeper than hydrostatic: an extended/outflowing envelope.'),
    ('KELT-9 b', 'H',     'detected',  'CARMENES',    '2018NatAs...2..714Y', NULL,
     'Yan & Henning 2018. Extended, escaping hot hydrogen envelope (Halpha) around the hottest known planet.'),
    ('KELT-9 b', 'Ca',    'tentative', 'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Tentative neutral calcium (requires further verification).'),
    ('KELT-9 b', 'Cr',    'tentative', 'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Tentative neutral chromium (requires further verification).'),
    ('KELT-9 b', 'Co',    'tentative', 'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Tentative neutral cobalt (requires further verification).'),
    ('KELT-9 b', 'Sr II', 'tentative', 'TNG/HARPS-N', '2019A&A...627A.165H', NULL,
     'Hoeijmakers et al. 2019. Tentative singly-ionised strontium (requires further verification).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('KELT-9 b', 'dayside_temperature', 4600, NULL, NULL, 'K', 'dayside brightness temperature',
     '2017Natur.546..514G',
     'Gaudi et al. 2017. Dayside ~4600 K - the hottest known planet, hotter than many K/M '
     'dwarf stars; the A0-type host (~10,170 K) drives extreme UV irradiation and escape.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
