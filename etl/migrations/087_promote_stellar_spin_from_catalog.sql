-- Bulk-promote host-star spin (rotation period + projected rotation velocity)
-- from the NASA Exoplanet Archive default parameter set into
-- planet_derived_measurements (2026-05-29). Pairs with the obliquity promote
-- (086): the obliquity scene draws a stellar spin axis, and st_rotp lets the
-- renderer turn that axis into a real rotating star (rate scaled, same stylized
-- approach as orbit pacing). st_vsin is surfaced as supplementary cited data.
--
-- NOTE: these are STELLAR properties stored keyed by pl_name (the catalog
-- records them per planet row, and the scene is focal-planet-centric). For
-- multi-planet systems the same value lands under each sibling's name; that
-- redundancy is harmless and keeps the existing focal-planet read path.
--
-- Same rules as 086: lim = 0 only, bibcode from reflink (skip unparseable),
-- unc_hi = err1, unc_lo = abs(err2), provenance = 'nasa_exoplanet_archive',
-- skip planets already curated for the quantity, idempotent ON CONFLICT.

-- Stellar rotation period (days)
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
SELECT
    pl_name,
    'stellar_rotation_period',
    NULLIF(raw_row->>'st_rotp','')::double precision,
    NULLIF(raw_row->>'st_rotperr1','')::double precision,
    abs(NULLIF(raw_row->>'st_rotperr2','')::double precision),
    'days',
    NULL,
    substring(raw_row->>'st_rotp_reflink' from 'abs/([^/]+)/abstract'),
    'NASA Exoplanet Archive default parameter set (st_rotp); host-star rotation period.',
    'nasa_exoplanet_archive'
FROM planets_current
WHERE NULLIF(raw_row->>'st_rotp','') IS NOT NULL
  AND COALESCE(NULLIF(raw_row->>'st_rotplim','')::double precision, 0) = 0
  AND substring(raw_row->>'st_rotp_reflink' from 'abs/([^/]+)/abstract') IS NOT NULL
  AND pl_name NOT IN (
      SELECT pl_name FROM planet_derived_measurements
      WHERE quantity = 'stellar_rotation_period' AND provenance = 'curated'
  )
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

-- Stellar projected rotation velocity v sin i (km/s)
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
SELECT
    pl_name,
    'stellar_vsini',
    NULLIF(raw_row->>'st_vsin','')::double precision,
    NULLIF(raw_row->>'st_vsinerr1','')::double precision,
    abs(NULLIF(raw_row->>'st_vsinerr2','')::double precision),
    'km_s',
    NULL,
    substring(raw_row->>'st_vsin_reflink' from 'abs/([^/]+)/abstract'),
    'NASA Exoplanet Archive default parameter set (st_vsin); host-star projected rotation velocity.',
    'nasa_exoplanet_archive'
FROM planets_current
WHERE NULLIF(raw_row->>'st_vsin','') IS NOT NULL
  AND COALESCE(NULLIF(raw_row->>'st_vsinlim','')::double precision, 0) = 0
  AND substring(raw_row->>'st_vsin_reflink' from 'abs/([^/]+)/abstract') IS NOT NULL
  AND pl_name NOT IN (
      SELECT pl_name FROM planet_derived_measurements
      WHERE quantity = 'stellar_vsini' AND provenance = 'curated'
  )
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
