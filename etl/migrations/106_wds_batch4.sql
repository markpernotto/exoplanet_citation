-- WDS curation Batch 4 (2026-06-22 / 2026-06-23). Fourth pass against the
-- 82-host WDS gap list. Six binary_companions rows, all CPM-confirmed
-- M-dwarf stellar companions to HAT-P transiting-planet hosts,
-- harvested from two papers in the Caltech "Friends of Hot Jupiters"
-- (FOHJ) imaging campaign:
--
--   Ngo et al. 2015 (2015ApJ...800..138N, FOHJ II) -- Keck NIRC2 AO of
--     50 short-period gas giant host stars; 19 stellar companions found.
--     Source for HAT-P-14 B and HAT-P-33 B (both close-in M dwarfs).
--
--   Ngo et al. 2016 (2016ApJ...827....8N, FOHJ IV) -- follow-up Keck
--     NIRC2 AO of 77 hot-Jupiter hosts, with CPM confirmation across
--     multiple epochs. Source for HAT-P-27, HAT-P-29, HAT-P-35, and
--     HAT-P-39 stellar companions (all confirmed comoving via two-
--     epoch astrometry).
--
-- HAT-P-29 is a partial special case: Ngo 2016 finds a WIDE M dwarf B
-- at 3.298 arcsec / ~1062 AU, but Knutson et al. 2014 (2014ApJ...785..126K,
-- the FOHJ I RV survey) detected a statistically significant RV trend
-- around HAT-P-29 implying an additional INNER companion at 2-36 AU with
-- mass 1-200 MJup that AO could not resolve. This inner trend is mentioned
-- in B's curator notes; it is NOT curated as its own row pending direct
-- characterization. The wide B at 1062 AU is too far and too low-mass to
-- cause the observed RV trend.
--
-- HAT-P-35 is a confirmed HIERARCHICAL TRIPLE: this migration adds the
-- CLOSE B at 0.932 arcsec / ~499 AU (Ngo 2016) which complements the
-- existing WIDE C at 9.018 arcsec / ~4637 AU (Mugrauer 2019; row added
-- in an earlier curation pass). Together A + B + C account for NASA EA's
-- sy_snum = 3.
--
-- Cross-confirmation data from Wöllert & Brandner 2015 (2015A&A...579A.129W,
-- AstraLux Lucky imaging) is mentioned in the curator notes for HAT-P-27,
-- HAT-P-29, and HAT-P-35 where their independent astrometry agrees with
-- the Ngo measurements within errors.
--
-- Apply after 105_wds_batch3.sql. Idempotent.


-- ============================================================================
-- HAT-P-14
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-14', 'B', 'A', 'M4-M5', 0.857,
     176, 0.21, false, 3310, false,
     'wide M-dwarf companion (Keck NIRC2 AO; CPM-confirmed across three epochs 2012-2014)', 'manual', '2015ApJ...800..138N',
     'HAT-P-14 B: M4-M5 dwarf companion to F6 planet host. Ngo et al. 2015 (FOHJ II) Keck NIRC2 AO across three '
     'epochs: rho = 857.6 +/- 1.5 mas (2012-Jun-05, K''), 857.4 +/- 1.5 (2013-Mar-26, Ks), 856.9 +/- 1.6 '
     '(2014-Jul-07, Ks) -- positionally stable, confirming CPM. PA = 264.10 deg (2012), 264.24 deg (2013), '
     '264.38 deg (2014). DK'' = 5.633 +/- 0.033 (2012), DKs = 5.647 (2013), 5.844 (2014) against the F6 primary '
     '(T_eff = 6671 K, M = 1.418 Msun). Companion T_eff = 3263-3356 K consistent across all bands, mass 0.187-'
     '0.232 Msun from photometric analysis -- recorded midpoints 3310 K and 0.21 Msun. Projected separation '
     '176 AU at d = 205 +/- 11 pc (Torres 2010). Stable astrometric measurements over 2+ years confirm CPM '
     'rather than chance background alignment.')
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
-- HAT-P-27
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-27', 'B', 'A', 'M3-M4', 0.656,
     133, 0.31, false, 3460, false,
     'close M-dwarf companion (Keck NIRC2 AO; CPM-confirmed; Wöllert & Brandner 2015 cross-confirms)', 'manual', '2016ApJ...827....8N',
     'HAT-P-27 B: M3-M4 dwarf companion to G7 planet host (also designated WASP-40). Ngo et al. 2016 (FOHJ IV) '
     'Keck NIRC2 AO across multiple epochs 2014-2015: rho = 656.0 +/- 1.5 mas (2014-Jul-12), 653.9 +/- 1.5 '
     '(2015-Jan-09), 652.8 +/- 1.5 (2015-Jun-24) -- positionally stable. PA stable near 25.5 deg. DJ = 3.38, '
     'DH = 3.14, DKs = 3.38-3.52 mag. Cross-confirmation from Wollert & Brandner 2015 (2015A&A...579A.129W) '
     'AstraLux Lucky imaging at Calar Alto: rho = 656 +/- 21 mas (2013-Jun-27, i+z), 644 +/- 7 mas '
     '(2015-Mar-09, i+z) at PA ~26-28 deg -- agrees with Ngo within errors. Companion T_eff = 3433-3479 K, '
     'mass 0.298-0.323 Msun (recorded midpoints 3460 K and 0.31 Msun). Projected separation 133 AU at d = '
     '204 +/- 14 pc (Beky 2011 discovery cite for host).')
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
-- HAT-P-29
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-29', 'B', 'A', 'M6-M8', 3.298,
     1062, 0.10, false, 2855, false,
     'wide very-late-M-dwarf companion (Ngo 2016 recovery after initial miss; Wöllert 2015 + Ngo 2015 cross-checks)', 'manual', '2016ApJ...827....8N',
     'HAT-P-29 B: very late M-dwarf (M6-M8 by T_eff) companion to F8 planet host. Ngo et al. 2016 (FOHJ IV) '
     'recovered this faint companion after Wollert & Brandner 2015 first reported it; Ngo et al. (2015) had '
     'originally missed it in their 2012 imaging. Multi-epoch astrometry: rho = 3290 +/- 2 mas (2012-Feb-02, '
     'K''), 3298 +/- 2 (2015-Jul-05, Ks), 3293 +/- 4 (2015-Jul-10, BrG) -- positionally stable across 3.5 '
     'years. PA = 159.89-159.57 deg, also stable. DKs ~6.30-6.92 mag (variability across epochs reflects '
     'low-S/N at this contrast). T_eff = 2710-2955 K, mass 0.0942-0.115 Msun -- right at the M/L spectral '
     'class boundary, recorded midpoints 2855 K and 0.10 Msun. Projected separation 1062 AU at d = 322 '
     '(+35, -21) pc. Wollert & Brandner 2015 cross-confirms astrometry: rho = 3285 +/- 50 (2014-Oct-21), '
     '3276 +/- 104 (2015-Mar-06) at PA ~160-161 deg. SEPARATE INNER COMPANION INDICATOR: Knutson et al. '
     '2014 (FOHJ I RV survey, 2014ApJ...785..126K) detected a statistically significant RV acceleration '
     '(gamma-dot = 0.0498 +0.0092/-0.0100 m/s/day) at HAT-P-29 that is INCONSISTENT with this wide B (too '
     'far and too low-mass to cause the trend); Knutson estimate is 1-200 MJup at 2-36 AU. The inner trend '
     'is plausibly explained by an unseen substellar/stellar companion not direct-imaged, making HAT-P-29 '
     'potentially a hierarchical system. Inner component NOT curated as its own row pending direct '
     'characterization (could be brown dwarf or planet rather than star).')
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
-- HAT-P-33
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-33', 'B', 'A', 'M3V', 0.307,
     119, 0.52, false, 3715, false,
     'close-in M-dwarf companion (Keck NIRC2 AO; missed by lower-contrast surveys at this tight separation)', 'manual', '2015ApJ...800..138N',
     'HAT-P-33 B: early M dwarf (M3V approx, T_eff 3715 K) companion to F4 planet host at very close '
     'separation. Ngo et al. 2015 (FOHJ II) Keck NIRC2 AO: rho = 307.2 +/- 1.5 mas (2012-Feb-02, K''), 306.3 '
     '+/- 1.5 (2013-Mar-02, Ks) -- positionally stable, confirming CPM. PA = 117.86 deg (2012), 118.05 deg '
     '(2013). DK'' = 3.94 mag (2012), DKs = 3.42 (2013). T_eff = 3653 K (2012) and 3776 K (2013), mass 0.493 '
     'and 0.557 Msun (recorded midpoints 3715 K and 0.52 Msun). Projected separation 119 AU at d = 387 +/- '
     '9 pc (Hartman 2011c). Three other AO/lucky-imaging surveys (Adams 2013, Wollert & Brandner 2015 with '
     'detection limit Dz'' = 3.86 mag at 0.25 arcsec, and Knutson 2014 with no statistically significant RV '
     'acceleration) did NOT detect this companion -- the 0.31 arcsec separation falls right at their '
     'sensitivity limit for M-dwarf-vs-F4-primary contrast in z'' or i band. Ngo''s NIRC2 K-band AO has '
     'better sensitivity for cool M dwarfs and clearly detects it.')
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
-- HAT-P-35  (close B, complementing existing wide C from Mugrauer 2019)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-35', 'B', 'A', 'M3-M4', 0.932,
     499, 0.40, false, 3544, false,
     'close M-dwarf companion in hierarchical triple A + B + C (wide C at 4637 AU from Mugrauer 2019)', 'manual', '2016ApJ...827....8N',
     'HAT-P-35 B: close M dwarf (M3-M4 by T_eff 3525-3563 K) companion to F6 planet host. Ngo et al. 2016 '
     '(FOHJ IV) Keck NIRC2 AO: rho = 932.1 +/- 1.5 mas (2013-Mar-02, Ks), 931.9 +/- 1.5 (2014-Nov-10, Ks) -- '
     'positionally stable, confirming CPM. PA = 139.27-139.31 deg, stable across epochs. DJ = 4.33 (2013), '
     '3.73 (2014); DH = 3.29 (2014); DKs = 3.19 (2013), 3.56 (2014). Wollert & Brandner 2015 cross-confirms '
     'at rho = 933 +/- 10 mas (2015-Mar-09) at PA 139.8 deg. Mass 0.383-0.428 Msun, recorded midpoints 3544 '
     'K and 0.40 Msun. Projected separation 499 AU at d = 535 +/- 32 pc (Bakos 2012). HIERARCHICAL TRIPLE: '
     'this close B at ~499 AU complements the wide C at 9.018 arcsec / ~4637 AU (Mugrauer 2019, '
     '2019MNRAS.490.5088M, Gaia DR2 wide CPM detection; M2V, 0.515 Msun, T_eff 3728 K) that was added in an '
     'earlier curation pass. Together A + B (close) + C (wide) account for NASA EA sy_snum = 3.')
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
-- HAT-P-39
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-39', 'B', 'A', 'M3-M4', 0.900,
     577, 0.37, false, 3525, false,
     'M-dwarf companion (Keck NIRC2 AO; CPM-confirmed across two epochs)', 'manual', '2016ApJ...827....8N',
     'HAT-P-39 B: M3-M4 dwarf (T_eff 3477-3558 K) companion to F-type planet host. Ngo et al. 2016 (FOHJ IV) '
     'Keck NIRC2 AO: rho = 898.0 +/- 1.6 mas (2013-Mar-02, Ks), 900.4 +/- 1.7 (2014-Nov-07, Ks) -- '
     'positionally stable, confirming CPM. PA = 94.31 deg (2013), 94.40 deg (2014). DJ = 5.58 (2013), 4.69 '
     '(2014); DH = 4.06 (2014); DKs = 4.17 (2013), 4.40 (2014). Mass 0.324-0.422 Msun, recorded midpoints '
     '3525 K and 0.37 Msun. Projected separation 577 AU at d = 641 (+115, -66) pc (Hartman 2012). '
     'Photometric variability across epochs partially reflects measurement precision at this contrast '
     'regime; positional astrometry is highly consistent.')
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
