-- Add STORED generated columns `normalized_pl_name` and
-- `normalized_hostname` to planets_snapshots, then build new GIN
-- trigram indexes on them. Eliminates the per-row normalize_alias()
-- call in the bitmap-heap-scan recheck step that made broad-prefix
-- queries like "Kepler-" take 30+ seconds.
--
-- WHAT CHANGES:
--   - Two new STORED columns, auto-populated from pl_name / hostname
--     via the existing IMMUTABLE normalize_alias() function. The ETL
--     in etl/load.py uses an explicit column list and never names
--     these, so INSERTs and ON CONFLICT UPDATEs continue to work and
--     Postgres recomputes the generated values whenever the source
--     columns change.
--   - Two new GIN trgm indexes on the new columns. These replace the
--     expression-based GIN indexes from migration 095 for substring
--     matching -- when the WHERE clause references the column
--     directly instead of normalize_alias(pl_name), the planner can
--     skip the recheck function call entirely.
--
-- WHAT STAYS:
--   - The 095 expression-based GIN indexes (idx_*_norm_*_trgm) are
--     LEFT IN PLACE deliberately. They're redundant with the new
--     column-based indexes once api/index.py is updated, but keeping
--     them avoids a slow window between this migration applying and
--     the code deploy landing. A later migration can drop them once
--     production has been stable on the new code for a while.
--
-- DEPLOYMENT NOTES:
--   - The ADD COLUMN triggers a full table rewrite (~25k rows). Lock
--     held for the duration is AccessExclusiveLock on
--     planets_snapshots; every endpoint that reads from that table
--     (and the nightly ETL's INSERT) will block until done. Estimate
--     30-60 seconds on this catalog size.
--   - Run this OUTSIDE the nightly ETL window (06:00 UTC) and during
--     a quiet traffic window. Confirm the nightly cron is not
--     mid-run before applying.
--   - After this migration applies cleanly, deploy the matching
--     api/index.py change (the one that references the new columns
--     directly in its UNION query). Until that code ships, queries
--     still call normalize_alias() per row -- the 095 expression
--     indexes keep them fast in that interim window.
--
-- Idempotent: ADD COLUMN IF NOT EXISTS and CREATE INDEX IF NOT EXISTS.

ALTER TABLE planets_snapshots
    ADD COLUMN IF NOT EXISTS normalized_pl_name TEXT
        GENERATED ALWAYS AS (normalize_alias(pl_name)) STORED;

ALTER TABLE planets_snapshots
    ADD COLUMN IF NOT EXISTS normalized_hostname TEXT
        GENERATED ALWAYS AS (normalize_alias(hostname)) STORED;

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_normalized_pl_name_trgm
    ON planets_snapshots
    USING gin (normalized_pl_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_normalized_hostname_trgm
    ON planets_snapshots
    USING gin (normalized_hostname gin_trgm_ops);
