-- Phase 1.x migration: promote ~13 columns from raw_row JSONB into typed
-- columns on planets_snapshots. These drive procedural rendering, the
-- planet "stat card" UI, and the galactic-positioning view.
--
-- Apply once against an existing DB:
--   psql "$DATABASE_URL" -f etl/migrations/001_phase1x_typed_columns.sql
--
-- After applying, re-run `python -m etl.load` to repopulate the new columns
-- from the existing R2-cached snapshot. The snapshot CSV is unchanged; only
-- our typed projection of it expands.

ALTER TABLE planets_snapshots
    ADD COLUMN IF NOT EXISTS pl_orbsmax  DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS pl_orbeccen DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS pl_dens     DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS pl_insol    DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS st_teff     DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS st_rad      DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS st_mass     DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS st_lum      DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS st_spectype TEXT,
    ADD COLUMN IF NOT EXISTS sy_dist     DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS ra          DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS dec         DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS gaia_dr3_id TEXT;
