-- Phase 1 schema for exoplanet_citation
-- Apply with: psql "$DATABASE_URL" -f etl/schema.sql

-- Raw landing: nightly snapshots of NASA Exoplanet Archive pscomppars
-- pscomppars is one-row-per-planet with archive-preferred parameter values,
-- so (snapshot_date, pl_name) is a safe primary key with no row collapse.
CREATE TABLE IF NOT EXISTS planets_snapshots (
    snapshot_date          DATE             NOT NULL,
    pl_name                TEXT             NOT NULL,
    hostname               TEXT             NOT NULL,
    sy_snum                INT,
    sy_pnum                INT,
    discoverymethod        TEXT,
    disc_year              INT,
    disc_facility          TEXT,
    disc_telescope         TEXT,
    disc_instrument        TEXT,
    disc_refname           TEXT,
    pl_orbper              DOUBLE PRECISION,
    pl_rade                DOUBLE PRECISION,
    pl_bmasse              DOUBLE PRECISION,
    pl_eqt                 DOUBLE PRECISION,
    st_dist                DOUBLE PRECISION,
    raw_row                JSONB            NOT NULL,
    source_url             TEXT             NOT NULL,
    source_retrieved_at    TIMESTAMPTZ      NOT NULL,
    source_checksum        TEXT             NOT NULL,
    extraction_version     TEXT             NOT NULL,
    PRIMARY KEY (snapshot_date, pl_name)
);

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_pl_name
    ON planets_snapshots (pl_name);

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_disc_year
    ON planets_snapshots (disc_year);

-- Derived: change events between consecutive snapshots
CREATE TABLE IF NOT EXISTS discovery_changes (
    change_id              BIGSERIAL        PRIMARY KEY,
    observed_at            TIMESTAMPTZ      NOT NULL DEFAULT now(),
    pl_name                TEXT             NOT NULL,
    change_type            TEXT             NOT NULL CHECK (change_type IN ('NEW', 'REMOVED', 'PARAMETER_CHANGE')),
    field_name             TEXT,
    field_tier             TEXT             CHECK (field_tier IN ('A', 'B')),
    prev_value             JSONB,
    new_value              JSONB,
    diff_summary           TEXT,
    source_snapshot_date   DATE             NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_discovery_changes_observed_at
    ON discovery_changes (observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_discovery_changes_pl_name
    ON discovery_changes (pl_name);

CREATE INDEX IF NOT EXISTS idx_discovery_changes_change_type
    ON discovery_changes (change_type);

CREATE INDEX IF NOT EXISTS idx_discovery_changes_field_tier
    ON discovery_changes (field_tier);

-- Idempotency guard for diff.py: don't double-emit identical change rows
-- for the same (snapshot_date, pl_name, change_type, field_name).
CREATE UNIQUE INDEX IF NOT EXISTS uq_discovery_changes_idempotency
    ON discovery_changes (source_snapshot_date, pl_name, change_type, COALESCE(field_name, ''));

-- View: most recent snapshot, exposed as planets_current
CREATE OR REPLACE VIEW planets_current AS
SELECT *
FROM planets_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots);
