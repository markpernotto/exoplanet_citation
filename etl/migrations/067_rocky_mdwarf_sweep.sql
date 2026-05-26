-- Atmosphere backlog batch 7: finish the rocky M-dwarf sweep started in batch 3
-- (manual literature review, 2026-05-26). Closes out three rocky-target systems
-- with recent JWST atmosphere results. TRAPPIST-1 g and h were also on the
-- shortlist but have no dedicated JWST atmosphere paper as of 2026-05 (the
-- 2024-2025 JWST work on TRAPPIST-1 has targeted b, c, e via the TST DREAMS
-- program); skipped silently per user decision.
--
-- Bibcodes:
--   GJ 357 b   -- Adams Redai et al. 2025, JWST COMPASS NIRSpec G395H. arXiv
--     2507.07165, accepted AJ. The formal AJ bibcode is not yet issued, so we
--     cite the arXiv eprint 2025arXiv250707165A (to be updated post-publication).
--   LHS 1140 c -- Fortune et al. 2025 "Hot Rocks Survey III", A&A 701, A25 ->
--     2025A&A...701A..25F.
--   LTT 3780 c -- Rigby et al. 2025 (Madhusudhan group), arXiv 2512.15844,
--     accepted ApJL. Formal bibcode not yet issued; cite 2025arXiv251215844R
--     for now (to be updated post-publication). Paper uses "TOI-732 c"; our
--     catalog pl_name is "LTT 3780 c" (NASA EA canonical).
--
-- Results in brief:
--   GJ 357 b -- JWST COMPASS NIRSpec G395H transmission (18-27 ppm precision)
--     rules out a cloud-free 100x solar metallicity (primordial H/He) atmosphere
--     at 8.2 sigma. Cloud-free 1000x solar / pure CH4 / pure CO2 / pure H2O
--     atmospheres all permitted to within 1.2 sigma alongside a bare-rock best-
--     fit (chi^2_r = 0.9, sigma 0.3). Broader rule-outs from Figure 4:
--     metallicity < 316x solar (10^2.5) ruled out at >3 sigma for chemical-
--     equilibrium atmospheres with opaque pressure >= 10^-4 bar; mean molecular
--     weight < 8 g/mol ruled out at >3 sigma for H2O-H2 mixtures with opaque
--     pressure >= 10^-1 bar. Headline: GJ 357 b is either airless or hosts a
--     high-MMW secondary atmosphere (potentially CO2-rich), planned JWST
--     thermal emission observations would distinguish.
--   LHS 1140 c -- "Hot Rocks Survey III" JWST/MIRI F1500W eclipses (three of
--     them, joint fit) measure dayside brightness temperature T_day = 561 +/-
--     44 K, close to the bare-rock theoretical maximum 537 +/- 9 K (so little
--     to no heat redistribution). Joint-fit eclipse depth 273 +/- 43 ppm (>6
--     sigma detection). Atmospheres containing CO2-N2 with surface pressure
--     >= 1 bar and CO2 mixing ratio >= 100 ppm are ruled out at > 4 sigma
--     (Table 8 in Fortune 2025); the paper's plain-language summary in the
--     Conclusions: "unlikely to host an atmosphere containing significant
--     levels (>100 ppm) of CO2." Bare-rock with low albedo consistent.
--     Cosmic-shoreline relevance: LHS 1140 c likely airless while sister
--     LHS 1140 b likely hosts an atmosphere -> could place each planet on
--     either side of the shoreline.
--   LTT 3780 c -- Rigby et al. 2025 JWST NIRISS + NIRSpec G395H + MIRI LRS
--     (0.9-12 um) transmission spectrum. Headline: CH4 detected at 3.0-4.6
--     sigma (lnB 3.2-8.8) depending on retrieval setup, with the M23
--     (Madhusudhan 2023 canonical biosignature setup) one-offset case giving
--     the strongest 4.6 sigma (log10 VMR -1.57 ≈ 3%). H2O / CO / CO2 nominal
--     constraints (95% upper limits) as non-detections in a H2-rich atm;
--     NH3 and HCN non-detected at tighter upper limits. A 250-species survey
--     finds moderate-to-strong evidence (up to lnB ~5.9, 3.9 sigma) for
--     additional absorption from one or more complex molecules: top candidates
--     are cyclopentene (3.9 sigma NIR), isobutylene, propylene, 1-pentene
--     (3.5-3.7 sigma NIR), with significant degeneracies precluding species
--     identification. Recorded as a single tentative `hydrocarbons` row
--     (category label, following the `silicate` precedent for cloud species).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql.
-- Idempotent (ON CONFLICT DO UPDATE).

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('GJ 357 b', 'H2', 'ruled_out', 'JWST/NIRSpec G395H', '2025arXiv250707165A', 8.2,
     'Adams Redai et al. 2025 (JWST COMPASS, Figure 5): cloud-free 100x solar metallicity (primordial '
     'H/He-rich) atmosphere ruled out at 8.2 sigma (chi^2_r = 4.2). 1000x solar metallicity, cloud-'
     'free CH4-pure, CO2-pure, and H2O-pure atmospheres all PERMITTED to within 1.2 sigma alongside '
     'a bare-rock best fit (no-atmosphere: chi^2_r = 0.9, sigma 0.3). NIRSpec G395H transmission, '
     'median precision 18-27 ppm. Broader rule-outs in Figure 4: see derived rows for the metallicity '
     'and MMW lower limits.'),

    ('LHS 1140 c', 'CO2', 'ruled_out', 'JWST/MIRI F1500W', '2025A&A...701A..25F', 4.3,
     'Fortune et al. 2025 (Hot Rocks Survey III) Table 8: any CO2-N2 atmosphere with surface pressure '
     '>= 1 bar AND CO2 mixing ratio >= 100 ppm ruled out at > 3 sigma (1 bar / 100 ppm CO2 = 3.7 '
     'sigma; 1 bar / 1000 ppm = 4.3 sigma recorded; 10 bar / any reasonable CO2 = 4.8-5.0 sigma). '
     'Reference eclipse depth d = 273 +/- 43 ppm (Table 4, AP Ext w/ GP joint fit of 3 eclipses), '
     'assumed surface albedo A_surf = 0.1. Paper Conclusions in plain language: "unlikely to host '
     'an atmosphere containing significant levels (>100 ppm) of CO2." Consistent with a low-albedo '
     'bare rock at T_day 561 +/- 44 K (see derived row).'),

    ('LTT 3780 c', 'CH4', 'detected', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 4.6,
     'Rigby et al. 2025 Table 3, M23 retrieval (Madhusudhan 2023 biosignature setup, 6 CNO + 5 bio '
     'species), 1-offset case: CH4 detected at 4.6 sigma (lnB 8.8), log10 VMR -1.57 +0.36/-0.48 '
     '(~2.7%). Range across all 8 retrieval configurations: 3.0-4.6 sigma, log10 VMR -2.61 to -1.57 '
     '(0.25-2.7%); the abstract reports ~1% as the typical median. Recorded value is the headline '
     'M23 1-offset case.'),

    ('LTT 3780 c', 'CO2', 'ruled_out', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 2.0,
     'Rigby et al. 2025 Table 3: non-detection with 95% upper limit log10 X < -2.18 to -2.83 across '
     'all 8 retrieval setups. Recorded sigma is the 95% confidence level (= ~2 sigma); the paper '
     'frames CO2 / CO / H2O as "nominal constraints" rather than ruled-out species.'),

    ('LTT 3780 c', 'CO', 'ruled_out', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 2.0,
     'Rigby et al. 2025 Table 3: 95% upper limit log10 X < -1.57 to -1.79 across all retrieval '
     'setups. Recorded sigma is 95% confidence (~2 sigma).'),

    ('LTT 3780 c', 'H2O', 'ruled_out', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 2.0,
     'Rigby et al. 2025 Table 3: 95% upper limit log10 X < -1.49 to -2.01 across all retrieval '
     'setups (M23 setup: < -1.49). Recorded sigma is 95% confidence (~2 sigma).'),

    ('LTT 3780 c', 'NH3', 'ruled_out', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 2.0,
     'Rigby et al. 2025 Table 3: tight non-detection, 95% upper limit log10 X < -4.13 to -4.80 across '
     'setups (M23 < -4.22). NH3 is the most strongly constrained non-detection. Recorded sigma is '
     '95% confidence (~2 sigma).'),

    ('LTT 3780 c', 'HCN', 'ruled_out', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 2.0,
     'Rigby et al. 2025 Table 3: non-detection, 95% upper limit log10 X < -2.62 to -3.65 across '
     'setups (M23 < -3.06). Recorded sigma is 95% confidence (~2 sigma).'),

    ('LTT 3780 c', 'hydrocarbons', 'tentative', 'JWST/NIRISS-SOSS + NIRSpec G395H + MIRI LRS', '2025arXiv251215844R', 3.9,
     'Rigby et al. 2025 Table 2 (250-species survey): TENTATIVE evidence for additional absorption '
     'beyond the CNO baseline, attributable to one or more complex molecules. Strongest candidates '
     'in the NIR 1-offset retrievals: cyclopentene (3.9 sigma, lnB 5.9, log10 VMR -4.24), isobutylene '
     '(3.7 sigma NIR + 3.6 sigma MIR JexoPipe, log10 -4.62/-3.78), propylene (3.7 sigma NIR, log10 '
     '-3.94), 1-pentene (3.5 sigma NIR, log10 -4.31). The data CANNOT uniquely distinguish among '
     'these candidates - any one (or combination) could explain the absorption; significant '
     'degeneracies persist per the paper. Recorded as a single `hydrocarbons` category row '
     '(following the `silicate` precedent for cloud-species), confidence_sigma = strongest candidate.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 357 b', 'metallicity', 316, NULL, 0, 'x_solar',
     'JWST NIRSpec G395H transmission, chemical-equilibrium retrieval (Figure 4 left)',
     '2025arXiv250707165A',
     'Adams Redai et al. 2025 Figure 4 (LEFT panel): chemical-equilibrium atmospheres with '
     'metallicity < 10^2.5 x solar (≈316x) are ruled out at >3 sigma for opaque pressure levels '
     '>= 10^-4 bar, regardless of the model-data comparison method (chi^2 or Bayesian). Recorded as '
     'a LOWER LIMIT: value 316 with unc_lo = 0 encodes ">= 316x solar"; unc_hi NULL (no upper '
     'bound, conditional on the atmosphere being chemical-equilibrium). Compatible with bare-rock '
     '(no atmosphere) as an alternative.'),

    ('GJ 357 b', 'mean_molecular_weight', 8, NULL, 0, 'g_per_mol',
     'JWST NIRSpec G395H transmission, H2O-H2 mixture retrieval (Figure 4 right)',
     '2025arXiv250707165A',
     'Adams Redai et al. 2025 Figure 4 (RIGHT panel): for H2O-H2 mixed atmospheres with opaque '
     'pressure level >= 10^-1 bar, the data rule out mean molecular weight < 8 g/mol at >3 sigma. '
     'New quantity. Recorded as LOWER LIMIT: value 8 with unc_lo = 0 encodes ">= 8 g/mol"; unc_hi '
     'NULL (no upper bound, conditional on the atmosphere existing). Equivalent to ruling out a '
     'primordial H/He envelope above mbar pressures.'),

    ('LHS 1140 c', 'eclipse_depth', 273, 43, 43, 'ppm',
     'JWST MIRI F1500W secondary eclipse, joint fit of 3 eclipses (AP Ext w/ GP)',
     '2025A&A...701A..25F',
     'Fortune et al. 2025 Table 4: 273 +/- 43 ppm joint-fit eclipse depth at 15 um from 3 secondary '
     'eclipses (Nov 2023, Jul 2024, Jul 2024) using the primary reduction (aperture extraction + GP '
     'detrending). Eclipse detected at >5 sigma with high consistency across independent analysis '
     'methods (Tables 5-7 and G.1, G.2). New quantity; instrument = MIRI/Imaging F1500W.'),

    ('LHS 1140 c', 'dayside_temperature', 561, 44, 44, 'K',
     'JWST MIRI F1500W eclipse, absolute flux calibration (T_brightness)',
     '2025A&A...701A..25F',
     'Fortune et al. 2025 Conclusions: T_day = 561 +/- 44 K from absolute flux calibration of the '
     '15 um eclipse depth, close to the theoretical bare-rock maximum T_day,max = 537 +/- 9 K. The '
     'two are consistent within 1 sigma, indicating little to no day-night heat redistribution -> '
     'consistent with a bare rock or a tenuous atmosphere unable to redistribute heat.'),

    ('LTT 3780 c', 'atmospheric_temperature_10mbar', 350, 69, 59, 'K',
     'JWST 0.9-12 um free retrieval (POSEIDON), M23 setup, 1 offset',
     '2025arXiv251215844R',
     'Rigby et al. 2025 Table 3, M23 retrieval 1-offset case: temperature at 10 mbar pressure '
     'T_10mbar = 350.0 +68.7/-58.8 K (the headline retrieval setup matching the abstract). Range '
     'across all 8 retrieval configurations: 300-350 K, all within 1 sigma of each other. New '
     'quantity; useful for constraining the atmospheric T-P structure for this temperate '
     'sub-Neptune (Teq ~352 K).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
