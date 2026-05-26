-- Atmosphere backlog batch 4: JWST hot Jupiters (manual literature review, 2026-05-25).
-- Four iconic JWST hot-Jupiter results, each a "first" or benchmark in some respect.
-- Bibcodes verified via ADS.
--
--   WASP-43 b   -- Bell et al. 2024 NatAs (JWST MIRI/LRS phase curve, 5-12 um):
--     dayside 1524 +/- 35 K vs nightside 863 +/- 23 K (huge day-night contrast); H2O
--     absorption at ALL orbital phases; NIGHTSIDE CLOUDS optically thick at P > ~100
--     mbar (cloudless dayside above the MIR photosphere); CH4 NOT detected on the
--     nightside (2 sigma upper limit ~1-6 ppm) -> direct evidence for disequilibrium
--     chemistry (equilibrium would predict CH4 nightside).
--   WASP-80 b   -- Bell et al. 2023 Nature (JWST NIRCam 2.4-4 um, transmission +
--     emission): CH4 detected at >6 sigma in BOTH geometries, the first definitive
--     space-based CH4 detection in a transiting exoplanet. C/O ~solar to sub-solar
--     and ~5x solar metallicity. Plus Mansfield et al. 2025 (JWST NIRISS/SOSS
--     0.68-2.83 um eclipse): Bond albedo 1 sigma 0.148-0.383; manganese sulfide and
--     silicate clouds DISFAVOURED; soots / low-formation-rate tholin hazes consistent.
--   WASP-77 A b -- August et al. 2023 (JWST NIRSpec 2.8-5.2 um eclipse): H2O and CO
--     detected; CO2 NOT detected. Sub-solar [M/H] = -0.91 +0.24/-0.16 dex, near-solar
--     C/O = 0.36 +0.10/-0.09. Confirms the high-resolution Line 2021 result to ~1 sigma.
--   HD 149026 b -- Bean et al. 2023 Nature (JWST NIRSpec 2.36-5.02 um eclipse): H2O
--     and CO2 detected; atmospheric METALLICITY 59-276x solar at 1 sigma, > 4 sigma
--     above Saturn's ~7.5x. The most metal-rich giant planet known. Atmospheric and
--     bulk metallicities correlate (with bulk ~66 +/- 2% heavy-element by mass).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-43 b', 'H2O', 'detected', 'JWST/MIRI-LRS', '2024NatAs...8..879B', NULL,
     'Bell et al. 2024 (JWST MIRI/LRS phase curve, 5-12 um): water absorption detected at all orbital '
     'phases. Nightside thermal emission also reveals OPTICALLY THICK NIGHTSIDE CLOUDS at P > ~100 mbar; '
     'the dayside is cloudless above the mid-IR photosphere. Dayside 1524 K, nightside 863 K.'),
    ('WASP-43 b', 'CH4', 'ruled_out', 'JWST/MIRI-LRS', '2024NatAs...8..879B', 2.0,
     'Bell et al. 2024: methane NOT detected on the nightside (2 sigma upper limit ~1-6 ppm, depending '
     'on model assumptions). This is a clean disequilibrium-chemistry result: thermochemical equilibrium '
     'would predict CH4 to dominate on a ~860 K nightside, so the non-detection requires zonal-wind-driven '
     'disequilibrium kinetics.'),
    ('WASP-80 b', 'CH4', 'detected', 'JWST/NIRCam', '2023Natur.623..709B', 6.0,
     'Bell et al. 2023 (JWST NIRCam 2.4-4 um, transmission AND emission): the FIRST definitive '
     'space-based CH4 detection in a transiting exoplanet (>6 sigma in each geometry). Abundances '
     'consistent between geometries and with ~5x solar metallicity and solar/sub-solar C/O. NB '
     'Mansfield et al. 2025 (NIRISS/SOSS 0.68-2.83 um eclipse) disfavours manganese-sulfide and '
     'silicate clouds; soots / low-formation-rate tholin hazes are consistent with the spectrum.'),
    ('WASP-77 A b', 'H2O', 'detected', 'JWST/NIRSpec G395H', '2023ApJ...953L..24A', NULL,
     'August et al. 2023 (JWST NIRSpec 2.8-5.2 um eclipse): water identified and its abundance '
     'constrained alongside CO; consistent within ~1-2 sigma with the prior high-resolution Line 2021 '
     'result, reaffirming high-res spectroscopy as a reliable abundance technique.'),
    ('WASP-77 A b', 'CO', 'detected', 'JWST/NIRSpec G395H', '2023ApJ...953L..24A', NULL,
     'August et al. 2023: carbon monoxide detected; one of the two driving species (with H2O) for the '
     'sub-solar [M/H] and near-solar C/O retrieval.'),
    ('WASP-77 A b', 'CO2', 'ruled_out', 'JWST/NIRSpec G395H', '2023ApJ...953L..24A', NULL,
     'August et al. 2023: no CO2 in the spectrum. NB WASP-77 A b and HD 149026 b have nearly identical '
     'near-IR brightness temperatures but very different compositions, highlighting hot-Jupiter atmospheric '
     'diversity.'),
    ('HD 149026 b', 'H2O', 'detected', 'JWST/NIRSpec G395H', '2023Natur.618...43B', NULL,
     'Bean et al. 2023 Nature (JWST NIRSpec 2.36-5.02 um eclipse): water absorption modelled in the '
     'thermal emission spectrum alongside CO2; together they constrain the atmospheric metallicity to '
     '59-276x solar at 1 sigma.'),
    ('HD 149026 b', 'CO2', 'detected', 'JWST/NIRSpec G395H', '2023Natur.618...43B', NULL,
     'Bean et al. 2023: carbon dioxide detected, the dominant driver (with H2O) for the strongly super-'
     'solar atmospheric metallicity that makes HD 149026 b the most metal-rich giant planet known.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-43 b', 'dayside_temperature', 1524, 35, 35, 'K',
     'JWST MIRI/LRS phase curve (dayside average brightness T)',
     '2024NatAs...8..879B',
     'Bell et al. 2024: dayside-average brightness T = 1524 +/- 35 K from the MIRI/LRS phase curve.'),
    ('WASP-43 b', 'nightside_temperature', 863, 23, 23, 'K',
     'JWST MIRI/LRS phase curve (nightside average brightness T)',
     '2024NatAs...8..879B',
     'Bell et al. 2024: nightside-average brightness T = 863 +/- 23 K. The ~660 K day-night contrast plus '
     'the lack of detectable CH4 on the nightside both indicate disequilibrium-chemistry driven by zonal winds.'),
    ('WASP-80 b', 'bond_albedo', 0.27, 0.12, 0.12, 'dimensionless',
     'JWST NIRISS/SOSS eclipse + reflected-light geometric-albedo retrieval',
     '2025AJ....169..277M',
     'Mansfield et al. 2025: Bond albedo 1 sigma range 0.148-0.383, midpoint 0.27 +/- 0.12 (the value '
     'recorded; the range is the honest constraint). Inferred via ~30 ppm reflected-light contribution '
     'at short wavelengths in NIRISS/SOSS 0.68-2.83 um eclipse.'),
    ('WASP-77 A b', 'metallicity', -0.91, 0.24, 0.16, 'dex',
     'JWST NIRSpec G395H eclipse, chemical-equilibrium retrieval',
     '2023ApJ...953L..24A',
     'August et al. 2023: [M/H] = -0.91 +0.24/-0.16 dex (SUB-SOLAR). Within ~1 sigma of the prior '
     'high-resolution Line 2021 ground-based result. Less consistent with the shorter-wavelength HST/WFC3 '
     'analysis.'),
    ('WASP-77 A b', 'C/O', 0.36, 0.10, 0.09, 'ratio',
     'JWST NIRSpec G395H eclipse, chemical-equilibrium retrieval',
     '2023ApJ...953L..24A',
     'August et al. 2023: C/O = 0.36 +0.10/-0.09 (near-solar). Within ~1.8 sigma of the Line 2021 high-'
     'resolution result.'),
    ('HD 149026 b', 'metallicity', 167, 109, 108, 'x_solar',
     'JWST NIRSpec G395H eclipse, atmospheric retrieval (CO2 + H2O)',
     '2023Natur.618...43B',
     'Bean et al. 2023: atmospheric metallicity in the 1 sigma range 59-276 x solar (the value recorded '
     'is the arithmetic midpoint ~167 with half-range uncertainties; the range is the honest constraint). '
     '> 4 sigma above Saturn''s atmospheric metallicity (~7.5x solar) -> HD 149026 b is the most metal-rich '
     'giant planet known. Bulk heavy-element mass fraction ~66 +/- 2%.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
