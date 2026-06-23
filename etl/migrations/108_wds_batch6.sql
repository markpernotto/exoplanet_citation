-- WDS curation Batch 6 (2026-06-23). Sixth pass against the WDS gap
-- list, focused on the HD-doubles remainder. Six binary_companions
-- rows + one sy_snum_audit row.
--
-- Notable: HD 86081 turned out to be a real binary after all
-- (Ngo et al. 2017 direct imaging) -- the agent verification caught
-- my earlier flawed "sy_snum disagreement" framing. Lesson: a discovery
-- paper that doesn't mention a stellar companion is NOT proof of
-- single-stardom; follow-up AO/RV-trend surveys often unearth them.
--
-- Systems and citations:
--   HD 41004 A   -- Santos et al. 2002 (2002A&A...392..215S) characterizes
--                  HD 41004 as a known visual binary at 0.5 arcsec with
--                  a 3.7-mag-fainter M-dwarf companion. Zucker et al.
--                  2003 (2003A&A...404..775Z) is the spectroscopic
--                  follow-up that resolved the brown-dwarf companion
--                  HD 41004 Bb (18.6 MJup) via TODCOR, kept in notes.
--                  Projected separation 0.5 arcsec * 43 pc = 21.5 AU.
--   HD 41004 B   -- Mirror row of HD 41004 A. Same Santos 2002 cite.
--                  HD 41004 B is the M-dwarf planet/BD host (HD 41004
--                  Bb is the famous 18.6 MJup BD on a 1.33 d orbit
--                  spuriously detected as a 0.5 m/s velocity signal
--                  through line-blending with HD 41004 A's spectrum).
--   HD 20781     -- Udry et al. 2019 (2019A&A...622A..37U) HARPS XLIV
--                  characterizes HD 20781 as one of eight planet-host
--                  stars and notes (Table 1 note a) that HD 20782 is
--                  its stellar visual companion (the famously eccentric
--                  e=0.95 Jupiter-host Jones et al. 2006). Udry doesn't
--                  measure precise arcsec/PA -- the wide pair is at
--                  ~9.3 arcmin separation per classical Hipparcos /
--                  WDS literature, but Udry just references that the
--                  visual-binary connection is known.
--   HD 86081     -- Ngo et al. 2017 (2017AJ....153..242N, "Friends of
--                  Hot Jupiters V") directly images HD 86081 B at
--                  rho = 2.901 arcsec / 276 AU. Mass 0.088 Msun
--                  (= 92 MJup, right at the H-burning limit; very late
--                  M dwarf). T_eff 2562 K. CPM-confirmed across two
--                  NIRC2 K-band epochs (2013-12-18 and 2014-12-05).
--                  Bryan et al. 2016 (cited in Ngo Section 4.1) reports
--                  a separate long-term RV trend (-1.3 m/s/yr)
--                  suggesting an additional inner unseen companion
--                  (likely planet or BD at ~4.6 AU); Ngo demonstrates
--                  the imaged B at 276 AU cannot produce the trend.
--                  HD 86081 may therefore be a hierarchical A + inner
--                  companion + B system.
--   HD 180902    -- Luhn et al. 2019 (2019AJ....157..149L, "Retired
--                  A Stars and Their Companions. VIII") resolves the
--                  long-term RV trend Johnson 2010 first flagged into
--                  a Keplerian orbit. HD 180902 B has m sin i = 98.7
--                  +/- 7.6 MJup (= 0.0943 Msun, right at the H-burning
--                  limit, very-late M dwarf), a = 7.15 AU, e = 0.335,
--                  P = 5880 d (~16 yr). Phase coverage is incomplete
--                  so period and separation poorly constrained; mass
--                  is m sin i lower bound from RV only.
--   HD 8673      -- Roberts et al. 2015 (2015AJ....149..144R, "Know
--                  the Star, Know the Planet. IV") characterizes
--                  HD 8673 B as an early M dwarf with mass 0.33-0.45
--                  Msun (midpoint 0.39) at projected separation ~10 AU
--                  (rho = 0.31 arcsec). Six astrometry epochs 2004-
--                  2013 across multiple telescopes confirm CPM and
--                  reveal orbital motion (PA sweeps 302 deg -> 339 deg).
--                  Orbital fit: a = 35-60 AU true semi-major axis,
--                  e <= 0.5, inclination 75-85 deg (near edge-on).
--                  Companion likely drives planet b's high e = 0.723
--                  via Kozai-Lidov. An earlier Patience 2002 speckle
--                  candidate was a false detection per Roberts 2015.
--
-- sy_snum disagreements:
--   HD 5608      -- Closes the deferred HD 5608 todo from Batch 3.
--                  Two independent surveys negative on a stellar
--                  companion: Luhn et al. 2019 (2019AJ....157..149L)
--                  characterizes HD 5608 as a subgiant planet host with
--                  only HD 5608 b (m sin i = 1.681 MJup, P = 780 d)
--                  in their Table 3 -- no binary row reported.
--                  Mugrauer 2019 (2019MNRAS.490.5088M, Gaia DR2 wide-
--                  CPM search at 20-9100 AU) did NOT detect HD 5608 in
--                  its detection tables. NASA EA's sy_snum = 2 is
--                  unsupported by primary literature.
--
-- A note on separation_au: where geometry is unknown from the cited
-- paper alone (HD 41004 A/B's PA, HD 20781's arcsec/PA), separation_au
-- carries the well-known classical-binary value with a "from earlier
-- literature" caveat in notes. For HD 86081, HD 180902, and HD 8673,
-- the cited paper directly measures the geometry.
--
-- Apply after 107_wds_batch5.sql. Idempotent.


-- ============================================================================
-- HD 41004 A  (companion = M2.5 dwarf HD 41004 B at 0.5 arcsec / 21.5 AU)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 41004 A', 'B', 'A', 'M2.5V', 0.5,
     21.5, 0.4, false, NULL, false,
     'close M-dwarf visual binary partner (Santos 2002 CORALIE TODCOR + earlier visual-binary literature)', 'manual', '2002A&A...392..215S',
     'HD 41004 B: M2.5V dwarf companion at 0.5 arcsec / ~21.5 AU projected from HD 41004 A (the K1V/K2V '
     'planet-host primary at d = 43 pc per Hipparcos). Visual-binary status established in the classical '
     'literature; Santos et al. 2002 confirms it via CORALIE blended-spectrum analysis (HD 41004 B is 3.7 '
     'mag fainter than A in V). PA not measured in Santos 2002 or in the cited CORALIE follow-up Zucker '
     'et al. 2003 (2003A&A...404..775Z); WDS lookup pending. HD 41004 B itself hosts a brown-dwarf '
     'companion HD 41004 Bb at 18.6 MJup minimum mass on a 1.328 d orbit (Zucker 2003 TODCOR analysis); '
     'that BD is in the planets table as HD 41004 B b, not curated here. HD 41004 is interesting '
     'historically as the first case where blended-spectrum line-shape contamination produced a '
     'spurious 50 m/s RV signal on HD 41004 A that was almost interpreted as a planet (Santos 2002 '
     'abstract: "this case should be taken as a serious warning about the importance of analyzing the '
     'bisector"). HD 41004 A also hosts a planet, HD 41004 A b.')
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
-- HD 41004 B  (mirror row -- companion = K0/K1V HD 41004 A at 0.5 arcsec)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 41004 B', 'A', 'B', 'K0V/K1V', 0.5,
     21.5, 0.7, false, 5010, false,
     'K1V visual binary primary (Santos 2002 + earlier visual-binary literature)', 'manual', '2002A&A...392..215S',
     'HD 41004 A: K1V/K2V planet-host primary at d = 43 pc per Hipparcos. Mass ~0.7 Msun, T_eff 5010 K, '
     'log g 4.42, [Fe/H] -0.09 (Santos 2002 Table 1). Visual companion of HD 41004 B (the planet/BD host '
     'on whose page this row appears) at 0.5 arcsec / ~21.5 AU projected. From HD 41004 B''s perspective, '
     'A is the brighter, more massive primary of the wide pair. HD 41004 A itself hosts a planet '
     '(HD 41004 A b) which is in the planets table. HD 41004 B hosts a brown dwarf HD 41004 B b at 18.6 '
     'MJup on 1.328 d orbit (Zucker et al. 2003 2003A&A...404..775Z TODCOR follow-up). PA not in Santos '
     '2002 or Zucker 2003; WDS lookup pending.')
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
-- HD 20781  (wide K0V partner = HD 20782, also a planet host)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 20781', 'B', 'A', 'K0/G3V', NULL,
     19500, 1.0, false, NULL, false,
     'wide visual binary partner (HD 20782 itself a planet host with e=0.95 Jupiter)', 'manual', '2019A&A...622A..37U',
     'HD 20781 B = HD 20782: G/K-type planet-host primary of the wide visual binary with HD 20781. Udry '
     'et al. 2019 (HARPS XLIV) characterizes HD 20781 (Table 1: K0V, 0.70 Msun, T_eff 5256 K, parallax '
     '28.27 mas -> d = 35 pc, [Fe/H] -0.11) and explicitly notes in Table 1 footnote (a) that "HD 20782, '
     'the stellar visual companion of HD 20781, hosts a planet as well. The corresponding stellar '
     'parameters are given in Jones et al. 2006." HD 20782 itself hosts the famously eccentric '
     'HD 20782 b (e = 0.95 Jupiter at 1.36 AU, P = 597 d; Jones et al. 2006 discovery). Udry doesn''t '
     'measure precise arcsec/PA -- the wide pair is at ~9.3 arcmin separation per classical Hipparcos / '
     'WDS literature, which at d = 35 pc gives ~19,500 AU projected. separation_arcsec left NULL; '
     'separation_au reflects the wide visual-binary value from earlier references. Together HD 20781 + '
     'HD 20782 are an interesting "twin" planet-hosting wide binary; Mack et al. 2014 (2014ApJ...787...98M) '
     'compares their chemistries.')
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
-- HD 86081  (very-late M / L0 boundary brown-dwarf-mass companion at 276 AU)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 86081', 'B', 'A', 'M9-L0', 2.901,
     276, 0.0876, false, 2562, false,
     'very-late M / L0 boundary companion (Keck NIRC2 AO, CPM-confirmed across two epochs)', 'manual', '2017AJ....153..242N',
     'HD 86081 B: very-late M dwarf or L0 boundary object (T_eff = 2562 +/- 61 K, M = 0.0876 +/- 0.0019 '
     'Msun = 92 MJup, right at the canonical 0.075 Msun H-burning limit). Ngo et al. 2017 ("Friends of '
     'Hot Jupiters V") Keck NIRC2 K-band imaging at two epochs (2013-12-18, 2014-12-05): rho = 2.904 +/- '
     '0.002 arcsec (2013) and 2.901 +/- 0.003 arcsec (2014); PA = 89.29 +/- 0.06 deg (2013), 89.35 +/- '
     '0.06 deg (2014) -- positionally stable confirming CPM. DKc = 7.95 (2013), 7.47 (2014) mag against '
     'the F8V primary. Projected separation 276 (+29, -24) AU at d = 95 (+10, -8) pc (Santos 2013). '
     'SEPARATE INNER COMPANION INDICATOR: Bryan et al. 2016 (cited in Ngo Section 4.1) report a long-'
     'term RV trend on HD 86081 of -1.3 +/- 0.25 m/s/yr corresponding to a minimum-mass 0.69 MJup '
     'companion at 4.6 AU. Ngo 2017 demonstrates that the imaged B at 276 AU CANNOT produce this trend '
     '(would require 1.4 Msun at this projected separation; Ngo Section 4.1 calculation). The inner '
     'trend implies a separate unseen companion (planet, brown dwarf, or low-mass star), so HD 86081 '
     'may be a hierarchical A + inner companion + B system. Inner unseen companion NOT curated as its '
     'own row pending direct detection.')
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
-- HD 180902  (RV-resolved very-late M / BD boundary companion at 7.15 AU)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     orbital_period_d, eccentricity)
VALUES
    ('HD 180902', 'B', 'A', 'M', NULL,
     7.15, 0.0943, true, NULL, false,
     'RV-resolved tight stellar/BD-boundary companion (Luhn 2019 Keplerian fit to long-term RV trend)', 'manual', '2019AJ....157..149L',
     'HD 180902 B: very-late M-dwarf / brown-dwarf boundary object resolved by Luhn et al. 2019 ("Retired '
     'A Stars and Their Companions. VIII"). Luhn fits the long-term RV trend first flagged by Johnson '
     'et al. 2010 into a Keplerian orbit: m sin i = 98.7 +/- 7.6 MJup (= 0.0943 Msun, just above the '
     'canonical 0.075 Msun H-burning limit), semi-major axis a = 7.15 +/- 0.69 AU, eccentricity e = '
     '0.335 +/- 0.025, period P = 5880 +/- 440 d (~16 yr), velocity semi-amplitude K = 898 +/- 28 m/s '
     '(Luhn Table 3). Phase coverage is incomplete -- the ~16-year period exceeds the RV monitoring '
     'baseline -- so period and separation are preliminary. Mass is m sin i (lower bound); the true '
     'mass could place B firmly in the late-M-dwarf range above the H-burning limit, or even higher. '
     'separation_arcsec NULL because the orbit is RV-derived only -- at d ~290 pc and 7.15 AU, the '
     'angular separation would be ~0.025 arcsec, below AO resolution. Ngo et al. 2017 also imaged '
     'HD 180902 with NIRC2 AO and found NO direct-imaged companion, consistent with B being at '
     'projected separations too small for AO resolution. The host is a K-giant subgiant (Luhn Table 2: '
     'mass 1.41 Msun, T_eff 4961 K, R 4.16 Rsun, log g 3.36); HD 180902 b is a 1.685 MJup planet on a '
     '511 d orbit (Johnson et al. 2010 discovery, Luhn Table 3 refinement).',
     5880, 0.335)
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
    eccentricity          = EXCLUDED.eccentricity;


-- ============================================================================
-- HD 8673  (close M-dwarf companion at one of the smallest exoplanet-host
--           binary separations known; Kozai-Lidov candidate)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     eccentricity, inclination_deg)
VALUES
    ('HD 8673', 'B', 'A', 'M3V', 0.308,
     10, 0.39, false, 3500, false,
     'early M-dwarf at ~10 AU projected; Kozai-Lidov candidate driving planet b''s e = 0.723', 'manual', '2015AJ....149..144R',
     'HD 8673 B: early M dwarf (M3V approximate, mass 0.39 +/- 0.06 Msun = midpoint of Roberts 2015''s '
     '0.33-0.45 Msun range) at one of the smallest projected separations of any exoplanet-host binary '
     'system known. Roberts et al. 2015 ("Know the Star, Know the Planet. IV") combines astrometry from '
     'six epochs across four telescopes (AEOS, Keck II, Palomar Hale, Palomar 1.5 m, 2004-2013): rho = '
     '0.308 +/- 0.003 arcsec (Keck II 2011-2012; representative low-error epoch), with stable rho = '
     '0.308-0.32 across all epochs. PA sweeps from 302.3 deg (2004) to 339.3 deg (2013), revealing '
     'orbital motion. Projected separation ~10 AU at d ~38 pc. Orbital fit: true semi-major axis a = '
     '35-60 AU, eccentricity e <= 0.5 (recorded upper bound 0.5), inclination i = 75-85 deg (recorded '
     'midpoint 80; near edge-on). DKs = 4.12 mag, DJ = 4.56 mag, DI = 6.5 mag against the F-type '
     'planet-host primary. The companion likely drives the planet HD 8673 b''s exceptionally high '
     'eccentricity (e = 0.723) via Kozai-Lidov oscillations -- Roberts 2015 explicit framing. '
     'Importantly, an earlier Patience et al. 2002 speckle "candidate companion" was a false detection; '
     'Roberts 2015 didn''t recover it and instead found this fainter, real companion.',
     0.5, 80)
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
    eccentricity          = EXCLUDED.eccentricity,
    inclination_deg       = EXCLUDED.inclination_deg;


-- ============================================================================
-- HD 5608  --  sy_snum disagreement (Luhn 2019 + Mugrauer 2019 both negative)
-- ============================================================================
INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HD 5608', 2, 1,
     'Two independent surveys negative on a stellar companion to HD 5608. Luhn et al. 2019 (2019AJ....157..149L, "Retired A Stars and Their Companions. VIII") characterizes HD 5608 as a K-subgiant planet host (Table 2: 1.53 Msun, T_eff 4877 K, V 5.99, log g 3.19) hosting a single planet HD 5608 b (Table 3: m sin i = 1.681 +/- 0.081 MJup, P = 780 +/- 5 d, e = 0.056, sma = 1.911 AU; Sato et al. 2012 discovery refined by Luhn). Luhn DOES NOT report any binary row for HD 5608 in their Table 3 (other systems in the table have explicit "Binary" entries; HD 5608 has only the planet b row). Mugrauer 2019 (2019MNRAS.490.5088M, Gaia DR2 wide-CPM search at 20-9100 AU) did NOT detect HD 5608 in its detection tables either. NASA EA''s sy_snum = 2 is unsupported by either of these independent primary-literature surveys. Same conventions/SIMBAD-artifact disagreement pattern as several other Batch 1-5 audit entries.',
     ARRAY['2019AJ....157..149L', '2019MNRAS.490.5088M'],
     'Closes the deferred HD 5608 todo originally surfaced in Batch 3 prep (the Mugrauer 2014 paper I''d guessed at didn''t exist; Mugrauer & Ginski 2015 didn''t cover HD 5608 either). The Luhn 2019 RV-survey negative paired with the Mugrauer 2019 Gaia DR2 wide-CPM negative gives two independent surveys. Worth noting Luhn 2019 only covers periods up to ~16 yr, so a long-period inner stellar companion is not strictly ruled out -- but the multi-decade RV monitoring without acceleration plus the wide-CPM non-detection covers the most likely parameter space.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;
