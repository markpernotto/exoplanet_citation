-- K2-290 stellar architecture enrichment + RELABEL (manual literature review,
-- 2026-05-26). Twelfth migration of the S-type stellar-multiplicity audit.
-- K2-290 was previously deep-dived for spin-orbit obliquity in migration 053
-- (Tilted & Tumbling theme, true obliquity 124° / retrograde). Stellar
-- architecture work was outstanding: catalog sy_snum = 3, binary_companions
-- had only ONE row (SIMBAD bulk-load entry mislabeled as 'B' at 11.25 arcsec
-- with no bibcode, mass, or AU separation).
--
-- LITERATURE-LABEL RECONCILIATION:
--   - The SIMBAD-labeled 'B' (separation 11.25 arcsec) physically corresponds
--     to LITERATURE'S 'C', the WIDE M-dwarf companion at ~2467 AU (Best
--     et al. 2022 ApJL). At K2-290's ~219 pc distance, 2467 AU = 11.27
--     arcsec, matching SIMBAD's 11.25 arcsec measurement.
--   - The literature's 'B' is a DIFFERENT, CLOSER M-dwarf companion at
--     ~113 AU (~0.52 arcsec; Hjorth et al. 2021 PNAS), which was NEVER in
--     our binary_companions table.
--
-- This migration MATCHES THE LITERATURE NAMING CONVENTION by:
--   1. DELETing the stale SIMBAD 'B' row (mislabeled; was the wide companion
--      but labeled 'B' historically before Hjorth 2021 identified the close
--      inner companion).
--   2. INSERTing a new 'B' row for Hjorth 2021's close M-dwarf at 113 AU
--      (mass 0.368 ± 0.021 Msun, the proximate driver of the proposed
--      primordial-disk-misalignment mechanism in migration 053's obliquity).
--   3. INSERTing a new 'C' row for Best 2022's wide M-dwarf at 2467 AU
--      (the chaotic-dynamics driver the Best paper proposes as an alternative
--      to Hjorth's primordial-disk story).
--
-- The DELETE is deliberately restricted to the SIMBAD bulk-load entry
-- (source_catalog = 'SIMBAD' AND source_bibcode IS NULL); if for any reason
-- a more authoritative 'B' row has been seeded since, the DELETE will not
-- touch it. Idempotent: re-applying the migration after the SIMBAD row is
-- gone will simply UPDATE B and C with the same Hjorth/Best values.
--
-- Bibcodes:
--   2021PNAS..11817418H -- Hjorth et al. 2021 PNAS, "A backward-spinning
--     star with two coplanar planets". K2-290 B (close, 113 AU) discovery
--     + characterization + primordial-disk-misalignment proposal. Already
--     cited in migration 053 for the obliquity role.
--   2022ApJ...924L..11B -- Best et al. 2022 ApJL 924, L11, "The chaotic
--     history of the retrograde multi-planet system in K2-290A driven by
--     distant stars". K2-290 C (wide, 2467 AU) characterization + chaotic
--     stellar-obliquity evolution alternative to Hjorth's primordial story.
--
-- Apply after 011_binary_companions.sql. Idempotent.

-- Step 1: remove the stale SIMBAD entry (mislabeled 'B', was the wide
-- companion). Restricted predicate keeps this safe if a better row was
-- seeded in the interim.
DELETE FROM binary_companions
WHERE hostname = 'K2-290'
  AND component_designation = 'B'
  AND source_catalog = 'SIMBAD'
  AND source_bibcode IS NULL;

-- Step 2: insert the literature B (close, 113 AU) and C (wide, 2467 AU).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('K2-290', 'B', 'A', 'M3V', 0.52,
     113, 0.368, false, NULL, false,
     'close M-dwarf companion (Hjorth 2021); proposed primordial-disk-misalignment driver', 'manual', '2021PNAS..11817418H',
     'K2-290 B: M-dwarf at projected separation 113 ± 2 AU (Hjorth et al. 2021 PNAS), corresponding to '
     '~0.52 arcsec at the ~219 pc system distance (consistent with the SIMBAD-recorded separation of '
     '11.25" for the wide companion; B is much closer in). Mass 0.368 ± 0.021 Msun. Spectype M3V '
     'approximate (inferred from mass; not explicitly classified in Hjorth 2021). Hjorth 2021 proposes '
     'this companion as the cause of the primordial-disk misalignment that produced K2-290 A''s '
     'retrograde 124° true obliquity (migration 053). component_teff_k NULL (paper does not quote).'),

    ('K2-290', 'C', 'A', 'M3V', 11.25,
     2467, 0.4, false, NULL, false,
     'wide M-dwarf companion (Best 2022); chaotic-obliquity-evolution driver', 'manual', '2022ApJ...924L..11B',
     'K2-290 C: wide M-dwarf at projected separation 2467 +177/-155 AU (Best et al. 2022 ApJL). At the '
     '~219 pc system distance, this corresponds to ~11.25 arcsec, matching the SIMBAD-recorded '
     'separation that was previously mislabeled as "B" before Hjorth 2021 identified the much closer '
     'true B. Best 2022 argues that secular chaotic obliquity evolution driven by C is sufficient to '
     'explain the retrograde planetary configuration without needing Hjorth''s primordial-disk story. '
     'Spectype M3V approximate; mass ~0.4 Msun (approximate; precise value depends on photometric '
     'modeling). component_teff_k NULL.')
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
