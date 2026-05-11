-- Hand-curated mutual inclinations for multi-planet systems where the 3D
-- orbital architecture has been measured (direct imaging, transit timing
-- variations, or multi-method follow-up).
--
-- One row per (hostname, secondary planet). Seed data is hand-entered from
-- published papers; expand over time. v1 stays small (~20-25 systems);
-- a future LLM-extraction pass over discovery_papers can grow it.
--
-- The renderer reads this table to tilt sibling orbits in the VR scene
-- when a system has measured geometry; otherwise orbits are assumed coplanar.

CREATE TABLE IF NOT EXISTS system_orbital_geometry (
    hostname              TEXT NOT NULL,
    pl_name               TEXT NOT NULL,        -- the planet whose orbit is being characterized
    reference_pl_name     TEXT,                 -- planet whose plane is the reference (NULL = system's primary plane)
    mutual_inclination_deg DOUBLE PRECISION,    -- angle between this planet's orbit and the reference plane
    inclination_uncertainty_deg DOUBLE PRECISION,
    method                TEXT NOT NULL,        -- 'direct_imaging' | 'TTV' | 'astrometric' | 'RV+transit' | 'manual'
    bibcode               TEXT,                 -- ADS reference for the measurement
    note                  TEXT,                 -- free-text — alignment story, caveats, etc.
    curated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, pl_name)
);

CREATE INDEX IF NOT EXISTS idx_orbital_geometry_hostname
    ON system_orbital_geometry (hostname);
