-- 129_discovery_change_reflinks.sql
-- Give every change event a citation for the value it reports.
--
-- Until now a PARAMETER_CHANGE row stored only the field and its old and new
-- values (e.g. HD 65216 c pl_orbper 5370.0 -> 7007.0), and the homepage
-- revisions list and RSS feeds surfaced those values with no source. NASA EA
-- publishes the source for each composite parameter as a per-field reference
-- anchor in pscomppars (`pl_orbper_reflink`, `pl_bmasse_reflink`, ...), which
-- we already keep in planets_snapshots.raw_row. These columns record it on the
-- change itself, verbatim, the same way planets_snapshots stores disc_refname:
--
--   <a refstr=BONOMO_ET_AL_2023 href=https://ui.adsabs.harvard.edu/abs/...
--      target=ref>Bonomo et al. 2023</a>
--
-- The API parses the anchor into label / url / bibcode. Not every reference is
-- an ADS paper: NASA also cites journal URLs without a bibcode, archive tables
-- (Kepler KOI), ExoFOP, and "Calculated Value" (a value NASA derived itself,
-- e.g. Earth masses from a Jupiter-mass measurement). All are kept and labelled
-- as what they are; NULL means NASA gave no reference.
--
--   prev_reflink  reference behind prev_value (from the previous snapshot)
--   new_reflink   reference behind new_value (from source_snapshot_date)
--
-- Keeping both shows when a value moved because NASA switched its default
-- solution from one paper to another.
--
-- Which reference a field uses is set by FieldSpec.ref_col in etl/diff.py.
-- discoverymethod / disc_year / disc_facility have no per-field reflink, so
-- they record disc_refname, which the UI labels "discovery reference" (NASA
-- does not update it when it reclassifies a planet). NEW and REMOVED rows
-- record the discovery paper too.
--
-- This migration adds the columns and backfills NEW / REMOVED rows, whose
-- snapshot of the planet row already holds disc_refname. PARAMETER_CHANGE rows
-- need the archived snapshots in R2 and are backfilled by
-- `python -m etl.backfill_change_reflinks` (run with --dry-run first).
--
-- Deploy order: apply this before the next nightly run picks up the new
-- etl/diff.py, which inserts into these columns.
--
-- Apply after 128; idempotent on re-run.

BEGIN;

ALTER TABLE discovery_changes
    ADD COLUMN IF NOT EXISTS prev_reflink TEXT,
    ADD COLUMN IF NOT EXISTS new_reflink  TEXT;

COMMENT ON COLUMN discovery_changes.prev_reflink IS
    'NASA EA reference anchor (pscomppars *_reflink or disc_refname) behind prev_value; NULL = none given';
COMMENT ON COLUMN discovery_changes.new_reflink IS
    'NASA EA reference anchor (pscomppars *_reflink or disc_refname) behind new_value; NULL = none given';

UPDATE discovery_changes
SET new_reflink = new_value->>'disc_refname'
WHERE change_type = 'NEW'
  AND new_reflink IS NULL
  AND new_value->>'disc_refname' IS NOT NULL;

UPDATE discovery_changes
SET prev_reflink = prev_value->>'disc_refname'
WHERE change_type = 'REMOVED'
  AND prev_reflink IS NULL
  AND prev_value->>'disc_refname' IS NOT NULL;

COMMIT;
