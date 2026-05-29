-- Bulk-promote spin-orbit obliquity from the NASA Exoplanet Archive default
-- parameter set into planet_derived_measurements (2026-05-29). Takes the v0.2
-- obliquity visual from the 5 curated "Tilted & Tumbling" systems to every
-- catalog planet with a measured obliquity (233 distinct), with citation
-- provenance preserved via the per-parameter reflink. The renderer already
-- consumes projected_obliquity / true_obliquity, so no frontend change is
-- needed for these to render; they tilt the orbit relative to the stellar
-- equator just like the curated ones.
--
-- This is STELLAR spin-orbit angle (orbit vs the host star's spin), NOT the
-- planet's axial tilt. See migrations 051-055 for the curated deep dives.
--
-- Rules:
--   * lim = 0 only: skip catalog upper/lower bounds (pl_*lim <> 0).
--   * bibcode parsed from the reflink href; skip the handful that don't parse
--     (bibcode is part of the PK, so it cannot be NULL).
--   * unc_hi = err1, unc_lo = abs(err2) (catalog err2 is negative; curated rows
--     store positive magnitudes).
--   * provenance = 'nasa_exoplanet_archive'; model left NULL (the catalog does
--     not record a uniform method per row).
--   * skip planets that already have a CURATED row for the quantity, so the
--     hand-written deep-dive notes are never clobbered.
--   * ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING -> idempotent.

-- Projected obliquity (lambda)
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
SELECT
    pl_name,
    'projected_obliquity',
    NULLIF(raw_row->>'pl_projobliq','')::double precision,
    NULLIF(raw_row->>'pl_projobliqerr1','')::double precision,
    abs(NULLIF(raw_row->>'pl_projobliqerr2','')::double precision),
    'deg',
    NULL,
    substring(raw_row->>'pl_projobliq_reflink' from 'abs/([^/]+)/abstract'),
    'NASA Exoplanet Archive default parameter set (pl_projobliq); sky-projected spin-orbit angle.',
    'nasa_exoplanet_archive'
FROM planets_current
WHERE NULLIF(raw_row->>'pl_projobliq','') IS NOT NULL
  AND COALESCE(NULLIF(raw_row->>'pl_projobliqlim','')::double precision, 0) = 0
  AND substring(raw_row->>'pl_projobliq_reflink' from 'abs/([^/]+)/abstract') IS NOT NULL
  AND pl_name NOT IN (
      SELECT pl_name FROM planet_derived_measurements
      WHERE quantity = 'projected_obliquity' AND provenance = 'curated'
  )
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

-- True obliquity (psi), where the catalog has a de-projected value
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
SELECT
    pl_name,
    'true_obliquity',
    NULLIF(raw_row->>'pl_trueobliq','')::double precision,
    NULLIF(raw_row->>'pl_trueobliqerr1','')::double precision,
    abs(NULLIF(raw_row->>'pl_trueobliqerr2','')::double precision),
    'deg',
    NULL,
    substring(raw_row->>'pl_trueobliq_reflink' from 'abs/([^/]+)/abstract'),
    'NASA Exoplanet Archive default parameter set (pl_trueobliq); de-projected 3-D spin-orbit angle.',
    'nasa_exoplanet_archive'
FROM planets_current
WHERE NULLIF(raw_row->>'pl_trueobliq','') IS NOT NULL
  AND COALESCE(NULLIF(raw_row->>'pl_trueobliqlim','')::double precision, 0) = 0
  AND substring(raw_row->>'pl_trueobliq_reflink' from 'abs/([^/]+)/abstract') IS NOT NULL
  AND pl_name NOT IN (
      SELECT pl_name FROM planet_derived_measurements
      WHERE quantity = 'true_obliquity' AND provenance = 'curated'
  )
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
