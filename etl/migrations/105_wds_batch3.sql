-- WDS curation Batch 3 (2026-06-22). Third pass against the 82-host WDS
-- gap list. Five binary_companions rows + one sy_snum_audit row, drawn
-- from five primary-source papers identified during the user's deep dive
-- on HD-prefixed double hosts. Mostly Roberts 2011 + Chauvin 2007 +
-- Rodigas 2016 + Ortiz 2016 + Mugrauer & Ginski 2015 + Mugrauer 2019.
--
-- One host (HD 5608) is deferred from this batch pending more research
-- (Mugrauer 2019 + Mugrauer & Ginski 2015 both negative on coverage; need
-- to check the Sato et al. discovery paper or SIMBAD for the reference
-- behind NASA EA's sy_snum = 2 claim).
--
-- Systems and citations:
--   HD 142245     -- Mugrauer & Ginski 2015 (2015MNRAS.450.3127M, NACO
--                    lucky imaging, two epochs, CPM-confirmed at 5.7
--                    sigma vs background hypothesis). REPLACES the
--                    existing Mugrauer 2019 BC row with the actual
--                    imaging-discovery paper that also identifies BC
--                    itself as a likely close binary at ~4 AU,
--                    making HD 142245 a hierarchical A + (BC) triple
--                    -- one of the few exoplanet-host triples currently
--                    known (Mugrauer & Ginski 2015 Table 6).
--                    Mugrauer 2019 retained in notes as Gaia DR2 CPM
--                    confirmation reference.
--   HD 196885 A   -- Chauvin 2007 (2007A&A...475..723C) NACO follow-up
--                    that confirmed CPM and spectroscopically classified
--                    B as M1 +/- 1V. Discovery cite Chauvin 2006
--                    (2006A&A...456.1165C) retained in notes.
--   HD 7449       -- Rodigas 2016 (2016ApJ...818..106R) Magellan/MagAO
--                    direct imaging + RV combined MCMC. M4-M5 dwarf
--                    constrained to >0.17 Msun at 99 percent CL, a ~18
--                    AU; framed as the source of the long-term RV trend
--                    and a Kozai-oscillation candidate for the e ~0.8
--                    planet HD 7449Ab.
--   HD 59686 A    -- Ortiz 2016 (2016A&A...595A..55O) Lick + LBT/LMIRCam
--                    long-period RV characterization. Inner stellar
--                    binary B at 13.56 AU, e = 0.729 (one of the most
--                    eccentric exoplanet-host binaries known), m sin i
--                    = 0.530 Msun. Roberts 2011 (RBR 16, 5.61"/543 AU,
--                    DI = 4.60 mag) found a separate wider candidate
--                    around the same host but CPM is not confirmed by
--                    Roberts and Ortiz does not characterize it; mentioned
--                    in B's notes pending follow-up, NOT curated as
--                    its own row.
--   HD 177830     -- Roberts 2011 (2011AJ....142..175R) AEOS AO survey
--                    measurement. Discoverer designation EGN 24
--                    (Eggenberger et al. 2007) per WDS 19053+2555.
--                    rho = 1.62", PA = 84.1 deg, DI = 7.5 mag against
--                    the K2 III/IV primary; mass and spectype not
--                    given by Roberts (left NULL pending follow-up).
--
-- sy_snum disagreements:
--   HD 38529      -- Roberts 2011 (2011AJ....142..175R) imaged at AO and
--                    listed as UNRESOLVED at FWHM 0.17" (Table 4) -- no
--                    companion at the ~0.5 to ~5" scale. Mugrauer 2019
--                    (2019MNRAS.490.5088M, Gaia DR2 search at 20-9100 AU)
--                    did not detect a wide comoving companion either.
--                    NASA EA's sy_snum = 2 likely counts the 13.99 MJup
--                    deuterium-burning-boundary companion HD 38529 c
--                    as a star (Benedict et al. astrometric mass refines
--                    it firmly into the brown-dwarf-mass regime). Our
--                    catalog treats c as a substellar / planet-table
--                    companion, not as a stellar component contributing
--                    to sy_snum. Same conventions-disagreement pattern
--                    as HD 87646 (migration 104).
--
-- Apply after 104. Idempotent.


-- ============================================================================
-- HD 142245 BC  (UPDATE existing Mugrauer 2019 row with M+G 2015 imaging data)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 142245', 'BC', 'A', 'M1', 2.498,
     273, 0.56, false, NULL, false,
     'unresolved tight binary visual companion (potential hierarchical A + BC triple)', 'manual', '2015MNRAS.450.3127M',
     'HD 142245 BC: unresolved close pair imaged by Mugrauer & Ginski 2015 with NACO at ESO Paranal across two '
     'epochs (2012-08-31 and 2013-07-24). Astrometry: rho = 2.498 +/- 0.006" / PA = 169.15 +/- 0.16 deg (2012); '
     'rho = 2.494 +/- 0.006" / PA = 169.07 +/- 0.10 deg (2013). Common proper motion CONFIRMED at 5.7 sigma vs '
     'background hypothesis. From the NACO-derived absolute Ks magnitude (M_Ks = 4.64 +/- 0.16) and Baraffe 2003 '
     'evolutionary tracks at 5 Gyr default age: combined mass M(BC) ~ 0.56 Msun, combined spectral type ~M1. '
     'Projected separation 273 AU at the host''s distance. Mugrauer & Ginski 2015 explicitly identify HD 142245 '
     'BC as a likely close binary itself, with ~4 AU internal separation, making HD 142245 a hierarchical '
     'A + (BC) triple (Table 6, one of the few exoplanet-host triples known at the time). Mugrauer 2019 '
     '(2019MNRAS.490.5088M) independently confirms BC as comoving via Gaia DR2 astrometry; that paper''s combined '
     'mass estimate (0.621 +/- 0.004 Msun) is slightly higher than M+G 2015''s 0.56 Msun, the difference '
     'reflecting different photometric pipelines and age priors. This migration replaces the prior Mugrauer 2019 '
     '-derived row with the M+G 2015 discovery cite as primary; Mugrauer 2019 retained as CPM confirmation.')
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
-- HD 196885 A
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 196885 A', 'B', 'A', 'M1V', 0.714,
     25, 0.5, false, NULL, false,
     'close M-dwarf stellar companion (one of the closer resolved binaries hosting an exoplanet)', 'manual', '2007A&A...475..723C',
     'HD 196885 B: M1 +/- 1V dwarf in a close binary with the F8IV planet host A. rho = 0.714" / PA = 67.5 deg '
     'at epoch 2005-08-01 (NACO at VLT, Chauvin et al. 2007 Table 3); follow-up at epoch 2006-08-26 measured '
     'rho = 0.713" / PA = 65.7 deg, showing 1.8 deg of orbital motion in one year. Projected separation 25 AU '
     'at the host''s d = 33.0 pc. DKs = 3.1 mag against the F8IV primary (Chauvin 2007 Table 2, value from '
     'discovery cite Chauvin et al. 2006). Spectral type M1 classified spectroscopically by Chauvin 2007 via '
     'NACO long-slit + SINFONI integral field spectroscopy across 1.4-2.5 micron. Mass ~0.5 Msun from M1V '
     'mass-spectype relation (Chauvin 2007 confirms comoving status but does not derive a numerical mass). '
     'Chauvin 2007 framing: "one of the closer (~23 AU) resolved binaries known to host an exoplanet". '
     'Discovery cite Chauvin et al. 2006 (2006A&A...456.1165C); this paper (2007) is the CPM + spectroscopic '
     'characterization. Famous chaotic-near-resonance configuration.')
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
-- HD 7449
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 7449', 'B', 'A', 'M4-M5', 0.55,
     18, 0.2, false, NULL, false,
     'M4-M5 dwarf companion at ~18 AU; Kozai-oscillation candidate for planet b''s e ~0.8 orbit', 'manual', '2016ApJ...818..106R',
     'HD 7449 B: M4-M5 dwarf companion to the Sun-like planet host. Rodigas et al. 2016 Magellan/MagAO direct '
     'imaging at two epochs (2014-11-05 and 2014-11-22): rho = 0.55 +/- 0.007", PA = 339.99 +/- 1.84 deg, both '
     'epochs consistent. Photometry: DKs = 4.85 mag, DH = 5.11, DJ = 5.81, Dz = 6.53, Di = 7.32, Dr = 8.82. '
     'Mass from MCMC combining RV trend + direct imaging: M > 0.17 Msun at 99 percent confidence; SED analysis '
     'prefers 0.1-0.2 Msun consistent with M4-M5V. Semi-major axis ~18 AU from MCMC fit, with N-body '
     'simulations constraining eccentricity to e <~ 0.5. Likely identified as the source of the long-term RV '
     'trend in CORALIE + HARPS + Magellan/MIKE + Magellan/PFS data. Per Rodigas 2016, B may be inducing Kozai '
     'oscillations on planet HD 7449Ab (Mjup_min = 1.09, sma = 2.33 AU, e = 0.8); if the planet''s orbit was '
     'initially circular, its mass would need to be <~1.5 MJup for Kozai to explain the current eccentricity. '
     'CPM-confirmed (same Gaia parallax + bound by 99 percent MCMC).')
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
-- HD 59686 A
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     orbital_period_d, eccentricity, primary_mass_msun, primary_radius_rsun, primary_teff_k, primary_spectype)
VALUES
    ('HD 59686 A', 'B', 'A', 'M', NULL,
     13.56, 0.5296, true, NULL, false,
     'eccentric (e=0.73) inner stellar binary partner at 13.56 AU; planet b on circumprimary orbit', 'manual', '2016A&A...595A..55O',
     'HD 59686 A B: M-dwarf inner stellar binary partner, characterized by Ortiz et al. 2016 (Lick Hamilton + '
     'CRIRES + LBT/LMIRCam). RV-resolved orbit: m sin i = 0.5296 (+0.0011, -0.0008) Msun, sma = 13.56 (+0.18, '
     '-0.14) AU, P = 11680 (+234, -173) days (~32 yr), e = 0.729 (+0.004, -0.003), omega = 149.4 (+0.2, -0.2) '
     'deg. One of the most eccentric exoplanet-host stellar binaries known; Ortiz 2016 frames it as a severe '
     'challenge to standard giant planet formation theories in tight binaries, requiring second-generation '
     'formation or strong dynamical interactions to explain planet b''s presence (m_b sin i = 6.92 MJup, sma '
     '= 1.086 AU, P = 299 d, e = 0.05 on a circumprimary orbit around the A giant primary). Host A: K2 III '
     'giant (M = 1.9 +/- 0.2 Msun, R = 13.2 +/- 0.3 Rsun, T_eff = 4658 +/- 24 K, age 1.73 +/- 0.47 Gyr, d = '
     '96.8 pc per Hipparcos). inner_binary = false because the planet orbits A alone (S-type / circumprimary), '
     'not the AB pair. Roberts 2011 (RBR 16) AEOS AO observation found another candidate companion to HD 59686 '
     'at rho = 5.61", PA = 224.8 deg, DI = 4.60 mag (~543 AU projected at 96.8 pc); CPM status not confirmed '
     'by Roberts 2011, and Ortiz 2016 does not characterize it. Possible additional outer triple component but '
     'NOT curated as a separate row pending bound-vs-background determination. Spectral type of B left as M '
     '(M-dwarf class, not subclassified) since Ortiz does not classify spectroscopically -- the 0.53 Msun mass '
     'is consistent with M0-M1 from mass-spectype relations, but reported m sin i is a lower bound (true mass '
     'higher if i < 90 deg).',
     11680, 0.729, 1.9, 13.2, 4658, 'K2 III')
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
    primary_mass_msun     = EXCLUDED.primary_mass_msun,
    primary_radius_rsun   = EXCLUDED.primary_radius_rsun,
    primary_teff_k        = EXCLUDED.primary_teff_k,
    primary_spectype      = EXCLUDED.primary_spectype;


-- ============================================================================
-- HD 177830
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 177830', 'B', 'A', NULL, 1.62,
     100, NULL, false, NULL, false,
     'wide visual companion (Roberts AEOS AO; spectype and mass not characterized by source)', 'manual', '2011AJ....142..175R',
     'HD 177830 B: visual companion to the K2 III/IV planet-host A. WDS designation 19053+2555, discoverer '
     'designation EGN 24 -- the companion was first announced by Eggenberger et al. 2007 (the EGN code); '
     'Roberts et al. 2011 AEOS AO is the cited measurement here. Astrometry at epoch 2002.5474: rho = 1.62", '
     'PA = 84.1 deg, DI = 7.5 +/- 0.3 mag against the K-giant primary. Projected separation ~100 AU at d ~62 '
     'pc (Hipparcos). At DI = 7.5 against a K2 giant the companion is consistent with an M dwarf, but Roberts '
     '2011 does not derive a numerical mass or assign a subclass, so component_spectype and component_mass_msun '
     'left NULL pending follow-up photometric / spectroscopic classification. CPM-confirmed by the 192-year '
     'astrometric baseline through WDS rather than by Roberts directly.')
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
-- HD 38529  --  sy_snum disagreement, no binary_companions row added
-- ============================================================================
INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HD 38529', 2, 1,
     'No wide stellar companion detected for HD 38529 in two independent imaging / astrometric surveys. Roberts 2011 (AEOS AO survey, AEOS imager) listed HD 38529 in Table 4 as UNRESOLVED at FWHM = 0.17 arcsec (epoch 2001.8987), ruling out companions from ~0.5 to ~5 arcsec at the survey''s I-band contrast limits. Mugrauer 2019 (Gaia DR2 wide-CPM search across the 20 to 9100 AU range) did NOT detect a comoving companion to HD 38529 either; the host is not in Tables 1-4 of detected CPM companions and not in Table 5 of background-rejected candidates. NASA EA''s sy_snum = 2 most likely counts HD 38529 c, a 13.99 MJup deuterium-burning-boundary companion at sma = 3.7 AU (m sin i refined to brown-dwarf-mass via HST astrometry by Benedict et al.), as a star. Our catalog treats c as a substellar / planet-table companion, not a stellar component contributing to sy_snum. Same conventions disagreement pattern as HD 87646 in the migration 104 seed.',
     ARRAY['2011AJ....142..175R', '2019MNRAS.490.5088M'],
     'Two independent imaging-and-astrometric non-detections (close via Roberts 2011, wide via Mugrauer 2019) reinforce this case beyond the typical single-paper claim. The Benedict et al. brown-dwarf-mass result for HD 38529 c is mentioned in the rationale prose; not added to source_bibcodes pending exact bibcode verification.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;
