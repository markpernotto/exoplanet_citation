-- Atmosphere backlog batch 5: directly-imaged young giants (manual literature review, 2026-05-25).
-- Companion set to the imaged giants already harvested (HR 8799, bet Pic, GJ 504 b,
-- 2M1207 b, kap And b, HIP 65426 b, AB Pic b, HD 95086 b). All four entries here are
-- JWST-era characterizations. Bibcodes verified via ADS.
--
--   AF Lep b   -- Discovered via HIPPARCOS-Gaia astrometric acceleration (Mesa 2023,
--     De Rosa 2023, both SPHERE/VLT NIR imaging + orbital fit). Dynamical mass 3-7
--     M_Jup, the LOWEST-mass directly-imaged planet with a direct mass measurement
--     (catalog already carries the mass). Franson 2024 (JWST/NIRCam F444W) detects it
--     photometrically and the 4.4 um flux affirms DISEQUILIBRIUM carbon chemistry and
--     enhanced metallicity, but no clean per-molecule detections are quoted -> no
--     planet_atmospheres row added; 3 citations only.
--   TYC 8998-760-1 b & c (YSES-1 b & c) -- Hoch et al. 2025 Nature (JWST 0.6-12 um,
--     multi-instrument): SILICATE detections in BOTH planets of the YSES-1 system.
--     YSES-1 c -> atmospheric silicate CLOUDS via the 9-11 um absorption feature
--     (amorphous iron-enriched pyroxene OR amorphous MgSiO3 + Mg2SiO4, particle radius
--     <= 0.1 um at 1 mbar). YSES-1 b -> first-ever CIRCUMPLANETARY-DISK silicate
--     EMISSION around a directly-imaged planet (submicron olivine dust grains, likely
--     from collisions of planet-forming bodies in the disk).
--   VHS J125601.92-125723.9 b (VHS 1256 b) -- Miles et al. 2023 (JWST NIRSpec IFU +
--     MIRI MRS, 1-20 um, R ~ 1000-3700): the highest-fidelity spectrum to date of any
--     planetary-mass object. Detects H2O, CH4, CO, CO2, Na, K. FIRST direct detection
--     of SILICATE CLOUDS in a planetary-mass companion. The spectrum is shaped by
--     disequilibrium chemistry and clouds; an L/T transition object on the cloudy-to-
--     clear boundary.
--   eps Ind A b -- Matthews et al. 2024 Nature (JWST coronagraphic MIRI): the COLDEST
--     directly-imaged exoplanet, T ~ 275 K, around a roughly solar-AGE (3.5-5.7 Gyr)
--     K5V star. Bright at 10.65 and 15.50 um but NOT detected at 3.5-5.0 um -> unknown
--     opacity source, possibly a high-metallicity, high-C/O atmosphere. Confirms (and
--     revises) previous RV / astrometric claims of a giant planet in the system.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('TYC 8998-760-1 b', 'silicate', 'detected', 'JWST/MIRI MRS', '2025Natur.643..938H', NULL,
     'Hoch et al. 2025 Nature (YSES-1 b): first-ever silicate EMISSION from a directly-imaged planet''s '
     'CIRCUMPLANETARY DISK (not from the planet''s photosphere). Submicron olivine dust grains, likely '
     'from collisions of planet-forming bodies in the CPD around this young Sun-like-star system.'),
    ('TYC 8998-760-1 c', 'silicate', 'detected', 'JWST/MIRI MRS', '2025Natur.643..938H', NULL,
     'Hoch et al. 2025 Nature (YSES-1 c): atmospheric silicate CLOUDS via the 9-11 um absorption '
     'feature. Composition is either amorphous iron-enriched pyroxene, OR a combination of amorphous '
     'MgSiO3 + Mg2SiO4. Particle radius <= 0.1 um at 1 mbar pressure.'),
    ('VHS J125601.92-125723.9 b', 'H2O', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: water detected in the 1-20 um JWST spectrum (R ~ 1000-3700, NIRSpec IFU + MIRI '
     'MRS), the highest-fidelity spectrum to date for a planetary-mass companion. Cross-checked against '
     'brown-dwarf templates, molecular opacities, and atmospheric models.'),
    ('VHS J125601.92-125723.9 b', 'CH4', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: methane detected; disequilibrium chemistry contributes to the spectral shape.'),
    ('VHS J125601.92-125723.9 b', 'CO', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: carbon monoxide detected.'),
    ('VHS J125601.92-125723.9 b', 'CO2', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: carbon dioxide detected.'),
    ('VHS J125601.92-125723.9 b', 'Na', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: atomic sodium detected.'),
    ('VHS J125601.92-125723.9 b', 'K', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: atomic potassium detected.'),
    ('VHS J125601.92-125723.9 b', 'silicate', 'detected', 'JWST/NIRSpec IFU + MIRI MRS', '2023ApJ...946L...6M', NULL,
     'Miles et al. 2023: first-ever DIRECT detection of silicate clouds in a planetary-mass companion. '
     'Object is at the L-to-T transition where substellar atmospheres shift from cloudy to clear.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('eps Ind A b', 'effective_temperature', 275, NULL, NULL, 'K', 'JWST coronagraphic MIRI SED fit',
     '2024Natur.633..789M',
     'Matthews et al. 2024 Nature: T ~ 275 K (approximate; no formal uncertainty quoted in the abstract), '
     'making eps Ind A b the coldest directly-imaged exoplanet known. Consistent with theoretical thermal '
     'evolution models for a ~3.5-5.7 Gyr-old planet around a K5V star. Bright at 10.65 and 15.50 um, but '
     'non-detection at 3.5-5.0 um indicates an unknown opacity source -> possibly high metallicity and '
     'high C/O ratio.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
