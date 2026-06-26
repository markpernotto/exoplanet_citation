-- WDS curation Batch 10 (2026-06-24). Final WDS gap-list closeout pass.
-- 21 new binary_companions INSERTs + 8 SIMBAD-debt DELETE+INSERT
-- replacements (citationless stubs upgraded to cited rows) + 1
-- sy_snum_audit row for LHS 1678.
--
-- BATCH 10 SCOPE:
--
--   Pure new INSERTs (21 rows, WDS gap-list closeout + bonus):
--     LHS 1678 B          (Silverstein 2022; astrometric BD companion)
--     NGTS-3 A B          (Gunther 2018; unresolved K1V from BLENDFITTER)
--     WASP-20 B           (Southworth 2020; K2V close imaging)
--     TOI-2031 A B        (Yee 2025; Gaia DR3 wide CPM)
--     TOI-2169 A B        (Yee 2025; Gaia DR3 close CPM)
--     TOI-3160 A B        (Yee 2025; close speckle)
--     TOI-3523 A B        (Yee 2025; close AO+speckle)
--     TOI-3523 A C        (Yee 2025; wide Gaia tertiary)
--     TOI-4487 A B        (Yee 2025; Gaia DR3 wide CPM)
--     TOI-5386 A B        (Yee 2025; close AO+speckle)
--     TOI-3540 A B        (Yee 2022; K1V close companion)
--     K2-265 B            (Lam 2018; M3V close CPM)
--     TOI-3984 A B        (Canas 2023; DA white dwarf wide CPM)
--     WASP-76 B           (Southworth 2020; K3V close companion)
--     WASP-131 B          (Southworth 2020; K-dwarf close companion)
--     TOI-1259 A B        (Martin 2021; DA white dwarf wide CPM)
--     DMPP-3 A B          (Barnes 2020; inner SB1 at H-burning limit)
--     IRAS 04125+2902 B   (Barber 2024; pre-MS M dwarf wide CPM)
--     K2-288 B "A"        (Feinstein 2019; M2V primary; planet on the secondary)
--     TOI-4633 B          (Eisner 2024; G-dwarf close binary, P=231yr, e=0.91)
--     TOI-2267 B "A"      (Zuniga-Fernandez 2025 MIRROR ROW for the dual-host
--                          system; primary M5V at 0.384" / 8 AU; both A and B
--                          are NASA EA planet hosts so we need both rows)
--
--   SIMBAD citation-debt DELETE+INSERT cleanups (8 rows):
--     TOI-5293 A B        (Canas 2023; mid M dwarf wide CPM)
--     TOI-5181 A B        (Yee 2025; close Gaia + AO/speckle)
--     TOI-2193 A B        (Yee 2022; M dwarf close Gaia+speckle, full SED fit)
--     TOI-3331 A B        (Yee 2022; K-dwarf close Gaia+speckle, full SED fit;
--                          NB: separate TOI-3331 A C at 193" stays in SIMBAD-debt)
--     WASP-193 B          (Yee 2026; K7V wide CPM from El-Badry 2021)
--     WASP-2 B            (Southworth 2020; M2V close companion)
--     WASP-8 B            (Southworth 2020; M3V wide companion)
--     WASP-70 B           (Southworth 2020; M0V wide companion)
--
--   sy_snum_audit (1 row):
--     LHS 1678            (NASA EA reports 2; BD detection is substellar so
--                          supported_sy_snum = 1)
--
-- DEFERRED to Batch 11 (paper available but binary geometry not in pasted
-- excerpt, or paper doesn't characterize the binary at all):
--   K2-136          - Mann 2018 treats as single star
--   HD 135344 A     - Stolker 2025 covers new planet Ab not the A-B binary
--   TOI-159         - Mantovan 2026 says "S-type binary" but no geometry
--
-- EXISTING-ROWS CHECK before applying:
--   SELECT hostname, component_designation, separation_arcsec, source_bibcode
--     FROM binary_companions
--    WHERE hostname IN ('LHS 1678', 'NGTS-3 A', 'WASP-20', 'TOI-2031 A',
--                       'TOI-2169 A', 'TOI-3160 A', 'TOI-3523 A',
--                       'TOI-4487 A', 'TOI-5386 A', 'TOI-3540 A',
--                       'K2-265', 'TOI-3984 A', 'WASP-76', 'WASP-131',
--                       'TOI-1259 A', 'DMPP-3 A', 'IRAS 04125+2902',
--                       'K2-288 B', 'TOI-4633', 'TOI-2267 B',
--                       'TOI-5293 A', 'TOI-5181 A', 'TOI-2193 A',
--                       'TOI-3331 A', 'WASP-193', 'WASP-2', 'WASP-8',
--                       'WASP-70')
--    ORDER BY hostname, component_designation;
--
-- The 8 SIMBAD-debt rows should appear with source_bibcode IS NULL and
-- source_catalog = 'SIMBAD'. They will be replaced by the DELETE+INSERT
-- pattern below. The other 20 hosts should return zero rows; if any
-- unexpected row surfaces, halt and reconvert that INSERT to DELETE+INSERT.
--
-- Apply after 113_wds_batch9.sql.


-- ============================================================================
-- LHS 1678 B  -- astrometric BD companion
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('LHS 1678', 'B', 'A', 'brown dwarf', NULL,
     NULL, NULL, false, NULL, false,
     'astrometric brown-dwarf companion (decades-long orbit, no imaging)', 'manual', '2022AJ....163..151S',
     'LHS 1678 B: substellar (brown-dwarf-or-smaller) companion detected via CTIO/SMARTS 0.9m '
     'astrometric monitoring per Silverstein et al. 2022 (2022AJ....163..151S) Section 3.5. '
     'Orbital period of order DECADES; no imaging detection (Table 3 speckle: no sources detected at '
     'rho > 0.04-0.05" with delta_m < 4 mag). HARPS+CHIRON RV monitoring places upper limits ruling '
     'out an equal-mass stellar companion at any reasonable period (Table 6). The combined evidence '
     'allows only an upper limit on mass: "high-mass brown dwarf or smaller" per the paper, i.e. '
     'M_B <= ~0.075 Msun (75 MJup, H-burning limit). component_mass_msun left NULL since the value '
     'is an upper limit, not a measurement; same for component_teff_k. The host LHS 1678 A is M2V '
     'at M = 0.345 Msun, d = 19.9 pc. Companion is the only stellar/substellar companion in the '
     'system per the paper (Section 3.5: "Detected companions: 1"). See also the sy_snum_audit '
     'row at the bottom of this migration -- NASA EA reports sy_snum=2 because it counts the BD '
     'as stellar; under the cb_flag-audit convention used elsewhere in this atlas, brown dwarfs are '
     'substellar and do not count toward sy_snum, so the supported_sy_snum value is 1.',
     NULL);


-- ============================================================================
-- NGTS-3 A B  -- unresolved binary disentangled via BLENDFITTER
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('NGTS-3 A', 'B', 'A', 'K1V', 0.78,
     788, 0.88, false, 5230, false,
     'unresolved K1V companion (BLENDFITTER joint photo+RV CCF disentangling)', 'manual', '2018MNRAS.478.4720G',
     'NGTS-3 A B: K1V dwarf companion to the G6V planet host. SPATIALLY UNRESOLVED in NGTS '
     'photometry (>5" pixels); disentangled via BLENDFITTER joint photometry + RV CCF profile '
     'modelling per Gunther et al. 2018 (2018MNRAS.478.4720G). Mass M_B = 0.88 +0.14/-0.12 Msun, '
     'radius R_B = 0.77 +0.22/-0.16 R_sun, Teff_B = 5230 +190/-220 K (Table 9 derived parameters). '
     'Position from joint MCMC blend model: Delta-x_sky = 0.42 +0.36/-0.43" (east), Delta-y_sky '
     '= 0.66 +0.23/-0.35" (north); combined rho = 0.78" (computed; very uncertain), PA = 32.5 deg '
     '(computed atan2 of Delta-x, Delta-y; NE quadrant; uncertainties >50%). Projected '
     'separation ~788 AU at d = 1010 +150/-130 pc. Orbital LOWER limits from systemic-RV offset: '
     'a_binary > 500 AU, P_binary > 11000 yr. CAVEAT: rho/PA are from the joint MCMC blend '
     'model, not resolved imaging; future high-res imaging could revise. The planet NGTS-3 A b '
     '(hot Jupiter, P=1.675d) orbits the G6V primary; no centroid shift in NGTS data (Table 6 '
     'SNR < 5 in roll. and cross-corr.).',
     32.5);


-- ============================================================================
-- WASP-20 B  -- SPHERE close companion
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-20', 'B', 'A', 'K2V', 0.259,
     54, 0.89, false, 5235, false,
     'K2V close companion (SPHERE detection, planet on brighter star)', 'manual', '2020A&A...635A..74S',
     'WASP-20 B: K2V dwarf close visual companion (M_B = 0.89 +0.06/-0.07 Msun, Teff_B = 5235 '
     '+242/-272 K per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). rho = 0.259 +/- 0.003", '
     'Delta-K = 0.86 +/- 0.06 mag (SPHERE detection from companion Paper I, Bohn et al. 2020 '
     '~2020A&A...635A..73B). Projected separation ~54 AU at d ~ 210 pc (Anderson 2015). The '
     'planet WASP-20 b orbits the BRIGHTER (planet host) star per Southworth 2020 Section 3.1; '
     'the alternative (planet on fainter star) is photometrically allowed but disfavoured by joint '
     'analysis. Original Anderson 2015 (2015A&A...575A..61A) planet discovery treated the system '
     'as single; the binarity was discovered subsequently by Evans 2016 (2016A&A...589A..58E) and '
     'SPHERE (Paper I). PA not stated in Southworth 2020; see Paper I (Bohn 2020) for resolved '
     'astrometry. Planet host is an aged F9 star (Teff_A = 6000 K, 7+ Gyr).',
     NULL);


-- ============================================================================
-- TOI-2031 A B  (Yee 2025; wide Gaia DR3 CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-2031 A', 'B', 'A', NULL, 45.88,
     12820, NULL, false, NULL, false,
     'wide Gaia DR3 CPM companion', 'manual', '2025ApJS..280...30Y',
     'TOI-2031 A B: wide visual CPM companion detected via Gaia DR3 (Yee et al. 2025 Table 7, '
     '2025ApJS..280...30Y). rho = 45.88", PA = 148.5 deg, projected separation 12820 AU. '
     'Gaia DR3 ID 2299101044431941248 (TIC 470127879). G_B = 18.41 vs G_A = 11.11 (Delta-G = 7.30 '
     'mag). Parallax 3.63 +/- 0.11 mas vs primary 3.618 +/- 0.013 (consistent); proper motions '
     '(mu_alpha = 25.76 +/- 0.14 vs 25.79 +/- 0.017; mu_delta = 2.25 +/- 0.12 vs 2.40 +/- 0.014) '
     'consistent. R_chance = 3.95 x 10^-4 (very low, El-Badry et al. 2021 catalog framework). '
     'Paper does not derive a companion mass.',
     148.5);


-- ============================================================================
-- TOI-2169 A B  (Yee 2025; close Gaia CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-2169 A', 'B', 'A', NULL, 6.45,
     2350, NULL, false, NULL, false,
     'close Gaia DR3 CPM companion', 'manual', '2025ApJS..280...30Y',
     'TOI-2169 A B: close visual CPM companion via Gaia DR3 (Yee et al. 2025 Table 7, '
     '2025ApJS..280...30Y). rho = 6.45", PA = 233.7 deg, projected separation 2350 AU. '
     'Gaia DR3 ID 4535299582695351424 (TIC 8516790). G_B = 13.68 vs G_A = 10.96 (Delta-G = 2.73 '
     'mag). Parallax 2.803 +/- 0.014 mas vs primary 2.779 +/- 0.017 (consistent); RV 13.4 +/- 1.6 '
     'km/s vs primary 13.09 +/- 0.34 (consistent within errors). R_chance = 1.89 x 10^-5 '
     '(extremely low, definitively bound). Paper does not derive a companion mass.',
     233.7);


-- ============================================================================
-- TOI-3160 A B  (Yee 2025; close speckle)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3160 A', 'B', 'A', NULL, 0.33,
     160, NULL, false, NULL, false,
     'close speckle imaging companion (AO Delta-m = 3.30 in Ic)', 'manual', '2025ApJS..280...30Y',
     'TOI-3160 A B: close visual companion (Yee et al. 2025 Table 7, 2025ApJS..280...30Y) '
     'detected via Gemini-S Zorro 832 nm speckle (2021-07-20) and SOAR HRCam Ic speckle '
     '(2022-04-15). rho = 0.33", PA = 348.9 deg. AO Delta-m = 3.30 (Ic), >= 4 (832 nm). Too '
     'close for Gaia DR3 to resolve (no separate Gaia DR3 ID for B). Paper does not derive a '
     'companion mass or distance; if assumed bound at d ~ 488 pc (Gaia parallax 2.048 mas), '
     'projected separation ~ 160 AU.',
     348.9);


-- ============================================================================
-- TOI-3523 A B  (Yee 2025; close imaging)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3523 A', 'B', 'A', NULL, 0.67,
     410, NULL, false, NULL, false,
     'close AO+speckle imaging companion', 'manual', '2025ApJS..280...30Y',
     'TOI-3523 A B: close visual companion (Yee et al. 2025 Table 7, 2025ApJS..280...30Y) detected '
     'via Palomar PHARO AO (Brgamma, Hcont; 2023-06-07) and SAI-2.5m speckle Polarimeter Ic '
     '(2023-08-02, 2023-08-27). rho = 0.67", PA = 95.7 deg. AO Delta-m = 2.058 (Hcont), 2.105 '
     '(Brgamma), 3.5 (I). Too close for Gaia DR3 to resolve. Projected separation ~410 AU at '
     'd ~ 606 pc (parallax 1.651 mas). Paper does not derive a companion mass. NB: TOI-3523 is '
     'a TRIPLE -- separate wider tertiary C row follows.',
     95.7);


-- ============================================================================
-- TOI-3523 A C  (Yee 2025; wide Gaia tertiary)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3523 A', 'C', 'A', NULL, 8.50,
     5200, NULL, false, NULL, false,
     'wide Gaia DR3 tertiary', 'manual', '2025ApJS..280...30Y',
     'TOI-3523 A C: wide visual tertiary CPM companion via Gaia DR3 (Yee et al. 2025 Table 7, '
     '2025ApJS..280...30Y). rho = 8.50", PA = 254.9 deg, projected separation 5200 AU. Gaia DR3 '
     'ID 2080811118319127680 (TIC 1971172836). G_C = 19.12 vs G_A = 12.50 (Delta-G = 6.62 mag). '
     'Parallax 1.53 +/- 0.20 mas vs primary 1.651 +/- 0.029 (consistent within errors); proper '
     'motions consistent. R_chance = 1.24 x 10^-2 (likely bound but not as clean as TOI-2169). '
     'Paper does not derive a companion mass. Pairs with the close TOI-3523 A B at 0.67" for a '
     'hierarchical triple.',
     254.9);


-- ============================================================================
-- TOI-4487 A B  (Yee 2025; wide Gaia CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-4487 A', 'B', 'A', NULL, 6.93,
     3360, NULL, false, NULL, false,
     'wide Gaia DR3 CPM companion', 'manual', '2025ApJS..280...30Y',
     'TOI-4487 A B: wide visual CPM companion via Gaia DR3 (Yee et al. 2025 Table 7, '
     '2025ApJS..280...30Y). rho = 6.93", PA = 356.7 deg, projected separation 3360 AU. '
     'Gaia DR3 ID 2083061371948751616 (TIC 193754364). G_B = 19.23 vs G_A = 11.92 (Delta-G = 7.31 '
     'mag). Parallax 2.18 +/- 0.20 mas vs primary 2.097 +/- 0.009 (consistent); proper motions '
     'consistent. R_chance = 5.44 x 10^-4 (low). Paper does not derive a companion mass.',
     356.7);


-- ============================================================================
-- TOI-5386 A B  (Yee 2025; close imaging)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-5386 A', 'B', 'A', NULL, 0.24,
     90, NULL, false, NULL, false,
     'close AO+speckle imaging companion', 'manual', '2025ApJS..280...30Y',
     'TOI-5386 A B: close visual companion (Yee et al. 2025 Table 7, 2025ApJS..280...30Y) '
     'detected via Palomar PHARO AO (Brgamma, Hcont; 2023-07-02) and WIYN NESSI 832 nm speckle '
     '(2022-04-20). rho = 0.24", PA = 240.6 deg. AO Delta-m = 1.784 (Brgamma), 2.071 (Hcont). '
     'Too close for Gaia DR3 to resolve. Projected separation ~90 AU at d ~ 383 pc (parallax '
     '2.608 mas). Paper does not derive a companion mass.',
     240.6);


-- ============================================================================
-- TOI-3540 A B  (Yee 2022; K1V close companion with SED-fit mass)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3540 A', 'B', 'A', 'K1V', 0.917,
     259, 0.800, false, 4819, false,
     'K1V close companion (SOAR+Palomar; SED-fit secondary parameters)', 'manual', '2022AJ....164...70Y',
     'TOI-3540 A B: K1V dwarf companion (M_B = 0.800 +0.020/-0.021 Msun, R_B = 0.761 +/- 0.013 '
     'R_sun, Teff_B = 4819 +67/-65 K per Yee et al. 2022 Table 12 SED Fit Secondary Properties, '
     '2022AJ....164...70Y). Detection via SOAR HRCam Ic speckle (2021-10-01) and Palomar PHARO '
     'AO (Brgamma, Hcont; 2021-08-24). rho = 0.917" / PA = 200 deg per Table 11. AO Delta-m '
     '= 1.8 (I), 1.022 (Brgamma), 1.144 (Hcont). Too close for Gaia DR3 to resolve. Projected '
     'separation ~259 AU at d = 282.6 +3.2/-3.1 pc. Assumed coeval with primary, age 6.3 +1.6/'
     '-1.3 Gyr.',
     200);


-- ============================================================================
-- K2-265 B  (Lam 2018; M3V close CPM, multi-epoch SPHERE)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('K2-265', 'B', 'A', 'M3V', 0.978,
     142, 0.40, false, 3428, false,
     'M3V close CPM companion (Keck NIRC2 + VLT SPHERE 3 epochs across 2 years)', 'manual', '2018A&A...620A..77L',
     'K2-265 B: M3V dwarf companion (M_B = 0.40 +/- 0.01 Msun, R_B = 0.391 +0.006/-0.010 R_sun, '
     'Teff_B = 3428 +/- 22 K per Lam et al. 2018 Table 2, 2018A&A...620A..77L). Multi-epoch '
     'astrometry (Table A.1) confirms CPM: rho = 979 +/- 5 mas, PA = 248.27 +/- 0.29 deg '
     '(Keck NIRC2 2015-08-04); rho = 978 +/- 1 mas, PA = 247.87 +/- 0.20 (VLT SPHERE 2015-08-04); '
     'rho = 975 +/- 1 mas, PA = 247.99 +/- 0.01 (VLT SPHERE 2017-08-30). Recorded values use '
     'the latest SPHERE epoch. Projected separation 142 AU at d = 145 +/- 8 pc. The primary '
     'K2-265 A is G8V (Teff_A = 5477 K, M_A = 0.915 Msun, age 9.7 +/- 3.0 Gyr) and hosts the '
     'super-Earth K2-265 b. Paper Table 1 caption notes "K2-265 has a nearby bound companion" '
     'and the host stellar parameters represent the BLENDED system.',
     247.99);


-- ============================================================================
-- TOI-3984 A B  (Canas 2023; DA white dwarf wide CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3984 A', 'B', 'A', 'DA white dwarf', 3.27,
     356, 0.75, false, NULL, false,
     'DA white dwarf wide CPM companion (El-Badry 2021 catalog + WD_models cooling)', 'manual', '2023AJ....166...30C',
     'TOI-3984 A B: DA white dwarf wide CPM companion identified via the El-Badry et al. 2021 '
     '(2021MNRAS.506.2269E) Gaia EDR3 wide binary catalog, characterized by Canas et al. 2023 '
     '(2023AJ....166...30C). Gaia DR3 ID 1291955574574621056 (TIC 1101522311). rho = 3.27", '
     'projected separation 356 AU at d = 108.4 pc. False-detection probability < 4 x 10^-8. '
     'M_WD ~ 0.75 Msun and cooling age ~2.9 Gyr derived using WD_models package (Cheng 2019) '
     'with hydrogen atmosphere assumption and Bedard 2020 cooling models. Progenitor mass '
     '1.59 +/- 0.22 Msun (El-Badry IFMR) or 1.72 +/- 0.17 Msun (Williams 2009 IFMR). Total '
     'age consistent with primary gyrochronology (0.7-5.1 Gyr). Inferred binary eccentricity '
     'e = 0.64 +0.18/-0.26 (Hwang 2022 v-r angle method). Primary TOI-3984 A is M4V (M_A = '
     '0.49 Msun, Teff_A = 3476 K). Gaia GSP-Phot confirms WD location on the color-magnitude '
     'diagram. PA not stated in pasted excerpt.',
     NULL);


-- ============================================================================
-- WASP-76 B  (Southworth 2020; close K3V imaging companion)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-76', 'B', 'A', 'K3V', 0.436,
     NULL, 0.78, false, 4824, false,
     'K3V close companion (lucky imaging; CPM confirmed)', 'manual', '2020A&A...635A..74S',
     'WASP-76 B: K3V dwarf close companion (M_B = 0.78 +/- 0.03 Msun, Teff_B = 4824 +126/-128 K '
     'per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). rho = 0.436 +/- 0.003", Delta-K '
     '= 2.30 +/- 0.05 mag. First detected by Wollert & Brandner 2015 lucky imaging; redetected '
     'and CPM-confirmed in subsequent studies (Ginski 2016, Ngo 2016, Bohn 2020 = "Paper I"); '
     'NOT in the original West et al. 2016 discovery paper. The planet WASP-76 b orbits the '
     'BRIGHTER primary (Teff_A = 6347 K, hot Jupiter host); Southworth 2020 Section 3.4 rules '
     'out the planet-on-fainter-star scenario at high significance. separation_au left NULL '
     '(distance not in pasted excerpt; ~120 pc would give ~52 AU). PA not stated. WASP-76 b is '
     'one of the hottest planets known and a frequent atmospheric-characterization target.',
     NULL);


-- ============================================================================
-- WASP-131 B  (Southworth 2020; close K-dwarf companion)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-131', 'B', 'A', 'K6V', 0.189,
     NULL, 0.62, false, 4109, false,
     'K6V close companion (SPHERE detection; previously unknown)', 'manual', '2020A&A...635A..74S',
     'WASP-131 B: K-dwarf close companion (M_B = 0.62 +0.05/-0.04 Msun, Teff_B = 4109 +200/-163 '
     'K per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). Detection from SPHERE (Paper I, '
     'Bohn 2020). rho = 0.189 +/- 0.003", Delta-K = 2.82 +/- 0.20 mag. PREVIOUSLY UNKNOWN '
     '-- the WASP-131 planet was discovered by Hellier et al. 2017 as a single-star system. '
     'Contamination level of ~2.5% in TESS light curve. The planet WASP-131 b (low-density hot '
     'Saturn) orbits the brighter primary (Teff_A = 5950 K). separation_au left NULL (distance '
     'not in pasted excerpt). PA not stated.',
     NULL);


-- ============================================================================
-- TOI-1259 A B  (Martin 2021; DA white dwarf wide CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-1259 A', 'B', 'A', 'DA white dwarf', 13.67,
     1648, 0.561, false, 6300, false,
     'DA white dwarf wide CPM companion (El-Badry+18 / Mugrauer+20 + SED fit)', 'manual', '2021MNRAS.507.4132M',
     'TOI-1259 B: DA white dwarf wide CPM companion to a K-dwarf planet host. Originally '
     'identified via El-Badry & Rix 2018 and Mugrauer & Michel 2020 wide-binary catalogs; '
     'characterized in detail by Martin et al. 2021 (2021MNRAS.507.4132M) Table 4 via SED fit. '
     'Gaia DR2 ID 2294170834291960832 (TIC 1718312312). Projected separation = 1648 AU at d = '
     '120.6 +/- 4.6 pc (compared to primary at 118.11 +/- 0.37 pc, consistent). Computed rho '
     '= 13.67" (sep_AU / d), PA = 29.6 deg (computed from Gaia coordinates: companion is NE of '
     'primary in NE quadrant). M_WD = 0.561 +/- 0.021 Msun, R_WD = 0.0131 +/- 0.0003 R_sun, '
     'Teff_WD = 6300 +80/-70 K. Cooling age 1.88 +/- 0.06 Gyr; total system age 4.08 +1.21/-0.53 '
     'Gyr; progenitor mass 1.59 +/- 0.22 Msun (El-Badry+18 IFMR). The total age via WD '
     'chronology constrains the primary K-dwarf age, complementing gyrochronology. The planet '
     'TOI-1259 A b (R = 1.022 RJ, M = 0.441 MJ, P = 3.48d) orbits the K dwarf.',
     29.6);


-- ============================================================================
-- DMPP-3 A B  (Barnes 2020; inner SB1 at H-burning limit)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('DMPP-3 A', 'B', 'A', 'M dwarf (H-burning boundary)', NULL,
     1.221, 0.076, true, NULL, true,
     'inner SB1 companion at the H-burning limit (RV-only; very late M dwarf)', 'manual', '2020NatAs...4..419B',
     'DMPP-3 B: very late M dwarf right at the H-burning limit; "just massive enough to fuse '
     'hydrogen" per Barnes et al. 2020 abstract (2020NatAs...4..419B). INNER SB1 partner to '
     'the planet host (DMPP-3 A = HD 42936, K0V at d = 48.9 pc). M sin i = 79.9 (76.9-83.6) '
     'MJ = 0.076 Msun, essentially at the canonical H-burning limit. component_mass_is_min = '
     'true since this is the RV-derived M sin i. True semimajor axis a_bin = 1.221 (1.198-1.244) '
     'AU from full Keplerian SB1 orbit (P = 506.84 d ~ 1.39 yr, e = 0.594, K = 2628 m/s). '
     'inner_binary = true. SPECTROSCOPIC ONLY -- no imaging detection -- separation_arcsec = '
     'NULL. The planet DMPP-3 A b is a hot super-Earth (M = 2.58 +/- 0.47 M_earth, P = 6.67 d) '
     'detected via CHEPS/DMPP/CORALIE RVs simultaneously fitted with the SB1 signal. This is '
     'the tightest known stellar binary hosting a planet around only one component.',
     NULL);


-- ============================================================================
-- IRAS 04125+2902 B  (Barber 2024; pre-MS M dwarf wide CPM)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('IRAS 04125+2902', 'B', 'A', 'M5V (pre-main-sequence)', 4.0,
     635, 0.17, false, NULL, false,
     'pre-MS M dwarf wide CPM (3.3 Myr Taurus member; system is misalignment lab)', 'manual', '2024Natur.635..574B',
     'IRAS 04125+2902 B: pre-main-sequence M dwarf wide visual companion (M_B = 0.17 +/- 0.04 '
     'Msun per Barber et al. 2024 Extended Data Table 3, 2024Natur.635..574B). Gaia DR3 ID '
     '164800235906367232 (TIC 56658273). rho = 4.0" (abstract; computed from coordinates 4.01"), '
     'projected separation 635 AU at d = 160 pc (Gaia parallax 6.247 mas). Computed PA = 198.2 '
     'deg (atan2 of Delta-RA = -1.25" west, Delta-Dec = -3.81" south; SSW quadrant). CPM-'
     'confirmed: mu_alpha = 12.56 +/- 0.16 vs primary 12.10 +/- 0.04; mu_delta = -17.19 +/- '
     '0.11 vs primary -18.15 +/- 0.02; parallaxes match within errors. The host is a 3.3 +0.6/'
     '-0.5 Myr pre-MS K7 star in the Taurus Molecular Cloud hosting the youngest known '
     'transiting planet (IRAS 04125+2902 b, P = 8.83 d, R = 10.7 R_earth). Spin-orbit '
     'architecture: host spin, planet transit, AND this wide companion are all consistent with '
     'edge-on; only the outer transitional disk (30 deg inclination) is misaligned -- making '
     'this system a clean lab for studying inner-disk-vs-outer-disk misalignment origins. '
     'Teff_B not given in pasted excerpt.',
     198.2);


-- ============================================================================
-- K2-288 B (planet host) -- row describes the M2V PRIMARY "A"
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('K2-288 B', 'A', 'B', 'M2V', 0.79,
     55, 0.52, false, 3584, false,
     'M2V primary; planet orbits the M3V secondary (Citizen Scientists discovery)', 'manual', '2019AJ....157...40F',
     'K2-288 A: M2V +/- 1 brighter primary of the K2-288 binary system (M_A = 0.52 +/- 0.02 '
     'Msun, R_A = 0.45 +/- 0.03 R_sun, Teff_A = 3584 +/- 205 K, log_g = 4.85 +/- 0.03 per '
     'Feinstein et al. 2019 Table 1, 2019AJ....157...40F). The system is unusual: NASA EA '
     'hostname is "K2-288 B" because the planet K2-288 Bb orbits the FAINTER M3V SECONDARY '
     '(M_B = 0.33 Msun, R_B = 0.32 R_sun, Teff_B = 3341 K). Per atlas convention the row '
     'describes the OTHER component (primary "A") relative to the planet host (B); same '
     'convention as the psi1 Dra B/A row. rho computed as 55 AU / 69.3 pc = 0.79". '
     'Projected separation a_proj ~ 55 AU per the paper abstract. Resolved via Keck HIRES '
     'spectroscopy (blended + partially resolved spectra) and Gaia DR2 photometry. PA not '
     'stated in pasted excerpt. The planet was discovered via the Exoplanet Explorers Citizen '
     'Scientists program on Zooniverse; one of the first transiting planets confirmed via '
     'citizen science.',
     NULL);


-- ============================================================================
-- TOI-4633 B  (Eisner 2024; G-dwarf close binary with 119-year baseline)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-4633', 'B', 'A', 'G5V', 0.062,
     48.6, 1.05, false, 5600, false,
     'G5V close visual binary; e=0.91, P=231 yr (orbitize! fit, 119-year baseline)', 'manual', '2024AJ....167..241E',
     'TOI-4633 B: early G dwarf close visual binary companion (M_B = 1.05 +/- 0.06 Msun, R_B = '
     '0.98 +/- 0.05 R_sun, Teff_B = 5600 +/- 50 K per Eisner et al. 2024 Table 3, '
     '2024AJ....167..241E). The system was first catalogued by Hussey 1905 (= WDS HU 918) with '
     'astrometry spanning 1905-2022 (Eisner 2024 Table 2, 119-year baseline). Most recent '
     'astrometry (2022.7959 Keck II NIRC2 AO): rho = 0.062 +/- 0.01", PA = 303.18 +/- 1.29 deg '
     '(180-deg ambiguity noted). Older WDS micrometer measurements show PA ~ 120-128 deg, rho '
     '~ 0.3-0.5", consistent with substantial orbital motion. Full Keplerian orbital solution '
     'via orbitize! (Table 3): TRUE semimajor axis a_bin = 48.6 +4.4/-3.5 AU (NOT projected at '
     'current epoch), e = 0.91 +/- 0.03, i = 90.1 +/- 0.4 deg (edge-on), P = 231 +32/-24 years, '
     'periastron = 4.5 +2.1/-1.5 AU. Dynamically interesting: the close-approach periastron '
     'is just inside the transiting planet orbit (a_p = 0.847 AU) by ~5x, making this a natural '
     'lab for planet stability under stellar perturbation. The planet TOI-4633 c is a long-'
     'period (P = 271.9 d) mini-Neptune in the optimistic habitable zone. d = 95.20 +/- 0.24 pc.',
     303.18);


-- ============================================================================
-- TOI-2267 B  -- MIRROR ROW for the dual-host system
-- ============================================================================
-- NASA EA lists BOTH TOI-2267 A and TOI-2267 B as planet hosts because the
-- Zuniga-Fernandez 2025 paper cannot determine which of A or B hosts the
-- transiting planets b, c, and candidate d (Table H.1 fits both scenarios).
-- Migration 113 added the binary row for hostname='TOI-2267 A' /
-- component='B'. This mirror row is for hostname='TOI-2267 B' /
-- component='A' so both planet-host hostnames have a binary_companions row
-- describing the same compact pair.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-2267 B', 'A', 'B', 'M5V', 0.384,
     8, 0.1710, false, 3030, false,
     'M5V primary; companion to the M6V planet host (compact M5+M6 pair with orbital motion)', 'manual', '2025A&A...702A..85Z',
     'TOI-2267 A: M5V primary of the M5V + M6V compact binary system. MIRROR ROW for the row '
     'in binary_companions where hostname=''TOI-2267 A'' / component=''B'' (added in migration '
     '113). NASA EA lists both A and B as planet hosts (Zuniga-Fernandez et al. 2025, '
     '2025A&A...702A..85Z, cannot determine which star hosts the transiting planets b, c, '
     'and candidate .02 / d). M_A = 0.1710 +/- 0.0079 Msun, R_A = 0.2075 +/- 0.0225 R_sun, '
     'Teff_A = 3030 +/- 100 K, P_rot = 0.6958 d per Table 2. SAI-2.5m speckle astrometry '
     'across three epochs resolves orbital motion (Table 4): 2020-10-25 rho = 408 +/- 5 mas, '
     'PA = 283.8 +/- 0.4 deg; 2021-10-22 rho = 393 +/- 2 mas, PA = 283.4 +/- 0.5 deg; '
     '2024-08-09 rho = 324 +/- 3 mas, PA = 282.3 +/- 0.5 deg. Paper fiducial values (abstract): '
     'rho = 0.384", projected separation ~8 AU at d = 22.55 +/- 0.19 pc. PA recorded as the '
     'mean of the three epochs (~283 deg). One of the most compact binaries known to host '
     'planets.',
     283.2);


-- ============================================================================
-- ============================================================================
-- SIMBAD CITATION-DEBT DELETE+INSERT CLEANUPS (8 rows)
--
-- Each block deletes the existing citation-less SIMBAD-seed row
-- (source_catalog='SIMBAD' AND source_bibcode IS NULL) and inserts the
-- primary-literature characterized row in its place. Guarded to avoid
-- accidentally clobbering rows that have been since cited.
-- ============================================================================
-- ============================================================================


-- ----- TOI-5293 A B (Canas 2023, mid M dwarf wide CPM) ----------------------
DELETE FROM binary_companions
 WHERE hostname = 'TOI-5293 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-5293 A', 'B', 'A', 'M5V', 3.57,
     579, NULL, false, 3041, false,
     'mid M dwarf wide CPM (El-Badry 2021 + Gaia DR3 MSC)', 'manual', '2023AJ....166...30C',
     'TOI-5293 A B: mid M dwarf wide CPM companion identified via El-Badry et al. 2021 '
     '(2021MNRAS.506.2269E) Gaia EDR3 wide binary catalog, characterized by Canas et al. 2023 '
     '(2023AJ....166...30C). Gaia DR3 ID 2640121482094497024 (TIC 2052711961). rho = 3.57", '
     'projected separation 579 AU at d = 160.8 pc. R_B = 0.26 +0.10/-0.08 R_sun, log_g = 4.72 '
     '+0.16/-0.14, Teff_B = 3041 +280/-41 K (Gaia DR3 MSC analysis of BP/RP spectra; Creevey '
     '2022 / Gaia DR3 stellar parameterization). Implied spectype M5V. Mass not directly '
     'derived; component_mass_msun left NULL. False-detection probability < 4 x 10^-8. '
     'Inferred eccentricity e = 0.77 +0.16/-0.24 (Hwang 2022). Primary TOI-5293 A is M3V (M_A '
     '= 0.54 Msun, Teff_A = 3586 K) hosting a temperate (Teq = 675 K) gas giant. PA not stated '
     'in pasted excerpt. Replaces citationless SIMBAD-seed stub at 3.56".',
     NULL);


-- ----- TOI-5181 A B (Yee 2025, close Gaia + AO/speckle) ---------------------
DELETE FROM binary_companions
 WHERE hostname = 'TOI-5181 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-5181 A', 'B', 'A', NULL, 1.65,
     790, NULL, false, NULL, false,
     'close visual + speckle CPM companion (Gaia DR3 + WIYN/Palomar AO)', 'manual', '2025ApJS..280...30Y',
     'TOI-5181 A B: close visual + speckle CPM companion (Yee et al. 2025 Table 7, '
     '2025ApJS..280...30Y). Gaia DR3 ID 4531901713810551296 (TIC 1813596259). rho = 1.65", '
     'PA = 172.5 deg, projected separation 790 AU at d = 479 pc (parallax 2.090 mas). '
     'G_B = 17.29 vs G_A = 12.21 (Delta-G = 5.08 mag). AO Delta-m = 4.51 (832 nm), 4.40 (I), '
     '3.015 (Brgamma), 3.179 (Hcont) from Palomar PHARO + WIYN NESSI imaging. Parallax 2.43 '
     '+/- 0.12 mas vs primary 2.090 +/- 0.014 (within errors); proper motions consistent. '
     'R_chance = 3.53 x 10^-4 (low). Paper does not derive a companion mass. Replaces '
     'citationless SIMBAD-seed stub at 1.668".',
     172.5);


-- ----- TOI-2193 A B (Yee 2022, M dwarf close Gaia+speckle, full SED fit) ----
DELETE FROM binary_companions
 WHERE hostname = 'TOI-2193 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-2193 A', 'B', 'A', 'M dwarf', 1.885,
     NULL, 0.54, false, 3913, false,
     'close Gaia + speckle CPM companion (SED-fit secondary parameters)', 'manual', '2022AJ....164...70Y',
     'TOI-2193 A B: M dwarf close visual CPM companion (Yee et al. 2022 Table 11 + Table 12 SED '
     'Fit Secondary Properties, 2022AJ....164...70Y). Gaia EDR3 ID 6373308503181838080 '
     '(TIC 1988059412). rho = 1.885", PA = 124 deg, Delta-I = 3.8 mag. M_B = 0.54 +/- 0.01 '
     'Msun, R_B = 0.5126 +0.0080/-0.0079 R_sun, Teff_B = 3913 +/- 19 K. Parallax 2.926 +/- '
     '0.087 mas vs primary 2.938 +/- 0.021 (consistent); proper motions consistent. SED-fit '
     'age 7.2 +/- 1.4 Gyr, consistent with primary (5.5 +1.9/-1.7 Gyr Table 13). At d = 345.3 '
     'pc the projected separation is ~650 AU; separation_au left NULL since not directly '
     'quoted. Replaces citationless SIMBAD-seed stub at 1.869".',
     124);


-- ----- TOI-3331 A B (Yee 2022, K-dwarf close Gaia+speckle, full SED fit) ----
-- NB: separate TOI-3331 A C at 193" stays in the SIMBAD-debt list -- Yee 2022
-- only characterizes the close B at 2.663".
DELETE FROM binary_companions
 WHERE hostname = 'TOI-3331 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3331 A', 'B', 'A', 'K dwarf', 2.663,
     NULL, 0.599, false, 4172, false,
     'close Gaia + speckle CPM companion (SED-fit secondary parameters)', 'manual', '2022AJ....164...70Y',
     'TOI-3331 A B: K dwarf close visual CPM companion (Yee et al. 2022 Table 11 + Table 12 SED '
     'Fit, 2022AJ....164...70Y). Gaia EDR3 ID 4042548120990244096 (TIC 1565174683). rho = '
     '2.663", PA = 48 deg, Delta-I = 2.6 mag. M_B = 0.599 +0.025/-0.022 Msun, R_B = 0.580 '
     '+0.022/-0.020 R_sun, Teff_B = 4172 +260/-94 K. Parallax 5.388 +/- 0.171 mas vs primary '
     '4.577 +/- 0.057 (somewhat discrepant but within ~5sigma); proper motions modestly '
     'different (mu_alpha 10.77 vs 0.42, mu_delta -22.71 vs -16.94) -- companion is bound but '
     'on a closer current orbit, consistent with Yee 2022 treatment. At d = 224.6 pc the '
     'projected separation is ~598 AU; separation_au left NULL since not directly quoted. '
     'Replaces citationless SIMBAD-seed stub at 2.611". NB: SEPARATE wide TOI-3331 A C '
     'companion at 193" stays in the SIMBAD-debt list -- Yee 2022 only characterizes the '
     'close B.',
     48);


-- ----- WASP-193 B (Yee 2026, K7V wide CPM from El-Badry 2021) ---------------
DELETE FROM binary_companions
 WHERE hostname = 'WASP-193'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-193', 'B', 'A', 'K7V', 4.25,
     1600, 0.594, false, 4007, false,
     'K7V wide CPM (El-Badry 2021 + EXOFASTv2 joint fit)', 'manual', '2026AJ....169..225Y',
     'WASP-193 B: K7V wide CPM companion (Yee et al. 2026 Table 2 + Table 3, 2026AJ....169..225Y; '
     'Vizier J/AJ/169/225). Gaia DR3 ID 5453063828179326976 (TIC 49043967). rho = 4.25" '
     '(stated by both this paper and the original Barkaoui 2024 super-puff discovery paper). '
     'Computed PA ~ 279.5 deg (from 2MASS positions; companion is WNW of primary). Projected '
     'separation = 1600 AU at d = 377.6 +2.2/-2.1 pc. M_B = 0.594 +/- 0.026 Msun, R_B = '
     '0.579 +0.025/-0.026 R_sun, Teff_B = 4007 +70/-68 K, log_g = 4.686, L = 0.0780 +/- 0.0046 '
     'L_sun, [Fe/H] = -0.027. Age 6.8 +3.1/-2.4 Gyr (coeval with primary, EXOFASTv2 joint '
     'fit). R_chance = 2.91 x 10^-7 (definitively bound per El-Badry et al. 2021 framework). '
     'Replaces citationless SIMBAD-seed stub at 4.237". NB: A SEPARATE wide WASP-193 C entry '
     'at 194" stays in the SIMBAD-debt list -- Yee 2026 does not characterize that wider '
     'entry.',
     279.5);


-- ----- WASP-2 B (Southworth 2020, M2V close companion) ----------------------
DELETE FROM binary_companions
 WHERE hostname = 'WASP-2'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-2', 'B', 'A', 'M2V', 0.710,
     NULL, 0.40, false, 3523, false,
     'M2V close CPM companion (multi-survey detection; CPM confirmed)', 'manual', '2020A&A...635A..74S',
     'WASP-2 B: M2V close visual companion (M_B = 0.40 +/- 0.02 Msun, Teff_B = 3523 +28/-19 K '
     'per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). rho = 0.710 +/- 0.003", '
     'Delta-K = 2.55 +/- 0.07 mag. Originally detected in the planet confirmation paper '
     '(Collier Cameron et al. 2007); subsequently confirmed by multiple AO/lucky-imaging '
     'surveys (Daemgen 2009, Bergfors 2013, Ngo 2015, Wollert & Brandner 2015). Evans 2016 '
     'confirmed CPM at 5sigma and tentatively identified orbital motion. The planet WASP-2 b '
     '(hot Jupiter) orbits the brighter primary (Teff_A = 5170 K). separation_au left NULL '
     '(distance not in pasted excerpt). PA not stated. Replaces citationless SIMBAD-seed stub '
     'at 0.709".',
     NULL);


-- ----- WASP-8 B (Southworth 2020, M3V wide companion) -----------------------
DELETE FROM binary_companions
 WHERE hostname = 'WASP-8'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-8', 'B', 'A', 'M3V', 4.520,
     NULL, 0.53, false, 3758, false,
     'M3V wide CPM companion (visible in 2MASS; Gaia DR2 CPM-confirmed)', 'manual', '2020A&A...635A..74S',
     'WASP-8 B: M3V wide visual CPM companion (M_B = 0.53 +/- 0.02 Msun, Teff_B = 3758 +47/-43 K '
     'per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). rho = 4.520 +/- 0.005", Delta-K '
     '= 2.29 +/- 0.08 mag. Companion is visible in 2MASS images and was noted in the planet '
     'discovery paper (Queloz et al. 2010); confirmed via AO (Ngo 2015) and lucky-imaging (Evans '
     '2016) studies. Gaia DR2 parallaxes and proper motions consistent with bound. The planet '
     'WASP-8 b (eccentric hot Jupiter, e = 0.31) orbits the brighter primary (Teff_A = 5600 K). '
     'separation_au left NULL (distance not in pasted excerpt). PA not stated. Replaces '
     'citationless SIMBAD-seed stub at 4.495".',
     NULL);


-- ----- WASP-70 B (Southworth 2020, M0V wide companion) ----------------------
DELETE FROM binary_companions
 WHERE hostname = 'WASP-70'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-70', 'B', 'A', 'M0V', 3.160,
     NULL, 0.70, false, 4504, false,
     'M0V wide CPM companion (multi-survey detection; CPM-confirmed in Paper I)', 'manual', '2020A&A...635A..74S',
     'WASP-70 B: M0V wide visual CPM companion (M_B = 0.70 +0.06/-0.07 Msun, Teff_B = 4504 '
     '+263/-213 K per Southworth et al. 2020 Table 1, 2020A&A...635A..74S). rho = 3.160 +/- '
     '0.004", Delta-K = 1.38 +/- 0.18 mag. Originally detected in the Anderson et al. 2014 '
     'planet discovery paper; redetected via Lucky Imaging (Wollert & Brandner 2015, Ginski '
     '2016, Evans 2018) and AO (Ngo 2016). Proper motion consistent with bound (Southworth '
     '2020 Paper I = Bohn 2020). Anderson 2014 accounted for the companions contribution to '
     'the light curves but ignored the uncertainty in that contribution; Southworth 2020 '
     'Section 3.2 redoes the analysis with proper error propagation. The planet WASP-70 b (hot '
     'Jupiter) orbits the brighter primary (Teff_A = 5700 K). separation_au left NULL '
     '(distance not in pasted excerpt). PA not stated. Replaces citationless SIMBAD-seed stub '
     'at 3.140".',
     NULL);


-- ============================================================================
-- ============================================================================
-- sy_snum_audit (1 row)
-- ============================================================================
-- ============================================================================


-- ----- LHS 1678 (BD detection but substellar, so supported_sy_snum = 1) ----
INSERT INTO sy_snum_audit
    (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes,
     curated_at, curator_note)
VALUES
    ('LHS 1678', 2, 1,
     'NASA EA reports sy_snum=2 for LHS 1678 because it counts the BD companion '
     'as stellar. Under the cb_flag-audit convention used elsewhere in this '
     'atlas (brown dwarfs are SUBSTELLAR and do not count toward sy_snum), the '
     'supported value is 1: the system has a single M dwarf star with one '
     'detected substellar (brown-dwarf-or-smaller) companion plus its '
     'transiting planets. Silverstein et al. 2022 (2022AJ....163..151S) '
     'Section 3.5 explicitly says "Detected companions: 1" -- the astrometric '
     'CTIO/SMARTS 0.9m companion that is bracketed by ground-based imaging '
     'and RV constraints as "high-mass brown dwarf or smaller" (M_B <= ~0.075 '
     'Msun, the H-burning limit). HARPS+CHIRON RV monitoring rules out any '
     'equal-mass stellar companion at reasonable periods (paper Table 6); '
     'speckle imaging (paper Table 3) finds no resolved sources at rho > '
     '0.04-0.05" with Delta-m < 4 mag. The companion is detected '
     'astrometrically but not stellar in mass. See the companion '
     'binary_companions row at the top of this migration for the substellar '
     'detection details.',
     ARRAY['2022AJ....163..151S'],
     DATE '2026-06-24',
     'Convention: BD detections go in binary_companions but do not increment supported_sy_snum.');
