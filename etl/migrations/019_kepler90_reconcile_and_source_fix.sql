-- Kepler-90 (geometry hostname KOI-351): pl_name reconciliation + geometry
-- source fix (manual deep dive, 2026-05-22).
--
-- Two problems, fixed together:
--   1. Naming. migration 010 keyed this system's geometry rows 'Kepler-90 b'..'h'
--      plus 'Kepler-90 i', but planets_current (NASA EA) names the first seven
--      'KOI-351 b'..'h' and only the eighth 'Kepler-90 i'. The b-h rows were
--      therefore orphaned (no matching catalog planet). Rename them to the
--      catalog form so the geometry joins and can be cited against real keys.
--   2. Source. migration 010 attributed all eight planets to Rowe et al. 2014
--      (2014ApJ...784...45R), a bulk validation paper for hundreds of systems
--      that also predates the eighth planet. Repoint b-h to Cabrera et al. 2014
--      (2014ApJ...781...18C, the dedicated seven-planet system paper) and planet
--      i to Shallue & Vanderburg 2018 (2018AJ....155...94S, which discovered it).
--      Bibcodes re-verified via ADS. Citations seeded as role='characterization',
--      contribution='mutual_inclination' in etl/seed_followup_citations.py.
--
-- Order matters: rewrite reference_pl_name and the bibcodes (keyed on the old
-- 'Kepler-90 b'..'h' names) BEFORE renaming pl_name, so the bibcode updates still
-- match. Each statement is scoped to its pre-fix value, so the whole migration is
-- idempotent (a second run matches 0 rows everywhere). The (hostname, pl_name)
-- uniqueness from migration 010 is safe: KOI-351 b..h do not yet exist as
-- geometry rows.
--
-- Apply after 010_orbital_geometry_seed.sql. Idempotent.

-- 1. Reference plane label moves to the catalog name (all 8 rows reference b).
UPDATE system_orbital_geometry SET reference_pl_name = 'KOI-351 b'
WHERE hostname = 'KOI-351' AND reference_pl_name = 'Kepler-90 b';

-- 2. Planet i -> its discovery paper (keyed before any rename; i keeps its name).
UPDATE system_orbital_geometry SET bibcode = '2018AJ....155...94S'
WHERE hostname = 'KOI-351' AND pl_name = 'Kepler-90 i'
  AND bibcode = '2014ApJ...784...45R';

-- 3. Planets b-h -> Cabrera et al. 2014 (still under their old 'Kepler-90 x' keys).
UPDATE system_orbital_geometry SET bibcode = '2014ApJ...781...18C'
WHERE hostname = 'KOI-351' AND pl_name LIKE 'Kepler-90 %'
  AND pl_name <> 'Kepler-90 i' AND bibcode = '2014ApJ...784...45R';

-- 4. Rename b-h to the catalog form (single-letter suffix preserved).
UPDATE system_orbital_geometry SET pl_name = 'KOI-351 ' || right(pl_name, 1)
WHERE hostname = 'KOI-351' AND pl_name LIKE 'Kepler-90 %' AND pl_name <> 'Kepler-90 i';
