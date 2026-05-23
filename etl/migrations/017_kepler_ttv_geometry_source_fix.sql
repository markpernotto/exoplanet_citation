-- Correct the orbital-geometry provenance for the four Kepler TTV systems that
-- migration 010 attributed to Fabrycky et al. 2014 (2014ApJ...790..146F). That
-- paper is a STATISTICAL architecture study across 365 Kepler multi-planet
-- systems using a generic mass-radius relation; it does not derive any single
-- system's mutual inclinations. Each system has a proper per-system source
-- (bibcodes re-verified via ADS, 2026-05-22); the matching citations are seeded
-- as role='characterization', contribution='mutual_inclination' in
-- etl/seed_followup_citations.py:
--
--   Kepler-11 -> Lissauer et al. 2013 (2013ApJ...770..131L), the six-planet TTV
--                dynamical analysis (eccentricity vectors + inclinations).
--   Kepler-9  -> Borsato et al. 2014 (2014A&A...571A..38B), the TRADES N-body
--                fit to the transit times and radial velocities.
--   Kepler-30 -> Sanchis-Ojeda et al. 2012 (2012Natur.487..449S), which shows
--                the three orbits are coplanar and aligned with the stellar spin.
--   Kepler-36 -> Carter et al. 2012 (2012Sci...337..556C), the discovery
--                dynamical solution.
--
-- (Sanchis-Ojeda 2012 and Carter 2012 are also the discovery cites for their
-- systems; this only changes the geometry-table provenance, not the citation
-- graph, which the seed handles.)
--
-- Apply after 010_orbital_geometry_seed.sql. Idempotent: each UPDATE is scoped
-- to rows still carrying the Fabrycky bibcode, so re-running matches 0 rows.

UPDATE system_orbital_geometry SET bibcode = '2013ApJ...770..131L'
WHERE hostname = 'Kepler-11' AND bibcode = '2014ApJ...790..146F';

UPDATE system_orbital_geometry SET bibcode = '2014A&A...571A..38B'
WHERE hostname = 'Kepler-9' AND bibcode = '2014ApJ...790..146F';

UPDATE system_orbital_geometry SET bibcode = '2012Natur.487..449S'
WHERE hostname = 'Kepler-30' AND bibcode = '2014ApJ...790..146F';

UPDATE system_orbital_geometry SET bibcode = '2012Sci...337..556C'
WHERE hostname = 'Kepler-36' AND bibcode = '2014ApJ...790..146F';
