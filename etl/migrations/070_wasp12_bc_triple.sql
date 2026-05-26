-- WASP-12 + HAT-P-8 stellar architecture enrichment (manual literature review,
-- 2026-05-26). First migration of the S-type stellar-multiplicity audit
-- campaign opened by migration 069 (V1298 Tau). Both hosts have catalog
-- sy_snum = 3 but empty binary_companions, and BOTH are characterized by
-- Bechter et al. 2014 -- so we close two hosts with one paper.
--
-- Bibcode:
--   2014ApJ...788....2B -- Bechter et al. 2014 ApJ 788, 2,
--     "WASP-12b and HAT-P-8b are Members of Triple Star Systems"
--     (arXiv 1307.6857). Keck NIRC2 AO imaging spatially resolved the
--     secondary previously detected as a single source by Bergfors et al. 2013
--     into two M-dwarf components. The same paper enables the first dynamical
--     mass determination for hot-Jupiter stellar companions via the BC
--     orbital fit (BC orbit not fully closed in the abstract; photometric
--     masses recorded here).
--
-- Architecture summary (from Bechter 2014 Tables 1 + 2):
--   - WASP-12 A: hot-Jupiter host, primary.
--   - WASP-12 B and C: tight M3V pair, separated from EACH OTHER by 84.3
--     ± 0.6 mas (~21 AU at the assumed 250 pc distance), and from WASP-12 A
--     by ~1.064 arcsec (B) and ~1.072 arcsec (C). Both BC components are
--     near-equal-mass (M_B = 0.38 ± 0.05 Msun, M_C = 0.37 ± 0.05 Msun) and
--     near-equal-luminosity (M_Ks 6.47 vs 6.50). PA ~ 247-251°.
--   - HAT-P-8 A: hot-Jupiter host, primary.
--   - HAT-P-8 B and C: tight M5V/M6V pair at ~1.04-1.05 arcsec from A
--     (~240 AU at the assumed 230 pc Latham 2009 distance). Slightly less
--     equal-mass than WASP-12 BC: M_B = 0.22 ± 0.03 Msun (≈M5V),
--     M_C = 0.18 ± 0.02 Msun (≈M6V), M_Ks 7.73 vs 8.32. PA ~ 138-141°.
--
-- Distance caveat: Bechter 2014 quotes the WASP-12 distance as 250 ± 30 pc
-- (Bergfors et al. 2013, photometric). Gaia DR3 has since refined the
-- distance; the masses recorded here are tied to the 250 pc assumption (mass
-- derivation via Kraus & Hillenbrand 2007 isochrones on M_Ks). If a future
-- pass uses a different distance, the M_Ks values shift and the masses change
-- (a 250 -> 430 pc revision would shift M_Ks by ~1.18 mag and push the
-- spectral types toward early-K / mass toward ~0.55 Msun). Recorded values
-- are the paper's own; separation_au computed at 250 pc.
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('WASP-12', 'B', 'A', 'M3V', 1.064,
     266, 0.38, false, NULL, false,
     'tight M-dwarf pair component, outer companion to hot-Jupiter host WASP-12 A', 'manual', '2014ApJ...788....2B',
     'WASP-12 B: M3V dwarf, mass 0.38 ± 0.05 Msun (Bechter et al. 2014 Table 2, derived from M_Ks = 6.47 '
     '± 0.27 via Kraus & Hillenbrand 2007 isochrones at the assumed 250 ± 30 pc Bergfors 2013 distance). '
     'Two-epoch Keck NIRC2 AO astrometry: ρ = 1064 ± 19 mas, PA = 251.3-251.4° (2012-Feb + 2013-Mar). '
     'Projected separation from WASP-12 A ≈ 266 AU at 250 pc. ∆J = 3.81 ± 0.05, ∆Ks = 3.25 ± 0.04. '
     'B and C are themselves separated by only 84.3 ± 0.6 mas (~21 AU), the first ever spatial '
     'resolution of this companion (Bergfors 2013 saw combined light). Distance caveat: a Gaia DR3 '
     'refinement of the host distance would shift the inferred mass.'),

    ('WASP-12', 'C', 'A', 'M3V', 1.072,
     268, 0.37, false, NULL, false,
     'tight M-dwarf pair component (paired with B), outer companion to hot-Jupiter host WASP-12 A', 'manual', '2014ApJ...788....2B',
     'WASP-12 C: M3V dwarf, mass 0.37 ± 0.05 Msun (Bechter et al. 2014 Table 2, derived from M_Ks = 6.50 '
     '± 0.27). Two-epoch Keck NIRC2 AO astrometry: ρ = 1072 ± 18 mas, PA = 246.8-247.1°. Projected '
     'separation from WASP-12 A ≈ 268 AU at 250 pc. ∆J = 3.92 ± 0.05, ∆Ks = 3.28 ± 0.04. Co-located '
     'with B on the sky (BC pair separation 84.3 mas / ~21 AU); the BC orbit is the basis for the '
     'paper''s claim of the first dynamical mass determination for hot-Jupiter stellar companions, '
     'though the orbital fit is not yet closed. Same 250 pc distance caveat as B.'),

    ('HAT-P-8', 'B', 'A', 'M5V', 1.047,
     241, 0.22, false, NULL, false,
     'tight M-dwarf pair component, outer companion to hot-Jupiter host HAT-P-8 A', 'manual', '2014ApJ...788....2B',
     'HAT-P-8 B: ≈M5V dwarf, mass 0.22 ± 0.03 Msun (Bechter et al. 2014 Table 2, derived from M_Ks = 7.73 '
     '± 0.16 via Kraus & Hillenbrand 2007 isochrones at the assumed 230 ± 15 pc Latham 2009 distance). '
     'Two-epoch Keck NIRC2 AO astrometry: ρ = 1040 ± 14 mas (2012-Jun) / 1053 ± 14 mas (2013-Jul), PA = '
     '137.9-137.6°. Average separation recorded; projected separation from HAT-P-8 A ≈ 241 AU at 230 pc. '
     '∆Ks = 5.58 ± 0.07. Keck epochs alone demonstrate physical association for HAT-P-8 (vs WASP-12 BC '
     'where association required combining with Bergfors 2013). BC pair: B and C separated by ~10-20 mas '
     'on the sky, the second triple system in this paper.'),

    ('HAT-P-8', 'C', 'A', 'M6V', 1.045,
     240, 0.18, false, NULL, false,
     'tight M-dwarf pair component (paired with B), outer companion to hot-Jupiter host HAT-P-8 A', 'manual', '2014ApJ...788....2B',
     'HAT-P-8 C: ≈M6V dwarf, mass 0.18 ± 0.02 Msun (Bechter et al. 2014 Table 2, derived from M_Ks = 8.32 '
     '± 0.17). Two-epoch Keck NIRC2 AO astrometry: ρ = 1049 ± 14 mas (2012-Jun) / 1041 ± 14 mas (2013-Jul), '
     'PA = 141.4-140.7°. Average separation recorded; projected separation from HAT-P-8 A ≈ 240 AU at '
     '230 pc. ∆Ks = 6.08 ± 0.10. Less equal-mass with B than the WASP-12 BC pair (0.18 vs 0.22 Msun '
     'here, 0.37 vs 0.38 there). Same 230 pc distance caveat as B.')
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
