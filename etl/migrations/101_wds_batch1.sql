-- WDS curation Batch 1 (manual literature review, 2026-06-15). First of
-- nine planned passes against the 82-host WDS gap list discovered post-
-- migration 099 (NASA EA sy_snum > 1 with binary_companions empty or
-- incomplete). Mirrors the per-system curation pattern established by
-- 098 (16 Cyg) and the wider triple-system campaign (070-079).
--
-- This batch covers 9 confirmed S-type / hierarchical-multiple systems
-- plus one negative-result audit note (HD 113337). All primary-source
-- bibcodes verified via the user pasting paper abstracts / tables.
--
-- Systems and citations:
--   91 Aqr           -- WDS 23159-0905 (STFB 12 A,BC + BU 1220 BC)
--                       Mason et al. 2001 (2001AJ....122.3466M, WDS catalog
--                       geometry); Chaname & Gould 2004 (2004ApJ...601..289C,
--                       physical-pair confirmation via CPM).
--   GJ 900 A         -- Martin 2003 (2003AJ....126..918M). Subaru CIAO AO
--                       discovery of two subarcsec companions B and C at
--                       10 AU and 14.5 AU; masses depend on IC 2391
--                       supercluster age (35-200 Myr).
--   HD 87646         -- Ma et al. 2016 (2016AJ....152..112M). MARVELS +
--                       Palomar PALAO AO. The G-type host has both a hot
--                       Jupiter (b, 12.4 MJup) and a brown dwarf (c, 57
--                       MJup) AND a stellar companion B at ~22 AU.
--   BD-14 3065 A     -- Subjak et al. 2024 (2024A&A...688A.120S). TESS
--                       transit + TRES/Pucheros+ RV + SOAR HRCam speckle.
--                       F-subgiant + G dwarf (B) at 0.92"/520 AU; possible
--                       unresolved third component c suggested by long-
--                       term RV trend + Gaia RUWE = 3.5 (NOT given its
--                       own row pending period constraint).
--   HD 2638          -- Wittrock et al. 2016 (2016AJ....152..149W, Gemini
--                       North DSSI speckle) refines the M-dwarf B at
--                       0.512"/25.6 AU; Roberts et al. 2015
--                       (2015AJ....149..118R) prior detection via Robo-AO
--                       + PALM-3000 with CPM confirmation. Independently
--                       cross-confirmed by Ginski et al. 2016
--                       (2016MNRAS.457.2173G, AstraLux lucky imaging).
--   HIP 81208 C      -- Viswanath et al. 2023 (2023A&A...675A..54V, SPHERE
--                       discovery of B brown dwarf + C M-dwarf) + Chomez
--                       et al. 2023 (2023A&A...676L..10C, PACO reanalysis
--                       discovers Cb to make a quadruple). Planet host is
--                       C (a late-M dwarf orbited by the 15 MJup brown
--                       dwarf Cb); A (B9V primary at ~230 AU from C) and
--                       B (~67 MJup BD around A at ~50 AU) are the
--                       sibling components.
--   PH1 (Kepler-64)  -- Schwamb et al. 2013 (2013ApJ...768..127S). The
--                       circumbinary planet around the Aa+Ab eclipsing
--                       binary, with a wide visual pair Ba+Bb at
--                       ~1000 AU. Ab (M dwarf, inner eclipsing partner)
--                       gets inner_binary = TRUE. Section 9.3 photometric
--                       deconvolution yields Ba ~ G2 at 0.99 Msun and
--                       Bb ~ M2 at 0.51 Msun at ~60 AU mutual separation.
--   HD 43691         -- Ginski et al. 2016 (2016MNRAS.457.2173G). Single-
--                       epoch AstraLux lucky-imaging CANDIDATE companion
--                       (CPM not confirmed at publication time). Recorded
--                       as TENTATIVE following the V1298 Tau D precedent
--                       from migration 069.
--   HD 207832        -- Lodieu et al. 2014 (2014A&A...569A.120L). Very-
--                       wide CPM candidate at 38.57 arcmin (~126,000 AU)
--                       discovered via VISTA-VHS + 2MASS cross-match;
--                       Lodieu classifies it as "Y:" (candidate at very
--                       wide separation, likely co-moving rather than
--                       gravitationally bound) and notes such pairs are
--                       NOT dynamically stable at field-density / Galactic
--                       age. Recorded honestly with that caveat.
--   HD 113337        -- AUDIT NOTE ONLY. No row added. Borgniet et al.
--                       2019 (2019A&A...627A..44B) refines stellar
--                       parameters + debris-disk geometry + planet b /
--                       candidate c masses but characterizes no stellar
--                       companion. Ginski et al. 2016 imaged the system
--                       and detects NO companion down to ~0.08 Msun at
--                       2.5". SIMBAD also shows only planets. Three
--                       independent negative confirmations -> the NASA
--                       EA sy_snum > 1 claim is unsupported by primary
--                       literature and belongs in the sy_snum audit pile,
--                       not in binary_companions.
--
-- A note on position angles: several rows below have precise PA
-- measurements (HD 2638 at 167.76 deg, HD 43691 at 40.77 deg, BD-14 3065
-- at 210.5 / 30.5 deg degeneracy, 91 Aqr A-BC at 312 deg, etc). Following
-- the 069 V1298 Tau / 098 16 Cyg precedent, PAs are captured in the
-- notes column rather than the position_angle_deg column for consistency
-- with existing rows. A future backfill migration can lift them into the
-- typed column for 3D sky placement.
--
-- Apply after 011_binary_companions.sql and 100. Idempotent (ON CONFLICT
-- on the (hostname, component_designation) primary key).


-- ============================================================================
-- 91 Aqr  (= psi-1 Aquarii)
-- ============================================================================
-- WDS designation 23159-0905. A-BC pair: classical Struve visual binary
-- STFB 12, 55 observations from 1824 to 2016, ρ = 49.3", PA = 312 deg
-- (essentially unchanged over 192 years; PM match A vs BC = (+369, -017)
-- vs (+370, -017) mas/yr -> physical pair). Inner BC pair: Burnham 1220
-- BC, 43 observations 1889-2025, ρ = 0.1-0.2" with 156 deg of orbital
-- motion observed -> a real tight binary in its own right. The A-BC
-- physical-pair status was independently confirmed by Chaname & Gould
-- 2004's NLTT-derived wide-CPM-binary catalog. Other WDS components
-- (BU 1220 AD and BU 1220 BC,E) have PM mismatches and increasing rho
-- with epoch -> background, not curated here.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('91 Aqr', 'B', 'A', 'K3', 49.3,
     2263, 0.75, false, NULL, false,
     'wide visual binary partner (Ba component of the unresolved tight BC pair = HD 219430)', 'WDS', '2001AJ....122.3466M',
     '91 Aqr B (= HD 219430 component Ba): K3 dwarf at the wide visual binary partner of K1III planet host 91 Aqr A. '
     'WDS 23159-0905 row STFB 12 A,BC: rho = 49.3" at PA = 312 deg (epoch 2016), virtually unchanged from rho = 49.8" / '
     'PA = 311 deg at epoch 1824 (55 observations across 192 years). At the 45.9 pc system distance the 49.3" '
     'separation gives ~2263 AU projected. Physical pair confirmed by matching Hipparcos PMs (A: +369, -017; BC: '
     '+370, -017 mas/yr) and independently by the wide-CPM-binary catalog of Chaname & Gould 2004 '
     '(2004ApJ...601..289C). The combined V mag of Ba+Bb (unresolved at most epochs) is 9.88; individual mags ~10.5 '
     '/ 10.7 from the resolved BU 1220 BC row, implying near-equal-mass K3 components. Mass estimate 0.75 Msun '
     'per K3V mass-spectype relation (not directly measured). 91 Aqr is a hierarchical triple: A + (Ba+Bb).'),

    ('91 Aqr', 'C', 'A', 'K3', 49.3,
     2263, 0.75, false, NULL, false,
     'wide visual binary partner (Bb component, tight pair with B at ~5-9 AU)', 'WDS', '2001AJ....122.3466M',
     '91 Aqr C (= HD 219430 component Bb): K3 dwarf, tight binary partner of B. Co-located with B at the 49.3" / '
     '~2263 AU wide separation from A. The Ba-Bb internal pair has its own WDS row (BU 1220 BC, 43 observations 1889-'
     '2025): rho swept 0.1" -> 0.2" while PA swept 267 deg -> 111 deg = 156 deg of orbital motion in 136 years, '
     'clearly resolved as a real binary. Internal pair separation ~5-9 AU at the system distance. Equal-magnitude '
     'pair (10.5 / 10.7 V mag). Mass ~0.75 Msun per K3 mass-spectype relation (not directly measured). inner_binary '
     '= false here because the flag is reserved for tight pairs that define the planet host architecture (i.e., '
     'the P-type Aa+Ab in a circumbinary system); Ba+Bb is a tight pair within a wide stellar companion, not the '
     'host''s inner binary.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- GJ 900 A
-- ============================================================================
-- Martin 2003 Subaru CIAO AO discovery of two subarcsec companions to
-- the young (35-200 Myr, IC 2391 supercluster member) K-dwarf GJ 900 at
-- 19.3 pc. Both companions are redder than the primary and share its
-- proper motion. Component masses depend on the assumed system age:
-- B is 0.2-0.4 Msun, C is 0.09-0.22 Msun across the 35-200 Myr range.
-- Recorded midpoints with notes covering the full range.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('GJ 900 A', 'B', 'A', NULL, 0.52,
     10, 0.30, false, NULL, false,
     'subarcsec AO companion (Subaru CIAO, IC 2391 supercluster age 35-200 Myr)', 'manual', '2003AJ....126..918M',
     'GJ 900 B: red companion at 10 AU projected separation from A (rho = 0.52" at the 19.3 pc Hipparcos distance). '
     'Martin 2003 discovered B and C with the Coronagraphic Imager with Adaptive Optics (CIAO) on the 8.2 m Subaru. '
     'Both companions are redder than the primary and share its proper motion. Mass depends on the assumed system '
     'age: 0.2 Msun at 35 Myr to 0.4 Msun at 200 Myr (IC 2391 supercluster age range). Recorded midpoint 0.30 Msun. '
     'Spectral type not explicitly classified in the discovery paper; redder than the K dwarf primary, implying '
     'M-type. Martin notes the apparent separations of the three components (A, B, C) meet the observational '
     'criterion for an unstable Trapezium-type configuration, but this could be a projection effect. Dynamical '
     'mass of the faintest component (C) would yield a system age via evolutionary tracks.'),

    ('GJ 900 A', 'C', 'A', NULL, 0.75,
     14.5, 0.15, false, NULL, false,
     'subarcsec AO companion (Subaru CIAO; faintest of the three, age-dependent mass)', 'manual', '2003AJ....126..918M',
     'GJ 900 C: red companion at 14.5 AU projected separation from A (rho = 0.75" at 19.3 pc). Co-discovered with '
     'B by Martin 2003 Subaru CIAO AO. Mass range 0.09 Msun (35 Myr) to 0.22 Msun (200 Myr); recorded midpoint '
     '0.15 Msun. Spectral type not classified; mass at low end is sub-stellar / brown-dwarf-boundary at the young '
     'age, M dwarf at older ages. The system could be an unstable Trapezium-type triple, but may also be a stable '
     'hierarchical configuration depending on the true line-of-sight separations (projection effect).')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 87646
-- ============================================================================
-- Ma et al. 2016 (MARVELS + KeckET + KPNO ET + HET + Fairborn RVs +
-- Palomar PALAO AO). HD 87646 A is the planet host with a hot Jupiter
-- b (12.4 MJup at 0.117 AU, P=13.481d) and a brown dwarf c (57 MJup at
-- 1.58 AU, P=674d, e=0.50) -- both stay in the planet table. The
-- stellar companion B is detected at ~22 AU from a Hipparcos +
-- Palomar AO analysis but is NOT spectrally characterized in the
-- discovery paper. spectype, mass, and teff are left NULL accordingly.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 87646', 'B', 'A', NULL, NULL,
     22, NULL, false, NULL, false,
     'close stellar companion (Hipparcos + Palomar PALAO AO; mass/spectype not characterized)', 'manual', '2016AJ....152..112M',
     'HD 87646 B: stellar companion to the planet host HD 87646 A at a projected separation of ~22 AU, established '
     'jointly from the Hipparcos catalog and a Palomar PALAO AO image (Ma et al. 2016 abstract). The discovery '
     'paper does not characterize B''s spectral type, mass, or effective temperature; those fields are NULL pending '
     'follow-up AO photometry / spectroscopy. A itself is a G-type primary (Teff 5770 +/- 80 K, log g 4.1, '
     '[Fe/H] -0.17, 1.12 +/- 0.09 Msun, 1.55 +/- 0.22 Rsun). The planet b (12.4 MJup, 13.481 d, e = 0.05) and brown '
     'dwarf c (57 MJup, 674 d, e = 0.50) orbit A and remain in the planets table; only B is curated here. Dynamical '
     'simulations in Ma 2016 show the system is stable for large AB semi-major axis with low eccentricity (to be '
     'verified with future astrometry).')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- BD-14 3065 A  (= TOI-4987 = TIC 293607057)
-- ============================================================================
-- Subjak et al. 2024 confirms a transiting deuterium-burning-boundary
-- planet/BD around the F-subgiant primary in a triple-star system.
-- SOAR HRCam I-band speckle imaging (April 2022) detects the wide
-- G-type companion B at 0.92" / 520 AU. A long-term RV trend (non-
-- linear, period unconstrained) plus Gaia RUWE = 3.5 hints at a third
-- close unresolved component c (their three-component SED model fits
-- M ~ 1.02 Msun for it), but with no measured period and no resolved
-- detection, it is NOT given its own row pending follow-up.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('BD-14 3065 A', 'B', 'A', 'G', 0.92,
     520, 0.99, false, 6190, false,
     'SOAR HRCam I-band speckle companion (G-type, CPM-assumed via shared Gaia parallax)', 'manual', '2024A&A...688A.120S',
     'BD-14 3065 B: G-type stellar companion to F-subgiant primary A, detected by SOAR HRCam speckle interferometry '
     '(2022-04-15, Cousins I, 36 mas resolution, 0.064" PSF). rho = 0.92" / 520 AU projected at the d = 567 pc '
     'Gaia parallax distance; PA = 210.5 or 30.5 deg (the 180 deg degeneracy is not resolved by speckle alone). '
     'Delta I = 2.3 mag. Subjak 2024 fits a two-component SED (Table 2) giving M = 0.99 +/- 0.03 Msun, R = 0.96 '
     '+/- 0.03 Rsun, Teff = 6190 +/- 150 K, log g = 4.47, [Fe/H] = -0.37. Physical association assumed (shared '
     'Gaia parallax, standard for sub-1" pairs at this brightness; not yet directly confirmed via multi-epoch CPM). '
     'NOT in Gaia catalog as a resolved source. ADDITIONAL HINT not curated as its own row: a long-term non-linear '
     'RV trend + Gaia RUWE = 3.5 suggest a closer (sub-0.9") unresolved component c; Subjak''s three-component SED '
     'fit (Table 2) gives M ~ 1.02 Msun and Teff ~ 6300 K for it under the assumption that the primary is itself an '
     'unresolved binary. Period unconstrained, no direct detection -> deferred. Together A + B + (possible c) match '
     'Subjak''s "triple-star system" framing in the abstract.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 2638
-- ============================================================================
-- Wittrock et al. 2016 (Gemini-North DSSI speckle, 692 + 880 nm) provides
-- the tightest characterization of HD 2638 B; Roberts et al. 2015 (Robo-AO
-- + PALM-3000) is the prior CPM-confirming detection (Wittrock cites it
-- explicitly). Independently cross-checked by Ginski et al. 2016
-- (2016MNRAS.457.2173G) AstraLux: rho = 0.5199" / PA = 167.76 deg /
-- delta-i = 3.11 mag (Ginski Table 3), in excellent agreement with
-- Wittrock's 0.512". Single row (one companion).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 2638', 'B', 'A', 'M', 0.512,
     25.6, 0.483, false, 3570, false,
     'tight M-dwarf companion (DSSI speckle + Robo-AO/PALM-3000 + AstraLux triple-confirmation)', 'manual', '2016AJ....152..149W',
     'HD 2638 B: late M-dwarf companion to the G-type planet-host A. rho = 0.512 +/- 0.002" (Wittrock et al. 2016 '
     'Gemini-North DSSI speckle, 692 + 880 nm), projected separation 25.6 +/- 1.9 AU at the 49.9 pc Hipparcos '
     'distance. M = 0.483 +/- 0.007 Msun, Teff = 3570 +/- 8 K from stellar isochrone models -> late M dwarf. '
     'Roberts et al. 2015 (2015AJ....149..118R) is the prior-detection / CPM-confirmation reference using '
     'Palomar Robo-AO + PALM-3000 with an orbital-period estimate of ~130 yr (factor-of-three uncertainty per the '
     'projected-separation method). Independently cross-checked by Ginski et al. 2016 (2016MNRAS.457.2173G) AstraLux '
     'lucky imaging at Calar Alto 2.2 m: rho = 0.5199 +/- 0.004", PA = 167.76 +/- 0.35 deg, delta i = 3.11 +/- 0.41 '
     'mag, co-moving = yes (Ginski Table 3). The three independent detections agree well within their error bars. '
     'PA = 167.76 deg (Ginski 2014 epoch, captured here in notes pending position_angle_deg backfill). The HD 2638 '
     'planet b is a hot Jupiter; the new B companion strengthens the literature connection between hot Jupiters '
     'and stellar multiplicity (Wittrock 2016 framing).')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HIP 81208 C
-- ============================================================================
-- Hierarchical quadruple system in Sco-Cen (17 Myr, 148.7 pc). Planet
-- host is the late-M star HIP 81208 C; its registered "planet" Cb is
-- a 15 MJup brown dwarf orbiting C at ~20 AU (Chomez 2023 discovery,
-- stays in planets table). For the host C, the sibling components are:
--   * HIP 81208 A: B9V primary (2.58 Msun) at ~230 AU from C.
--   * HIP 81208 B: ~67 MJup brown dwarf orbiting A at ~50 AU (sibling
--     object in the system, not a direct binary partner of C).
-- Both Viswanath 2023 (B+C discovery) and Chomez 2023 (Cb reanalysis)
-- are cited. The system is "the first stellar binary with substellar
-- companions around each component ever found by direct imaging"
-- (Chomez 2023). Kozai resonance candidate; orbital planes of B and C
-- around A likely close to orthogonal (Viswanath 2023).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HIP 81208 C', 'A', 'C', 'B9V', NULL,
     230, 2.58, false, NULL, false,
     'hierarchical primary B9V star (planet host C orbits A at ~230 AU)', 'manual', '2023A&A...675A..54V',
     'HIP 81208 A: B9V primary, M = 2.58 +/- 0.06 Msun, V = 6.632 +/- 0.006, distance 148.7 (-1.3, +1.5) pc, age '
     '17 (-4, +3) Myr (Sco-Cen association). The planet host of this binary_companions row is HIP 81208 C (a '
     'late-M star orbiting A at ~230 AU); A is the wide hierarchical primary. SPHERE@VLT discovery by Viswanath '
     'et al. 2023 (2023A&A...675A..54V) as part of the BEAST (B-star Exoplanet Abundance Study) survey. '
     'Architecture: A is the central B9V star; B (~67 MJup brown dwarf, separate row below) orbits A at ~50 AU; '
     'C (this row''s host, ~0.135 Msun) orbits A at ~230 AU; Cb (15 MJup brown dwarf, in planets table) orbits C '
     'at ~20 AU. The system is dubbed "the first stellar binary with substellar companions around each component '
     'ever found by direct imaging" (Chomez et al. 2023, 2023A&A...676L..10C) and is a candidate Kozai resonance '
     'with B and C''s orbital planes around A likely close to orthogonal (Viswanath 2023).'),

    ('HIP 81208 C', 'B', 'C', NULL, NULL,
     230, 0.064, false, NULL, false,
     'brown dwarf around hierarchical primary A (sibling component to planet host C, not direct binary partner)', 'manual', '2023A&A...675A..54V',
     'HIP 81208 B: ~67 (-7, +6) MJup brown dwarf (= 0.064 Msun) orbiting the B9V primary HIP 81208 A at ~50 AU '
     '(Viswanath et al. 2023 SPHERE discovery; refined by Chomez et al. 2023 PACO reanalysis). From the planet '
     'host HIP 81208 C''s perspective B is a sibling object in the hierarchical quadruple system, not a direct '
     'binary partner: C orbits A at ~230 AU; B orbits A at ~50 AU; so B''s instantaneous distance from C varies '
     '~180-280 AU depending on its phase. separation_au = 230 here approximates the system scale rather than the '
     'BC pair separation. inner_binary = false because B is not the planet host''s tight pair (Cb is the planet). '
     'Together A + B + C + Cb give NASA EA sy_snum = 3 + the substellar planet count of 1 for Cb.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- PH1  (= Kepler-64, KIC 4862625)
-- ============================================================================
-- Hierarchical quadruple circumbinary system: the planet PH1b orbits
-- the eclipsing binary Aa+Ab (P=20d) at 0.652 AU (P=138.3d); a wide
-- visual binary Ba+Bb sits at ~1000 AU. Schwamb et al. 2013 fully
-- characterizes all four stars via Kepler light curve + Keck spectra
-- + AO + photometric-deconvolution isochrone fitting (Section 9.3).
-- Migration 100 already deleted a bogus 162.5" SIMBAD wide-companion
-- row; this migration adds the canonical Ab (inner eclipsing M dwarf,
-- inner_binary = TRUE) plus the wide Ba (G2, 0.99 Msun) and Bb (M2,
-- 0.51 Msun) at the ~1000 AU projected distance. The wide Ba-Bb pair
-- itself is separated by ~60 AU internally.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('PH1', 'B', 'A', 'M', NULL,
     0.18, 0.408, false, NULL, true,
     'inner eclipsing-binary M-dwarf partner (defines the P-type circumbinary architecture)', 'manual', '2013ApJ...768..127S',
     'PH1 Ab: M-dwarf eclipsing-binary partner of the F-dwarf primary Aa. Photometric-dynamical model from '
     'Schwamb et al. 2013 (Tables 7 and 8): M = 0.408 +/- 0.024 Msun, R = 0.378 +/- 0.023 Rsun. Aa-Ab orbital '
     'period 20.0002468 +/- 0.0000044 d, semi-major axis ~0.18 AU. The transiting circumbinary planet PH1b '
     '(R = 6.18 R_earth, P = 138.3 d, a = 0.652 AU, m < 169 M_earth at 99.7 percent CL, equilibrium temperature '
     '463-498 K) orbits the Aa+Ab pair, not either star individually. This row carries inner_binary = TRUE per '
     'the migration 011 convention -- PH1 is one of the canonical P-type cb_flag = 1 systems. The wider Ba+Bb '
     'visual pair at ~1000 AU is curated as separate rows (C and D) below. Note on designation: the literature '
     'uses Aa/Ab/Ba/Bb; this row stores Ab as designation B following the simple A/B/C/D convention used by '
     'sibling migrations (070-079, 098). Migration 100 previously removed a bogus 162.5" SIMBAD wide-companion '
     'row for this host.'),

    ('PH1', 'C', 'A', 'G2', NULL,
     1000, 0.99, false, NULL, false,
     'wide visual pair (Ba component, G2 dwarf at ~1000 AU from the Aa+Ab eclipsing binary)', 'manual', '2013ApJ...768..127S',
     'PH1 Ba: G2 dwarf in the wide visual pair Ba+Bb at ~1000 AU projected from the Aa+Ab eclipsing binary. '
     'Properties from Schwamb 2013 Section 9.3 photometric-deconvolution fit to SDSS griz + 2MASS JHKs + KIC '
     'D51 photometry using a 2 Gyr Dartmouth isochrone (after iteration with the photometric-dynamical model). '
     'Mass ~ 0.99 Msun -> G2 spectral type. Bound to Aa+Ab via RV (Ba and Bb both have the systemic velocity '
     'of Aa, Schwamb Section 9.3 narrative). Combined AO photometry (Ba + Bb relative to Aa + Ab): delta J = '
     '1.89 +/- 0.04, delta Ks = 1.67 +/- 0.03. System distance ~1500 pc from the photometric fit -> the 0.68" '
     'angular separation translates to ~1000 AU. Ba and Bb are themselves separated by ~60 AU (Bb row below). '
     'Designation C used for Ba (vs the literature''s Aa/Ab/Ba/Bb) following the simple A/B/C/D convention used '
     'by sibling migrations. inner_binary = false because Ba is part of the wide pair, not the planet-defining '
     'inner binary (that''s Ab in the row above).'),

    ('PH1', 'D', 'A', 'M2', NULL,
     1000, 0.51, false, NULL, false,
     'wide visual pair (Bb component, M2 dwarf, tight pair with Ba at ~60 AU)', 'manual', '2013ApJ...768..127S',
     'PH1 Bb: M2 dwarf in the wide visual pair Ba+Bb, the smaller component. Mass ~0.51 Msun per Schwamb 2013 '
     'Section 9.3 photometric-deconvolution fit (caveat: 0.51 Msun is more typical of K7-M0 than M2 at solar '
     'metallicity; the paper''s photometric classification favors M2). Co-located with Ba at the ~1000 AU '
     'projected distance from the Aa+Ab eclipsing binary. Ba-Bb internal separation ~60 AU (Schwamb 2013 Section '
     '9.3). Both Ba and Bb bound to the Aa+Ab pair gravitationally (RV-confirmed shared systemic velocity). The '
     'wide-pair semi-major axis around Aa+Ab is poorly constrained; Schwamb 2013 Section 9.3 uses 1000 AU as a '
     'representative value for MERCURY orbital integrations, finding negligible perturbation on PH1b''s orbit. '
     'inner_binary = false (same rationale as Ba: this is the wide pair, not the inner eclipsing binary).')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 43691
-- ============================================================================
-- Ginski et al. 2016 (2016MNRAS.457.2173G) Calar Alto 2.2 m AstraLux
-- lucky-imaging single-epoch detection. HD 43691 is in the "new
-- companion candidates" group of their Table 3 -- the co-moving column
-- is "-" (not determined at one epoch). Mass derived from photometric
-- absolute magnitude (Table 6) is 0.160 +/- 0.010 Msun -> late M
-- dwarf; the footnote on the Table 6 row indicates the value is the
-- UNRESOLVED magnitude, so the candidate may itself be a tight binary
-- (cannot tell from single epoch). Recorded as TENTATIVE following
-- the V1298 Tau D precedent.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 43691', 'B', 'A', 'M', 4.435,
     357, 0.160, false, NULL, false,
     'AstraLux lucky-imaging candidate companion (single-epoch detection, CPM not yet confirmed)', 'manual', '2016MNRAS.457.2173G',
     'HD 43691 B: TENTATIVE late-M-dwarf candidate companion detected by Ginski et al. 2016 with AstraLux lucky '
     'imaging at Calar Alto 2.2 m. Single epoch (2015-03-10): rho = 4.435 +/- 0.016", PA = 40.77 +/- 0.24 deg, '
     'delta i = 7.71 +/- 0.11 mag (Ginski Table 3). Projected separation ~357 AU at the 80.4 +/- 5.7 pc Hipparcos '
     'distance (Ginski Table 5). Mass 0.160 +/- 0.010 Msun derived from the photometric absolute SDSS-i magnitude '
     '(Ginski Table 6) ASSUMING physical association. The Table 6 footnote indicates the mass / absolute magnitude '
     'is unresolved -> the candidate may itself be a tight binary, which cannot be ruled out from a single epoch. '
     'co_moving status in Ginski Table 3 is "-" (not yet determined at the time of publication; multi-epoch CPM '
     'follow-up needed). Recorded here following the V1298 Tau D precedent (migration 069): we curate the '
     'observed geometry honestly with explicit candidate flagging; if the source turns out to be a background '
     'object, this row can be deleted in a future migration. binary_class set to descriptive candidate text. PA = '
     '40.77 deg captured in notes pending position_angle_deg backfill.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 207832
-- ============================================================================
-- Lodieu et al. 2014 VISTA-VHS + 2MASS cross-match identifies a wide
-- M6.5 CPM CANDIDATE (2MASS J21512497-2636426) at 38.57 arcmin from
-- the G5V planet host. Projected separation ~126,000 AU. Lodieu's own
-- Table 1 conclusion column flags this as "Y:" (candidate at very
-- wide separation, NOT a confirmed bound binary); Lodieu Section 7
-- analytically estimates the disruption timescale for >100,000 AU pairs
-- in the solar vicinity and concludes such systems "are not physically
-- bound" -- co-moving via common origin or shared dynamical evolution
-- rather than gravitationally bound. Curated with that caveat front
-- and center in the notes.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 207832', 'B', 'A', 'M6.5', 2314,
     126000, 0.095, false, NULL, false,
     'very-wide CPM candidate at ~126,000 AU (Lodieu 2014 "Y:" status, likely co-moving not bound)', 'manual', '2014A&A...569A.120L',
     'HD 207832 B: TENTATIVE very-wide M6.5 +/- 0.5 dwarf CPM candidate identified by Lodieu et al. 2014 via cross-'
     'match of the VISTA Hemisphere Survey with 2MASS. 2MASS J21512497-2636426, J = 13.912, Ks = 13.039. Projected '
     'angular separation 38.57 arcmin = 2314" at the d = 54.4 pc host distance gives a projected linear separation '
     'of ~126,000 AU = 0.61 pc -- well into the "co-moving but not bound" regime. Lodieu''s Table 1 conclusion '
     'column flags this as "Y:" (candidate at very wide separation), NOT confirmed Y (bound) -- they explicitly '
     'distinguish three confirmed bound systems (HD 126614, HIP 70849, HD 213240) from five "Y:" candidates at '
     '>100,000 AU. Lodieu Section 7 analytically estimates a disruption timescale of "several hundred Myr" for '
     '~0.07 objects/pc^-3 solar-vicinity density, far less than the system age, and concludes these systems "are '
     'not physically bound. Given the large uncertainties in the determination of their distances, they are either '
     'objects with similar proper motions that lie along the same line of sight by chance ... or systems located '
     'at the same distance and share similar projected velocities" (possibly common origin / shared dynamical '
     'evolution). Mass 0.095 Msun recorded from the M6.5 mass-spectype relation (8 pc census, Lodieu Table 3); '
     'this is a single-component estimate, may be an equal-mass binary doubling the apparent mass. PM match: '
     'companion (+133, -117) vs host (+132.05 +/- 0.97, -143.15 +/- 0.52) mas/yr (RA matches well, Dec offset '
     '~26 mas/yr within Lodieu''s 40 mas/yr threshold). Recorded honestly as a wide-CPM candidate; NASA EA''s '
     'sy_snum > 1 for this host most likely traces to this Lodieu detection.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 113337  --  AUDIT NOTE ONLY, no row added
-- ============================================================================
-- NASA EA carries sy_snum > 1 for HD 113337 but the primary literature
-- does NOT support a stellar companion. Three independent negative
-- confirmations:
--   1. Borgniet et al. 2019 (2019A&A...627A..44B) CHARA-VEGA
--      interferometry + LBTI imaging + SOPHIE RV + MESS2 combined
--      analysis. The paper refines stellar fundamental parameters
--      (M = 1.40 Msun, R = 1.50 Rsun, Teff = 6774 K, d = 36.2 pc),
--      partially resolves the outer debris disk (i ~25 deg), refines
--      the planet b mass (3.1 MJup) and candidate planet c mass
--      (7.2 MJup), and explicitly sets detection limits for further
--      undetected companions. NO known stellar companion is mentioned
--      anywhere in the paper.
--   2. Ginski et al. 2016 (2016MNRAS.457.2173G) AstraLux lucky imaging
--      observed HD 113337 (Ginski Table 1, 2015-03-10). HD 113337 is
--      ABSENT from Ginski Table 3 (detected companions / candidates).
--      Ginski Table 8 detection limits: rules out stellar companions
--      to ~0.082 Msun at >= 2.5" and ~0.075 Msun at >= 5".
--   3. SIMBAD shows only planets for this system (per user check
--      2026-06-13).
-- The agent guess earlier in this curation pass had asserted that
-- Borgniet 2019 characterized a wide M-dwarf companion at ~120"/~4000
-- AU -- that turned out to be incorrect. Recording the negative finding
-- here as durable provenance; the sy_snum >1 discrepancy belongs in
-- the value-added-catalog sy_snum audit pile, not in binary_companions.
-- No INSERT statement for HD 113337 in this migration.
