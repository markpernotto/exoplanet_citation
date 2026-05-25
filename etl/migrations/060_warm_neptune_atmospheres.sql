-- Warm-Neptune / sub-Neptune atmosphere batch (manual literature review, 2026-05-24).
-- First batch of the atmosphere deep-dive backlog (planets with published JWST-era
-- spectroscopy in planet_atmospheric_observations but no curated molecule verdicts).
-- Molecules + significances taken from the cited papers' tables (user-pasted) where
-- available, otherwise their abstracts; bibcodes verified via ADS.
--
--   GJ 3470 b  -- Beatty et al. 2024 (JWST/NIRCam + archival HST/WFC3 + Spitzer):
--     H2O, CH4, SO2, CO2 each detected at >3 sigma; SO2 = disequilibrium
--     photochemistry at unusually low mass/temp (11.2 M_earth, 600 K).
--   GJ 436 b   -- Mukherjee et al. 2025 (JWST NIRCam+MIRI emission, 2.4-11.9 um):
--     famously weak features; only tentative CO2 (2 sigma); dayside ~663 K.
--   HAT-P-26 b -- Wakeford et al. 2017 (HST/WFC3+Spitzer): prominent H2O, metallicity
--     4.8x solar. Gao et al. 2025 (JWST/NIRSpec G395H): CO2 + SO2 (decisive/strong),
--     marginal H2S + CO. NB Gao reports log-Bayes factors (lnB), not sigma -> recorded
--     with lnB in the note, confidence_sigma left NULL.
--   TOI-270 d  -- Holmberg & Madhusudhan 2024 (JWST/NIRSpec G395H + HST/WFC3):
--     CH4 (4.9 sigma) + CO2 (3.6 sigma) + a tentative CS2 (2.8 sigma; also in Felix
--     et al. 2025, Bayes factor 78); NH3 not detected; DMS not detected. Felix 2025
--     adds the derived C/O (0.77) and [M/H] (2.2 dex) = the miscible-envelope side of
--     the Hycean-vs-miscible debate.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    -- GJ 3470 b: exact per-molecule significances + log mixing ratios from Beatty et al.
    -- 2024 Table 1 (free retrieval; "DS" = detection significance). User-pasted table.
    ('GJ 3470 b', 'H2O',  'detected', 'JWST/NIRCam', '2024ApJ...970L..10B', 6.3,
     'Beatty et al. 2024 free retrieval (JWST/NIRCam + archival HST/WFC3 + Spitzer): 6.3 sigma, '
     'log mixing ratio -1.08 (+0.43/-0.52).'),
    ('GJ 3470 b', 'CO2',  'detected', 'JWST/NIRCam', '2024ApJ...970L..10B', 7.3,
     'Beatty et al. 2024: 7.3 sigma, log mixing ratio -2.47 (+0.61/-0.43).'),
    ('GJ 3470 b', 'SO2',  'detected', 'JWST/NIRCam', '2024ApJ...970L..10B', 4.0,
     'Beatty et al. 2024: 4.0 sigma, log mixing ratio -3.57 (+0.26/-0.25). The lowest-mass, coldest '
     'planet known with a strong SO2 feature (11.2 M_earth, 600 K) -> disequilibrium photochemistry.'),
    ('GJ 3470 b', 'CH4',  'detected', 'JWST/NIRCam', '2024ApJ...970L..10B', 3.8,
     'Beatty et al. 2024: 3.8 sigma, log mixing ratio -4.05 (+0.25/-0.27).'),
    ('GJ 3470 b', 'CO',   'upper_limit', 'JWST/NIRCam', '2024ApJ...970L..10B', NULL,
     'Beatty et al. 2024: not detected (1.5 sigma); retrieved log mixing ratio -0.96, poorly constrained.'),
    ('GJ 3470 b', 'HCN',  'upper_limit', 'JWST/NIRCam', '2024ApJ...970L..10B', NULL,
     'Beatty et al. 2024: not detected (1.2 sigma); retrieved log mixing ratio -8.14.'),
    ('GJ 3470 b', 'NH3',  'upper_limit', 'JWST/NIRCam', '2024ApJ...970L..10B', NULL,
     'Beatty et al. 2024: not detected (significance N/A); retrieved log mixing ratio -7.30.'),
    ('GJ 436 b', 'CO2',   'tentative', 'JWST/NIRCam+MIRI', '2025ApJ...982L..39M', 2.0,
     'Mukherjee et al. 2025: only tentative CO2 (2 sigma) in the panchromatic emission spectrum; '
     'molecular features are weak (the planet has long been interpreted as metal-rich and/or cloudy).'),
    -- HAT-P-26 b: detection significances are log-Bayes factors (lnB) from Gao et al. 2025's
    -- abstract (the paper reports Bayesian evidence, not sigma, so confidence_sigma stays NULL);
    -- abundances + 3-sigma upper limits from Gao Table 5 (free retrieval). User-pasted tables.
    ('HAT-P-26 b', 'H2O', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: lnB = 4.1; log mixing ratio ~ -1.5. Water was first measured by Wakeford et al. '
     '2017 (HST/WFC3+Spitzer, 525 ppm bands), the basis of the 4.8x-solar metallicity.'),
    ('HAT-P-26 b', 'CO2', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: decisive (lnB = 85.6); log mixing ratio ~ -3.0.'),
    ('HAT-P-26 b', 'SO2', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: strong (lnB = 13.5); log mixing ratio ~ -4.4; photochemical SO2 in a warm '
     'super-Neptune (~6 R_earth).'),
    ('HAT-P-26 b', 'CO',  'upper_limit', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: not detected (lnB < 0.5); 3-sigma upper limit on log mixing ratio ~ < -2.2.'),
    ('HAT-P-26 b', 'H2S', 'upper_limit', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: marginal / not detected (lnB < 0.5); Table 5 gives mostly 3-sigma upper limits.'),
    ('HAT-P-26 b', 'CH4', 'upper_limit', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: 3-sigma upper limit on log mixing ratio ~ < -4.6.'),
    ('HAT-P-26 b', 'NH3', 'upper_limit', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: 3-sigma upper limit on log mixing ratio ~ < -4.0.'),
    ('HAT-P-26 b', 'HCN', 'upper_limit', 'JWST/NIRSpec G395H', '2025AJ....170..292G', NULL,
     'Gao et al. 2025: 3-sigma upper limit on log mixing ratio ~ < -4.5.'),
    -- TOI-270 d: detections + non-detections from Holmberg & Madhusudhan 2024 Table 1 (canonical
    -- one-offset case; DS = detection significance), independently recovered by Felix et al. 2025
    -- (Bayes factors). The two agree on the molecules but disagree on interpretation (Hycean vs
    -- high-metallicity miscible envelope). User-pasted tables.
    ('TOI-270 d', 'CH4',  'detected', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', 4.9,
     'Holmberg & Madhusudhan 2024: 4.9 sigma (canonical case; 3.8-4.9 across cases), log mixing ratio '
     '-2.44 (+0.34/-0.46). Decisive in Felix 2025 (Bayes factor ~3e25).'),
    ('TOI-270 d', 'CO2',  'detected', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', 3.6,
     'Holmberg & Madhusudhan 2024: 3.6 sigma (2.9-3.9 across cases), log mixing ratio -1.96 (+0.49/-0.79). '
     'Decisive in Felix 2025 (Bayes factor ~3e7).'),
    ('TOI-270 d', 'CS2',  'tentative', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', 2.8,
     'Holmberg & Madhusudhan 2024: 2.8 sigma (2.7-3.0 across cases), log mixing ratio -2.59 (+0.67/-0.95); '
     'carbon disulfide, independently recovered by Felix 2025 (Bayes factor 78). A sulfur-chemistry '
     'signature central to the Hycean-vs-miscible-envelope debate. NB DMS (the contested K2-18 b '
     'biosignature) is NOT detected here.'),
    ('TOI-270 d', 'H2O',  'inconclusive', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', NULL,
     'Holmberg & Madhusudhan 2024: model-dependent (1.6 sigma in the canonical case, up to 4.4 sigma '
     'with clouds), not robustly constrained. Felix 2025 finds it not significant (Bayes factor ~1).'),
    ('TOI-270 d', 'CO',   'upper_limit', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', NULL,
     'Holmberg & Madhusudhan 2024: not detected (95% upper limit log < -1.63); Felix 2025 log < -4.'),
    ('TOI-270 d', 'SO2',  'upper_limit', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', NULL,
     'Holmberg & Madhusudhan 2024: not detected (retrieval log ~ -8); Felix 2025 log < -5.'),
    ('TOI-270 d', 'NH3',  'ruled_out', 'JWST/NIRSpec G395H', '2024A&A...683L...2H', NULL,
     'Holmberg & Madhusudhan 2024: not detected (log < -5.75); the low NH3 is a point cited for the '
     'Hycean interpretation.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 3470 b', 'metallicity', 125, 40, 40, 'x_solar', '1D-RCPE grid retrieval (ScCHIMERA)',
     '2024ApJ...970L..10B',
     'Beatty et al. 2024: 125 +/- 40 x solar (M/H = 2.1 +/- 0.15 dex); the free retrieval independently '
     'gives >=100x. Resolves the long-standing "low metallicity" puzzle for this planet: older estimates '
     'used water/H, whereas the SO2 + CH4 detections here pin a super-solar value matching formation theory.'),
    ('GJ 3470 b', 'C/O', 0.35, 0.1, 0.1, 'ratio', '1D-RCPE grid retrieval (ScCHIMERA)',
     '2024ApJ...970L..10B',
     'Beatty et al. 2024: slightly sub-solar, C/O = 0.35 +/- 0.1 (solar is ~0.55).'),
    ('GJ 436 b', 'dayside_temperature', 662.8, 5.0, 5.0, 'K', 'JWST emission, dayside blackbody',
     '2025ApJ...982L..39M',
     'Mukherjee et al. 2025: T_day = 662.8 +/- 5.0 K, close to the zero-albedo equilibrium temperature; '
     'JWST flux near 3.6 um is fainter than the older Spitzer photometry implied.'),
    ('HAT-P-26 b', 'metallicity', 4.8, 21.5, 4.0, 'x_solar', 'HST/Spitzer transmission retrieval',
     '2017Sci...356..628W',
     'Wakeford et al. 2017: heavy-element abundance 4.8 (+21.5/-4.0) x solar, via the water abundance; '
     'suggests a primordial envelope acquired late in the disk lifetime.'),
    ('TOI-270 d', 'C/O', 0.77, 0.28, 0.14, 'ratio', 'miscible-envelope retrieval (fiducial)',
     '2025A&A...701A.296F',
     'Felix et al. 2025 fiducial model: super-solar C/O = 0.77 (+0.28/-0.14). Sulfur-bearing model '
     'variants push it much higher (up to ~3); part of the contested Hycean-vs-miscible interpretation.'),
    ('TOI-270 d', 'metallicity', 2.20, 0.14, 0.14, 'dex', 'miscible-envelope retrieval (fiducial)',
     '2025A&A...701A.296F',
     'Felix et al. 2025: [M/H] = 2.20 +/- 0.14 dex (~158x solar), supporting a high-metallicity miscible '
     'envelope over a low-metallicity Hycean atmosphere (the central debate for this planet).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
