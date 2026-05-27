-- binary_companions hostname alias normalization (2026-05-27). Sixteenth
-- migration of the S-type stellar-multiplicity audit campaign and the FINAL
-- v0.1 fix in the audit. The Mugrauer 2019 bulk attack (migration 077) wrote
-- some binary_companions rows under the host name that Mugrauer's paper used
-- (e.g. "HAT-P-10", "Kepler-13", "Pr 0211"); for 9 of those, our NASA EA
-- catalog uses a DIFFERENT canonical host name (e.g. "WASP-11", "KOI-13",
-- "Pr0211"). The Q1 audit (hostname-joined COUNT of planet_publications
-- entries) saw 31 missing links, of which 10 were fixable. Six of those 10
-- need this hostname-rename UPDATE to make the join match the catalog (the
-- other four were pure pl_name renames in the seed file alone).
--
-- The 9 hostname renames here:
--   HAT-P-10      -> WASP-11   (same star, two surveys / two discovery papers)
--   Kepler-13     -> KOI-13    (catalog uses KOI- form for this object)
--   Kepler-89     -> KOI-94    (catalog uses KOI- form)
--   HD 132563 B   -> HD 132563 (catalog drops the B subscript)
--   HD 195689     -> KELT-9    (HD 195689 = KELT-9; catalog uses survey name)
--   Pr 0211       -> Pr0211    (catalog has no internal space)
--   Qatar 6       -> Qatar-6   (catalog uses hyphen)
--   WASP-87 A     -> WASP-87   (catalog drops the A suffix)
--   Aldebaran     -> alf Tau   (catalog uses Bayer designation)
--
-- The Mugrauer 2019 source paper's hostname labels were preserved verbatim
-- in migration 077 for fidelity-to-the-paper; this migration reconciles to
-- the catalog hostname so downstream joins (Q1 audit, 3D renderer system
-- lookup, planet-detail-page binary_companions list) all resolve.
--
-- The proper long-term fix is a planet_aliases table (deferred to v0.2);
-- with that table, the rename here would be unnecessary because the join
-- could resolve via alias. For v0.1 we touch the 9 specific rows.
--
-- Apply after 077_mugrauer2019_bulk.sql (the source of all 9 rows). Idempotent:
-- after the UPDATE runs once, re-applying is a no-op (the WHERE predicates
-- won't match any rows because the hostnames are already the new values).

UPDATE binary_companions SET hostname = 'WASP-11'    WHERE hostname = 'HAT-P-10';
UPDATE binary_companions SET hostname = 'KOI-13'     WHERE hostname = 'Kepler-13';
UPDATE binary_companions SET hostname = 'KOI-94'     WHERE hostname = 'Kepler-89';
UPDATE binary_companions SET hostname = 'HD 132563'  WHERE hostname = 'HD 132563 B';
UPDATE binary_companions SET hostname = 'KELT-9'     WHERE hostname = 'HD 195689';
UPDATE binary_companions SET hostname = 'Pr0211'     WHERE hostname = 'Pr 0211';
UPDATE binary_companions SET hostname = 'Qatar-6'    WHERE hostname = 'Qatar 6';
UPDATE binary_companions SET hostname = 'WASP-87'    WHERE hostname = 'WASP-87 A';
UPDATE binary_companions SET hostname = 'alf Tau'    WHERE hostname = 'Aldebaran';
