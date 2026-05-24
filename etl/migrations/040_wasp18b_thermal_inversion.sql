-- WASP-18 b deep dive (manual literature review, 2026-05-23). A massive (~10 Mjup),
-- extremely irradiated ultra-hot Jupiter on a 0.94-day orbit -- a benchmark for
-- dayside THERMAL INVERSIONS (a stratosphere where temperature rises with altitude,
-- so molecular bands appear in emission rather than absorption). The value-add is
-- the inversion story and its drivers: H2O seen in emission, contested CO, and the
-- still-open question of what optical absorber sustains the inversion (the oxides
-- TiO/VO were ruled out by HST/Spitzer but reappear tentatively with JWST, alongside
-- H- continuum opacity). Molecule rows -> planet_atmospheres; the modern metallicity
-- and dayside temperature -> planet_derived_measurements. Values read from the cited
-- papers; bibcodes verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Sheppard et al. 2017 (HST/WFC3 + Spitzer emission) -- first evidence of the
--     thermal inversion; H2O NOT seen at 1.4 um; 4.5 um emission + 1.6 um absorption
--     attributed to CO; no TiO/VO. Inferred a very high C/H (~283x solar), C/O ~1.
--   Arcangeli et al. 2018 (HST/WFC3 + Spitzer) -- showed the spectrum is shaped by
--     H- opacity + thermal dissociation of H2O + thermal ionization of metals, not
--     clean bands; revised metallicity to SOLAR ([M/H] = -0.01 +/- 0.35, C/O < 0.85);
--     confirmed the inversion (4.5 um emission feature); T_day ~ 2900 K.
--   Coulombe et al. 2023 (JWST/NIRISS, 0.85-2.85 um emission) -- three H2O emission
--     features at >6 sigma (definitive); evidence for optical opacity possibly from
--     H-, TiO and VO (combined 3.8 sigma); requires a thermal inversion; solar
--     metallicity (M/H = 1.03 +1.11/-0.51 x solar), C/O < 1.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-18 b', 'H2O', 'detected', 'JWST/NIRISS', '2023Natur.620..292C', 6.0,
     'Coulombe et al. 2023. Three water emission features at >6 sigma in the JWST/NIRISS '
     'dayside spectrum -- seen in EMISSION because of the thermal inversion. Supersedes the '
     'earlier HST non-detection at 1.4 um (Sheppard et al. 2017), which lacked the sensitivity.'),
    ('WASP-18 b', 'CO', 'tentative', 'Spitzer/IRAC', '2017ApJ...850L..32S', NULL,
     'Sheppard et al. 2017. 4.5 um emission + 1.6 um absorption attributed to CO. Contested: '
     'Arcangeli et al. 2018 reproduces the 4.5 um Spitzer emission with H- continuum opacity and '
     'the thermal inversion alone, without requiring a CO detection.'),
    ('WASP-18 b', 'TiO', 'inconclusive', 'JWST/NIRISS', '2023Natur.620..292C', NULL,
     'Coulombe et al. 2023. TiO is one candidate for the optical opacity that could drive the '
     'inversion, but only at a combined 3.8 sigma with H- and VO (not species-resolved). '
     'Sheppard et al. 2017 found no TiO/VO, so the inversion driver remains open.'),
    ('WASP-18 b', 'VO', 'inconclusive', 'JWST/NIRISS', '2023Natur.620..292C', NULL,
     'Coulombe et al. 2023. VO is a candidate optical absorber for the inversion, part of the '
     'same 3.8 sigma combined optical-opacity signal (H-/TiO/VO, not species-resolved). '
     'Ruled out earlier by Sheppard et al. 2017.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-18 b', 'metallicity', 1.03, 1.11, 0.51, 'x_solar', 'JWST/NIRISS retrieval',
     '2023Natur.620..292C',
     'Coulombe et al. 2023: M/H = 1.03 +1.11/-0.51 x solar (i.e. solar), C/O < 1. Resolves an '
     'earlier tension -- Sheppard et al. 2017 inferred a very high C/H (~283x solar) from HST '
     '+ Spitzer, while Arcangeli et al. 2018 inferred solar ([M/H] = -0.01 +/- 0.35) once H- '
     'and thermal dissociation were modelled. The JWST value confirms the solar result.'),
    ('WASP-18 b', 'dayside_temperature', 2900, NULL, NULL, 'K', 'self-consistent 1D forward models',
     '2018ApJ...855L..30A',
     'Arcangeli et al. 2018: dayside temperature ~2900 K (approximate). Hot enough to thermally '
     'dissociate H2O and ionize metals, producing the H- continuum opacity; cf. catalog '
     'equilibrium temperature 2429 K.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
