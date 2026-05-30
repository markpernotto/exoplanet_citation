-- Add a provenance flag to planet_derived_measurements so hand-reviewed deep
-- dives are distinguishable from catalog bulk-ingest (manual deep dive,
-- 2026-05-29). The table was built "provenance-carrying" (migration 024) but
-- the only provenance was the bibcode; nothing separated a curated row from a
-- row promoted wholesale out of the NASA Exoplanet Archive's default parameter
-- set. As we begin promoting cited raw_row parameters in bulk (obliquity in
-- migration 086, stellar spin in 087), that distinction has to be explicit so
-- the renderer and UI can prefer curated values and label the source honestly.
--
-- Controlled vocabulary (kept as a comment, matching how `quantity` is governed
-- in migration 024 rather than a CHECK, so future sources can be added freely):
--   'curated'                -- hand-entered from a reviewed paper/table
--   'nasa_exoplanet_archive' -- promoted from raw_row, cite = the EA reflink
--
-- DEFAULT 'curated' is correct for backfill: every row that exists today was
-- hand-entered via a migration. Idempotent.

ALTER TABLE planet_derived_measurements
    ADD COLUMN IF NOT EXISTS provenance TEXT NOT NULL DEFAULT 'curated';

CREATE INDEX IF NOT EXISTS idx_derived_provenance
    ON planet_derived_measurements (provenance);
