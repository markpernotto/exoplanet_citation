"""Backfill ADS metadata (authors, dates, citation counts, abstract, journal) for
manually-seeded publications.

Why: the audit-citation seed (seed_followup_citations.py) inserts publications with
only bibcode + title, leaving `authors` NULL. But author pages are driven by
publications.authors -- GET /api/authors/{name}/publications filters
`WHERE authors @> jsonb_build_array(name)` -- so without authors a manually-cited
paper never links to the people who wrote it (or to the systems it was credited
with). This fetches the missing metadata from ADS by bibcode, exactly as
resolve_citations.py does for discovery papers, so manual citations join the author
graph too. The future literature monitor will need this same step for anything it
auto-cites.

Targets publications with `authors IS NULL AND resolved_via = 'manual'` (so it only
touches hand-curated rows; ADS-resolved discovery papers already have authors).
Reuses etl.sources.ads. Needs ADS_API_TOKEN. Idempotent; dry-run by default.

Run:
  python -m etl.enrich_publication_metadata            # dry-run (default): list targets, no ADS calls
  python -m etl.enrich_publication_metadata --execute  # fetch from ADS + write
"""

from __future__ import annotations

import argparse
import logging
import os

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from etl.sources.ads import BATCH_SIZE, fetch_normalized_batch

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# Fill only where we lack the value; never clobber existing data with NULL.
UPDATE_SQL = """
UPDATE publications SET
    authors        = COALESCE(%(authors)s, authors),
    title          = COALESCE(%(title)s, title),
    abstract       = COALESCE(%(abstract)s, abstract),
    journal        = COALESCE(%(journal)s, journal),
    pub_date       = COALESCE(%(pub_date)s, pub_date),
    doi            = COALESCE(%(doi)s, doi),
    arxiv_id       = COALESCE(%(arxiv_id)s, arxiv_id),
    citation_count = COALESCE(%(citation_count)s::INT, citation_count),
    citation_count_updated_at = CASE WHEN %(citation_count)s::INT IS NOT NULL THEN now()
                                     ELSE citation_count_updated_at END,
    updated_at     = now()
WHERE bibcode = %(bibcode)s
"""


def _batched(seq: list, n: int):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def main() -> int:
    ap = argparse.ArgumentParser(description="Backfill ADS metadata for manual publications")
    ap.add_argument("--execute", action="store_true", help="Fetch from ADS and write (default is dry-run)")
    args = ap.parse_args()

    db_url = os.environ["DATABASE_URL"]
    with psycopg.connect(db_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT bibcode FROM publications
                WHERE authors IS NULL AND bibcode IS NOT NULL AND resolved_via = 'manual'
                ORDER BY bibcode
                """
            )
            bibcodes = [r["bibcode"] for r in cur.fetchall()]

    print(f"Manual publications missing authors: {len(bibcodes)}")
    for b in bibcodes:
        print(f"  {b}")
    if not bibcodes:
        print("Nothing to backfill.")
        return 0
    if not args.execute:
        print("\nDRY RUN — no ADS calls, nothing written. Re-run with --execute.")
        return 0

    api_key = os.environ.get("ADS_API_TOKEN")
    if not api_key:
        raise SystemExit("ADS_API_TOKEN environment variable is required")

    updated = 0
    with psycopg.connect(db_url) as conn:
        for batch in _batched(bibcodes, BATCH_SIZE):
            docs = fetch_normalized_batch(batch, api_key)
            by_bib = {d["bibcode"]: d for d in docs}
            with conn.cursor() as cur:
                for b in batch:
                    d = by_bib.get(b)
                    if not d:
                        log.warning("  ADS returned nothing for %s (verify the bibcode)", b)
                        continue
                    params = dict(d, authors=Jsonb(d["authors"]) if d["authors"] else None)
                    cur.execute(UPDATE_SQL, params)
                    updated += cur.rowcount
                    log.info("  %s -> %d author(s)", b, len(d["authors"]))
            conn.commit()
    print(f"Done — {updated} publication(s) enriched from ADS.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
