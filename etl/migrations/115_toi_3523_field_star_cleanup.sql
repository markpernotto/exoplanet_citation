-- Migration 115 (2026-06-26). Cleanup pass after migration 114
-- (114_wds_batch10.sql) hit four primary-key conflicts on apply.
--
-- Three of the conflicts (WASP-2 B, WASP-76 B, WASP-8 B) turned out to
-- already be properly cited rows (Bohn et al. 2020 Paper I or Mugrauer
-- 2019) with equivalent or more complete data than what migration 114
-- proposed -- so we SKIP those and leave the existing rows untouched.
--
-- The remaining conflict, TOI-3523 A B, is a real fix:
--   - An existing SIMBAD-seed stub claims a "B" companion at rho =
--     149.99". At the system distance d ~ 606 pc (parallax 1.651 mas
--     per Yee et al. 2025), 149.99" corresponds to a projected
--     separation of ~91,000 AU. That is well beyond the bound-companion
--     regime (Gaia wide-binary catalogs become chance-alignment-
--     dominated above ~30,000 AU) and the entry has no source_bibcode
--     to defend the claim.
--   - Yee et al. 2025 (2025ApJS..280...30Y) Table 7 detects the actual
--     close visual companion to TOI-3523 A at rho = 0.67", PA = 95.7
--     deg via Palomar PHARO AO and SAI-2.5m speckle. That companion
--     deserves the 'B' designation.
--
-- The 8.50" tertiary 'C' row from Yee 2025 was successfully inserted
-- by migration 114 -- only the close 'B' row was blocked by the
-- citation-less wide stub.
--
-- This migration:
--   (a) DELETEs the SIMBAD stub for TOI-3523 A B (guarded by
--       source_catalog and source_bibcode IS NULL so we cannot
--       accidentally delete a cited row).
--   (b) INSERTs the Yee 2025 close companion data.
--
-- Apply after 114_wds_batch10.sql.


-- (a) Delete the citation-less SIMBAD stub at 149.99"
DELETE FROM binary_companions
 WHERE hostname = 'TOI-3523 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;


-- (b) Insert the real close companion from Yee et al. 2025
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-3523 A', 'B', 'A', NULL, 0.67,
     410, NULL, false, NULL, false,
     'close AO+speckle imaging companion', 'manual', '2025ApJS..280...30Y',
     'TOI-3523 A B: close visual companion (Yee et al. 2025 Table 7, 2025ApJS..280...30Y) detected '
     'via Palomar PHARO AO (Brgamma, Hcont; 2023-06-07) and SAI-2.5m speckle Polarimeter Ic '
     '(2023-08-02, 2023-08-27). rho = 0.67", PA = 95.7 deg. AO Delta-m = 2.058 (Hcont), 2.105 '
     '(Brgamma), 3.5 (I). Too close for Gaia DR3 to resolve. Projected separation ~410 AU at '
     'd ~ 606 pc (parallax 1.651 mas). Paper does not derive a companion mass. NB: TOI-3523 is '
     'a TRIPLE -- separate wider tertiary C row exists from migration 114 (rho = 8.50", '
     'projected separation 5200 AU, Gaia DR3 ID 2080811118319127680). Replaces a citation-less '
     'SIMBAD-seed stub at 149.99" that was almost certainly an unbound field-star alignment at '
     '~91,000 AU.',
     95.7);
