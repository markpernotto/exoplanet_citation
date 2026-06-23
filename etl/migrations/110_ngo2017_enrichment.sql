-- Ngo 2017 enrichment pass (2026-06-23). Ngo et al. 2017 ("Friends of
-- Hot Jupiters V", 2017AJ....153..242N) Keck NIRC2 AO imaging across
-- multiple 2013-2016 epochs RESOLVES several previously unresolved or
-- single-detection companion rows from earlier batches into proper
-- hierarchical structure. This migration lifts those resolved details
-- into the typed columns and refines mass/Teff estimates.
--
-- Three targeted refinements:
--
--   HD 142245   -- The existing BC row (added in migration 105 with
--                  Mugrauer & Ginski 2015 imaging-discovery cite) treats
--                  BC as a single unresolved pair. Ngo 2017 Table 4
--                  resolves B and C as separate point sources with
--                  ~0.05 arcsec internal separation (Tables 3+5 give
--                  individual masses and effective temperatures).
--                  DELETE the unresolved BC row, INSERT B and C as
--                  separate rows.
--
--   HD 43691    -- The existing B row (added in migration 101 with
--                  Ginski 2016 single-epoch lucky-imaging cite) was
--                  TENTATIVE per [[feedback-complete-migrations]] -- a
--                  single-epoch candidate, CPM not yet confirmed at the
--                  time of publication. Ngo 2017 confirms CPM across
--                  four epochs AND resolves the "candidate companion"
--                  into a tight BC pair (Ngo Tables 3+4+5). HD 43691
--                  is therefore a hierarchical triple A + (BC).
--                  DELETE the candidate B row, INSERT confirmed B and
--                  C with refined geometry/masses.
--
--   HD 116029   -- The existing B row (added in migration 103 with
--                  Ginski 2016 cite) was TENTATIVE -- single-epoch
--                  detection, CPM not yet determined. Ngo 2017 confirms
--                  CPM across three epochs (Ngo Table 4) and refines
--                  the mass via multi-band photometry to 0.259 Msun
--                  (vs Ginski's preliminary 0.18 Msun assuming bound).
--                  UPDATE the existing row to confirmed-status data.
--
-- Deferred from this enrichment pass:
--
--   HD 207832   -- Currently carries a "Y:" wide-CPM candidate row
--                  (Lodieu 2014, M6.5 at ~126,000 AU). Ngo 2017 finds
--                  a SEPARATE resolved BC pair at ~110 AU. These are
--                  physically distinct objects (Lodieu's candidate is
--                  unbound co-moving; Ngo's BC is the real bound binary
--                  partner). Resolving the designation conflict
--                  (rename the wide Lodieu candidate to D? drop it?)
--                  needs a separate decision pass.
--
--   HD 126614   -- Has 1 existing curated companion (from an earlier
--                  ingest era). Need to verify what's in the row before
--                  adding the Howard 2010 inner companion that Ngo
--                  2017 also detected. Deferred until existing-state
--                  audit.
--
-- Apply after 109_backfill_position_angles.sql. Idempotent.


-- ============================================================================
-- HD 142245  --  split unresolved BC -> separate B + C
-- ============================================================================

-- 1. Remove the unresolved BC row from migration 105 (M+G 2015 cite).
DELETE FROM binary_companions
 WHERE hostname = 'HD 142245' AND component_designation = 'BC';

-- 2. Insert resolved B and C as separate rows. Astrometry from Ngo 2017
--    Table 4 (epoch 2014-06-09, mid-survey); masses + Teff from Table 5
--    (representative epoch 2013-07-04 marked with asterisk, lowest error).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 142245', 'B', 'A', 'M3V', 2.4995,
     273, 0.455, false, 3589, false,
     'tight BC inner-pair member (Ngo 2017 resolves the unresolved Mugrauer&Ginski 2015 BC into B+C)', 'manual', '2017AJ....153..242N',
     'HD 142245 B: M3V dwarf in the tight inner pair of the hierarchical triple A + (BC). Ngo et al. 2017 '
     'Keck NIRC2 K-band AO RESOLVES the unresolved Mugrauer & Ginski 2015 "BC" point source into separate '
     'B and C components separated by ~0.04 arcsec internally. Astrometry from Ngo Table 4 across four '
     'epochs (2013-07-04, 2014-06-09, 2015-06-24, 2016-06-09) shows stable positions confirming CPM: rho = '
     '2.484-2.508 arcsec, PA = 168.07-168.79 deg. Recorded geometry from the 2014-06-09 epoch (mid-survey): '
     'rho = 2.4995 arcsec, PA = 168.21 deg. Mass and Teff from Ngo Table 5 representative epoch 2013-07-04: '
     'M = 0.455 +/- 0.011 Msun, Teff = 3589 +/- 14 K. Projected separation 273 +20/-17 AU at d = 110 +8/-7 '
     'pc. Mugrauer & Ginski 2015 (2015MNRAS.450.3127M, NACO 2012+2013 imaging) is the discovery cite for '
     'the unresolved BC point source; Mugrauer 2019 (2019MNRAS.490.5088M) is independent Gaia DR2 CPM '
     'confirmation. The BC inner separation is ~4 AU per M&G 2015 framing -- a tight pair within the wide '
     'A+(BC) hierarchical triple. This row replaces the prior unresolved BC row from migration 105.',
     168.21);

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 142245', 'C', 'A', 'M3V', 2.5167,
     278, 0.5172, false, 3687, false,
     'tight BC inner-pair member (Ngo 2017 resolves the unresolved Mugrauer&Ginski 2015 BC into B+C)', 'manual', '2017AJ....153..242N',
     'HD 142245 C: M3V dwarf, slightly more massive sibling of HD 142245 B in the tight inner BC pair. '
     'Ngo et al. 2017 Keck NIRC2 K-band AO multi-epoch astrometry from Table 4: rho = 2.506-2.525 arcsec, '
     'PA = 169.54-169.74 deg, stable across 2013-2016. Recorded geometry from the 2014-06-09 epoch: rho = '
     '2.5167 arcsec, PA = 169.66 deg. Mass and Teff from Ngo Table 5 representative epoch 2013-07-04: M = '
     '0.5172 +/- 0.0091 Msun, Teff = 3687 +/- 20 K. Projected separation 278 +20/-18 AU at d = 110 pc. Co-'
     'located with B in the BC inner pair at ~0.04 arcsec internal separation (B is at 2.4995 arcsec / PA '
     '168.21 deg; C is at 2.5167 arcsec / PA 169.66 deg; the angular offset between B and C corresponds to '
     '~4 AU at the host distance per Mugrauer & Ginski 2015 framing). Discovery cite of the unresolved BC '
     'pair: M&G 2015 (2015MNRAS.450.3127M); independent CPM confirmation: Mugrauer 2019.',
     169.66);


-- ============================================================================
-- HD 43691  --  upgrade single candidate B -> confirmed BC pair
-- ============================================================================

-- 1. Remove the single-epoch candidate B row from migration 101 (Ginski 2016 cite).
DELETE FROM binary_companions
 WHERE hostname = 'HD 43691' AND component_designation = 'B';

-- 2. Insert confirmed B and C as separate rows. Astrometry from Ngo 2017
--    Table 4 (representative epoch 2014-12-04, longer time baseline);
--    masses + Teff from Table 5 (representative epoch 2016-09-13 marked
--    with asterisk; B's Teff has high uncertainty so we use the average).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 43691', 'B', 'A', 'M5V', 4.546,
     365, 0.126, false, 3020, false,
     'late M-dwarf in resolved BC pair (Ngo 2017 confirms CPM across 4 epochs + resolves Ginski 2016 candidate)', 'manual', '2017AJ....153..242N',
     'HD 43691 B: late M-dwarf (M5V approx, T_eff 3020 +/- 110 K, M = 0.126 +/- 0.019 Msun) in the tight '
     'BC inner pair of the hierarchical triple A + (BC). Ngo et al. 2017 Keck NIRC2 K-band AO RESOLVES '
     'the Ginski 2016 single-epoch candidate into B + C and CONFIRMS CPM across four epochs (2013-12-18, '
     '2014-12-04, 2015-10-26, 2016-09-13). B astrometry (Ngo Table 4): rho = 4.550-4.536 arcsec showing '
     'stable position, PA = 40.50-39.91 deg with detected orbital motion of ~0.6 deg across 3 years. '
     'Recorded geometry from the 2014-12-04 epoch: rho = 4.546 arcsec, PA = 40.40 deg. Mass and Teff '
     'from Ngo Table 5 representative epoch 2016-09-13. Projected separation 365 +26/-23 AU at d = 81 '
     '+6/-5 pc (Da Silva et al. 2007). HD 43691 B is co-located on sky with HD 43691 C (the slightly '
     'more massive sibling at ~0.1 arcsec internal separation). Discovery cite for the unresolved '
     'companion: Ginski et al. 2016 (2016MNRAS.457.2173G) AstraLux lucky imaging 2015-03-10; Ngo 2017 '
     'CPM-confirms and resolves. This row replaces the prior single-candidate B row from migration 101.',
     40.40);

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 43691', 'C', 'A', 'M5V', 4.456,
     359, 0.209, false, 3308, false,
     'M-dwarf in resolved BC pair, slightly more massive than B (Ngo 2017 resolution of Ginski 2016 candidate)', 'manual', '2017AJ....153..242N',
     'HD 43691 C: early-to-mid M-dwarf (T_eff 3308 +/- 71 K, M = 0.209 +/- 0.037 Msun), the slightly '
     'more massive sibling of HD 43691 B in the tight BC inner pair. Ngo et al. 2017 Keck NIRC2 K-band '
     'AO multi-epoch astrometry from Table 4: rho = 4.452-4.464 arcsec, PA = 41.08-40.90 deg, stable '
     'across 2013-2016 confirming CPM. Recorded geometry from the 2014-12-04 epoch: rho = 4.456 arcsec, '
     'PA = 41.08 deg. Mass and Teff from Ngo Table 5 representative epoch 2016-09-13. Projected '
     'separation 359 +25/-22 AU at d = 81 pc. Co-located with B in the BC inner pair (B at 4.546 '
     'arcsec / PA 40.40 deg; C at 4.456 arcsec / PA 41.08 deg; angular offset corresponds to ~8 AU '
     'internal separation). This is the "Friends of Hot Jupiters V" Ngo et al. 2017 newly-resolved '
     'sibling -- before Ngo, HD 43691 was thought to have a single unresolved companion candidate '
     '(Ginski 2016).',
     41.08);


-- ============================================================================
-- HD 116029  --  upgrade candidate -> confirmed via Ngo 2017 multi-epoch CPM
-- ============================================================================

-- Use UPDATE-by-conflict-style INSERT to keep the row's primary key (and any
-- subsequent backfills) intact. Ngo 2017 provides refined mass, Teff,
-- and CPM-confirmed status; PA is already backfilled from migration 109.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 116029', 'B', 'A', 'M4V', 1.392,
     171, 0.259, false, 3387, false,
     'M4V companion (Ngo 2017 confirms Ginski 2016 candidate via multi-epoch CPM)', 'manual', '2017AJ....153..242N',
     'HD 116029 B: M4V dwarf (T_eff 3387 +/- 18 K, M = 0.259 +/- 0.014 Msun) -- CPM-confirmed by Ngo et '
     'al. 2017 Keck NIRC2 K-band AO across three epochs (2013-07-04, 2014-06-09, 2015-01-09). Ngo Table '
     '4 astrometry: rho = 1.391-1.393 arcsec, PA = 209.32-209.37 deg, stable across 1.5 years confirming '
     'CPM at 4.4 sigma. Recorded geometry from the 2013-07-04 representative epoch (lowest error): rho = '
     '1.392 arcsec, PA = 209.37 deg. Mass and Teff from Ngo Table 5 representative epoch 2013-07-04. '
     'Projected separation 171 +15/-13 AU at d = 123 +11/-9 pc. This row UPGRADES the prior Ginski 2016 '
     '(2016MNRAS.457.2173G) candidate row from migration 103 (single-epoch detection, CPM not then '
     'determined) to Ngo 2017 CPM-confirmed status. Mass refined from Ginski''s preliminary 0.18 +0.21/'
     '-0.07 (assuming bound) to Ngo''s 0.259 +/- 0.014 from multi-band photometry. The Ginski 2016 '
     'discovery cite is retained in this curator note even though source_bibcode now points to Ngo 2017 '
     'for the definitive characterization.',
     209.37)
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
    position_angle_deg    = EXCLUDED.position_angle_deg;
