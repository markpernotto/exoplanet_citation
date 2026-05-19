"""One-shot resolver for the final 7 citation_manual_queue rows.

These planets all failed the automated tiers in resolve_citations.py for
reasons that are obvious once you look at each refname by hand:

  - 4 of them cite Nature / Nature Astronomy / Science Advances with no
    ADS bibcode in the refname (only a journal URL with the DOI). The
    Tier-1 regex looks for `abs/.../abstract` and finds nothing.
  - 2 of them have malformed or non-canonical ADS bibcodes embedded in
    the refname (`2009ReA&A...9....1L` should be `2009RAA.....9....1L`,
    and Proxima Cen d's refname ends in `..11M` but ADS canonicalizes
    Suárez Mascareño's first-author sort key to `..11S`).
  - 1 of them (TOI-1080 b) had an in-press `..tmp..` placeholder bibcode
    in the original refname; ADS has since assigned the final volume.

This script hand-fetches each paper's metadata (via DOI when the refname
gave us one, via ADS bibcode or title/author search otherwise), upserts
into `publications`, links to `planet_publications`, and deletes the row
from `citation_manual_queue`. All in a single transaction.

Resolved_via is set to 'manual' for all 7 rows because the bibcode that
finally resolved each one was determined by hand, not by an automated
tier. Confidence is 'high' because every match was visually verified
against the original disc_refname title and authors.

Run:
    python -m etl.clear_manual_queue [--dry-run]

This is idempotent and safe to run on a fresh clone. The upstream NASA
Exoplanet Archive `disc_refname` strings for these 7 planets haven't
changed since 2026-05-09, so a fresh `resolve_citations.py` run will
deposit the same 7 rows into citation_manual_queue, and this script
will clear them the same way. If the upstream catalog ever evolves
such that one of the 7 starts resolving via Tier 1/2/3, this script's
queue DELETE becomes a no-op for that row (harmless); the publications
upsert and planet_publications link still execute idempotently.

The full bootstrap order on a fresh clone, after the schema migrations:
    make pipeline
    python -m etl.enrich_gaia
    python -m etl.enrich_ads
    python -m etl.resolve_citations
    python -m etl.clear_manual_queue   # this script

After a successful run, the citation_manual_queue table is empty and
citation coverage is 100% (every planet in planets_current has at least
one row in planet_publications with role='discovery').
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from etl.resolve_citations import JUNCTION_SQL, PUB_UPSERT_SQL, QUEUE_DELETE_SQL, _pub_params
from etl.sources import ads
from etl.sources.ads import FIELDS, _get, normalize_doc

load_dotenv()

# Lookup recipe per planet. Each tuple is:
#   (pl_name, strategy, value, expected_bibcode)
#
# strategy:
#   "doi"           - lookup by DOI (most reliable when the original refname
#                     carries a Nature/Science journal URL)
#   "bibcode"       - lookup by bibcode (use when refname's ADS URL parses
#                     cleanly; here, only HD 173416 after correcting the
#                     malformed 'ReA&A' to 'RAA')
#   "ads_search"    - free-form ADS search query (use for Proxima Cen d
#                     where the bibcode contains '&' and ADS's q-string
#                     can't accept it, and TOI-1080 b which needed an
#                     author + bibstem search to find the final bibcode)
#
# expected_bibcode is the canonical bibcode we expect to come back; the
# script bails out if the lookup returns anything else, since a mismatch
# means the source data has shifted and a human should re-verify.
LOOKUPS: list[tuple[str, str, str, str]] = [
    ("GJ 1132 b",        "doi",        "10.1038/nature15762",            "2015Natur.527..204B"),
    ("HD 173416 b",      "bibcode",    "2009RAA.....9....1L",            "2009RAA.....9....1L"),
    ("Kepler-1708 b",    "doi",        "10.1038/s41550-021-01539-1",     "2022NatAs...6..367K"),
    ("Proxima Cen d",    "ads_search", 'author:"Suárez Mascareño" year:2025 bibstem:A&A title:"Proxima"',  "2025A&A...700A..11S"),
    ("TIC 241249530 b",  "doi",        "10.1038/s41586-024-07688-3",     "2024Natur.632...50G"),
    ("TOI-1080 b",       "ads_search", 'bibstem:MNRAS year:2026 author:"Gomez Maqueo Chew" title:"TOI-1080"', "2026MNRAS.548ag438G"),
    ("TOI-201 d",        "doi",        "10.1126/sciadv.aef2618",         "2026SciA...12f2618M"),
]


def lookup_doc(strategy: str, value: str, expected_bibcode: str, api_key: str) -> dict[str, Any]:
    """Run the strategy, return the doc whose bibcode matches the expected.

    Raises RuntimeError if the lookup returns nothing, or if a result is
    returned but its bibcode disagrees with what we expect (which would
    indicate the source paper has shifted; safer to stop than guess).
    """
    if strategy == "doi":
        doc = ads.fetch_by_doi(value, api_key)
        docs = [doc] if doc else []
    elif strategy == "bibcode":
        docs = ads.fetch_by_bibcodes([value], api_key)
    elif strategy == "ads_search":
        docs = _get({"q": value, "fl": FIELDS, "rows": 5}, api_key)
    else:
        raise ValueError(f"Unknown strategy: {strategy}")

    if not docs:
        raise RuntimeError(f"No result for strategy={strategy} value={value}")

    for d in docs:
        if d.get("bibcode") == expected_bibcode:
            return d

    found = [d.get("bibcode") for d in docs]
    raise RuntimeError(
        f"Expected bibcode {expected_bibcode} but got {found}. "
        "Source data may have shifted; re-verify by hand."
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch + print resolutions but do not write to the DB.",
    )
    args = parser.parse_args(argv)

    api_key = os.environ["ADS_API_TOKEN"]

    # Phase 1: fetch + normalize everything first, before touching the DB.
    # If any single lookup fails, we want to stop *before* writing partial
    # state to the queue. The whole resolution is all-or-nothing.
    resolutions: list[tuple[str, dict[str, Any]]] = []
    for pl_name, strategy, value, expected_bibcode in LOOKUPS:
        print(f"  resolving {pl_name} via {strategy}…", end=" ", flush=True)
        try:
            doc = lookup_doc(strategy, value, expected_bibcode, api_key)
            n = normalize_doc(doc)
            resolutions.append((pl_name, n))
            print(f"OK ({n['bibcode']})")
        except Exception as exc:
            print(f"FAIL")
            print(f"\nERROR: {exc}", file=sys.stderr)
            return 1

    print(f"\nAll {len(resolutions)} planets resolved against ADS.")

    if args.dry_run:
        print("Dry-run: no DB writes.")
        return 0

    # Phase 2: write to DB in a single transaction. If any step fails, the
    # entire batch rolls back and the queue stays consistent.
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            for pl_name, data in resolutions:
                params = _pub_params(data, resolved_via="manual", confidence="high")
                # _pub_params hands back a plain Python list for `authors`;
                # the upsert SQL expects JSONB, so wrap it before binding.
                if params.get("authors") is not None and not isinstance(params["authors"], Jsonb):
                    params["authors"] = Jsonb(params["authors"])
                cur.execute(PUB_UPSERT_SQL, params)
                pub_id = cur.fetchone()["pub_id"]
                cur.execute(JUNCTION_SQL, {"pl_name": pl_name, "pub_id": pub_id})
                cur.execute(QUEUE_DELETE_SQL, {"pl_name": pl_name})
                print(f"  wrote {pl_name} → pub_id={pub_id} ({data['bibcode']})")

            # Verify the queue is now empty inside the same transaction.
            cur.execute("SELECT COUNT(*) AS n FROM citation_manual_queue")
            remaining = cur.fetchone()["n"]
            if remaining != 0:
                conn.rollback()
                print(
                    f"\nERROR: queue still has {remaining} rows after the run. "
                    "Rolling back; investigate.",
                    file=sys.stderr,
                )
                return 1
        conn.commit()

    print("\nDone. citation_manual_queue is empty; coverage is 100%.")
    print("etl/walk_manual_queue.py can be deleted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
