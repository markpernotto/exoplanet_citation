-- Bulk cleanup of self-reference companion rows from a SIMBAD bulk
-- ingest. Same pattern as the 16 Cyg case fixed in migration 098: for
-- systems where the planet host is the B component of a wide binary
-- (named "X B"), the ingest stored both A→B and B→A binary relations,
-- and the latter ends up as "host has a companion designated B" — i.e.,
-- a star is listed as its own companion. Bogus by construction.
--
-- All seven rows below have source_catalog = 'SIMBAD' and
-- source_bibcode IS NULL, confirming bulk-ingest origin. Discovered by
-- the post-098 audit query:
--   SELECT hostname, component_designation, source_catalog, source_bibcode
--   FROM binary_companions
--   WHERE source_bibcode IS NULL
--     AND component_designation = (regexp_match(hostname, '\s([A-Z])$'))[1];
--
-- This migration only DELETEs; it does NOT add curated replacements.
-- Each of these systems likely also has a REAL wide-binary A-component
-- row that deserves enrichment with proper literature citation in its
-- own per-system curation pass (the pattern established by migration
-- 098 for 16 Cyg). Doing those individually avoids mass-applying
-- potentially wrong assertions.
--
-- Idempotent. The WHERE clause triple-gates on hostname + designation +
-- the SIMBAD-no-bibcode marker, so no risk of touching properly-cited
-- rows on systems that happen to share a hostname.

DELETE FROM binary_companions
WHERE component_designation = 'B'
  AND source_catalog = 'SIMBAD'
  AND source_bibcode IS NULL
  AND hostname IN (
    'HD 133131 B',
    'HD 178911 B',
    'OGLE-2013-BLG-0341L B',
    'TOI-858 B',
    'WASP-160 B',
    'WASP-94 B',
    'psi1 Dra B'
  );
