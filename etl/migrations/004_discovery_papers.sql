-- ADS-enriched discovery paper metadata, keyed by NASA ADS bibcode.
-- Backfill: python -m etl.enrich_ads
-- Nightly: same script is idempotent — only fetches bibcodes not yet cached.

CREATE TABLE IF NOT EXISTS discovery_papers (
    bibcode                     TEXT        PRIMARY KEY,
    title                       TEXT,
    authors                     JSONB,      -- ordered list of "Last, F." strings
    abstract                    TEXT,
    citation_count              INT,
    pub_date                    TEXT,       -- YYYY-MM or YYYY-MM-DD as returned by ADS
    journal                     TEXT,
    doi                         TEXT,
    arxiv_id                    TEXT,
    retrieved_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    citation_count_updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_discovery_papers_arxiv
    ON discovery_papers (arxiv_id)
    WHERE arxiv_id IS NOT NULL;
