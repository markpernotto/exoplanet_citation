BEGIN;

-- Migration 123: SIMBAD citation-debt pass, 2-row-tier cleanup — batch 1.
-- Covers 6 hosts audited via Gaia DR3 astrometry + primary-source literature:
--   GJ 229, GJ 667 C, GJ 896 A, HIP 65 A, HIP 79098 AB, K2-419 A.
--
-- Aggregate: 5 DELETEs, 8 UPDATEs, 1 INSERT.
--
-- Methodology inherited from migrations 119/120/121: for each host, matched
-- each SIMBAD debt row to a Gaia DR3 counterpart by (separation, PA), verified
-- parallax + PM consistency against the host's own Gaia astrometry, and chased
-- primary-source literature for every real bound companion. Per-host rationale
-- documented in each section below.
--
-- ===========================================================================
-- Section A: GJ 229 — 1 UPDATE (B) + 1 DELETE (C = PM-echo of A itself)
-- ===========================================================================
--
-- GJ 229 (Gaia DR3 2940856402123426176) is at 5.76 pc with a huge proper motion
-- (~735 mas/yr magnitude). Gaia cone search at 12" radius returned ONLY GJ 229 A
-- itself — no other resolved sources at any separation. That is diagnostic:
--
--   B (4.63", PA 68.4°, T6.5): the historic Gl 229 B, first directly imaged
--     brown dwarf (Nakajima et al. 1995, 1995Natur.378..463N). At T6.5 the
--     object is too faint for Gaia astrometric solution (G > 20), which is why
--     it doesn't appear in the cone search. Real bound companion, cite Nakajima.
--     Projected separation: 4.63" x 5.76 pc = 26.7 AU.
--
--   C (9.21", PA 10.8°, M1V): PM-echo artifact of GJ 229 A itself at approx
--     epoch J2003.4. GJ 229 A moves 719 mas/yr in Dec; over 12.6 years that's
--     9.06 arcsec of drift, which exactly matches C's stored 9.05" projection
--     onto the Dec axis (9.21" x cos(10.8°) = 9.05"). RA-axis check also passes
--     (9.21" x sin(10.8°) = 1.73", matches ~12.7 years of RA drift). SIMBAD's
--     recorded spectype "M1V" for C matches GJ 229 A's own spectype. This is
--     the same star, ingested twice at different epochs by cross-catalog
--     aggregation. New pattern; PM-echo watch task recorded in todos.
--
-- NOTE: Deferred followup — Xuan et al. 2024 (2024Natur.634..795X) resolved
-- Gl 229 B into a tight brown-dwarf binary Ba + Bb. Keeping B as a single row
-- cited to Nakajima 1995 for this migration; future migration can split.

UPDATE binary_companions
   SET source_bibcode = '1995Natur.378..463N',
       separation_au = 26.7,
       notes = 'Gl 229 B, the first directly imaged brown dwarf (Nakajima et al. 1995 Nature). T6.5 methane dwarf at 4.63" from the M1V primary. Projected separation 26.7 AU from GJ 229 A distance 5.76 pc. Too faint (G > 20) for Gaia DR3 astrometric solution, so identification rests on the historical direct-imaging discovery and subsequent characterization. Deferred followup: Xuan et al. 2024 (2024Natur.634..795X) resolved Gl 229 B into a tight brown-dwarf binary Ba+Bb via RV; a future migration can split this row.'
 WHERE hostname = 'GJ 229'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

DELETE FROM binary_companions
 WHERE hostname = 'GJ 229'
   AND component_designation = 'C'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row deleted (PM-echo artifact of GJ 229 A itself).

-- ===========================================================================
-- Section B: GJ 667 C — 2 UPDATEs (A + B, both bound to the planet host C)
-- ===========================================================================
--
-- GJ 667 is a well-known hierarchical triple: A + B is a tight visual pair at
-- ~1.8" internal separation, and C is the planet host at ~30" from the AB
-- barycenter. Our two SIMBAD debt rows are A (39.51") and B (41.25"), both
-- claiming to be companions of the planet host C. This is the correct
-- catalog structure — A and B ARE bound to C as a wider tertiary/quaternary
-- system.
--
-- Söderhjelm 1999 (1999A&A...341..121S) Table 3 characterizes HIP 84709
-- (= GJ 667 AB) via Hipparcos Transit-Data orbit refinement:
--   improved parallax = 138.2 +/- 0.7 mas -> distance 7.235 pc (matches Gaia)
--   Sigma-M (AB mass sum) = 1.27 M_sun (3% error)
--   q (photometric mass ratio B/A) = 0.88
--   P_AB = 42.15 years
--   a_AB = 1.81" (visual-orbit semi-major axis, ~13.1 AU internal)
--   e_AB = 0.58
--
-- Individual masses derived from Söderhjelm 1999:
--   M_A = 1.27 / (1 + 0.88) = 0.676 M_sun
--   M_B = 0.88 x 0.676 = 0.595 M_sun
--
-- Anglada-Escudé et al. 2013 (2013A&A...556A.126A) is the exoplanet-host paper
-- that establishes the AB pair as bound context for C. Both papers cited in
-- notes; source_bibcode goes to Söderhjelm for the actual mass characterization.
--
-- Projected separations from GJ 667 C stored separations x 7.235 pc:
--   A: 39.51" x 7.235 = 286 AU
--   B: 41.25" x 7.235 = 298 AU
--
-- Caveat: the stored SIMBAD separations (39-41") reflect an older epoch. Gaia
-- currently measures the AB blend at ~32" from C, indicating the AB pair has
-- moved by their orbital motion between the SIMBAD source epoch and J2016.
-- This is expected and does not affect the bound-status verdict.

UPDATE binary_companions
   SET source_bibcode = '1999A&A...341..121S',
       component_mass_msun = 0.676,
       separation_au = 286,
       notes = 'GJ 667 A, K3 dwarf, primary of the tight visual pair GJ 667 AB (HIP 84709). Söderhjelm 1999 Table 3 (Hipparcos Transit-Data orbit refinement): improved parallax 138.2 +/- 0.7 mas (d = 7.235 pc), AB mass sum 1.27 M_sun, mass ratio q = 0.88, P_AB = 42.15 yr, a_AB = 1.81" (~13.1 AU internal), e_AB = 0.58. Derived M_A = 1.27/(1+0.88) = 0.676 M_sun. Projected separation 286 AU from GJ 667 C at stored separation 39.51". The wider linkage of AB to the planet host GJ 667 C as a bound system is documented in Anglada-Escudé et al. 2013 (2013A&A...556A.126A) as the system context for the planet analysis. Note: stored 39-41" separations for A and B reflect the SIMBAD-source epoch; current Gaia measures the AB blend at ~32" from C due to AB orbital motion between epochs.'
 WHERE hostname = 'GJ 667 C'
   AND component_designation = 'A'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

UPDATE binary_companions
   SET source_bibcode = '1999A&A...341..121S',
       component_mass_msun = 0.595,
       separation_au = 298,
       notes = 'GJ 667 B, K4 dwarf, secondary of the tight visual pair GJ 667 AB (HIP 84709). Söderhjelm 1999 Table 3: derived M_B = 0.88 x 0.676 = 0.595 M_sun (from AB mass sum 1.27 and photometric mass ratio q = 0.88). See A row for the full Söderhjelm 1999 characterization details and the Anglada-Escudé et al. 2013 (2013A&A...556A.126A) attribution for the AB-to-C bound-system context. Projected separation 298 AU from GJ 667 C at stored separation 41.25".'
 WHERE hostname = 'GJ 667 C'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

-- ===========================================================================
-- Section C: GJ 896 A — 1 UPDATE (B) + 1 DELETE (C = alias duplicate)
-- ===========================================================================
--
-- GJ 896 A = EQ Peg A, an M3.5V flare star in a well-known nearby M+M binary
-- with GJ 896 B = EQ Peg B (M4.5V). Two SIMBAD debt rows both point at the
-- same physical bound companion:
--   B (5.59", PA 271.5°, M3.5V)
--   C (5.66", PA 271.3°, M3.5Ve)
-- Separations differ by 0.07" and PAs by 0.2° (well within measurement error).
-- Both rows correspond to Gaia DR3 2824770686019004032 (parallax 159.91 mas,
-- matching GJ 896 A's 159.66 mas within 5 sigma). Alias duplicate.
--
-- Curiel et al. 2022 (2022AJ....164...93C) VLBA astrometric characterization,
-- Table 3 "Full Combined" column:
--   m_A = 0.436 +/- 0.001 M_sun (dynamical, VLBA-derived)
--   m_B = 0.165 +/- 0.0003 M_sun
--   Q(mB/mA) = 0.377
--   a_AB = 5.058" = 31.6 AU physical (binary orbital semi-major axis)
--   P_AB = 83665 d ~ 229 years
--   e_AB = 0.108
--   i_AB = 130° (retrograde relative to the discovered planet)
--   D = 6.2545 pc
--   Bonus: discovery of a 2.35 M_Jup planet around GJ 896 A (GJ 896 Ab).
--
-- Projected separation 5.591" x 6.2545 pc = 35.0 AU (very close to the 31.6 AU
-- physical orbital semi-major axis from Curiel 2022).

UPDATE binary_companions
   SET source_bibcode = '2022AJ....164...93C',
       component_mass_msun = 0.165,
       separation_au = 35.0,
       source_catalog = 'manual',
       notes = 'GJ 896 B = EQ Peg B, M4.5V flare-star companion of GJ 896 A = EQ Peg A. Curiel et al. 2022 VLBA astrometric + optical/IR characterization: dynamical m_B = 0.165 +/- 0.0003 M_sun (paired with m_A = 0.436 +/- 0.001 M_sun), binary orbital semi-major axis a_AB = 31.6 AU physical (5.058"), P_AB ~ 229 years, e_AB = 0.108, i_AB = 130° retrograde. Distance D = 6.2545 pc. Same paper also announces the discovery of a 2.35 M_Jup planet GJ 896 Ab around the primary. Verified as Gaia DR3 2824770686019004032, parallax 159.91 mas matching GJ 896 A''s 159.66 mas within 5 sigma. Projected separation 35.0 AU at our stored 5.591" (consistent with Curiel''s 31.6 AU physical orbital a).'
 WHERE hostname = 'GJ 896 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

DELETE FROM binary_companions
 WHERE hostname = 'GJ 896 A'
   AND component_designation = 'C'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row deleted (SIMBAD alias duplicate of the same Gaia source as B).

-- ===========================================================================
-- Section D: HIP 65 A — 2 UPDATEs (B + C, both bound; hierarchical triple)
-- ===========================================================================
--
-- HIP 65 is confirmed as a hierarchical triple system:
--   A: K-dwarf planet host (hot Jupiter HIP 65 A b, Nielsen et al. 2020)
--   B: mid-M dwarf companion at 3.81"
--   C: late-M/L dwarf companion at 73.62"
--
-- Michel & Mugrauer 2024 (2024MNRAS.527.3183M) "Gaia search for (sub)stellar
-- companions of exoplanet hosts" characterizes BOTH B and C using Gaia DR3
-- astrometry + photometry. All values verified against their Tables 2, 3, 4:
--
-- HIP 65 B:
--   Mass 0.236 +/- 0.006 M_sun (mid-M dwarf)
--   Teff 3318 K
--   Projected separation 236 AU (matches atlas Gaia-derived 234 AU)
--   rho 3.81271", PA 322.31°
--   cpm-index = 80 (strongly bound; below Table 5 escape-velocity threshold)
--
-- HIP 65 C:
--   Mass 0.096 +/- 0.001 M_sun (near the H-burning limit, ultra-cool)
--   Teff 2745 K (late M or early L)
--   Projected separation 4554 AU (matches atlas Gaia-derived 4557 AU)
--   rho 73.61775", PA 161.67°
--   cpm-index = 14 (bound; also below Table 5 escape-velocity threshold)
--
-- Independently corroborated:
--   Nielsen et al. 2020 A&A (2020A&A...639A..76N) discovery of HIP 65 A b
--     and identification of HIP 65 A + B as a binary, quoted projected sep
--     269 AU (consistent with Michel & Mugrauer's 236 AU within measurement).
--   Gunn et al. 2026 (2026MNRAS.545f2057G) HIP 65 A tidal decay + triple
--     system architecture.
--   Genet et al. 2022 (2022SASS...41....7G) speckle observations confirming
--     the B companion with WDS 2015 measurement PA 322°, sep 3.8".
--   Reyle 2018 (2018A&A...619L...8R) flagged CD-55 9423C as an ultracool
--     dwarf candidate, matching Michel & Mugrauer's Teff 2745 K.

UPDATE binary_companions
   SET source_bibcode = '2024MNRAS.527.3183M',
       component_mass_msun = 0.236,
       component_spectype = 'M dwarf',
       separation_au = 236,
       notes = 'HIP 65 B, mid-M dwarf companion at 3.81" from the K-dwarf planet host HIP 65 A. Michel & Mugrauer 2024 Gaia DR3 characterization: mass 0.236 +/- 0.006 M_sun, Teff 3318 K, projected sep 236 AU, cpm-index 80 (strongly bound). Independently confirmed by Nielsen et al. 2020 (2020A&A...639A..76N) as the binary companion in the HIP 65 A b hot Jupiter discovery paper (quoted projected sep 269 AU), by Gunn et al. 2026 (2026MNRAS.545f2057G) tidal decay + triple-system context, and by Genet et al. 2022 (2022SASS...41....7G) speckle observations matching WDS 2015 measurement (PA 322°, sep 3.8"). Part of the hierarchical triple with HIP 65 C.'
 WHERE hostname = 'HIP 65 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

UPDATE binary_companions
   SET source_bibcode = '2024MNRAS.527.3183M',
       component_mass_msun = 0.096,
       component_spectype = 'M/L',
       separation_au = 4554,
       notes = 'HIP 65 C, late-M/L dwarf companion at 73.62" from the K-dwarf planet host HIP 65 A. Michel & Mugrauer 2024 Gaia DR3 characterization: mass 0.096 +/- 0.001 M_sun (near the hydrogen-burning limit), Teff 2745 K (late M or early L, at the ultracool boundary), projected sep 4554 AU, cpm-index 14 (bound). Independently corroborated by Reyle 2018 (2018A&A...619L...8R) flagging CD-55 9423 C as an ultracool dwarf candidate — matches the Michel & Mugrauer Teff and mass. Wide bound tertiary of the hierarchical triple HIP 65 A + B + C.'
 WHERE hostname = 'HIP 65 A'
   AND component_designation = 'C'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

-- ===========================================================================
-- Section E: HIP 79098 AB — 2 DELETEs + 1 UPDATE + 1 INSERT
-- ===========================================================================
--
-- HIP 79098 is a B9-type spectroscopic binary in the Upper Scorpius association.
-- Existing atlas structure treats it as an unresolved AB pair (planet host is
-- the pair itself). Current binary_companions rows for hostname = 'HIP 79098 AB':
--   Aa/Ab (inner): properly cited to Janson 2019 as spectroscopic binary,
--     but all measurements NULL. Updated below with Gratton 2023 masses/sma.
--   B (65.30", PA 101.87°, M5.0): SIMBAD debt row. Verdict below: DELETE.
--   C (189.19", PA 277.17°, M3-M3.5): SIMBAD debt row. Verdict below: DELETE.
--
-- Gratton et al. 2023 (2023A&A...678A..93G) "Multiples among B stars in the
-- Scorpius-Centaurus association" is a systematic survey with completeness for
-- stellar secondaries at sep > 3 AU. At HIP 79098's ~150 pc distance, 65" =
-- ~9750 AU is deep inside their completeness window. Their methodology
-- includes Gaia direct detection for wide companions (demonstrated by their
-- reporting a new BD companion at 9.6" for HIP 74752). Their Table 4 lists
-- HIP 79098's characterized companions:
--   Inner spectroscopic binary Aa/Ab: M_Ab = 0.526 +/- 0.263 M_sun,
--     a = 1.859 +/- 0.561 AU (based on Levato 1987 RVs + Gaia RUWE 2.693
--     + Gaia PMa SNR 2.36).
--   HIP 79098 (AB)b substellar circumbinary: separately documented in Janson
--     et al. 2019 (2019A&A...626A..99J), NOT part of Gratton's inner-binary
--     analysis. Details in the INSERT below.
-- No stellar companion at 65" is characterized by Gratton. That absence, given
-- their completeness at that separation, is decisive negative evidence.
--
-- SIMBAD B (65.30", M5.0) matches Gaia DR3 6242059181703801472 = 2MASS
-- J16084836-2341209, an Upper-Sco coeval member documented in ~27 Upper-Sco
-- census papers. PM matches HIP 79098 within 0.3σ (expected for shared
-- association motion) but parallax differs by 3σ. Upper-Sco membership !=
-- bound to HIP 79098. Neither Janson 2019, Gratton 2023, nor WDS document
-- it as a bound tertiary. DELETE as coeval-not-bound.
--
-- SIMBAD C (189.19", M3-M3.5) matches Gaia DR3 6242105945307733632. Gaia PM
-- mismatched by 117σ (pmra) and 187σ (pmdec); parallax coincidentally matches
-- at Sco-Cen distance. Chance alignment. DELETE.
--
-- New INSERT: HIP 79098 (AB)b substellar circumbinary companion.
-- Janson et al. 2019 (2019A&A...626A..99J) BEAST survey (B-star Exoplanet
-- Abundance Study). SPHERE 2015 astrometry (their Table 1, most precise
-- measurement): sep 2.359", PA 116.13°. Projected sep 345 +/- 6 AU. Model-
-- dependent mass 16-25 M_Jup (recorded as NULL with range in notes; no
-- committed single value). Common proper motion confirmed over 15-yr
-- baseline. Formerly catalogued as HIP 79098 B (thought background
-- contaminant); Janson 2019 reclassifies as bona fide substellar circumbinary.

UPDATE binary_companions
   SET source_bibcode = '2023A&A...678A..93G',
       component_mass_msun = 0.526,
       separation_au = 1.859,
       notes = 'HIP 79098 Aa/Ab inner spectroscopic binary. Gratton et al. 2023 Table 4 analysis: M_Ab = 0.526 +/- 0.263 M_sun, orbital semi-major axis a = 1.859 +/- 0.561 AU. Based on Levato et al. 1987 (1987ApJS...64..487L) RV variations combined with Gaia DR3 RUWE 2.693 and PMa SNR 2.36. B9-type primary. Original detection as an unresolved spectroscopic binary in Janson et al. 2019 (2019A&A...626A..99J). The wider substellar circumbinary companion HIP 79098 (AB)b (16-25 M_Jup at 345 AU) is a separate row cited to Janson 2019.'
 WHERE hostname = 'HIP 79098 AB'
   AND component_designation = 'Ab'
   AND inner_binary IS TRUE;
-- Expected: 1 row updated.

DELETE FROM binary_companions
 WHERE hostname = 'HIP 79098 AB'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;
-- Expected: 1 row deleted (2MASS J16084836-2341209 is a Sco-Cen coeval member,
--   not bound to HIP 79098; Gratton 2023 systematic survey excludes it).

DELETE FROM binary_companions
 WHERE hostname = 'HIP 79098 AB'
   AND component_designation = 'C'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;
-- Expected: 1 row deleted (chance alignment at 189"; Gaia PM mismatch 117σ / 187σ).

INSERT INTO binary_companions (
    hostname,
    component_designation,
    primary_designation,
    inner_binary,
    separation_arcsec,
    separation_au,
    position_angle_deg,
    component_mass_msun,
    component_spectype,
    source_catalog,
    source_bibcode,
    notes
) VALUES (
    'HIP 79098 AB',
    'b',
    '(AB)',
    FALSE,
    2.359,
    345,
    116.13,
    NULL,       -- 16-25 M_Jup model-dependent range; no committed single value
    NULL,
    'manual',
    '2019A&A...626A..99J',
    'HIP 79098 (AB)b substellar circumbinary companion. Janson et al. 2019 BEAST (B-star Exoplanet Abundance Study). Model-dependent mass 16-25 M_Jup (~0.015-0.024 M_sun); no single value committed by the paper. Projected sep 345 +/- 6 AU. SPHERE 2015 astrometry (most precise, their Table 1): sep 2.359", PA 116.13°. Common proper motion confirmed over 15-yr baseline (ADONIS 2000, NACO 2004, SPHERE 2015). Formerly catalogued as HIP 79098 B by older direct-imaging surveys (thought background contaminant on peculiar colors); Janson 2019 reclassifies as bona fide substellar circumbinary via CPM. Orbits the inner spectroscopic B9 pair; the (AB) parenthetical designation is Janson''s explicit convention for circumbinary. Mass ratio ~<1% (planet-like).'
);
-- Expected: 1 row inserted.

-- ===========================================================================
-- Section F: K2-419 A — 1 UPDATE (B) + 1 DELETE (C = field star)
-- ===========================================================================
--
-- K2-419 A is an M-dwarf (M* = 0.562 M_sun, Teff 3711 K) planet host in the K2
-- Campaign 5 field, also observed by TESS as TOI-5176. Gaia DR3 605593554127479936,
-- distance 263.8 pc, parallax 3.79 mas.
--
-- Kanodia et al. 2024 (2024AJ....168..235K) "Searching for GEMS: Characterizing
-- Six Giant Planets Around Cool Dwarfs" Section 3.4 explicitly characterizes
-- K2-419 B:
--   Gaia DR3 605593554127091200 (TIC-800461642)
--   ~2.2" separation (consistent with atlas SIMBAD 1.94"; small epoch/PA offset)
--   Projected separation ~520 AU
--   G = 19.1, delta-G = 3.4 mag fainter than the primary
--   Distance ~224 +/- 21 pc (matches K2-419 A's 263.8 pc within 2σ)
--   Mid/late M-dwarf (consistent with SIMBAD's M5.0 classification)
--   Bound-pair confirmed via El-Badry, Rix & Heintz 2021 (2021MNRAS.506.2269E)
--     Gaia wide-binary catalog.
--
-- Verification: Gaia cone search returned K2-419 A (row 1) and K2-419 B
-- (row 2 at sep 1.96", G 19.14) with parallax 4.45 mas (1.5σ), pmra Δ 3.2σ
-- (expected residual orbital motion for a bound pair), pmdec Δ 1.4σ.
-- El-Badry 2021 cross-match confirmed.
--
-- SIMBAD C (108.32", PA 324°) matches Gaia DR3 605593829005387136 at
-- sep 107.97" and consistent PA. G=12.05 (brighter than K2-419 A itself,
-- which is why SIMBAD had a wide-crossmatch entry). Astrometric mismatches:
--   parallax 3.08 vs 3.79 mas: 17.7σ mismatch (background at ~324 pc)
--   pmra -15.98 vs -71.34 mas/yr: ~1200σ mismatch
--   pmdec -14.43 vs -27.15 mas/yr: ~340σ mismatch
-- Decisive field-star verdict. DELETE.

UPDATE binary_companions
   SET source_bibcode = '2024AJ....168..235K',
       separation_au = 520,
       notes = 'K2-419 B, mid/late M-dwarf bound companion at 1.94" from the M-dwarf planet host K2-419 A. Kanodia et al. 2024 Section 3.4 (GEMS survey characterization): Gaia DR3 605593554127091200 = TIC-800461642, G = 19.1, delta-G = 3.4 mag, distance 224 +/- 21 pc (matches K2-419 A''s 263.8 pc within 2σ), projected sep 520 AU. Bound-pair confirmation via El-Badry, Rix & Heintz 2021 (2021MNRAS.506.2269E) Gaia wide-binary catalog cross-match. Verified against Gaia DR3 cone search: matched source at sep 1.96", parallax 4.45 mas (1.5σ from primary), residual PM offset 3.2σ pmra + 1.4σ pmdec (expected orbital motion). Not an AO/speckle discovery — resolved by Gaia directly; not yet in WDS.'
 WHERE hostname = 'K2-419 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row updated.

DELETE FROM binary_companions
 WHERE hostname = 'K2-419 A'
   AND component_designation = 'C'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;
-- Expected: 1 row deleted (Gaia DR3 605593829005387136, field star at 324 pc;
--   17.7σ parallax mismatch, ~1200σ pmra mismatch, ~340σ pmdec mismatch).

-- ===========================================================================
-- Migration 123 grand totals: 5 DELETEs + 8 UPDATEs + 1 INSERT across 6 hosts.
-- ===========================================================================

COMMIT;
