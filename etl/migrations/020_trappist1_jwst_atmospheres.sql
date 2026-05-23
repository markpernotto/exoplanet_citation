-- TRAPPIST-1 JWST atmosphere deep dive (manual literature review, 2026-05-22).
-- The TRAPPIST-1 planets held no curated atmospheric conclusions despite a large
-- JWST campaign. The observation campaigns themselves are already in
-- planet_atmospheric_observations (bulk-loaded from the NASA EA spectra table),
-- so this migration adds ONLY the curated layer: the scientific conclusions, with
-- their sources. Bibcodes verified via ADS; citations linked as
-- role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
-- The honest headline is that NO molecule has been positively detected on any
-- TRAPPIST-1 planet. Results are atmosphere constraints, recorded with two
-- non-positive detection values (the table's `detection` is free text; the VR
-- scene tints only on detection='detected', so these rows are render-safe):
--   'ruled_out'    -- the named atmosphere/molecule is excluded by the data.
--   'inconclusive' -- competing scenarios remain degenerate at current precision.
--
--   b: Greene et al. 2023 (15 um) favoured a bare rock with no CO2, but Ducrot
--      et al. 2025 added a 12.8 um band and found a thick CO2 atmosphere with
--      photochemical haze fits as well as an airless ultramafic surface --
--      degenerate, so 'inconclusive'.
--   c: Zieba et al. 2023 (15 um emission) rules out a thick CO2/Venus-like
--      atmosphere; NIRISS (Radica 2025) and NIRSpec (Rathcke 2025) transmission
--      independently exclude H2-dominated atmospheres. 'ruled_out'.
--   d: Piaulet-Ghorayeb et al. 2025 -- flat NIRSpec/PRISM spectrum, clear
--      H2-dominated and trace CO2 excluded >3 sigma. 'ruled_out'.
--   e: Espinoza et al. 2025 (habitable-zone planet) -- cloudy H2-dominated
--      atmospheres ruled out, but a secondary atmosphere is neither detected nor
--      excluded; contamination-limited. 'inconclusive'.
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('TRAPPIST-1 b', 'CO2', 'inconclusive', 'JWST/MIRI', '2025NatAs...9..358D', NULL,
     'Greene et al. 2023 (2023Natur.618...39G; MIRI F1500W/15 um secondary eclipse, '
     '8.7 sigma) favoured a bare rock with no CO2. Ducrot et al. 2025 added a 12.8 um '
     'band (10 eclipses; fp/f* = 452 +/- 86 ppm at 12.8 um, 775 +/- 90 ppm at 15 um) '
     'and finds two scenarios fit equally well: an airless planet with a fresh '
     'ultramafic surface, OR a thick pure-CO2 atmosphere with photochemical hazes '
     'and a thermal inversion. Bare-rock vs thick-CO2 remains degenerate.'),
    ('TRAPPIST-1 c', 'CO2', 'ruled_out', 'JWST/MIRI', '2023Natur.620..746Z', NULL,
     'Zieba et al. 2023. 15 um thermal emission (fp/f* = 421 +/- 94 ppm; dayside '
     '380 +/- 31 K) disfavours a thick CO2-rich atmosphere: rules out cloud-free '
     'O2/CO2 mixtures from 10 bar (10 ppm CO2) to 0.1 bar (pure CO2), Venus-analogue '
     '(H2SO4 clouds) at 2.6 sigma. NIRISS transmission (Radica et al. 2025) and '
     'contamination-corrected NIRSpec/PRISM (Rathcke et al. 2025) independently '
     'exclude H2-dominated atmospheres; thin atmosphere or bare rock consistent.'),
    ('TRAPPIST-1 d', 'CO2', 'ruled_out', 'JWST/NIRSpec', '2025ApJ...989..181P', NULL,
     'Piaulet-Ghorayeb et al. 2025. First 0.6-5.2 um NIRSpec/PRISM transmission '
     'spectrum (2 transits); flat to +/-100-150 ppm after correcting 500-1000 ppm '
     'stellar-contamination slopes, with no CH4/H2O/CO/SO2/CO2 absorption. Clear '
     'H2-dominated atmospheres excluded at >3 sigma and strict limits set on trace '
     'CO2; no secondary atmosphere detected.'),
    ('TRAPPIST-1 e', 'CO2', 'inconclusive', 'JWST/NIRSpec', '2025ApJ...990L..52E', NULL,
     'Espinoza et al. 2025 (JWST-TST DREAMS). Four NIRSpec/PRISM transits of the '
     'habitable-zone planet; heavy stellar contamination marginalised with Gaussian '
     'processes. Cloudy, primary H2-dominated atmospheres are '
     'ruled out, but a secondary atmosphere is neither detected nor excluded at '
     'current precision.')  -- >~80% H2 by volume
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
