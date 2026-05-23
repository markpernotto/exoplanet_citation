-- Orbital-geometry provenance correction, round 2 (manual deep dive,
-- 2026-05-22). The second pass over the migration-010 geometry cohort found that
-- WASP-47's recorded bibcode 2017AJ....154..237B does not resolve: the
-- volume/page is Vanderburg et al. 2017, "Precise Masses in the WASP-47 System"
-- (2017AJ....154..237V), and the trailing author initial was a typo (B for V).
-- Bibcode re-verified via ADS. The matching citation is seeded as
-- role='characterization', contribution='mutual_inclination' in
-- etl/seed_followup_citations.py.
--
-- The other seven round-2 systems (K2-138, Kepler-186, Kepler-223, Kepler-419,
-- Kepler-444, Kepler-56, TOI-178) had correct recorded bibcodes and need no
-- migration, only the citation links.
--
-- DEFERRED -- Kepler-90 (geometry hostname KOI-351): its rows were also found
-- to be mis-sourced (Rowe et al. 2014 bulk validation paper; the dedicated
-- sources are Cabrera et al. 2014 for planets b-h and Shallue & Vanderburg 2018
-- for planet i). It is NOT fixed here because system_orbital_geometry keys those
-- planets as 'Kepler-90 b'..'h' while planets_current names them 'KOI-351 b'..'h'
-- (only the eighth planet is 'Kepler-90 i'). That pl_name mismatch must be
-- reconciled before the geometry can be re-sourced and cited against real
-- catalog keys; held for a dedicated migration.
--
-- Apply after 010_orbital_geometry_seed.sql. Idempotent: the UPDATE is scoped to
-- rows still carrying the old bibcode, so re-running matches 0 rows.

UPDATE system_orbital_geometry SET bibcode = '2017AJ....154..237V'
WHERE hostname = 'WASP-47' AND bibcode = '2017AJ....154..237B';
