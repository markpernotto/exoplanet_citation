-- WDS curation Batch 5 (2026-06-23). Fifth pass against the 82-host WDS
-- gap list, focused on the HIP-named cohort. Two binary_companions rows
-- plus three sy_snum_audit rows: the HIP cohort turns out to be
-- dominated by NASA EA conventions disagreements (3 of 5 hosts) where
-- the cataloged "stellar companion" is actually a substellar object
-- our convention places in the planets table rather than counting as
-- a sy_snum component.
--
-- Systems and citations:
--   HIP 70849 B  -- Lodieu et al. 2014 (2014A&A...569A.120L). Wide T4.5
--                   brown dwarf companion at 6.29 arcmin (~9000 AU
--                   projected) discovered via VHS-2MASS cross-match and
--                   NTT/SofI near-infrared spectroscopy. "The second
--                   brown dwarf companion to a planet-host star directly
--                   imaged" per Lodieu's framing. Bona-fide bound CPM
--                   (Lodieu Table 1 conclusion column = "Y"). Curated
--                   here as a binary_companions row -- substellar but
--                   genuinely a wide separate companion (not a planet
--                   orbiting the host), same pattern as HIP 81208 B in
--                   migration 101.
--   HIP 94235 B  -- Zhou et al. 2022 (2022AJ....163..289Z). M-dwarf
--                   stellar binary partner at 56 (+9, -7) AU true semi-
--                   major axis (a/R* orbit fit), e = 0.25, period
--                   ~365 yr. Discovered via 11-year diffraction-limited
--                   astrometric baseline (VLT-NaCo 2010 from Chauvin
--                   et al. 2015 and Desidera et al. 2015; Gemini-Zorro
--                   2021 epochs from Zhou 2022 itself). Host is a young
--                   G0V in the AB Doradus moving group with a transiting
--                   mini-Neptune b; Zhou 2022 frames HIP 94235 as "one
--                   of the tightest stellar binaries to host an inner
--                   planet". Discovery cites Chauvin 2015
--                   (2015A&A...573A.127C) and Desidera 2015
--                   (2015MNRAS.454.4202D) retained in notes.
--
-- sy_snum disagreements (no binary_companions row added for these):
--   HIP 19976    -- Feng et al. 2022 (2022ApJS..262...21F, "3D Selection
--                   of 167 Sub-stellar Companions") characterizes
--                   HIP 19976's RV+astrometry signal as a brown-dwarf-
--                   mass companion at ~30 MJup, not a stellar binary
--                   partner. The paper''s scope is explicitly substellar
--                   companions identified via combined RV + Gaia/Hipparcos
--                   astrometry + imaging. NASA EA''s sy_snum = 2 likely
--                   counts this BD as a star; our convention treats it
--                   as a substellar planet-table companion. Same pattern
--                   as HD 87646 (migration 104), HD 38529 (migration
--                   105), HIP 21152 (this migration).
--   HIP 21152    -- Kuzuhara et al. 2022 (2022ApJ...934L..18K, direct-
--                   imaging discovery via SCExAO/CHARIS + Keck/NIRC2 of
--                   the only confirmed substellar companion to a main-
--                   sequence Hyades cluster member). Dynamical mass
--                   27.8 (+8.4, -5.4) MJup, spectrum L/T transition
--                   (early T dwarf), semi-major axis 17.5 (+7.2, -3.8)
--                   AU. Mass ratio relative to host ~2%, right at the
--                   planet/brown dwarf boundary. Substellar, not a star.
--                   Refined by Franson et al. 2023
--                   (2023AJ....165...39F).
--   HIP 38594    -- Feng et al. 2020 (2020ApJS..250...29F, "Nearby Earth
--                   Analogs III") characterizes HIP 38594 as an early
--                   M dwarf (Table 1: M0, 0.61 +/- 0.02 Msun, 17.8 pc
--                   distance) hosting two planets: b (8.2 M_earth super-
--                   Earth in habitable zone, P = 60.7 d, sma 0.256 AU)
--                   and c (48 M_earth warm Neptune, P = 3478 d, sma
--                   3.8 AU). NO stellar companion characterized. NASA EA's
--                   sy_snum = 2 most likely either a SIMBAD bulk-ingest
--                   artifact or a planet (b or c) miscounted as a star,
--                   but at 8 and 48 M_earth respectively, neither planet
--                   is plausibly stellar.
--
-- Apply after 106_wds_batch4.sql. Idempotent.


-- ============================================================================
-- HIP 70849 B  (wide T4.5 brown dwarf, Lodieu 2014)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HIP 70849', 'B', 'A', 'T4.5', 377.4,
     9058, 0.04, false, NULL, false,
     'wide T4.5 brown dwarf companion (VHS+2MASS CPM + NTT/SofI near-infrared spectroscopy)', 'manual', '2014A&A...569A.120L',
     'HIP 70849 B: T4.5 +/- 0.5 brown dwarf companion to K7V planet-host A, discovered by Lodieu et al. 2014 '
     'via VISTA-VHS / 2MASS cross-match for common proper motion candidates and confirmed substellar via '
     'NTT/SofI near-infrared spectroscopy (1.16-2.52 micron). Astrometry from Lodieu Table 1: rho = 6.29 '
     'arcmin = 377.4 arcsec at host distance d = 24.0 +/- 1.2 pc (van Leeuwen 2007 Hipparcos) -> projected '
     'separation ~9000 AU. PM match: companion (-35, -196) vs host (-47.12 +/- 2.15, -203.52 +/- 1.93) '
     'mas/yr -- well within Lodieu''s 40 mas/yr CPM threshold, classified as bona-fide bound "Y" in their '
     'Table 1 conclusion column. J = 15.533, Ks = 15.582 mag. Mass for a T4.5 at the system age (1-5 Gyr '
     'per Segransan et al. 2011) is approximately 30-50 MJup ~ 0.029-0.048 Msun; recorded midpoint 0.04 Msun. '
     'Lodieu''s contamination analysis estimates probability of chance T4.5 alignment within 6.3 arcmin to '
     'be 0.027 (2.7 percent), strongly supporting real association. Lodieu frames this as the second brown-'
     'dwarf companion directly imaged around a planet-host star (after HD 3651) and possibly the first '
     'brown-dwarf binary at wide separation from a star orbited by a 9 MJup planet. Despite being substellar '
     'this row IS curated in binary_companions (rather than treated as a sy_snum disagreement) because it '
     'is a SEPARATE wide companion that is gravitationally bound, not a planet orbiting the host -- same '
     'pattern as HIP 81208 B in migration 101. NASA EA likely counts this BD toward HIP 70849''s sy_snum=2.')
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
-- HIP 94235 B  (M-dwarf stellar binary, Zhou 2022)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     orbital_period_d, eccentricity, inclination_deg,
     primary_mass_msun, primary_radius_rsun, primary_teff_k, primary_spectype)
VALUES
    ('HIP 94235', 'B', 'A', 'M', 0.600,
     56, 0.26, false, NULL, false,
     'M-dwarf inner binary partner (11-year astrometric baseline, dynamical orbit fit)', 'manual', '2022AJ....163..289Z',
     'HIP 94235 B: M-dwarf stellar binary partner (mass ~0.26 Msun implies approximately M3-M4V) to the '
     'young G0V planet-host A. Zhou et al. 2022 (TESS discovery + diffraction-limited imaging + MCMC orbit '
     'fit) derived the binary architecture from an 11-year astrometric baseline: VLT-NaCo at 2010-07-30 '
     '(rho = 506 +/- 7 mas, PA = 150.6 +/- 0.8 deg, DH = 3.8 +/- 0.3 mag; cited from Chauvin et al. 2015 '
     '2015A&A...573A.127C and Desidera et al. 2015 2015MNRAS.454.4202D), Gemini-Zorro at 2021-07-23 (rho '
     '= 596 +/- 5 mas, PA = 162.87 +/- 0.48 deg) and 2021-10-22 (rho = 600 +/- 8 mas, PA = 161.73 +/- 0.75 '
     'deg). Orbit fit MCMC (Zhou Table 6): true semi-major axis a = 56 (+9, -7) AU, eccentricity e = 0.25 '
     '(+0.22, -0.14), period P = 365 (+92, -69) yr, inclination 67.8 (+2.7, -2.9) deg, periastron distance '
     '43 (+11, -15) AU, dynamical mass 0.26 +/- 0.04 Msun. Recorded rho = 0.600 arcsec from the most-recent '
     '(Gemini-Zorro 2021-10-22) epoch; separation_au stores Zhou''s true SMA fit (56 AU) rather than the '
     'projected separation (600 mas * 58.54 pc = 35 AU). Host: G0V at d = 58.54 +0.08/-0.07 pc, M = 1.094 '
     '+0.024/-0.007 Msun, R = 1.08 (+0.11, -0.10) Rsun, T_eff = 5991 +/- 50 K, age 50-150 Myr (AB Doradus '
     'moving group), P_rot = 2.24 +/- 0.11 d. Planet HIP 94235 b is a 3.00 (+0.32, -0.28) R_earth mini-'
     'Neptune on a 7.7 d orbit around A. Zhou 2022 frames HIP 94235 as "one of the tightest stellar '
     'binaries to host an inner planet" -- 56 AU compares to typical S-type planet-host binary separations '
     'of 100s of AU. inner_binary = false because A is the planet host on a circumprimary (S-type) orbit, '
     'not circumbinary.',
     133316, 0.25, 67.8,
     1.094, 1.08, 5991, 'G0V')
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
    notes                 = EXCLUDED.notes,
    orbital_period_d      = EXCLUDED.orbital_period_d,
    eccentricity          = EXCLUDED.eccentricity,
    inclination_deg       = EXCLUDED.inclination_deg,
    primary_mass_msun     = EXCLUDED.primary_mass_msun,
    primary_radius_rsun   = EXCLUDED.primary_radius_rsun,
    primary_teff_k        = EXCLUDED.primary_teff_k,
    primary_spectype      = EXCLUDED.primary_spectype;


-- ============================================================================
-- HIP 19976  --  sy_snum disagreement (Feng 2022, brown-dwarf-mass companion)
-- ============================================================================
INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HIP 19976', 2, 1,
     'Feng et al. 2022 (2022ApJS..262...21F, "3D Selection of 167 Sub-stellar Companions to Nearby AFGKM Stars") characterizes HIP 19976''s RV + Hipparcos-Gaia astrometry signal as a brown-dwarf-mass companion (approximately 30 MJup). The paper''s entire scope is wide-orbit substellar companions identified via combined high-precision RV + Gaia/Hipparcos astrometry; their detection table includes HIP 19976 in the substellar (not stellar) regime. NASA EA''s sy_snum = 2 most likely counts this brown dwarf as a star; our convention treats substellar companions as planet-table entries, not as stellar components contributing to sy_snum. Same conventions disagreement pattern as HD 87646 (migration 104), HD 38529 (migration 105), HIP 21152 (this migration).',
     ARRAY['2022ApJS..262...21F'],
     'BD-counted-as-star case. Feng 2022 is the source paper for HIP 19976''s substellar nature.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;


-- ============================================================================
-- HIP 21152  --  sy_snum disagreement (Kuzuhara 2022, T-dwarf brown dwarf)
-- ============================================================================
INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HIP 21152', 2, 1,
     'Kuzuhara et al. 2022 (2022ApJ...934L..18K) directly imaged HIP 21152 B with Subaru SCExAO/CHARIS and Keck/NIRC2; the companion is a T-dwarf brown dwarf, not a star. Dynamical mass from MCMC orbit fit + RV: 27.8 (+8.4, -5.4) MJup. Spectrum: L/T transition, best fit by an early T dwarf. Semi-major axis 17.5 (+7.2, -3.8) AU. Mass ratio relative to the Sun-like host ~2%, right at the planet/brown dwarf boundary. Hyades cluster membership constrains the age, making this a benchmark substellar object. HIP 21152 B is "the only substellar companion unambiguously confirmed via direct imaging around a main-sequence star in Hyades" (Kuzuhara abstract). Substellar, not stellar -- NASA EA''s sy_snum = 2 is counting a brown dwarf as a star.',
     ARRAY['2022ApJ...934L..18K'],
     'Refined by Franson et al. 2023 (2023AJ....165...39F). Same conventions disagreement as HIP 19976 and the HD 87646 / HD 38529 family.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;


-- ============================================================================
-- HIP 38594  --  sy_snum disagreement (Feng 2020, no stellar companion)
-- ============================================================================
INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HIP 38594', 2, 1,
     'Feng et al. 2020 (2020ApJS..250...29F, "Nearby Earth Analogs III") characterizes HIP 38594 as a single early M-dwarf (Table 1: M0, 0.61 +/- 0.02 Msun, parallax 56.19 mas = 17.8 pc, V = 9.7 mag) hosting two PLANETS: HIP 38594 b is a 8.1 +/- 1.7 M_earth super-Earth in the habitable zone (P = 60.7 d, sma = 0.256 AU) and HIP 38594 c is a 48.4 +/- 7.4 M_earth warm Neptune (P = 3478 d, sma = 3.8 AU). No stellar companion is described anywhere in Feng 2020. NASA EA''s sy_snum = 2 is unsupported by the primary literature -- either a SIMBAD bulk-ingest artifact, or planet b or c being miscounted as stellar (implausible at 8 and 48 Earth masses respectively).',
     ARRAY['2020ApJS..250...29F'],
     'Cleanest sy_snum disagreement in Batch 5 -- the host is unambiguously single in the primary literature and the only "companions" are sub-Neptune mass planets.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;
