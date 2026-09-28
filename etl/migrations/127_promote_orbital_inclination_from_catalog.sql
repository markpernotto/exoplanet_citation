-- Bulk-promote orbital inclination (pl_orbincl) from the NASA Exoplanet
-- Archive default parameter set into planet_derived_measurements, with the
-- per-parameter reflink bibcode as citation. Same pattern as 086 (obliquity).
--
-- Why now: the 3D scene draws a debris disk's measured inclination as a tilt
-- away from the planets' orbital plane, but that inclination is measured
-- against our line of sight, not against the orbits. β Pic's disk (88.9 deg)
-- and planets (b 89.0, c 88.9 deg) are coplanar, yet the scene drew them at
-- right angles. The fix compares the disk's sky inclination with the
-- reference orbit's sky inclination, and that needs the orbit inclination as
-- a cited value the scene can show next to the disk.
--
-- Both are sky-plane inclinations, so |i_disk - i_orbit| is only a LOWER
-- bound on the disk-to-orbit mutual inclination (the longitudes of the
-- ascending node are unknown). The renderer labels it as such and prefers a
-- cited mutual inclination whenever a paper states one.
--
-- Rules (as 086):
--   * lim = 0 only: skip catalog upper/lower bounds (pl_orbincllim <> 0).
--   * bibcode parsed from the reflink href; rows whose reflink is not an ADS
--     abstract (e.g. the Kepler DR25 KOI table) are skipped, because bibcode
--     is part of the PK and a citation is required to surface the value.
--   * unc_hi = err1, unc_lo = abs(err2).
--   * provenance = 'nasa_exoplanet_archive'; model NULL.
--   * skip planets that already have a CURATED orbital_inclination row (e.g.
--     bet Pic d from migration 124), so deep-dive values are never clobbered.
--   * ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING -> idempotent.
--
-- Not shown on the planet page (the Composition block filters to composition
-- quantities); consumed by the 3D scene's debris-disk tilt.
--
-- Apply after 126; idempotent on re-run.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
SELECT
    pl_name,
    'orbital_inclination',
    NULLIF(raw_row->>'pl_orbincl','')::double precision,
    NULLIF(raw_row->>'pl_orbinclerr1','')::double precision,
    abs(NULLIF(raw_row->>'pl_orbinclerr2','')::double precision),
    'deg',
    NULL,
    substring(raw_row->>'pl_orbincl_reflink' from 'abs/([^/]+)/abstract'),
    'NASA Exoplanet Archive default parameter set (pl_orbincl); orbital inclination to the line of sight.',
    'nasa_exoplanet_archive'
FROM planets_current
WHERE NULLIF(raw_row->>'pl_orbincl','') IS NOT NULL
  AND COALESCE(NULLIF(raw_row->>'pl_orbincllim','')::double precision, 0) = 0
  AND substring(raw_row->>'pl_orbincl_reflink' from 'abs/([^/]+)/abstract') IS NOT NULL
  AND pl_name NOT IN (
      SELECT pl_name FROM planet_derived_measurements
      WHERE quantity = 'orbital_inclination' AND provenance = 'curated'
  )
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

-- Verify:
--   SELECT provenance, count(*) FROM planet_derived_measurements
--    WHERE quantity = 'orbital_inclination' GROUP BY provenance;
--   -- expect a few curated rows plus a few thousand nasa_exoplanet_archive rows
--   SELECT pl_name, value, bibcode FROM planet_derived_measurements
--    WHERE quantity = 'orbital_inclination'
--      AND pl_name IN ('bet Pic b', 'bet Pic c', 'HR 8799 e', 'AU Mic b')
--    ORDER BY pl_name;
--   -- expect bet Pic b ~89.0, bet Pic c ~88.9, HR 8799 e 25.0 (2019A&A...623L..11G)
