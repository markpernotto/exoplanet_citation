-- LTT 3780 stellar architecture enrichment (manual literature review,
-- 2026-05-26). Tenth migration of the S-type stellar-multiplicity audit
-- campaign, continuing the per-host work for the 13-system priority targets
-- that aren't covered by Mugrauer 2019 (migration 077). LTT 3780 = TOI-732 =
-- LP 729-54 is a nearby (22 pc) mid-M dwarf with a known wide M-dwarf
-- companion LP 729-55 that the Cloutier 2020 discovery paper characterizes.
-- Already-relevant context: LTT 3780 c atmosphere was deep-dived for CH4
-- detection in migration 067 (Rigby 2025 batch 7).
--
-- Bibcode:
--   2020AJ....160....3C -- Cloutier et al. 2020 AJ 160, 3, "A Pair of TESS
--     Planets Spanning the Radius Valley around the Nearby Mid-M Dwarf
--     LTT 3780" (arXiv 2003.01136). Source for LP 729-55 mass + projected
--     separation cited in the binary_companions row below.
--   2020A&A...642A.173N -- Nowak et al. 2020 A&A 642, A173, "The CARMENES
--     search for exoplanets around M dwarfs: Two planets on the opposite
--     sides of the radius gap transiting the nearby M dwarf LTT 3780"
--     (arXiv 2003.01140). Simultaneous independent discovery and
--     characterization of the LTT 3780 b + c planetary system. Both papers
--     mention the wide companion LP 729-55 but neither dedicates a
--     parameter table to it; this row's values are Cloutier-sourced and
--     Nowak appears in the seed citations as a complementary discovery
--     reference. The two stellar-parameter sets for LTT 3780 A agree within
--     errors: Cloutier Teff 3331+/-157 K, mass 0.401+/-0.012 vs Nowak
--     Teff 3360+/-51 K, mass 0.379+/-0.016 (M4V vs M3.5V is rounding).
--
-- Architecture (Cloutier 2020):
--   - LTT 3780 A (= LP 729-54 = TOI-732 = TIC 36724087): M4V planet host
--     at 22.0 pc, mass 0.401 ± 0.012 Msun, radius 0.374 ± 0.011 Rsun, Teff
--     3331 ± 157 K. Hosts two planets: b (1.33 R_earth, 0.77 d) and c
--     (2.30 R_earth, 12.25 d, deep-dived for CH4 atmosphere in migration 067).
--   - LTT 3780 B (= LP 729-55): late M-dwarf wide companion, mass 0.136 ±
--     0.004 Msun, radius 0.173 ± 0.005 Rsun (~M5V approx, spectype inferred
--     from mass). Angular separation ~16.1 arcsec from A, projected
--     separation 354 AU at 22 pc. Mass ratio q = 0.340 ± 0.014. Estimated
--     orbital period ~9100 yr at the projected separation. Gaia DR2 confirms
--     common parallax + proper motion.
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('LTT 3780', 'B', 'A', 'M5V', 16.1,
     354, 0.136, false, NULL, false,
     'wide late M-dwarf visual companion LP 729-55 (Gaia DR2 confirmed)', 'manual', '2020AJ....160....3C',
     'LTT 3780 B = LP 729-55: late M-dwarf wide companion to LTT 3780 A (M4V planet host). Mass '
     '0.136 ± 0.004 Msun, radius 0.173 ± 0.005 Rsun (M5V approx; spectype inferred from mass, not '
     'explicitly classified in Cloutier 2020 Table 1 which covers only LTT 3780 A). Angular '
     'separation ~16.1 arcsec from A; projected separation 354 AU at the 21.98 pc system distance. '
     'Mass ratio q = M_B / M_A = 0.340 ± 0.014. Gaia DR2 confirms common parallax + proper motion. '
     'Estimated orbital period ~9100 yr at the projected separation. component_teff_k NULL because '
     'Cloutier 2020 does not quote a Teff for B (only the mass and radius via main-sequence isochrones).')
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
