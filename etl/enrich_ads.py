"""ADS discovery-paper enrichment.

Fetches metadata from the NASA Astrophysics Data System for every unique
bibcode referenced in planets_current.disc_refname. Results are cached in
discovery_papers; subsequent runs only fetch bibcodes not already stored.

Prerequisite: apply etl/migrations/004_discovery_papers.sql to your DB.

Run:
  python -m etl.enrich_ads                   # incremental (default)
  python -m etl.enrich_ads --refresh-all     # re-fetch every bibcode
  python -m etl.enrich_ads --dry-run         # show plan, no writes or API calls
  python -m etl.enrich_ads --max-batches 5   # stop early (debug)
"""

from __future__ import annotations

import argparse
import logging
import os
import re
import time
from typing import Any
from urllib.parse import unquote

import psycopg
from dotenv import load_dotenv
from psycopg.types.json import Jsonb

from etl.sources.ads import BATCH_SIZE, SLEEP_BETWEEN, extract_arxiv_id, fetch_by_bibcodes

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

SLEEP_BETWEEN_BATCHES = SLEEP_BETWEEN


def extract_bibcode(refname: str | None) -> str | None:
    m = re.search(r"abs/([^/]+)/abstract", refname or "")
    return unquote(m.group(1)) if m else None


def doc_to_row(doc: dict[str, Any]) -> dict[str, Any]:
    title_list = doc.get("title") or []
    doi_list   = doc.get("doi") or []
    return {
        "bibcode":        doc.get("bibcode"),
        "title":          title_list[0] if title_list else None,
        "authors":        Jsonb(doc.get("author") or []),
        "abstract":       doc.get("abstract"),
        "citation_count": doc.get("citation_count"),
        "pub_date":       doc.get("pubdate"),
        "journal":        doc.get("pub"),
        "doi":            doi_list[0] if doi_list else None,
        "arxiv_id":       extract_arxiv_id(doc.get("identifier") or []),
    }


UPSERT_SQL = """
INSERT INTO discovery_papers
    (bibcode, title, authors, abstract, citation_count, pub_date, journal, doi, arxiv_id)
VALUES
    (%(bibcode)s, %(title)s, %(authors)s, %(abstract)s, %(citation_count)s,
     %(pub_date)s, %(journal)s, %(doi)s, %(arxiv_id)s)
ON CONFLICT (bibcode) DO UPDATE SET
    title                       = EXCLUDED.title,
    authors                     = EXCLUDED.authors,
    abstract                    = EXCLUDED.abstract,
    citation_count              = EXCLUDED.citation_count,
    pub_date                    = EXCLUDED.pub_date,
    journal                     = EXCLUDED.journal,
    doi                         = EXCLUDED.doi,
    arxiv_id                    = EXCLUDED.arxiv_id,
    citation_count_updated_at   = now()
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Enrich discovery_papers from ADS")
    parser.add_argument("--refresh-all", action="store_true",
                        help="Re-fetch every bibcode, not just missing ones")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show plan without hitting ADS or writing to DB")
    parser.add_argument("--max-batches", type=int, default=None,
                        help="Stop after N batches (debug/partial backfill)")
    args = parser.parse_args()

    api_key = os.environ.get("ADS_API_TOKEN")
    if not api_key and not args.dry_run:
        raise SystemExit("ADS_API_TOKEN environment variable is required")

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        # All bibcodes referenced in the current catalog
        with conn.cursor() as cur:
            cur.execute(
                "SELECT DISTINCT disc_refname FROM planets_current "
                "WHERE disc_refname IS NOT NULL"
            )
            refnames = [row[0] for row in cur.fetchall()]

        catalog_bibcodes = {
            bc for r in refnames if (bc := extract_bibcode(r))
        }
        log.info("Catalog has %d unique bibcodes", len(catalog_bibcodes))

        if args.refresh_all:
            todo = sorted(catalog_bibcodes)
        else:
            with conn.cursor() as cur:
                cur.execute("SELECT bibcode FROM discovery_papers")
                existing = {row[0] for row in cur.fetchall()}
            todo = sorted(catalog_bibcodes - existing)
            log.info(
                "%d already cached, %d to fetch", len(existing), len(todo)
            )

        if not todo:
            log.info("Nothing to do.")
            return

        if args.dry_run:
            log.info("DRY RUN — would fetch %d bibcodes in %d batches",
                     len(todo), -(-len(todo) // BATCH_SIZE))
            for bc in todo[:5]:
                log.info("  e.g. %s", bc)
            return

        fetched = stored = 0
        batches = [todo[i:i + BATCH_SIZE] for i in range(0, len(todo), BATCH_SIZE)]
        if args.max_batches:
            batches = batches[: args.max_batches]

    # Close the planning connection — each write batch reopens its own so
    # Neon doesn't drop the connection during long retry waits between batches.
    db_url = os.environ["DATABASE_URL"]

    for i, batch in enumerate(batches, 1):
        log.info("Batch %d/%d (%d bibcodes)", i, len(batches), len(batch))
        try:
            docs = fetch_by_bibcodes(batch, api_key)
            fetched += len(docs)
            rows = [doc_to_row(d) for d in docs]
            with psycopg.connect(db_url) as wconn:
                with wconn.cursor() as cur:
                    cur.executemany(UPSERT_SQL, rows)
                wconn.commit()
            stored += len(rows)
        except Exception as exc:
            log.error("Batch %d failed: %s", i, exc)

        if i < len(batches):
            time.sleep(SLEEP_BETWEEN_BATCHES)

    log.info("Done — fetched %d docs, stored %d rows", fetched, stored)


if __name__ == "__main__":
    main()
