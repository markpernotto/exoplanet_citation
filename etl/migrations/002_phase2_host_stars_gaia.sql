-- Phase 2 migration: Gaia DR3 host-star enrichment + resumable backfill state.
--
-- Adds two tables:
--   * host_stars_gaia: one row per unique Gaia DR3 source we've enriched.
--     Keyed by gaia_dr3_id (the bare integer source ID, stored as TEXT to
--     avoid overflow risk in clients that don't carry int64 well, and to
--     preserve any leading-zero or whitespace quirks the loader didn't
--     normalize). Joins to planets_snapshots.gaia_dr3_id (post-parse).
--   * backfill_state: generic resume cursor for long-running batched jobs
--     (Gaia enrichment, citation resolution, future ADS lookups). One row
--     per logical batch.
--
-- Apply once against an existing DB:
--   psql "$DATABASE_URL" -f etl/migrations/002_phase2_host_stars_gaia.sql
--
-- After applying, run `make enrich-gaia` (or `python -m etl.enrich_gaia`) to
-- populate host_stars_gaia from the existing planets_snapshots cross-references.

CREATE TABLE IF NOT EXISTS host_stars_gaia (
    gaia_dr3_id            TEXT             PRIMARY KEY,
    hostname               TEXT             NOT NULL,
    parallax_mas           DOUBLE PRECISION,
    parallax_error         DOUBLE PRECISION,
    pmra_mas_yr            DOUBLE PRECISION,
    pmdec_mas_yr           DOUBLE PRECISION,
    radial_velocity_km_s   DOUBLE PRECISION,
    phot_g_mean_mag        DOUBLE PRECISION,
    phot_bp_mean_mag       DOUBLE PRECISION,
    phot_rp_mean_mag       DOUBLE PRECISION,
    bp_rp                  DOUBLE PRECISION,
    teff_gspphot           DOUBLE PRECISION,
    logg_gspphot           DOUBLE PRECISION,
    mh_gspphot             DOUBLE PRECISION,
    distance_gspphot_pc    DOUBLE PRECISION,
    source_record          JSONB            NOT NULL,
    retrieved_at           TIMESTAMPTZ      NOT NULL DEFAULT now()
);

-- Hostname index supports the API's planned /api/planets/{name}/host_star
-- endpoint (joins by hostname when gaia_dr3_id resolution is uncertain).
CREATE INDEX IF NOT EXISTS idx_host_stars_gaia_hostname
    ON host_stars_gaia (hostname);

-- retrieved_at index supports re-enrichment workflows (find rows older than X).
CREATE INDEX IF NOT EXISTS idx_host_stars_gaia_retrieved_at
    ON host_stars_gaia (retrieved_at DESC);


CREATE TABLE IF NOT EXISTS backfill_state (
    batch_id                TEXT             PRIMARY KEY,
    -- Generic resume cursor — caller-defined semantics. For Gaia enrichment
    -- this typically holds the last processed gaia_dr3_id; for citation
    -- resolution it holds the last processed pl_name. Diverges from the
    -- earlier PLAN.md spec ("last_processed_pl_name") because the column is
    -- shared across non-planet batches.
    last_processed_key      TEXT             NOT NULL DEFAULT '',
    total_targets           INT              NOT NULL,
    processed_count         INT              NOT NULL DEFAULT 0,
    error_count             INT              NOT NULL DEFAULT 0,
    last_updated_at         TIMESTAMPTZ      NOT NULL DEFAULT now(),
    status                  TEXT             NOT NULL
        CHECK (status IN ('in_progress', 'completed', 'paused', 'failed')),
    -- Free-form per-batch metadata: KPI snapshots (e.g. resolution_rate),
    -- last error message, source-system rate-limit telemetry. Schema-less by
    -- design; consumers should treat unknown keys as opaque.
    notes                   JSONB            NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_backfill_state_status
    ON backfill_state (status, last_updated_at DESC);
