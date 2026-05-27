-- Mugrauer 2019 Gaia DR2 bulk enrichment, ~85 hosts (manual literature review,
-- 2026-05-26). Eighth migration of the S-type stellar-multiplicity audit
-- campaign. THE big one: this single paper (Mugrauer 2019 MNRAS 490, 5088)
-- covers a large fraction of our 174-host audit, plus many additional hosts
-- already counted correctly in sy_snum that we never had binary_companions
-- rows for. After this migration most of the WASP / HAT-P / HD / Kepler /
-- HATS / KELT exoplanet-host families will be properly rendered as multi-star.
--
-- Bibcode:
--   2019MNRAS.490.5088M -- Mugrauer 2019, "Search for stellar companions of
--     exoplanet host stars by exploring the second ESA-Gaia data release"
--     (Tables 2 + 3 + 4 covered here; Table 5 lists ruled-out candidates and
--     contributes no rows; Appendices A + B are statistics + methodology with
--     no new companion data).
--
-- All rows below are STATUS-CONFIRMED comoving companions: Gaia DR2
-- equidistance (sig-Delta-pi <= 3 with the host's astrometric excess noise)
-- AND common proper motion (cpm-index >= 3). Table 5's ruled-out candidates
-- are NOT included. Masses + Teff are derived from the absolute G-band
-- magnitude assuming main-sequence isochrones (BHAC15 / Baraffe; flags in
-- Table 4 indicate the photometric validation: PRI = primary Gaia detection,
-- 2MA = 2MASS counterpart, BPRP = Gaia BP/RP photometry, WD = white-dwarf
-- locus, SB = spectroscopic binary, EB = eclipsing binary).
--
-- Already-done hosts (covered in earlier migrations) are SKIPPED here:
--   069: V1298 Tau (HD 284154 system)
--   070: WASP-12, HAT-P-8 (Bechter 2014 BC pairs)
--   071: LTT 1445 A (Winters 2019)
--   072: HD 110067 (Apps & Luque 2023)
--   073: Kepler-444 (Dupuy 2016)
--   074: 51 Eri (Montet 2015 GJ 3305 AB)
--   075: WASP-76, HAT-P-57, WASP-2 (Bohn 2020)
--   076: HD 142, WASP-1, WASP-45, HAT-P-16, HD 4113 (Mugrauer 2019 first 5)
--
-- Naming caveats baked in:
--   - HD 99492, Kepler-99, Kepler-477, Kepler-970, Kepler-1086, Kepler-1150,
--     EPIC 220621087, WASP-160, K2-27, WASP-64, ups And, ψ1 Dra, HD 178911,
--     30 Ari -- Mugrauer labels the planet host as "B" or "C" historically;
--     the audit uses the planet host as primary 'A' regardless of sky-name
--     convention. component_designation = 'B' here means "the companion of
--     the planet host" not "the literature B star," with the curator_note
--     documenting any flip.
--   - "BC" entries (HD 19994, HD 65216, HD 142245, HD 185269, HD 196050,
--     KELT-4) are unresolved tight binary companions; recorded as a single
--     row with component_designation containing 'BC' to mark the unresolved
--     pair. NOT split into 2 rows because Mugrauer reports a single
--     photometric mass without per-component decomposition.
--   - White-dwarf companions (HD 147513 B, HD 8535 B, WASP-98 B, HD 27442 B,
--     HD 118904 B, HD 107148 B, Kepler-779 B, HIP 116454 B) are flagged in
--     binary_class.
--
-- Apply after 011_binary_companions.sql. Idempotent (ON CONFLICT DO UPDATE;
-- a prior row for the same (hostname, component_designation) will be
-- overwritten with Mugrauer 2019's values).

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    -- == HD-host wide-binary M-dwarfs (~K-dwarf in a few cases) ===========
    ('WASP-26', 'B', 'A', 'K5V', 15.386, 3916, 0.742, false, 4625, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019 Tables 3+4: rho=15.386", PA=143.6°, sep=3916 AU, mass=0.742 +0.020/-0.033 Msun, '
     'Teff=4625 +93/-155 K. Flags: PRI 2MA BPRP.'),

    ('GJ 15 A', 'B', 'A', 'M5V', 34.377, 122, 0.189, false, 3235, false,
     'wide M-dwarf visual companion (GJ 15 B)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=34.378", PA=65.45°, sep=122 AU, mass=0.189 +0.020/-0.015 Msun, Teff=3235 K. '
     'GJ 15 system is a nearby M-dwarf binary (host GJ 15 A is the planet host).'),

    ('HATS-30', 'B', 'A', 'M5V', 7.412, 2561, 0.215, false, 3286, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.412", PA=339.24°, sep=2561 AU, mass=0.215 ± 0.005, Teff=3286 K. '
     'Not previously in WDS per Mugrauer 2019.'),

    ('HD 4732', 'B', 'A', 'M2V', 8.774, 481, 0.532, false, 3779, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.774", PA=165.45°, sep=481 AU, mass=0.532 +0.022/-0.027 Msun, Teff=3779 K.'),

    ('EPIC 220194974', 'B', 'A', 'M0V', 9.346, 1167, 0.605, false, 4008, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.346", PA=249.77°, sep=1167 AU, mass=0.605 +0.013/-0.037 Msun, Teff=4008 K. '
     'Originally reported by Hirano et al. 2018.'),

    ('EPIC 220621087', 'B', 'A', 'K2V', 24.974, 1739, 0.734, false, 4586, false,
     'wide K-dwarf visual companion (Mugrauer labels host as B*; recorded here as planet-host A)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=24.974", PA=267.13°, sep=1739 AU, mass=0.734 +0.007/-0.016 Msun, Teff=4586 K. '
     'NAMING NOTE: Mugrauer 2019 lists "EPIC 220621087 B*" as planet host and "EPIC 220621087 A" as '
     'companion. Our schema convention uses primary_designation=A for the planet host regardless.'),

    ('HD 8535', 'B', 'A', NULL, 10.090, 560, 0.129, false, 3041, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.090", PA=246.10°, sep=560 AU, mass=0.129 +0.007/-0.005 Msun, Teff=3041 K. '
     'Flags include WD: photometry consistent with white-dwarf locus.'),

    ('ups And', 'B', 'A', 'M4V', 55.617, 746, 0.171, false, 3195, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=55.617", PA=148.77°, sep=746 AU, mass=0.171 ± 0.001, Teff=3195 K. '
     'ups And system already deep-dived for atmosphere (migrations 015/016).'),

    ('WASP-18', 'B', 'A', NULL, 26.728, 3312, 0.085, false, 2507, false,
     'late M-dwarf / candidate brown dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=26.728", PA=200.52°, sep=3312 AU, mass=0.085 ± 0.001 Msun, Teff=2507 K. '
     'Right at the stellar/sub-stellar boundary. Csizmadia et al. 2019 also confirmed via Gaia DR2.'),

    ('HIP 8541', 'B', 'A', 'K2V', 17.239, 2686, 0.727, false, 4556, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=17.239", PA=77.96°, sep=2686 AU, mass=0.727 ± 0.028, Teff=4556 K. '
     'Not previously in WDS.'),

    ('HD 11964', 'B', 'A', 'K5V', 29.678, 996, 0.691, false, 4388, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=29.678", PA=134.04°, sep=996 AU, mass=0.691 +0.034/-0.048, Teff=4388 K.'),

    ('WASP-33', 'C', 'A', 'G5V', 48.972, 5992, 0.846, false, 5093, false,
     'wide G-dwarf visual companion (third star; obliquity work in migration 052)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=48.972", PA=171.41°, sep=5992 AU, mass=0.846 +0.008/-0.021 Msun, Teff=5093 K. '
     'WASP-33 deep-dived for obliquity in migration 052; this row adds the wide third-star companion.'),

    ('WASP-77 A', 'B', 'A', 'K4V', 3.276, 345, 0.742, false, 4625, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.276", PA=153.81°, sep=345 AU, mass=0.742 +0.003/-0.011, Teff=4625 K. '
     'WASP-77 A b atmosphere deep-dived in migration 064.'),

    ('75 Cet', 'B', 'A', 'K7V', 11.524, 958, 0.620, false, 4074, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=11.524", PA=115.46°, sep=958 AU, mass=0.620 +0.013/-0.012, Teff=4074 K. '
     'Not previously in WDS.'),

    ('HD 16141', 'B', 'A', 'M2V', 6.274, 237, 0.367, false, 3486, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.274", PA=185.78°, sep=237 AU, mass=0.367 +0.050/-0.066, Teff=3486 K.'),

    ('30 Ari B', 'C', 'B', 'F5V', 37.937, 1696, 1.297, false, 6439, false,
     'wide F-dwarf SB visual companion (30 Ari A spec-binary; planet host is 30 Ari B)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=37.937", PA=94.66°, sep=1696 AU, mass=1.297 +0.039/-0.041 Msun, Teff=6439 K. '
     'NAMING: planet host is 30 Ari B (Mugrauer labels as 30 Ari B*C; the C indicates a known close '
     'companion to B). 30 Ari A is itself an SB (recorded here as the wide companion to the planet host).'),

    ('HD 16417', 'B', 'A', NULL, 45.007, 1144, 0.108, false, 2900, false,
     'late M-dwarf / brown dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=45.007", PA=78.63°, sep=1144 AU, mass=0.108 +0.005/-0.006 Msun, Teff=2900 K. '
     'Near the stellar/sub-stellar boundary.'),

    ('HAT-P-10', 'C', 'A', 'M4V', 16.406, 2053, 0.245, false, 3331, false,
     'wide M-dwarf visual companion (third star; B is closer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=16.406", PA=341.34°, sep=2053 AU, mass=0.245 +0.008/-0.012, Teff=3331 K. '
     'Not in WDS. HAT-P-10 = WASP-11.'),

    ('HD 19994', 'BC', 'A', 'K3V', 2.233, 50, 0.721, false, 4529, false,
     'tight binary BC pair, wide companion to HD 19994 A (unresolved by Mugrauer 2019)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.233", PA=197.31°, sep=50 AU, mass=0.721 +0.052/-0.033 Msun (combined), '
     'Teff=4529 K. Recorded as single "BC" component since Mugrauer does not resolve B and C.'),

    ('WASP-139', 'B', 'A', 'M5V', 30.379, 6495, 0.165, false, 3178, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=30.379", PA=316.48°, sep=6495 AU, mass=0.165 +0.003/-0.011, Teff=3178 K. '
     'Not in WDS.'),

    ('HD 20782', 'B', 'A', 'G3V', 252.987, 9114, 0.907, false, 5353, false,
     'wide G-dwarf visual companion (planet host pair: HD 20781 + HD 20782 both have planets)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=252.987", PA=358.11°, sep=9114 AU, mass=0.907 ± 0.019 Msun, Teff=5353 K. '
     'HD 20781 (Mugrauer also lists as HD 20782 B per their labeling) is itself a planet host.'),

    ('HD 23596', 'B', 'A', 'K4V', 70.720, 3683, 0.776, false, 4782, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=70.720", PA=62.86°, sep=3683 AU, mass=0.776 +0.044/-0.030, Teff=4782 K.'),

    ('WASP-98', 'B', 'A', NULL, 12.234, 3475, 0.127, false, 3025, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=12.234", PA=225.09°, sep=3475 AU, mass=0.127 ± 0.004 Msun, Teff=3025 K. WD flag.'),

    ('HD 25171', 'B', 'A', 'M5V', 65.035, 3623, 0.158, false, 3156, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=65.035", PA=275.55°, sep=3623 AU, mass=0.158 +0.003/-0.025 Msun, Teff=3156 K. '
     'Not in WDS.'),

    ('WASP-140', 'B', 'A', 'K7V', 7.235, 854, 0.651, false, 4213, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.235", PA=77.34°, sep=854 AU, mass=0.651 +0.010/-0.032 Msun, Teff=4213 K. '
     'Hellier et al. 2017 reported as candidate; Mugrauer 2019 confirms.'),

    ('EPIC 211089792', 'B', 'A', 'K4V', 4.308, 773, 0.700, false, 4429, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.308", PA=33.99°, sep=773 AU, mass=0.700 +0.054/-0.051, Teff=4429 K.'),

    ('HD 26965', 'C', 'A', 'M5V', 78.101, 393, 0.256, false, 3349, false,
     'wide M-dwarf visual companion (third star)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=78.101", PA=97.49°, sep=393 AU, mass=0.256 +0.005/-0.031 Msun, Teff=3349 K.'),

    ('HD 27442', 'B', 'A', NULL, 13.040, 238, 0.230, false, 3309, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=13.040", PA=36.70°, sep=238 AU, mass=0.230 ± 0.003 Msun, Teff=3309 K. WD flag.'),

    ('HD 28254', 'B', 'A', 'M2V', 4.876, 270, 0.507, false, 3703, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.876", PA=259.40°, sep=270 AU, mass=0.507 ± 0.002, Teff=3703 K.'),

    ('WASP-100', 'B', 'A', 'M3V', 3.964, 1460, 0.428, false, 3566, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.964", PA=186.47°, sep=1460 AU, mass=0.428 ± 0.007, Teff=3566 K.'),

    ('Aldebaran', 'B', 'A', 'M3V', 31.320, 640, 0.360, false, 3479, false,
     'wide M-dwarf visual companion to alpha Tau (Aldebaran)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=31.320", PA=113.12°, sep=640 AU, mass=0.360 +0.025/-0.043 Msun, Teff=3479 K. '
     'Aldebaran b (the planet) was retracted in 2019 but the host-companion relation stands.'),

    ('HD 33283', 'B', 'A', 'M5V', 55.725, 5021, 0.153, false, 3141, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=55.725", PA=194.46°, sep=5021 AU, mass=0.153 ± 0.002 Msun, Teff=3141 K.'),

    ('EPIC 246851721', 'B', 'A', 'M2V', 5.899, 2214, 0.488, false, 3663, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.899", PA=223.50°, sep=2214 AU, mass=0.488 +0.024/-0.026 Msun, Teff=3663 K. '
     'Originally Yu et al. 2018.'),

    ('WASP-160 B', 'A', 'A', 'G8V', 28.479, 8280, 0.943, false, 5500, false,
     'wide G-dwarf visual companion (planet host is WASP-160 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=28.479", PA=50.03°, sep=8280 AU, mass=0.943 +0.015/-0.019 Msun, Teff=5500 K. '
     'NAMING: planet host is WASP-160 B per the literature; WASP-160 A is the wide companion. '
     'Lendl et al. 2019 already established via Gaia DR2.'),

    ('HD 40979', 'B', 'A', 'G5V', 192.547, 6570, 0.831, false, 5030, false,
     'wide G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=192.547", PA=289.25°, sep=6570 AU, mass=0.831 +0.027/-0.020 Msun, Teff=5030 K.'),

    ('HD 40979', 'C', 'A', 'M4V', 191.379, 6530, 0.323, false, 3440, false,
     'third star M-dwarf, paired with B', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=191.379", PA=290.33°, sep=6530 AU, mass=0.323 +0.007/-0.022 Msun, Teff=3440 K. '
     'Companion to HD 40979 B (the B+C pair forms a tight binary at ~6500 AU from A).'),

    ('WASP-49', 'B', 'A', 'M3V', 2.264, 443, 0.337, false, 3454, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.264", PA=177.53°, sep=443 AU, mass=0.337 +0.009/-0.024 Msun, Teff=3454 K.'),

    ('KELT-2 A', 'B', 'A', 'K3V', 2.379, 320, 0.804, false, 4912, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.379", PA=332.14°, sep=320 AU, mass=0.804 +0.009/-0.008 Msun, Teff=4912 K.'),

    ('WASP-168', 'B', 'A', 'M5V', 3.967, 1216, 0.153, false, 3142, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.967", PA=201.66°, sep=1216 AU, mass=0.153 +0.006/-0.005 Msun, Teff=3142 K.'),

    ('HD 46375', 'B', 'A', 'M2V', 10.439, 309, 0.572, false, 3901, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.439", PA=309.41°, sep=309 AU, mass=0.572 +0.040/-0.042 Msun, Teff=3901 K.'),

    ('WASP-64', 'B', 'A', 'F7V', 24.226, 9058, 1.371, false, 6614, false,
     'wide F-dwarf visual companion (planet host is WASP-64 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=24.226", PA=88.34°, sep=9058 AU, mass=1.371 +0.073/-0.058 Msun, Teff=6614 K. '
     'NAMING: planet host WASP-64 = WASP-64 B; companion is WASP-64 A. Not in WDS.'),

    ('HAT-P-24', 'B', 'A', 'M3V', 4.943, 2077, 0.392, false, 3513, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.943", PA=170.83°, sep=2077 AU, mass=0.392 ± 0.011, Teff=3513 K.'),

    ('XO-2 N', 'B', 'A', 'G7V', 31.207, 4745, 0.983, false, 5663, false,
     'wide G-dwarf visual companion (XO-2 S is itself a planet host)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=31.207", PA=341.91°, sep=4745 AU, mass=0.983 +0.018/-0.044 Msun, Teff=5663 K. '
     'Both XO-2 N and XO-2 S host planets; recorded here from the N-host perspective.'),

    ('KELT-15', 'B', 'A', 'M3V', 6.085, 1994, 0.444, false, 3591, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.085", PA=283.14°, sep=1994 AU, mass=0.444 +0.014/-0.045 Msun, Teff=3591 K.'),

    ('HD 65216', 'BC', 'A', NULL, 7.240, 255, 0.089, false, 2606, false,
     'tight BC pair, wide companion to HD 65216 A (unresolved by Mugrauer 2019)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.240", PA=90.16°, sep=255 AU, mass=0.089 ± 0.001 Msun, Teff=2606 K (combined). '
     'BC unresolved; mass implies the combined system is very low-mass (~M5V each if equal).'),

    ('HAT-P-35', 'C', 'A', 'M2V', 9.018, 4637, 0.515, false, 3728, false,
     'wide M-dwarf visual companion (third star; B is closer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.018", PA=213.95°, sep=4637 AU, mass=0.515 +0.019/-0.016, Teff=3728 K. '
     'HAT-P-35 sy_snum=3 missing 2; this row closes 1 of 2.'),

    ('HAT-P-30', 'B', 'A', 'M2V', 3.834, 826, 0.571, false, 3895, false,
     'wide M-dwarf visual companion (KELT-26 is same system)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.834", PA=4.15°, sep=826 AU, mass=0.571 +0.017/-0.024, Teff=3895 K. '
     'HAT-P-30 = KELT-26.'),

    ('bet Cnc', 'B', 'A', 'K7V', 29.472, 2668, 0.620, false, 4073, false,
     'wide K-dwarf visual companion to beta Cnc', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=29.472", PA=294.60°, sep=2668 AU, mass=0.620 +0.038/-0.042 Msun, Teff=4073 K.'),

    ('EPIC 212006344', 'B', 'A', 'M3V', 20.076, 1449, 0.335, false, 3452, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=20.076", PA=345.28°, sep=1449 AU, mass=0.335 +0.045/-0.035 Msun, Teff=3452 K. '
     'Not in WDS.'),

    ('omi UMa', 'B', 'A', 'M2V', 6.787, 411, 0.540, false, 3802, false,
     'wide M-dwarf visual companion to omicron UMa', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.787", PA=196.72°, sep=411 AU, mass=0.540 ± 0.006, Teff=3802 K.'),

    ('Pr 0211', 'B', 'A', 'G6V', 38.519, 7075, 0.839, false, 5063, false,
     'wide G-dwarf visual companion (open-cluster planet host)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=38.519", PA=150.01°, sep=7075 AU, mass=0.839 +0.028/-0.016 Msun, Teff=5063 K. '
     'Catalog hostname is "Pr0211"; not in WDS.'),

    ('WASP-36', 'B', 'A', 'M3V', 4.871, 1903, 0.400, false, 3521, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.871", PA=66.90°, sep=1903 AU, mass=0.400 +0.008/-0.014, Teff=3521 K.'),

    ('HD 75289', 'B', 'A', NULL, 21.641, 631, 0.136, false, 3071, false,
     'late M-dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=21.641", PA=76.67°, sep=631 AU, mass=0.136 +0.006/-0.004 Msun, Teff=3071 K.'),

    ('55 Cnc', 'B', 'A', 'M4V', 84.821, 1068, 0.272, false, 3374, false,
     'wide M-dwarf visual companion (rho1 Cnc B)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=84.821", PA=128.07°, sep=1068 AU, mass=0.272 +0.027/-0.023, Teff=3374 K. '
     '55 Cnc multi-planet system deep-dived for atmosphere in migration 016.'),

    ('HD 79498', 'B', 'A', 'K5V', 59.960, 2939, 0.680, false, 4339, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=59.960", PA=170.76°, sep=2939 AU, mass=0.680 +0.030/-0.055, Teff=4339 K.'),

    ('HD 80606', 'B', 'A', 'G0V', 20.516, 1366, 1.002, false, 5736, false,
     'wide G-dwarf visual companion (HD 80607); Kozai-Lidov driver for HD 80606 b eccentricity', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=20.516", PA=88.57°, sep=1366 AU, mass=1.002 +0.019/-0.029 Msun, Teff=5736 K. '
     'HD 80606 b flash-heating deep-dived in migration 056; B = HD 80607 is the Kozai driver.'),

    ('KELT-3', 'B', 'A', 'K2V', 3.746, 792, 0.754, false, 4682, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.746", PA=41.91°, sep=792 AU, mass=0.754 +0.023/-0.028 Msun, Teff=4682 K.'),

    ('HD 89744', 'B', 'A', NULL, 63.081, 2440, 0.078, false, 2222, false,
     'late M-dwarf or brown dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=63.081", PA=50.45°, sep=2440 AU, mass=0.078 ± 0.000 Msun, Teff=2222 K. '
     'Below or near the hydrogen-burning limit.'),

    ('HAT-P-22', 'B', 'A', 'M2V', 9.162, 751, 0.597, false, 3975, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.162", PA=23.47°, sep=751 AU, mass=0.597 +0.022/-0.015 Msun, Teff=3975 K. '
     'Originally Bakos et al. 2011.'),

    ('KELT-4 A', 'BC', 'A', 'G2V', 1.558, 342, 0.973, false, 5623, false,
     'tight BC pair, close companion to KELT-4 A (unresolved by Mugrauer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.558", PA=29.53°, sep=342 AU, mass=0.973 +0.068/-0.038 Msun, Teff=5623 K. '
     'Recorded as single BC entry since Mugrauer does not resolve B from C.'),

    ('EPIC 248435473', 'B', 'A', 'K5V', 42.661, 3316, 0.646, false, 4188, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=42.661", PA=255.96°, sep=3316 AU, mass=0.646 +0.030/-0.052 Msun, Teff=4188 K.'),

    ('WASP-127', 'B', 'A', 'G3V', 40.481, 6486, 0.950, false, 5530, false,
     'wide G-dwarf visual companion (TYC 4916-897-1)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=40.481", PA=260.34°, sep=6486 AU, mass=0.950 +0.007/-0.008 Msun, Teff=5530 K. '
     'WASP-127 b atmosphere deep-dived in migration 066. Lam et al. 2017 noticed as candidate.'),

    ('WASP-104', 'B', 'A', 'M5V', 6.842, 1279, 0.189, false, 3237, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.842", PA=176.59°, sep=1279 AU, mass=0.189 +0.008/-0.007, Teff=3237 K. '
     'Not in WDS.'),

    ('HD 93385', 'B', 'A', 'M3V', 10.395, 451, 0.463, false, 3622, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.395", PA=289.06°, sep=451 AU, mass=0.463 ± 0.022, Teff=3622 K.'),

    ('HD 96167', 'B', 'A', 'M4V', 5.887, 503, 0.200, false, 3262, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.887", PA=297.07°, sep=503 AU, mass=0.200 ± 0.001 Msun, Teff=3262 K.'),

    ('EPIC 201637175', 'B', 'A', 'M4V', 1.918, 471, 0.292, false, 3403, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.918", PA=226.49°, sep=471 AU, mass=0.292 +0.019/-0.039, Teff=3403 K. '
     'Originally Sanchis-Ojeda et al. 2015.'),

    ('HD 98736', 'B', 'A', 'K5V', 5.077, 165, 0.646, false, 4190, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.077", PA=314.09°, sep=165 AU, mass=0.646 ± 0.022, Teff=4190 K.'),

    ('K2-27', 'B', 'A', 'G2V', 32.402, 8147, 1.080, false, 5906, false,
     'wide G-dwarf visual companion (planet host is K2-27 B per Mugrauer; A is the companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=32.402", PA=275.99°, sep=8147 AU, mass=1.080 +0.023/-0.041 Msun, Teff=5906 K. '
     'NAMING: Mugrauer labels planet host as K2-27 B*; K2-27 A is the wide companion. K2-27 also has '
     'a closer C component (recorded as next row).'),

    ('K2-27', 'C', 'A', 'M4V', 2.973, 748, 0.230, false, 3308, false,
     'close M-dwarf companion (third star alongside the wide A companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.973", PA=177.69°, sep=748 AU, mass=0.230 +0.009/-0.012 Msun, Teff=3308 K. '
     'Together K2-27 A + C make this a hierarchical triple.'),

    ('HD 99492', 'B', 'A', 'G8V', 28.178, 513, 0.969, false, 5605, false,
     'wide G-dwarf visual companion (planet host is HD 99492 B per Mugrauer; A is the companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=28.178", PA=329.51°, sep=513 AU, mass=0.969 +0.014/-0.024 Msun, Teff=5605 K. '
     'NAMING: Mugrauer labels planet host as HD 99492 B*; HD 99492 A is the wide companion.'),

    ('HD 100655', 'B', 'A', 'K5V', 49.315, 6791, 0.669, false, 4293, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=49.315", PA=81.12°, sep=6791 AU, mass=0.669 +0.022/-0.036 Msun, Teff=4293 K. '
     'Not in WDS.'),

    ('EPIC 201828749', 'B', 'A', 'K5V', 2.450, 523, 0.689, false, 4382, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.450", PA=57.41°, sep=523 AU, mass=0.689 +0.006/-0.007 Msun, Teff=4382 K.'),

    ('HD 101930', 'B', 'A', 'K3V', 73.014, 2194, 0.726, false, 4551, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=73.014", PA=8.33°, sep=2194 AU, mass=0.726 +0.037/-0.029, Teff=4551 K.'),

    ('WASP-129', 'B', 'A', 'M5V', 4.340, 1320, 0.156, false, 3150, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.340", PA=215.11°, sep=1320 AU, mass=0.156 +0.005/-0.007 Msun, Teff=3150 K. '
     'Not in WDS.'),

    ('HD 102365', 'B', 'A', 'M5V', 22.722, 211, 0.192, false, 3243, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=22.722", PA=54.04°, sep=211 AU, mass=0.192 +0.022/-0.011 Msun, Teff=3243 K.'),

    ('HD 102956', 'B', 'A', 'M3V', 31.890, 3901, 0.411, false, 3539, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=31.890", PA=62.03°, sep=3901 AU, mass=0.411 ± 0.003, Teff=3539 K.'),

    ('HD 103774', 'B', 'A', 'M3V', 6.204, 351, 0.384, false, 3504, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.204", PA=27.87°, sep=351 AU, mass=0.384 +0.042/-0.052 Msun, Teff=3504 K. '
     'Not in WDS.'),

    ('WASP-56', 'B', 'A', 'M4V', 3.420, 1108, 0.223, false, 3298, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.420", PA=113.09°, sep=1108 AU, mass=0.223 +0.013/-0.014 Msun, Teff=3298 K.'),

    ('HD 106515', 'B', 'A', 'G7V', 6.851, 234, 0.925, false, 5425, false,
     'wide G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.851", PA=265.92°, sep=234 AU, mass=0.925 +0.009/-0.011 Msun, Teff=5425 K.'),

    ('HD 107148', 'B', 'A', NULL, 34.982, 1731, 0.102, false, 2835, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=34.982", PA=174.63°, sep=1731 AU, mass=0.102 ± 0.003 Msun, Teff=2835 K. WD.'),

    ('11 Com', 'B', 'A', 'K5V', 9.586, 895, 0.687, false, 4374, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.586", PA=43.71°, sep=895 AU, mass=0.687 +0.012/-0.031 Msun, Teff=4374 K.'),

    ('WASP-87 A', 'B', 'A', 'G5V', 8.088, 2434, 0.906, false, 5349, false,
     'wide G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.088", PA=141.32°, sep=2434 AU, mass=0.906 +0.008/-0.015 Msun, Teff=5349 K. '
     'Anderson et al. 2014 reported as candidate; not in WDS.'),

    ('HD 108341', 'B', 'A', 'M3V', 7.814, 383, 0.431, false, 3570, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.814", PA=7.36°, sep=383 AU, mass=0.431 +0.004/-0.013 Msun, Teff=3570 K.'),

    ('HD 109749', 'B', 'A', 'G8V', 8.374, 529, 0.814, false, 4954, false,
     'wide G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.374", PA=180.72°, sep=529 AU, mass=0.814 +0.009/-0.021 Msun, Teff=4954 K.'),

    ('WASP-108', 'B', 'A', 'M5V', 8.797, 2293, 0.157, false, 3152, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.797", PA=41.32°, sep=2293 AU, mass=0.157 +0.007/-0.005 Msun, Teff=3152 K. '
     'Not in WDS.'),

    ('HD 113996', 'B', 'A', 'M4V', 44.066, 5127, 0.229, false, 3307, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=44.066", PA=262.60°, sep=5127 AU, mass=0.229 +0.038/-0.058 Msun, Teff=3307 K. '
     'Not in WDS.'),

    ('HD 114729', 'B', 'A', 'M3V', 8.195, 310, 0.376, false, 3496, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.195", PA=332.97°, sep=310 AU, mass=0.376 +0.041/-0.039 Msun, Teff=3496 K.'),

    ('WASP-55', 'B', 'A', 'M3V', 4.360, 1308, 0.343, false, 3461, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.360", PA=163.97°, sep=1308 AU, mass=0.343 ± 0.011 Msun, Teff=3461 K.'),

    ('HD 118904', 'B', 'A', NULL, 32.123, 3948, 0.173, false, 3200, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=32.123", PA=224.13°, sep=3948 AU, mass=0.173 +0.013/-0.051 Msun, Teff=3200 K. WD.'),

    ('HAT-P-3', 'B', 'A', 'M4V', 9.800, 1324, 0.230, false, 3309, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.800", PA=117.10°, sep=1324 AU, mass=0.230 +0.007/-0.022 Msun, Teff=3309 K. '
     'Not in WDS.'),

    ('HD 125612', 'B', 'A', 'M5V', 89.986, 5194, 0.207, false, 3273, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=89.986", PA=162.64°, sep=5194 AU, mass=0.207 +0.006/-0.027 Msun, Teff=3273 K.'),

    ('KELT-18', 'B', 'A', 'K7V', 3.420, 1110, 0.617, false, 4061, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.420", PA=68.21°, sep=1110 AU, mass=0.617 ± 0.006 Msun, Teff=4061 K. '
     'Originally McLeod et al. 2017 (AO); Mugrauer confirms.'),

    ('HD 126614', 'B', 'A', 'M4V', 41.852, 3066, 0.306, false, 3422, false,
     'wide M-dwarf visual companion (third star; A is closer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=41.852", PA=299.38°, sep=3066 AU, mass=0.306 +0.016/-0.022 Msun, Teff=3422 K. '
     'HD 126614 sy_snum=3 missing 1; this closes it. NAMING: Mugrauer labels host as A*C (C = inner '
     'close companion to A); B here is the wide outer.'),

    ('WASP-14', 'C', 'A', 'M4V', 11.540, 1878, 0.231, false, 3309, false,
     'wide M-dwarf visual companion (third star)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=11.540", PA=4.78°, sep=1878 AU, mass=0.231 +0.011/-0.020 Msun, Teff=3309 K. '
     'Not in WDS.'),

    ('Qatar 6', 'B', 'A', 'M4V', 4.803, 486, 0.244, false, 3330, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.803", PA=173.56°, sep=486 AU, mass=0.244 +0.013/-0.010 Msun, Teff=3330 K. '
     'Not in WDS.'),

    ('HD 132563 B', 'A', 'B', 'F8V', 4.087, 430, 1.153, false, 6098, false,
     'wide F-dwarf SB visual companion (planet host is HD 132563 B; A is the SB)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.087", PA=96.85°, sep=430 AU, mass=1.153 +0.012/-0.017 Msun, Teff=6098 K. '
     'NAMING: planet host is HD 132563 B; HD 132563 A is itself an SB. Recorded with primary_designation=B '
     'and component_designation=A to reflect that the SB is the companion to the planet-host B star.'),

    ('HD 133131 A', 'B', 'A', 'G7V', 7.369, 379, 0.987, false, 5679, false,
     'wide G-dwarf visual companion (both A and B host planets)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.369", PA=221.11°, sep=379 AU, mass=0.987 ± 0.002 Msun, Teff=5679 K. '
     'HD 133131 is a planet-host pair: A and B both host planets.'),

    ('WASP-24', 'B', 'A', 'M2V', 21.834, 7097, 0.491, false, 3668, false,
     'wide M-dwarf EB visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=21.834", PA=258.17°, sep=7097 AU, mass=0.491 +0.028/-0.015 Msun, Teff=3668 K. '
     'WASP-24 B is itself an eclipsing binary (Street et al. 2010); WASP-24 system is hierarchical triple.'),

    ('NLTT 41135', 'B', 'A', 'M4V', 2.335, 80, 0.250, false, 3339, false,
     'close M-dwarf visual companion (NLTT 41136)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.335", PA=52.47°, sep=80 AU, mass=0.250 +0.002/-0.021 Msun, Teff=3339 K.'),

    ('ome Ser', 'B', 'A', 'G5V', 74.826, 5755, 0.876, false, 5224, false,
     'wide G-dwarf visual companion to omega Serpentis', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=74.826", PA=300.30°, sep=5755 AU, mass=0.876 ± 0.005 Msun, Teff=5224 K.'),

    ('HD 142245', 'BC', 'A', 'K5V', 2.503, 244, 0.621, false, 4078, false,
     'tight BC pair, close companion to HD 142245 A (unresolved by Mugrauer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.503", PA=169.09°, sep=244 AU, mass=0.621 ± 0.004 Msun, Teff=4078 K (combined). '
     'BC unresolved.'),

    ('HD 142022 A', 'B', 'A', 'K5V', 20.019, 687, 0.730, false, 4572, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=20.019", PA=129.15°, sep=687 AU, mass=0.730 +0.052/-0.026 Msun, Teff=4572 K.'),

    ('HD 147379', 'B', 'A', 'M3V', 64.525, 695, 0.540, false, 3801, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=64.525", PA=13.56°, sep=695 AU, mass=0.540 +0.044/-0.034 Msun, Teff=3801 K.'),

    ('K2-31', 'B', 'A', NULL, 8.401, 931, 0.109, false, 2903, false,
     'late M-dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.401", PA=127.99°, sep=931 AU, mass=0.109 +0.003/-0.004 Msun, Teff=2903 K. '
     'Not in WDS.'),

    ('HD 147513', 'B', 'A', NULL, 345.042, 4454, 0.307, false, 3424, false,
     'WD wide companion (HD 147513 B is a known white dwarf at very wide separation)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=345.042", PA=247.60°, sep=4454 AU, mass=0.307 +0.007/-0.017 Msun, Teff=3424 K. '
     'WD flag in Mugrauer Table 4.'),

    ('HD 147873', 'B', 'A', 'M2V', 59.371, 6494, 0.552, false, 3838, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=59.371", PA=334.15°, sep=6494 AU, mass=0.552 +0.020/-0.048 Msun, Teff=3838 K. '
     'Not in WDS.'),

    ('EPIC 205071984', 'B', 'A', 'M5V', 14.810, 2346, 0.203, false, 3267, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=14.810", PA=183.04°, sep=2346 AU, mass=0.203 +0.029/-0.014 Msun, Teff=3267 K. '
     'Not in WDS.'),

    ('HAT-P-67', 'B', 'A', 'M2V', 9.099, 3419, 0.521, false, 3746, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=9.099", PA=336.99°, sep=3419 AU, mass=0.521 ± 0.007 Msun, Teff=3746 K. '
     'Not in WDS.'),

    ('HD 155233', 'B', 'A', 'M3V', 12.317, 916, 0.418, false, 3550, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=12.317", PA=29.18°, sep=916 AU, mass=0.418 ± 0.009 Msun, Teff=3550 K. '
     'Not in WDS.'),

    ('GJ 676 A', 'B', 'A', 'M5V', 47.647, 764, 0.288, false, 3398, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=47.647", PA=101.46°, sep=764 AU, mass=0.288 +0.023/-0.025 Msun, Teff=3398 K.'),

    ('psi1 Dra B', 'A', 'B', 'F5V', 30.081, 684, 1.329, false, 6515, false,
     'wide F-dwarf SB visual companion (planet host is psi1 Dra B; A is the SB)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=30.081", PA=196.50°, sep=684 AU, mass=1.329 +0.016/-0.018 Msun, Teff=6515 K. '
     'NAMING: planet host is psi1 Dra B; psi1 Dra A is itself an SB.'),

    ('HD 164595', 'B', 'A', 'M2V', 88.125, 2492, 0.471, false, 3635, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=88.125", PA=104.57°, sep=2492 AU, mass=0.471 +0.027/-0.054 Msun, Teff=3635 K.'),

    ('42 Dra', 'B', 'A', 'M2V', 24.435, 2220, 0.471, false, 3635, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=24.435", PA=208.41°, sep=2220 AU, mass=0.471 ± 0.019, Teff=3635 K.'),

    ('HD 170469', 'B', 'A', 'M2V', 43.194, 2604, 0.494, false, 3672, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=43.194", PA=112.58°, sep=2604 AU, mass=0.494 +0.023/-0.027 Msun, Teff=3672 K.'),

    ('WASP-3', 'C', 'A', 'K0V', 18.331, 4266, 0.816, false, 4967, false,
     'wide K-dwarf visual companion (third star)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=18.331", PA=245.82°, sep=4266 AU, mass=0.816 +0.031/-0.016 Msun, Teff=4967 K. '
     'WASP-3 sy_snum=3 missing 2; this closes 1 of 2. Not in WDS.'),

    ('Kepler-1341', 'B', 'A', 'M4V', 10.591, 5121, 0.238, false, 3321, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.591", PA=245.96°, sep=5121 AU, mass=0.238 +0.016/-0.036 Msun, Teff=3321 K. '
     'Not in WDS.'),

    ('CoRoT-9', 'B', 'A', 'M3V', 11.968, 5002, 0.388, false, 3509, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=11.968", PA=47.47°, sep=5002 AU, mass=0.388 ± 0.003 Msun, Teff=3509 K.'),

    ('Kepler-83', 'B', 'A', 'M3V', 22.084, 8944, 0.376, false, 3495, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=22.084", PA=303.28°, sep=8944 AU, mass=0.376 +0.009/-0.039 Msun, Teff=3495 K. '
     'Not in WDS.'),

    ('Kepler-410 A', 'B', 'A', 'K2V', 1.664, 247, 0.793, false, 4863, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.664", PA=35.57°, sep=247 AU, mass=0.793 +0.009/-0.011 Msun, Teff=4863 K.'),

    ('Kepler-530', 'B', 'A', 'M4V', 4.145, 1923, 0.262, false, 3357, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.145", PA=178.46°, sep=1923 AU, mass=0.262 +0.006/-0.008 Msun, Teff=3357 K.'),

    ('Kepler-1540', 'B', 'A', 'M4V', 5.542, 1367, 0.262, false, 3358, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.542", PA=35.01°, sep=1367 AU, mass=0.262 ± 0.027 Msun, Teff=3358 K.'),

    ('Kepler-1651', 'B', 'A', 'M4V', 4.051, 270, 0.276, false, 3379, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.051", PA=98.49°, sep=270 AU, mass=0.276 +0.018/-0.013 Msun, Teff=3379 K.'),

    ('HD 176051', 'B', 'A', 'K2V', 1.275, 19, 0.763, false, 4723, false,
     'very close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.275", PA=242.31°, sep=19 AU, mass=0.763 +0.008/-0.010 Msun, Teff=4723 K. '
     'Closest companion in this batch.'),

    ('Kepler-504', 'B', 'A', 'M3V', 4.333, 431, 0.323, false, 3440, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.333", PA=28.02°, sep=431 AU, mass=0.323 +0.018/-0.023 Msun, Teff=3440 K.'),

    ('Kepler-1130', 'B', 'A', 'M3V', 3.511, 882, 0.381, false, 3502, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.511", PA=67.20°, sep=882 AU, mass=0.381 +0.012/-0.016 Msun, Teff=3502 K.'),

    ('Kepler-779', 'B', 'A', NULL, 3.870, 1105, 0.125, false, 3012, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.870", PA=35.05°, sep=1105 AU, mass=0.125 +0.005/-0.010 Msun, Teff=3012 K. WD.'),

    ('TrES-1', 'B', 'A', NULL, 13.161, 2111, 0.097, false, 2761, false,
     'late M-dwarf or brown dwarf wide companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=13.161", PA=275.94°, sep=2111 AU, mass=0.097 ± 0.001 Msun, Teff=2761 K. '
     'Just above the hydrogen-burning limit. Not in WDS.'),

    ('Kepler-514', 'B', 'A', 'M2V', 10.540, 4863, 0.471, false, 3636, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.540", PA=42.19°, sep=4863 AU, mass=0.471 +0.009/-0.020 Msun, Teff=3636 K. '
     'Not in WDS.'),

    ('Kepler-25', 'B', 'A', 'K2V', 8.415, 2061, 0.800, false, 4895, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.415", PA=288.29°, sep=2061 AU, mass=0.800 +0.012/-0.008 Msun, Teff=4895 K.'),

    ('Kepler-13', 'B', 'A', 'F2V', 1.156, 607, 1.426, false, 6744, false,
     'close F-dwarf SB visual companion (KOI-13 = Kepler-13)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.156", PA=279.92°, sep=607 AU, mass=1.426 ± 0.020 Msun, Teff=6744 K. '
     'Kepler-13 B is itself a spectroscopic binary. Catalog hostname is KOI-13.'),

    ('HD 178911 B', 'A', 'B', 'G2V', 15.898, 652, 1.193, false, 6192, false,
     'wide G-dwarf SB visual companion (planet host is HD 178911 B; AC is the wide SB pair)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=15.898", PA=82.98°, sep=652 AU, mass=1.193 +0.015/-0.012 Msun, Teff=6192 K. '
     'NAMING: planet host is HD 178911 B; HD 178911 A is itself an SB.'),

    ('Kepler-454', 'B', 'A', 'M4V', 5.596, 1301, 0.174, false, 3202, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.596", PA=339.52°, sep=1301 AU, mass=0.174 +0.010/-0.008 Msun, Teff=3202 K.'),

    ('Kepler-1027', 'B', 'A', 'M2V', 18.975, 7776, 0.471, false, 3635, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=18.975", PA=91.27°, sep=7776 AU, mass=0.471 +0.032/-0.021 Msun, Teff=3635 K.'),

    ('Kepler-104', 'B', 'A', 'K0V', 16.964, 6877, 0.828, false, 5018, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=16.964", PA=307.91°, sep=6877 AU, mass=0.828 +0.009/-0.012 Msun, Teff=5018 K.'),

    ('Kepler-411', 'B', 'A', 'M3V', 3.452, 533, 0.329, false, 3446, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.452", PA=331.77°, sep=533 AU, mass=0.329 +0.013/-0.015 Msun, Teff=3446 K.'),

    ('Kepler-20', 'B', 'A', 'M5V', 3.790, 1080, 0.202, false, 3265, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.790", PA=52.69°, sep=1080 AU, mass=0.202 +0.005/-0.011 Msun, Teff=3265 K.'),

    ('Kepler-951', 'B', 'A', 'M3V', 15.505, 5997, 0.406, false, 3531, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=15.505", PA=34.49°, sep=5997 AU, mass=0.406 ± 0.004 Msun, Teff=3531 K. '
     'Not in WDS.'),

    ('Kepler-477', 'A', 'B', 'G5V', 1.206, 555, 0.859, false, 5151, false,
     'close G-dwarf visual companion (planet host is Kepler-477 B; A is the close companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.206", PA=212.70°, sep=555 AU, mass=0.859 ± 0.009 Msun, Teff=5151 K. '
     'NAMING: planet host is Kepler-477 B; A is closer companion.'),

    ('Kepler-130', 'B', 'A', 'M3V', 4.184, 1337, 0.343, false, 3461, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.184", PA=209.94°, sep=1337 AU, mass=0.343 +0.019/-0.017 Msun, Teff=3461 K.'),

    ('Kepler-970', 'A', 'B', 'F5V', 22.465, 7520, 1.240, false, 6302, false,
     'wide F-dwarf visual companion (planet host is Kepler-970 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=22.465", PA=303.42°, sep=7520 AU, mass=1.240 +0.019/-0.048 Msun, Teff=6302 K. '
     'NAMING: planet host Kepler-970 = Kepler-970 B; A is the wide companion. Not in WDS.'),

    ('Kepler-515', 'B', 'A', 'G8V', 1.999, 662, 0.835, false, 5044, false,
     'close G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.999", PA=272.94°, sep=662 AU, mass=0.835 +0.024/-0.048 Msun, Teff=5044 K.'),

    ('Kepler-1063', 'B', 'A', 'K0V', 1.112, 491, 0.979, false, 5645, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.112", PA=318.14°, sep=491 AU, mass=0.979 +0.046/-0.044 Msun, Teff=5645 K.'),

    ('Kepler-1319', 'B', 'A', NULL, 1.889, 197, 0.146, false, 3114, false,
     'close late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.889", PA=303.93°, sep=197 AU, mass=0.146 ± 0.002 Msun, Teff=3114 K.'),

    ('Kepler-795', 'B', 'A', 'K7V', 2.922, 1459, 0.614, false, 4047, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.922", PA=15.48°, sep=1459 AU, mass=0.614 +0.013/-0.010 Msun, Teff=4047 K.'),

    ('Kepler-390', 'B', 'A', 'M3V', 20.703, 9125, 0.350, false, 3469, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=20.703", PA=23.79°, sep=9125 AU, mass=0.350 +0.004/-0.008 Msun, Teff=3469 K.'),

    ('CoRoT-2', 'B', 'A', 'K7V', 4.081, 876, 0.548, false, 3828, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.081", PA=208.49°, sep=876 AU, mass=0.548 +0.015/-0.024 Msun, Teff=3828 K.'),

    ('Kepler-1480', 'B', 'A', 'K5V', 5.095, 2589, 0.728, false, 4560, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.095", PA=201.79°, sep=2589 AU, mass=0.728 +0.019/-0.026 Msun, Teff=4560 K.'),

    ('Kepler-333', 'B', 'A', 'M4V', 1.273, 417, 0.249, false, 3337, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.273", PA=258.69°, sep=417 AU, mass=0.249 +0.032/-0.015 Msun, Teff=3337 K.'),

    ('Kepler-167', 'B', 'A', 'M5V', 2.216, 765, 0.214, false, 3284, false,
     'close late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.216", PA=62.56°, sep=765 AU, mass=0.214 +0.010/-0.013 Msun, Teff=3284 K.'),

    ('HATS-65', 'B', 'A', 'M3V', 5.005, 2502, 0.451, false, 3604, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.005", PA=324.69°, sep=2502 AU, mass=0.451 ± 0.025, Teff=3604 K. '
     'Originally Hartman et al. 2019.'),

    ('Kepler-636', 'B', 'A', 'K2V', 1.217, 614, 0.787, false, 4836, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.217", PA=272.70°, sep=614 AU, mass=0.787 +0.031/-0.039 Msun, Teff=4836 K.'),

    ('Kepler-517', 'B', 'A', 'M3V', 6.493, 1898, 0.311, false, 3427, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.493", PA=272.19°, sep=1898 AU, mass=0.311 +0.014/-0.016 Msun, Teff=3427 K.'),

    ('Kepler-78', 'B', 'A', 'M4V', 7.380, 921, 0.289, false, 3399, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.380", PA=270.24°, sep=921 AU, mass=0.289 +0.014/-0.007 Msun, Teff=3399 K. '
     'Not in WDS.'),

    ('HD 185269', 'BC', 'A', 'M3V', 4.504, 235, 0.312, false, 3429, false,
     'tight BC pair, close companion to HD 185269 A (unresolved by Mugrauer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.504", PA=7.98°, sep=235 AU, mass=0.312 ± 0.008 Msun, Teff=3429 K (combined). '
     'BC unresolved.'),

    ('KOI-4427', 'B', 'A', 'M5V', 5.259, 1464, 0.188, false, 3233, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.259", PA=272.10°, sep=1464 AU, mass=0.188 +0.026/-0.024 Msun, Teff=3233 K.'),

    ('Kepler-197', 'B', 'A', 'K5V', 5.621, 1876, 0.725, false, 4548, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.621", PA=201.60°, sep=1876 AU, mass=0.725 +0.018/-0.022 Msun, Teff=4548 K.'),

    ('Kepler-1086', 'A', 'B', 'K2V', 15.830, 7476, 0.793, false, 4863, false,
     'wide K-dwarf visual companion (planet host is Kepler-1086 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=15.830", PA=148.67°, sep=7476 AU, mass=0.793 ± 0.016 Msun, Teff=4863 K. '
     'NAMING: planet host is Kepler-1086 B; A is the wide companion.'),

    ('Kepler-908', 'B', 'A', 'M4V', 8.079, 2370, 0.259, false, 3353, false,
     'wide M-dwarf visual companion (one of two; C is closer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.079", PA=169.91°, sep=2370 AU, mass=0.259 ± 0.015 Msun, Teff=3353 K. '
     'Not in WDS. Kepler-908 sy_snum=3 missing 2; this row + the C row close both.'),

    ('Kepler-908', 'C', 'A', 'M4V', 7.309, 2144, 0.219, false, 3291, false,
     'wide M-dwarf visual companion (one of two; B is also recorded)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.309", PA=172.99°, sep=2144 AU, mass=0.219 +0.015/-0.021 Msun, Teff=3291 K. '
     'Not in WDS.'),

    ('Kepler-743', 'B', 'A', 'M2V', 1.966, 553, 0.480, false, 3649, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.966", PA=225.69°, sep=553 AU, mass=0.480 +0.010/-0.017 Msun, Teff=3649 K.'),

    ('Kepler-136', 'B', 'A', 'M3V', 8.721, 3715, 0.438, false, 3582, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.721", PA=1.70°, sep=3715 AU, mass=0.438 ± 0.008 Msun, Teff=3582 K. '
     'Not in WDS.'),

    ('Kepler-1008', 'B', 'A', 'M3V', 29.545, 8417, 0.415, false, 3545, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=29.545", PA=169.96°, sep=8417 AU, mass=0.415 +0.004/-0.007 Msun, Teff=3545 K. '
     'Not in WDS.'),

    ('Kepler-1150', 'A', 'B', 'G8V', 14.425, 5225, 0.840, false, 5067, false,
     'wide G-dwarf visual companion (planet host is Kepler-1150 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=14.425", PA=17.99°, sep=5225 AU, mass=0.840 +0.002/-0.015 Msun, Teff=5067 K. '
     'NAMING: planet host is Kepler-1150 B. Not in WDS.'),

    ('Kepler-353', 'B', 'A', 'K5V', 12.888, 5012, 0.667, false, 4282, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=12.888", PA=147.43°, sep=5012 AU, mass=0.667 +0.048/-0.052 Msun, Teff=4282 K.'),

    ('Kepler-755', 'B', 'A', 'M2V', 2.061, 832, 0.538, false, 3798, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.061", PA=196.65°, sep=832 AU, mass=0.538 +0.015/-0.032 Msun, Teff=3798 K.'),

    ('HAT-P-41', 'B', 'A', 'K0V', 3.613, 1271, 0.815, false, 4959, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.613", PA=184.05°, sep=1271 AU, mass=0.815 +0.043/-0.048 Msun, Teff=4959 K.'),

    ('Kepler-89', 'B', 'A', 'K5V', 7.330, 3545, 0.716, false, 4505, false,
     'wide K-dwarf visual companion (also known as KOI-94)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=7.330", PA=108.36°, sep=3545 AU, mass=0.716 +0.025/-0.034 Msun, Teff=4505 K.'),

    ('Kepler-99', 'B', 'A', 'G5V', 14.913, 3126, 0.873, false, 5211, false,
     'wide G-dwarf visual companion (planet host is Kepler-99 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=14.913", PA=24.82°, sep=3126 AU, mass=0.873 +0.030/-0.019 Msun, Teff=5211 K. '
     'NAMING: planet host is Kepler-99 B; A is the wide companion. Not in WDS.'),

    ('Kepler-538', 'B', 'A', NULL, 17.213, 2697, 0.124, false, 3009, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=17.213", PA=312.33°, sep=2697 AU, mass=0.124 +0.001/-0.002 Msun, Teff=3009 K. '
     'Not in WDS.'),

    ('HD 188015', 'B', 'A', 'M5V', 13.027, 661, 0.189, false, 3236, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=13.027", PA=79.27°, sep=661 AU, mass=0.189 +0.023/-0.011 Msun, Teff=3236 K.'),

    ('Kepler-519', 'B', 'A', 'M2V', 2.102, 522, 0.494, false, 3673, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=2.102", PA=246.24°, sep=522 AU, mass=0.494 +0.014/-0.013 Msun, Teff=3673 K.'),

    ('HD 189733', 'B', 'A', 'M5V', 11.437, 226, 0.200, false, 3262, false,
     'close M-dwarf visual companion (already characterized; this row updates Mugrauer values)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=11.437", PA=244.35°, sep=226 AU, mass=0.200 +0.008/-0.017 Msun, Teff=3262 K. '
     'HD 189733 b deep-dived for atmosphere in migrations 015/016/062; B was known but Mugrauer 2019 '
     'gives Gaia DR2 precision.'),

    ('Kepler-560', 'A', 'B', 'K2V', 40.452, 4436, 0.506, false, 3700, false,
     'wide K-dwarf visual companion (planet host is Kepler-560 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=40.452", PA=101.02°, sep=4436 AU, mass=0.506 +0.029/-0.032 Msun, Teff=3700 K. '
     'NAMING: planet host is Kepler-560 B.'),

    ('HD 190360', 'B', 'A', 'M5V', 178.053, 2851, 0.228, false, 3305, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=178.053", PA=232.27°, sep=2851 AU, mass=0.228 +0.033/-0.015 Msun, Teff=3305 K.'),

    ('WASP-68', 'B', 'A', 'M3V', 13.083, 2981, 0.442, false, 3589, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=13.083", PA=119.89°, sep=2981 AU, mass=0.442 +0.062/-0.056 Msun, Teff=3589 K.'),

    ('HD 195019', 'B', 'A', 'K5V', 3.388, 128, 0.697, false, 4418, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.388", PA=333.93°, sep=128 AU, mass=0.697 +0.033/-0.022 Msun, Teff=4418 K.'),

    ('HD 195689', 'B', 'A', 'M5V', 12.888, 2650, 0.185, false, 3226, false,
     'wide late M-dwarf visual companion (HD 195689 = KELT-9)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=12.888", PA=123.22°, sep=2650 AU, mass=0.185 +0.021/-0.010 Msun, Teff=3226 K. '
     'KELT-9 b deep-dived (atmosphere migration 035; Beyond Archive featured planet).'),

    ('HD 196050', 'BC', 'A', 'M3V', 10.772, 547, 0.365, false, 3484, false,
     'tight BC pair, close companion to HD 196050 A (unresolved by Mugrauer)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=10.772", PA=174.53°, sep=547 AU, mass=0.365 +0.039/-0.019 Msun, Teff=3484 K (combined). '
     'BC unresolved.'),

    ('HD 197037', 'B', 'A', 'M3V', 3.691, 123, 0.402, false, 3524, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.691", PA=182.02°, sep=123 AU, mass=0.402 ± 0.003 Msun, Teff=3524 K.'),

    ('HD 196067', 'B', 'A', 'F8V', 16.625, 665, 1.143, false, 6072, false,
     'wide F-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=16.625", PA=19.26°, sep=665 AU, mass=1.143 +0.027/-0.031 Msun, Teff=6072 K.'),

    ('WASP-94 A', 'B', 'A', 'F8V', 15.060, 3200, 1.181, false, 6162, false,
     'wide F-dwarf visual companion (planet host is WASP-94 A; B also hosts a planet)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=15.060", PA=89.63°, sep=3200 AU, mass=1.181 +0.020/-0.019 Msun, Teff=6162 K. '
     'WASP-94 is a planet-host pair: A and B both host planets (recorded from A perspective).'),

    ('18 Del', 'B', 'A', 'M5V', 29.231, 2233, 0.197, false, 3254, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=29.231", PA=193.73°, sep=2233 AU, mass=0.197 +0.008/-0.017 Msun, Teff=3254 K.'),

    ('WASP-70 A', 'B', 'A', 'K2V', 3.161, 707, 0.781, false, 4807, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=3.161", PA=167.58°, sep=707 AU, mass=0.781 +0.018/-0.022 Msun, Teff=4807 K.'),

    ('HD 202772 A', 'B', 'A', 'G0V', 1.299, 211, 1.125, false, 6030, false,
     'close G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=1.299", PA=294.18°, sep=211 AU, mass=1.125 ± 0.005 Msun, Teff=6030 K.'),

    ('WASP-145 A', 'B', 'A', 'M2V', 5.166, 473, 0.591, false, 3956, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.166", PA=354.75°, sep=473 AU, mass=0.591 +0.008/-0.012 Msun, Teff=3956 K. '
     'Originally Hellier et al. 2019 as candidate; Mugrauer confirms. Not in WDS.'),

    ('HD 204941', 'B', 'A', 'K7V', 56.066, 1611, 0.607, false, 4017, false,
     'wide K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=56.066", PA=219.15°, sep=1611 AU, mass=0.607 +0.035/-0.034 Msun, Teff=4017 K.'),

    ('WASP-114', 'B', 'A', 'K5V', 4.961, 2633, 0.697, false, 4416, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.961", PA=290.60°, sep=2633 AU, mass=0.697 +0.033/-0.043 Msun, Teff=4416 K. '
     'Not in WDS.'),

    ('WASP-111', 'B', 'A', 'K2V', 5.029, 1511, 0.758, false, 4701, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.029", PA=100.16°, sep=1511 AU, mass=0.758 +0.033/-0.017 Msun, Teff=4701 K. '
     'Not in WDS.'),

    ('HIP 109600', 'B', 'A', 'M3V', 14.993, 996, 0.409, false, 3536, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=14.993", PA=147.13°, sep=996 AU, mass=0.409 +0.003/-0.007 Msun, Teff=3536 K. '
     'Not in WDS.'),

    ('HD 212301', 'B', 'A', 'M3V', 4.385, 238, 0.330, false, 3448, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.385", PA=276.23°, sep=238 AU, mass=0.330 +0.013/-0.017 Msun, Teff=3448 K.'),

    ('HD 213240', 'B', 'A', NULL, 95.638, 3913, 0.149, false, 3125, false,
     'wide late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=95.638", PA=126.52°, sep=3913 AU, mass=0.149 ± 0.008 Msun, Teff=3125 K.'),

    ('HD 214823', 'B', 'A', 'K5V', 6.622, 673, 0.647, false, 4195, false,
     'close K-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.622", PA=96.09°, sep=673 AU, mass=0.647 +0.022/-0.034 Msun, Teff=4195 K. '
     'Not in WDS.'),

    ('HD 215456', 'B', 'A', 'M3V', 50.724, 2011, 0.354, false, 3473, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=50.724", PA=294.86°, sep=2011 AU, mass=0.354 ± 0.003 Msun, Teff=3473 K.'),

    ('WASP-75', 'B', 'A', 'M4V', 30.220, 8958, 0.262, false, 3357, false,
     'wide M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=30.220", PA=252.35°, sep=8958 AU, mass=0.262 +0.017/-0.014 Msun, Teff=3357 K. '
     'Not in WDS.'),

    ('HAT-P-1', 'A', 'B', 'F2V', 11.268, 1800, 1.230, false, 6280, false,
     'wide F-dwarf visual companion (planet host is HAT-P-1 B; A is the wide companion)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=11.268", PA=253.71°, sep=1800 AU, mass=1.230 +0.041/-0.026 Msun, Teff=6280 K. '
     'NAMING: planet host is HAT-P-1 B; A is the wide companion.'),

    ('HD 220842', 'B', 'A', NULL, 5.252, 340, 0.146, false, 3113, false,
     'close late M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=5.252", PA=54.39°, sep=340 AU, mass=0.146 +0.010/-0.013 Msun, Teff=3113 K. '
     'Not in WDS.'),

    ('HIP 116454', 'B', 'A', NULL, 8.370, 524, 0.125, false, 3016, false,
     'WD wide companion (white-dwarf locus per Mugrauer 2019 Table 4)', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=8.370", PA=235.82°, sep=524 AU, mass=0.125 +0.003/-0.006 Msun, Teff=3016 K. WD.'),

    ('WASP-173 A', 'B', 'A', 'G8V', 6.122, 1436, 0.947, false, 5518, false,
     'wide G-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=6.122", PA=110.25°, sep=1436 AU, mass=0.947 +0.017/-0.009 Msun, Teff=5518 K.'),

    ('WASP-8', 'B', 'A', 'M2V', 4.511, 407, 0.533, false, 3782, false,
     'close M-dwarf visual companion', 'manual', '2019MNRAS.490.5088M',
     'Mugrauer 2019: rho=4.511", PA=170.94°, sep=407 AU, mass=0.533 +0.010/-0.106 Msun, Teff=3782 K.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation  = EXCLUDED.primary_designation,
    component_spectype   = EXCLUDED.component_spectype,
    separation_arcsec    = EXCLUDED.separation_arcsec,
    separation_au        = EXCLUDED.separation_au,
    component_mass_msun  = EXCLUDED.component_mass_msun,
    component_mass_is_min= EXCLUDED.component_mass_is_min,
    component_teff_k     = EXCLUDED.component_teff_k,
    inner_binary         = EXCLUDED.inner_binary,
    binary_class         = EXCLUDED.binary_class,
    source_catalog       = EXCLUDED.source_catalog,
    source_bibcode       = EXCLUDED.source_bibcode,
    notes                = EXCLUDED.notes;
