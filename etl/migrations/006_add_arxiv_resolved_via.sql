-- Allow 'arxiv' as a resolved_via value on publications, used by the arXiv
-- resolver tier (etl/sources/arxiv.py + Tier 2 in etl/resolve_citations.py).
--
-- Background: roughly 60 planets in citation_manual_queue cite arXiv-only
-- preprints with bibcodes like 2010arXiv1007.4552J that ADS's bibcode lookup
-- doesn't accept (the formal journal version may not exist yet, or NASA
-- never updated the reference). The arXiv tier extracts the arXiv ID from
-- the bibcode and queries arXiv's Atom API directly.

ALTER TABLE publications
    DROP CONSTRAINT IF EXISTS publications_resolved_via_check;

ALTER TABLE publications
    ADD CONSTRAINT publications_resolved_via_check
    CHECK (resolved_via IN ('ads_bibcode', 'crossref_doi', 'arxiv', 'ads_title', 'manual'));
