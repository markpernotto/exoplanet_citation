-- Migration 003: rebuild planets_current so it sees all columns.
--
-- PostgreSQL expands SELECT * at view-creation time. After migration 001 added
-- typed columns to planets_snapshots (including gaia_dr3_id), any existing
-- planets_current view created with SELECT * will silently omit the new columns
-- until it is dropped and recreated. CREATE OR REPLACE VIEW cannot fix this
-- because it still sees the same old expansion.
--
-- Apply once:
--   psql "$DATABASE_URL" -f etl/migrations/003_fix_planets_current_view.sql

DROP VIEW IF EXISTS planets_current;

CREATE VIEW planets_current AS
SELECT *
FROM planets_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots);
