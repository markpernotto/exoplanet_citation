-- Atmosphere backlog batch 3: rocky JWST targets (manual literature review, 2026-05-25).
-- The "does it even have an atmosphere?" campaign on small M-dwarf planets. As with the
-- TRAPPIST-1 series (migration 020), most results are honest non-detections / upper
-- limits rather than positive species detections. Bibcodes verified via ADS.
--
--   GJ 1132 b   -- Xue et al. 2024 (JWST MIRI/LRS eclipse): dayside brightness T = 709
--     +/- 31 K, only 1 sigma below the maximum possible bare-rock dayside (zero albedo,
--     no heat redistribution) -> bare-rock consistent. Belozhentsev et al. 2025 (JWST
--     NIRSpec G395H+G395M, 4 transits) finds a FEATURELESS transmission spectrum,
--     extending May et al. 2023's inconclusive 2-transit result -> CO2 ruled out.
--   GJ 486 b    -- Moran et al. 2023 (JWST NIRSpec G395H transmission): spectrum
--     deviates from a flat line at 2.2-3 sigma; planet vs. stellar contamination
--     was ambiguous. RESOLVED by Weiner Mansfield et al. 2024 (JWST MIRI/LRS, 2
--     eclipses): dayside T = 865 +/- 14 K (R = 0.97 +/- 0.01 vs max bare-rock) is
--     inconsistent with a water-rich atmosphere; H2O ruled_out (< 1% if any thin
--     atmosphere), CO2 ruled_out (< 1 ppm). Best explained as airless. The most
--     precise terrestrial JWST emission to date.
--   L 98-59 b   -- Banerjee et al. 2025 (JWST NIRSpec G395H, 4 transits): "Evidence for
--     a Volcanic Atmosphere on the Sub-Earth L 98-59 b." An SO2 atmosphere is preferred
--     by 3.6 sigma over a flat line (although the airless model also fits adequately).
--     Recorded as a tentative SO2 detection; first volcanic-atmosphere evidence for a
--     sub-Earth-mass rocky world.
--   LTT 1445 A b -- Wachiraphan et al. 2025 (JWST MIRI/LRS eclipse, 5-12 um): broadband
--     eclipse depth 41 +/- 9 ppm; dayside T = 525 +/- 15 K (R = 0.952 vs max bare-rock).
--     Thick pure-CO2 atmospheres disfavoured: 100/10/1-bar at 6.8/6.6/4.2 sigma. Prior
--     transmission also ruled out H/He. A thin atmosphere (Mars/Titan/Earth-like) remains
--     possible but unconstrained here.
--   L 98-59 c   -- Scarsdale et al. 2024 (JWST COMPASS, NIRSpec G395H 3-5 um): featureless
--     transmission spectrum at 22/36 ppm precision -> primordial H2-He and pure-methane
--     atmospheres ruled out; metallicities below ~300x solar (MMW < 10 g/mol) excluded at
--     3 sigma. Compatible with no atmosphere or a high-MMW (CO2-/H2O-rich) one.
--   L 98-59 d   -- Gressier et al. 2024 (JWST NIRSpec G395H, single transit): "Hints of a
--     Sulfur-rich Atmosphere" at 2.6-5.6 sigma (reduction-dependent), 3.3-4.8 um feature.
--     Stellar contamination rejected; best-fit atmosphere has sulfur-bearing species
--     (out-of-equilibrium chemistry). Awaits a second NIRSpec visit + NIRISS SOSS.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('GJ 1132 b', 'CO2', 'ruled_out', 'JWST/NIRSpec G395H+G395M', '2025AJ....170..205B', NULL,
     'Belozhentsev et al. 2025: four-transit JWST NIRSpec spectrum is FEATURELESS, ruling out the '
     'CO2-rich (and other thick) atmospheres that would produce visible features in 2.8-5 um. Builds '
     'on May et al. 2023''s inconclusive 2-transit study. Combined with Xue et al. 2024''s MIRI dayside '
     'T = 709 K (bare-rock-consistent), no atmosphere is required by the data.'),
    ('GJ 486 b', 'H2O', 'ruled_out', 'JWST/MIRI-LRS', '2024ApJ...975L..22W', NULL,
     'RESOLVED: Moran et al. 2023 (NIRSpec transmission) saw a 2.2-3 sigma deviation that could have '
     'been water-rich atmosphere OR stellar contamination ("high tide or riptide on the cosmic '
     'shoreline"). Weiner Mansfield et al. 2024 (MIRI emission, 2 eclipses) settles it: dayside T = '
     '865 +/- 14 K is INCONSISTENT with a water-rich atmosphere; the transmission deviation was likely '
     'stellar contamination. The data permit only an airless body or a thin atmosphere with <1% H2O.'),
    ('GJ 486 b', 'CO2', 'ruled_out', 'JWST/MIRI-LRS', '2024ApJ...975L..22W', NULL,
     'Weiner Mansfield et al. 2024: MIRI emission + dayside T = 865 K constrains any CO2 atmosphere '
     'to < 1 ppm. Also inconsistent with Earth- or Venus-like atmospheres. Most likely interpretation: '
     'an airless planet (consistent with the host''s long high-XUV history).'),
    ('L 98-59 b', 'SO2', 'tentative', 'JWST/NIRSpec G395H', '2025ApJ...980L..26B', 3.6,
     'Banerjee et al. 2025: an SO2 atmosphere is preferred by 3.6 sigma over a flat line in the four-'
     'transit NIRSpec G395H spectrum (although an airless model also fits the chi-squared adequately). '
     'Evidence for a tidally-heated VOLCANIC atmosphere on the sub-Earth-mass planet (the first such '
     'candidate); not yet a confirmed detection. Volcanic outgassing has been proposed as a mechanism '
     'to replenish atmospheres of rocky M-dwarf planets against stellar-wind stripping.'),
    ('LTT 1445 A b', 'CO2', 'ruled_out', 'JWST/MIRI-LRS', '2025AJ....169..311W', 6.8,
     'Wachiraphan et al. 2025: thick pure-CO2 atmospheres disfavoured by emission-spectrum forward '
     'modelling: 100-bar at 6.8 sigma, 10-bar at 6.6 sigma, 1-bar at 4.2 sigma (sigma here is the '
     'strongest, 100-bar, constraint). The energy-balance argument also excludes ~100-bar atmospheres '
     'with Bond albedo > 0.08 at 3 sigma. Prior transmission (cited within) also ruled out an H/He '
     'envelope. A thin Mars/Titan/Earth-like atmosphere remains uncertain.'),
    ('L 98-59 c', 'H2', 'ruled_out', 'JWST/NIRSpec G395H', '2024AJ....168..276S', NULL,
     'Scarsdale et al. 2024 (JWST COMPASS): the transmission spectrum is featureless at 22 ppm (NRS1) / '
     '36 ppm (NRS2) precision -> primordial H2-He atmospheres ruled out across cloud pressures up to '
     '~0.1 mbar; atmospheric metallicities below ~300x solar (mean molecular weights below ~10 g/mol) '
     'excluded at 3 sigma. Compatible: no atmosphere, or a much higher-MMW (CO2- or H2O-rich) one.'),
    ('L 98-59 c', 'CH4', 'ruled_out', 'JWST/NIRSpec G395H', '2024AJ....168..276S', NULL,
     'Scarsdale et al. 2024: pure-methane atmospheres also ruled out by the featureless transmission '
     'spectrum.'),
    ('L 98-59 d', 'SO2', 'tentative', 'JWST/NIRSpec G395H', '2024ApJ...975L..10G', NULL,
     'Gressier et al. 2024: single transit deviates from a flat line by 2.6-5.6 sigma (range depends '
     'on data reduction and retrieval setup), driven by a 3.3-4.8 um absorption feature. A stellar-'
     'contamination retrieval rejects the stellar origin -> the best fit is an atmospheric model with '
     'SULFUR-BEARING SPECIES (not at chemical equilibrium); the paper does not commit to a specific '
     'species, but SO2 is the natural candidate given the wavelength range and the L 98-59 b precedent. '
     'Awaits confirmation from a second NIRSpec G395H visit + NIRISS SOSS.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 1132 b', 'dayside_temperature', 709, 31, 31, 'K', 'JWST MIRI/LRS broadband eclipse',
     '2024ApJ...973L...8X',
     'Xue et al. 2024: dayside brightness T = 709 +/- 31 K from a 140 +/- 17 ppm secondary eclipse '
     'depth in MIRI/LRS 5-12 um. Only 1 sigma below the maximum possible bare-rock dayside '
     '(zero-albedo, no heat redistribution) -> consistent with a bare-rock interpretation.'),
    ('LTT 1445 A b', 'dayside_temperature', 525, 15, 15, 'K', 'JWST MIRI/LRS broadband eclipse',
     '2025AJ....169..311W',
     'Wachiraphan et al. 2025: dayside brightness T = 525 +/- 15 K from a 41 +/- 9 ppm secondary '
     'eclipse depth in MIRI/LRS 5-12 um. Temperature ratio R = 0.952 +/- 0.057 vs the maximum '
     'instant-thermal-reradiation rocky dayside -> consistent with emission from a dark rocky surface.'),
    ('GJ 486 b', 'dayside_temperature', 865, 14, 14, 'K', 'JWST MIRI/LRS broadband eclipse',
     '2024ApJ...975L..22W',
     'Weiner Mansfield et al. 2024: dayside T = 865 +/- 14 K from two JWST MIRI/LRS 5-12 um eclipses. '
     'R = T_p,dayside / T_p,max = 0.97 +/- 0.01 vs the maximum bare-rock (zero-albedo, no heat redistribution) '
     'temperature -> consistent with an airless planet; the most precise terrestrial JWST emission '
     'measurement to date and a strong constraint on the "cosmic shoreline" between airless and atmosphered worlds.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
