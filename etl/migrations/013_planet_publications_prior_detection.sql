-- Add a 'prior_detection' role to planet_publications.
--
-- Motivation: the cb_flag audit's citation enrichment links each planet to papers
-- beyond its single discovery cite. Some of those are post-discovery follow-ups
-- (already allowed: role='follow_up'), but others PRECEDE the warehouse's discovery
-- cite — the detection or prediction that came first. Labeling an earlier paper
-- 'follow_up' is chronologically backwards, so we add a dedicated role.
--
-- Examples (seeded by etl/seed_followup_citations.py):
--   Kepler-1660 AB b — Borkovits 2016, Getley 2017 (preceded the 2023 discovery cite)
--   NY Vir c         — Qian 2012 (predicted it; Song 2019 is the discovery cite)
--   PSR B1620-26 b   — Thorsett 1999 (preceded the 2003 discovery cite)
--
-- Idempotent. The original constraint is unnamed-by-us but Postgres named it
-- planet_publications_role_check (verified). DROP IF EXISTS + re-ADD widens it.

ALTER TABLE planet_publications
    DROP CONSTRAINT IF EXISTS planet_publications_role_check;

ALTER TABLE planet_publications
    ADD CONSTRAINT planet_publications_role_check
    CHECK (role IN ('discovery', 'follow_up', 'prior_detection'));
