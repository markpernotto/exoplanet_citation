-- Companion-star astrometry for multi-star systems hosting confirmed exoplanets.
-- Drives the VR scene's accurate placement of "second/third suns" in the sky.
-- Backfill: python -m etl.enrich_binaries
-- Nightly: same script is idempotent — only refreshes hostnames whose entry is older than 30 days.

CREATE TABLE IF NOT EXISTS binary_companions (
    hostname              TEXT NOT NULL,
    component_designation TEXT NOT NULL,    -- 'A', 'B', 'C', etc. (the companion)
    primary_designation   TEXT NOT NULL,    -- the component the planet orbits
    separation_arcsec     DOUBLE PRECISION,
    position_angle_deg    DOUBLE PRECISION,
    component_mass_msun   DOUBLE PRECISION,
    component_teff_k      DOUBLE PRECISION,
    component_mag_v       DOUBLE PRECISION,
    component_spectype    TEXT,
    source_catalog        TEXT NOT NULL,    -- 'SIMBAD' | 'WDS' | 'manual'
    source_bibcode        TEXT,             -- ADS reference for the measurement, when known
    retrieved_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, component_designation)
);

CREATE INDEX IF NOT EXISTS idx_binary_companions_source
    ON binary_companions (source_catalog);
