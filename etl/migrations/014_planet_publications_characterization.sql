-- Credit the host/binary data sources: add a 'characterization' citation role and
-- a per-link 'contribution' descriptor.
--
-- Motivation: the cb_flag deeper dive pulled real measurements (binary component
-- masses, system distances) from papers that are NOT the planet's discovery cite
-- and were recorded only in binary_companions.source_bibcode / host_distances_manual.
-- If we use a paper's data we must cite it, so those papers now get first-class
-- planet_publications links.
--
-- Design: two orthogonal axes, deliberately NOT merged into one enum.
--   * role         = the paper's RELATIONSHIP to the planet
--                    (discovery | follow_up | prior_detection | characterization)
--   * contribution = WHAT data we took from it ('binary_masses', 'distance', ...),
--                    free-text so new data types need no further migration.
-- This keeps the role enum small and stable while still letting the card show
-- "characterization, binary masses: Schwope 2011" and supporting queries like
-- "all distance sources" = WHERE contribution = 'distance'.
--
-- Idempotent. Apply after 013.

ALTER TABLE planet_publications
    DROP CONSTRAINT IF EXISTS planet_publications_role_check;

ALTER TABLE planet_publications
    ADD CONSTRAINT planet_publications_role_check
    CHECK (role IN ('discovery', 'follow_up', 'prior_detection', 'characterization'));

ALTER TABLE planet_publications
    ADD COLUMN IF NOT EXISTS contribution TEXT;

COMMENT ON COLUMN planet_publications.contribution IS
    'What data this paper contributed, e.g. binary_masses, distance, true_mass. Orthogonal to role; free-text so new data types need no migration.';
