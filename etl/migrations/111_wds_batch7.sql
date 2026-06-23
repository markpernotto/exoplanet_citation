-- WDS curation Batch 7 (2026-06-23). Seventh pass against the WDS gap
-- list. Three binary_companions rows, all from papers already in hand
-- from earlier batch pastes (Ngo 2017 for HD 30856, Ngo 2015 for
-- WASP-3, Ngo 2016 for WASP-58 with Wollert & Brandner 2015 cross-
-- confirmation).
--
-- Systems and citations:
--
--   HD 30856 B  -- Ngo et al. 2017 ("Friends of Hot Jupiters V") Keck
--                  NIRC2 K-band AO across three epochs (2014-10-04,
--                  2014-12-07, 2015-10-26). Astrometry stable: rho =
--                  786-789 mas, PA = 108.6-108.8 deg. Mass 0.537 +/-
--                  0.013 Msun, Teff 3731 +/- 29 K -> M2V. Projected
--                  separation 92 AU at d = 118 +11/-9 pc (Johnson et
--                  al. 2011 host parameters cited by Ngo 2017 Table 2,
--                  ultimately from van Leeuwen 2007 Hipparcos).
--
--   WASP-3 B    -- Ngo et al. 2015 ("Friends of Hot Jupiters II") Keck
--                  NIRC2 detection across three epochs (2012-06-05,
--                  2012-07-27, 2013-05-31). Astrometry: rho = 1189-
--                  1192 mas, PA = 87.07-87.17 deg, stable. Mass ~0.11
--                  Msun, Teff ~2900 K -- very late M dwarf right at
--                  the H-burning limit. Photometry: DK' = 6.53-6.64
--                  mag, DKs = 6.55 mag against the F7V/F6V host.
--                  Projected separation 262 AU at d = 220 +/- 20 pc.
--                  This row COMPLEMENTS the existing wide WASP-3 C
--                  from Mugrauer 2019 (2019MNRAS.490.5088M, Gaia DR2
--                  CPM at 20-9100 AU range) -- WASP-3 is a triple
--                  A + B (close, this row) + C (wide).
--
--   WASP-58 B   -- Ngo et al. 2016 ("Friends of Hot Jupiters IV") Keck
--                  NIRC2 BrG-band AO at 2015-07-10. rho = 1286.0 +/-
--                  1.6 mas, PA = 183.36 +/- 0.07 deg. Cross-confirmed
--                  by Wollert & Brandner 2015 (2015A&A...579A.129W)
--                  AstraLux lucky imaging at 2013-06-25: rho = 1275
--                  +/- 15 mas, PA = 183.2 +/- 0.4 deg. Mass 0.265 +/-
--                  0.042 Msun, Teff 3396 +/- 53 K -> M3-M4V. Projected
--                  separation 384 +/- 64 AU at d = 300 +/- 50 pc
--                  (Hebrard et al. 2013 host).
--
-- Apply after 110_ngo2017_enrichment.sql. Idempotent.


-- ============================================================================
-- HD 30856 B
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 30856', 'B', 'A', 'M2V', 0.789,
     92, 0.537, false, 3731, false,
     'M2V companion (Keck NIRC2 AO, CPM-confirmed across three epochs 2014-2015)', 'manual', '2017AJ....153..242N',
     'HD 30856 B: M2V dwarf companion (Teff 3731 +/- 29 K, M = 0.537 +/- 0.013 Msun from Ngo Table 5 '
     'representative epoch 2015-10-26 marked with asterisk for lowest error). Ngo et al. 2017 ("Friends '
     'of Hot Jupiters V") Keck NIRC2 K-band AO multi-epoch astrometry from Table 4: rho = 789.4 +/- 1.5 '
     'mas (2014-10-04), 788.7 +/- 1.5 (2014-12-07), 786.3 +/- 1.5 (2015-10-26) -- positionally stable, '
     'confirming CPM. PA = 108.6-108.8 deg, also stable. Photometry across J and K bands (Ngo Table 3): '
     'DJc = 4.71-4.91 mag, DKc = 4.82-5.25 mag against the K-giant subgiant host (Mhost = 1.35 +/- 0.09 '
     'Msun, Teff 4982 K, log g 3.40 per Ngo Table 2 citing Johnson et al. 2011). Projected separation '
     '93 AU at d = 118 +11/-9 pc (van Leeuwen 2007 Hipparcos). HD 30856 is one of "three new multi-'
     'stellar systems" announced for the first time in Ngo 2017 (the others being HD 86081 and '
     'HD 207832).',
     108.8);


-- ============================================================================
-- WASP-3 B (close, complements existing wide C from Mugrauer 2019)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-3', 'B', 'A', 'M9-L0', 1.191,
     262, 0.111, false, 2922, false,
     'very-late M / L0 boundary close companion (Keck NIRC2 AO, CPM-confirmed across three epochs)', 'manual', '2015ApJ...800..138N',
     'WASP-3 B: very-late M dwarf / brown-dwarf boundary object (Teff = 2871-2922 K, M = 0.105-0.111 '
     'Msun -- right at the canonical 0.075 Msun H-burning limit; recorded representative values from '
     'Ngo Table 8 2013-05-31 epoch: Teff 2922 +/- 48 K, M = 0.1109 +/- 0.0058 Msun). Ngo et al. 2015 '
     '("Friends of Hot Jupiters II") Keck NIRC2 K-band AO multi-epoch astrometry from Table 5: rho = '
     '1192.2 +/- 1.6 mas (2012-06-05, K''), 1191.0 +/- 1.5 (2012-07-27, K''), 1189.1 +/- 1.6 (2013-05-31, '
     'Ks) -- positionally stable, confirming CPM. PA = 87.07-87.17 deg, stable. Photometry: DK'' = 6.53-'
     '6.64 mag, DKs = 6.55 mag against the F7V host (Mhost = 1.20 Msun, Teff 6375 K, [Fe/H] -0.06). '
     'Projected separation 262 AU at d = 220 +/- 20 pc (Ngo 2015 Table 2 citing Triaud et al. 2014). '
     'COMPLEMENTS the existing WASP-3 C row from Mugrauer 2019 (2019MNRAS.490.5088M, Gaia DR2 wide-CPM '
     'detection at the 20-9100 AU range; marked with the asterisk hierarchical-triple flag in Mugrauer '
     '2019 Table 1). Together A + B (close, 262 AU) + C (wide) account for the hierarchical triple '
     'system; this row adds the close B that Mugrauer 2019 could not resolve at Gaia DR2''s typical '
     '0.5 arcsec floor.',
     87.10);


-- ============================================================================
-- WASP-58 B
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-58', 'B', 'A', 'M3-M4V', 1.286,
     384, 0.265, false, 3396, false,
     'M3-M4V companion (Keck NIRC2 BrG-band AO; Wollert & Brandner 2015 cross-confirms)', 'manual', '2016ApJ...827....8N',
     'WASP-58 B: M3-M4V dwarf (Teff = 3396 +/- 53 K, M = 0.265 +/- 0.042 Msun, log g = 5.00 per Ngo '
     'Table 6 derived parameters). Ngo et al. 2016 ("Friends of Hot Jupiters IV") Keck NIRC2 BrG-band '
     'AO at 2015-07-10 (Table 5): rho = 1286.0 +/- 1.6 mas, PA = 183.36 +/- 0.07 deg. CROSS-CONFIRMED '
     'by Wollert & Brandner 2015 (2015A&A...579A.129W) AstraLux Calar Alto lucky imaging at 2013-06-25: '
     'rho = 1275 +/- 15 mas, PA = 183.2 +/- 0.4 deg (also in Ngo Table 5 reference). Two independent '
     'detections two years apart confirm CPM. Photometry: DJc = 4.62 +/- 0.14 mag, DKs = 4.39 +/- 0.10 '
     'mag against the G2V planet-host primary (Mhost = 0.94 +/- 0.1 Msun, Teff 5800 K, d = 300 +/- 50 '
     'pc per Hebrard et al. 2013). Projected separation 384 +/- 64 AU at the host distance.',
     183.36);
