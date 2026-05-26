-- 51 Eri stellar architecture enrichment (manual literature review,
-- 2026-05-26). Fifth migration of the S-type stellar-multiplicity audit
-- campaign (after 070 WASP-12 + HAT-P-8, 071 LTT 1445 A, 072 HD 110067,
-- 073 Kepler-444). Catalog sy_snum = 3 for 51 Eri but binary_companions was
-- empty. Already-relevant context: 51 Eri b was deep-dived for atmosphere
-- in migration 038 (cold methane young Jupiter); now adding the stellar
-- architecture. The famous wide visual companion GJ 3305 is itself a tight
-- M+M binary, making 51 Eri a hierarchical triple in the beta-Pic moving
-- group at ~30 pc.
--
-- Bibcode:
--   2015ApJ...813L..11M -- Montet et al. 2015 ApJL 813, L11,
--     "Dynamical Masses of Young M Dwarfs: Masses and Orbital Parameters of
--     GJ 3305 AB, the Wide Binary Companion to the Imaged Exoplanet Host
--     51 Eri" (arXiv 1508.05945). Provides the GJ 3305 internal-binary
--     orbit + individual dynamical masses; the 51 Eri to GJ 3305 wide
--     common-proper-motion pair itself was first characterized in earlier
--     work (Feigelson et al. 2006, etc.).
--
-- Architecture:
--   - 51 Eri A: F0V planet host (51 Eri b directly imaged 2015 SPHERE/GPI,
--     cold methane young Jupiter; see migration 038 atmosphere data).
--   - GJ 3305 A and B: a TIGHT M+M binary, the wide visual companion of
--     51 Eri at 66 arcsec on the sky (~2000 AU projected at the ~30 pc
--     system distance). The GJ 3305 internal orbit is fully resolved by
--     Montet 2015 Table 2: semi-major axis a = 9.78 ± 0.14 AU, period
--     29.03 ± 0.50 yr, eccentricity 0.19 ± 0.02, inclination 92.1°
--     (near edge-on). Individual masses M_A = 0.67 ± 0.05 Msun, M_B =
--     0.44 ± 0.05 Msun (total 1.11 ± 0.04, mass ratio M_B/M_A = 0.65 ±
--     0.10). Individual luminosities L_A = 0.112 ± 0.007 Lsun, L_B =
--     0.043 ± 0.005 Lsun (Table 2). System age 37 ± 9 Myr per Montet 2015
--     BHAC15 isochrone fit; consistent with the 25 Myr beta-Pic moving
--     group age within errors.
--   - The 51 Eri to GJ 3305 wide pair: 66 arcsec / ~2000 AU separation, on
--     a very long-period orbit (period not constrained by Montet 2015; the
--     wide pair separation alone implies ~100,000 yr by Kepler's third law
--     for the total system mass).
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('51 Eri', 'B', 'A', 'M0V', 66,
     1953, 0.67, false, NULL, false,
     'wide M-dwarf visual binary (component A of GJ 3305, itself a tight M+M binary)', 'manual', '2015ApJ...813L..11M',
     'GJ 3305 A: 0.67 ± 0.05 Msun (Montet et al. 2015 Table 2 dynamical mass from the GJ 3305 internal '
     'AB orbit; spectype M0V approximate, inferred from mass), luminosity 0.112 ± 0.007 Lsun. The wide '
     '51 Eri / GJ 3305 separation of 66 arcsec on the sky (~1953 AU at the ~29.6 pc system distance) is '
     'from the common-proper-motion pair characterization (first by Feigelson et al. 2006; not in Montet '
     '2015''s tables, which characterize the INTERNAL GJ 3305 orbit). GJ 3305 A and B are themselves on '
     'an orbit with semi-major axis 9.78 ± 0.14 AU, period 29.03 ± 0.50 yr, eccentricity 0.19 ± 0.02, '
     'inclination 92.1° (near edge-on; Montet 2015 Table 2). Together 51 Eri A + GJ 3305 A + GJ 3305 B '
     'account for the catalog sy_snum = 3. System is a beta-Pic moving group member, age 37 ± 9 Myr '
     '(Montet 2015 BHAC15 fit).'),

    ('51 Eri', 'C', 'A', 'M2V', 66,
     1953, 0.44, false, NULL, false,
     'wide M-dwarf visual binary (component B of GJ 3305, paired with A)', 'manual', '2015ApJ...813L..11M',
     'GJ 3305 B: 0.44 ± 0.05 Msun (Montet et al. 2015 Table 2 dynamical mass; ~M2V approx), luminosity '
     '0.043 ± 0.005 Lsun. Co-located with GJ 3305 A on the wide 51 Eri view (the AB internal binary is '
     'too tight to resolve at the 66 arcsec wide-pair scale). Mass ratio M_B / M_A = 0.65 ± 0.10. The '
     'internal AB orbit (a = 9.78 AU, e = 0.19) makes B and C the most physically well-characterized '
     'unresolved-from-distance pair of any host in this audit so far.')
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
