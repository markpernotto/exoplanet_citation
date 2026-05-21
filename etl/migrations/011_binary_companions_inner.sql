-- Extend binary_companions to hold the *inner* (tight / spectroscopic / eclipsing)
-- binaries that define P-type circumbinary architectures, not just the wide visual
-- companions SIMBAD/WDS resolve.
--
-- Motivation: the cb_flag audit (docs/cb_flag_audit.md, 2026-05) found that 28 of
-- 44 cb_flag=1 hosts had NO binary_companions row at all, because the tight inner
-- binaries that make a system circumbinary are unresolved and absent from
-- wide-binary catalogs. The discovery-paper inner-binary parameters were harvested
-- by hand into the audit's per-entry Notes; this migration gives them a home and
-- the next migration backfills them.
--
-- Design: stays one-row-per-companion. Existing SIMBAD rows simply carry the new
-- columns as NULL and inner_binary = FALSE. Manually curated inner binaries are
-- inserted with inner_binary = TRUE and source_catalog = 'manual'. Primary-star
-- parameters are denormalised onto the companion row (circumbinary inner binaries
-- have a single companion, so there is no duplication in practice).
--
-- Idempotent. Apply after 007_binary_companions.sql.

ALTER TABLE binary_companions
    ADD COLUMN IF NOT EXISTS inner_binary          BOOLEAN NOT NULL DEFAULT FALSE,
    -- TRUE  = the tight pair the planet orbits as a unit (defines the P-type architecture)
    -- FALSE = a wide visual tertiary/field companion (the existing SIMBAD/WDS rows)
    ADD COLUMN IF NOT EXISTS binary_class          TEXT,
    -- free-text class tag, e.g. 'main-sequence EB', 'sdB+dM', 'WD+dM (polar)',
    -- 'PCEB', 'T Tauri', 'pulsar+WD', 'LMXB', 'BD+BD', 'ultracool dwarf binary'

    -- orbital relationship of the A-companion pair --------------------------------
    ADD COLUMN IF NOT EXISTS separation_au         DOUBLE PRECISION,  -- physical or projected, see notes
    ADD COLUMN IF NOT EXISTS orbital_period_d      DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS eccentricity          DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS inclination_deg       DOUBLE PRECISION,

    -- companion (component_*) extras (mass/teff/mag/spectype already exist) -------
    ADD COLUMN IF NOT EXISTS component_radius_rsun DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS component_mass_is_min BOOLEAN,            -- TRUE if component_mass_msun is m sin i

    -- primary (planet-hosting component) parameters ------------------------------
    ADD COLUMN IF NOT EXISTS primary_mass_msun     DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS primary_radius_rsun   DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS primary_teff_k        DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS primary_spectype      TEXT,

    -- provenance / caveats -------------------------------------------------------
    ADD COLUMN IF NOT EXISTS notes                 TEXT;

CREATE INDEX IF NOT EXISTS idx_binary_companions_inner
    ON binary_companions (inner_binary) WHERE inner_binary;

COMMENT ON COLUMN binary_companions.inner_binary IS
    'TRUE for the tight pair that defines the P-type circumbinary architecture; FALSE for wide visual/field companions.';
COMMENT ON COLUMN binary_companions.separation_au IS
    'Physical separation in AU for inner binaries; for unresolved spectroscopic pairs this is derived from the orbit, not measured. See notes column for which.';
