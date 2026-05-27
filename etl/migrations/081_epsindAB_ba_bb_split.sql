-- eps Ind A stellar architecture enrichment + SPLIT (manual literature
-- review, 2026-05-26). Thirteenth migration of the S-type stellar-
-- multiplicity audit. eps Ind A was previously deep-dived for atmosphere
-- in migration 065 (Matthews et al. 2024 Nature, eps Ind A b at T~275 K,
-- the coldest directly-imaged exoplanet). Stellar architecture work was
-- outstanding: catalog sy_snum = 3, binary_companions had only ONE row
-- (SIMBAD bulk-load entry labeled 'B' at 402.30 arcsec with combined
-- spectype "T1V+T6V" -- a real combined entry for the unresolved Ba+Bb
-- pair, not a mislabel).
--
-- LITERATURE-SPLIT (matches the K2-290 pattern from migration 080):
--   - eps Ind Ba and Bb are a resolved T-dwarf BINARY at ~402 arcsec from
--     eps Ind A (~1457 AU at the 3.62 pc system distance) -- the wide pair.
--     Within the wide pair, Ba and Bb are themselves bound on an 11.4-year
--     orbit (Dieterich et al. 2018 dynamical solution: P = 4165 ± 44 days,
--     e = 0.47 ± 0.02, i = 75.9° ± 0.4°, semi-major axes a_B = 1.267 AU
--     and a_C = 1.355 AU about the BC barycenter).
--   - Each component is individually characterized in McCaughrean 2004
--     (discovery + photometric mass) and Dieterich 2018 (dynamical mass
--     via VLT/NACO 6-epoch orbital astrometry combined with CTIOPI/CAPS
--     parallax data). DYNAMICAL masses are the gold-standard values and
--     are recorded here.
--
-- This migration DELETEs the combined SIMBAD 'B' row and INSERTs 'Ba' and
-- 'Bb' rows matching literature naming.
--
-- Bibcodes:
--   2018ApJ...865...28D -- Dieterich et al. 2018, "The Solar Neighborhood
--     XLV: The Stellar/Substellar Boundary Revisited", ApJ 865, 28. Source
--     for the DYNAMICAL masses: ε Ind Ba 75.0 ± 0.82 M_Jup = 0.0716 ±
--     0.0008 Msun, ε Ind Bb 70.1 ± 0.68 M_Jup = 0.0669 ± 0.00064 Msun
--     (Dieterich Table 4 weighted means). Spectral type refinement to
--     T1.5 (Ba) and T6 (Bb). Critical context: both objects sit right at
--     the H-burning boundary (~75 M_Jup; Dieterich Table 5), implying ε
--     Ind Ba is at or just above the stellar boundary while Bb is just
--     below. (The masses are an order of magnitude refinement over
--     McCaughrean's 1.3 Gyr photometric estimates because the system age
--     was revised UP from ~1.3 Gyr to ~3.5-5.7 Gyr.)
--   2004A&A...413.1029M -- McCaughrean et al. 2004, "eps Indi Ba, Bb: a
--     mature, resolved T dwarf binary at the very heart of our Solar
--     neighbourhood". Original NACO resolved-binary discovery; provides
--     internal Ba-Bb astrometry (0.732 arcsec / ~2.65 AU separation at
--     epoch 2004) and the spectral-typing framework. Kept as a secondary
--     cite for historical provenance.
--
-- The DELETE is restricted to the SIMBAD bulk-load entry (source_catalog =
-- 'SIMBAD' AND source_bibcode IS NULL); a more authoritative 'B' row would
-- not be touched. Idempotent.
--
-- Apply after 011_binary_companions.sql.

-- Step 1: remove the SIMBAD combined 'B' row.
DELETE FROM binary_companions
WHERE hostname = 'eps Ind A'
  AND component_designation = 'B'
  AND source_catalog = 'SIMBAD'
  AND source_bibcode IS NULL;

-- Step 2: insert per-component Ba (T1.5) + Bb (T6) entries from Dieterich 2018
-- dynamical masses + Table 1 system params, with McCaughrean 2004 framework.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('eps Ind A', 'Ba', 'A', 'T1.5', 402.003,
     1457, 0.0716, false, 1320, false,
     'T1.5 brown dwarf / very-low-mass stellar boundary object, primary of the eps Ind B BD binary', 'manual', '2018ApJ...865...28D',
     'eps Ind Ba: T1.5 brown dwarf at the very heart of the stellar/substellar boundary. DYNAMICAL '
     'mass from Dieterich et al. 2018 Table 4 (VLT/NACO 6-epoch orbital astrometry combined with '
     'CTIOPI/CAPS parallax): 75.0 ± 0.82 M_Jup = 0.0716 ± 0.0008 Msun. Teff 1320 K (King 2010 via '
     'Dieterich Table 5), L/L_sun = log -4.70. Spectral type T1.5 (Dieterich 2018 Table 1; refines '
     'McCaughrean 2004 T1 to T1.5). Wide-pair angular separation 402.003 arcsec from eps Ind A (van '
     'Leeuwen 2007 reference epoch 2004), projected separation ~1457 AU at the 3.622 ± 0.004 pc '
     'system distance. INTERNAL Ba-Bb orbit (Dieterich 2018 Table 3): P = 4165.09 ± 43.7 d (~11.4 '
     'yr), e = 0.47 ± 0.02, i = 75.9° ± 0.4°, Ba semi-major axis a_B = 1.267 ± 0.018 AU about the '
     'BC barycenter. Critically, Ba at 75.0 M_Jup is at-or-just-above the predicted stellar/substellar '
     'mass boundary depending on model (~73-80 M_Jup, Dieterich Table 5) -- could be a very-low-mass '
     'star rather than a brown dwarf. McCaughrean 2004 (cited secondarily) is the discovery paper '
     'and used photometric isochrones with the older Lachaume 1999 age of 1.3 Gyr; with the system '
     'age now revised to ~3.5-5.7 Gyr (Matthews 2024, migration 065), Dieterich 2018''s dynamical '
     'mass supersedes McCaughrean''s 47 M_Jup photometric estimate.'),

    ('eps Ind A', 'Bb', 'A', 'T6', 402.003,
     1457, 0.0669, false, 910, false,
     'T6 brown dwarf, secondary of the eps Ind B BD binary', 'manual', '2018ApJ...865...28D',
     'eps Ind Bb: T6 brown dwarf. DYNAMICAL mass from Dieterich et al. 2018 Table 4: 70.1 ± 0.68 '
     'M_Jup = 0.0669 ± 0.00064 Msun. Teff 910 K (King 2010), L/L_sun = log -5.23. Spectral type T6 '
     '(consistent across Dieterich 2018 and McCaughrean 2004). Wide-pair angular separation '
     '402.003 arcsec from eps Ind A (same as Ba; the Ba-Bb pair is unresolved at the wide-pair '
     'scale). Within the Ba-Bb pair, Bb semi-major axis a_C = 1.355 ± 0.020 AU about the BC '
     'barycenter (Dieterich 2018 Table 3); current sky separation from Ba ranges across the 11.4-yr '
     'orbit. Bb at 70.1 M_Jup is just below the stellar/substellar boundary (~73-80 M_Jup per '
     'Dieterich Table 5), so it is unambiguously a (high-mass) brown dwarf. eps Ind A + Ba + Bb = '
     'the catalog sy_snum = 3.')
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
