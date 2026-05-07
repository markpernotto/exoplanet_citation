-- Citation graph: richer publication store + planet→paper junction.
-- Backfill: python -m etl.resolve_citations --all
-- Nightly: same script is idempotent — skips planets already in planet_publications.

CREATE TABLE IF NOT EXISTS publications (
    pub_id                    BIGSERIAL    PRIMARY KEY,
    bibcode                   TEXT         UNIQUE,
    doi                       TEXT         UNIQUE,
    arxiv_id                  TEXT,
    title                     TEXT,
    authors                   JSONB,                 -- ["Last, F.", ...]
    abstract                  TEXT,
    journal                   TEXT,
    pub_date                  DATE,
    citation_count            INT,
    citation_count_updated_at TIMESTAMPTZ,
    resolved_via              TEXT         NOT NULL,  -- see CHECK below
    confidence                TEXT         NOT NULL CHECK (confidence IN ('high', 'medium', 'low')),
    created_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT publications_resolved_via_check
        CHECK (resolved_via IN ('ads_bibcode', 'crossref_doi', 'ads_title', 'manual'))
);

CREATE INDEX IF NOT EXISTS idx_publications_bibcode ON publications (bibcode) WHERE bibcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_publications_doi     ON publications (doi)     WHERE doi IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_publications_arxiv   ON publications (arxiv_id) WHERE arxiv_id IS NOT NULL;

-- Many-to-many planet→paper (supports future follow-up / characterization papers)
CREATE TABLE IF NOT EXISTS planet_publications (
    pl_name  TEXT    NOT NULL,
    pub_id   BIGINT  NOT NULL REFERENCES publications (pub_id) ON DELETE CASCADE,
    role     TEXT    NOT NULL DEFAULT 'discovery' CHECK (role IN ('discovery', 'follow_up')),
    PRIMARY KEY (pl_name, pub_id, role)
);

CREATE INDEX IF NOT EXISTS idx_planet_publications_pl_name ON planet_publications (pl_name);
CREATE INDEX IF NOT EXISTS idx_planet_publications_pub_id  ON planet_publications (pub_id);

-- Manual queue for planets that failed all automated tiers
CREATE TABLE IF NOT EXISTS citation_manual_queue (
    pl_name      TEXT        PRIMARY KEY,
    disc_refname TEXT,
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
