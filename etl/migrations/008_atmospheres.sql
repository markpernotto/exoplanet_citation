-- Atmospheric data, in two layers:
--   1) planet_atmospheric_observations: bulk-loaded "we know this planet has been observed"
--      from NASA Exoplanet Archive's `spectra` table (observation metadata only — instrument,
--      wavelength range, bibcode). One row per observation campaign.
--   2) planet_atmospheres: curated molecule detections — "this planet has H2O at 5σ".
--      Hand-entered or LLM-extracted from the bibcodes in (1) and reviewed.
--      This is the table the VR scene reads to tint the sky.
--
-- Backfill (1): python -m etl.enrich_atmospheric_observations
-- Backfill (2): manual / curated additions — no automated job in v0

CREATE TABLE IF NOT EXISTS planet_atmospheric_observations (
    pl_name           TEXT NOT NULL,
    spec_type         TEXT,                    -- 'transmission' | 'emission' | 'phase' | etc.
    instrument        TEXT,
    facility          TEXT,
    min_wavelength_um DOUBLE PRECISION,
    max_wavelength_um DOUBLE PRECISION,
    num_datapoints    INT,
    bibcode           TEXT,
    notes             TEXT,
    retrieved_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, bibcode, instrument)
);

CREATE INDEX IF NOT EXISTS idx_atm_obs_pl_name
    ON planet_atmospheric_observations (pl_name);

CREATE TABLE IF NOT EXISTS planet_atmospheres (
    pl_name          TEXT NOT NULL,
    molecule         TEXT NOT NULL,             -- 'H2O', 'CO2', 'CH4', 'Na', 'K', etc.
    detection        TEXT NOT NULL,             -- 'detected' | 'tentative' | 'upper_limit'
    instrument       TEXT,                      -- 'JWST/NIRSpec', 'HST/STIS', etc.
    bibcode          TEXT,                      -- ADS reference for the detection
    confidence_sigma DOUBLE PRECISION,          -- statistical significance, when reported
    curator_note     TEXT,                      -- free-text provenance (who/what extracted this)
    curated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, molecule)
);

CREATE INDEX IF NOT EXISTS idx_atmospheres_pl_name
    ON planet_atmospheres (pl_name);
