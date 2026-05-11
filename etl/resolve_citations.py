"""Citation graph resolution.

Resolves every planet in planets_current to a publication record, using a
4-tier strategy (stopping at the first success per planet):

  Tier 1  disc_refname → ADS bibcode       (confidence: high)
  Tier 2  arXiv-form bibcode → arXiv API   (confidence: high)
  Tier 3  paper title → ADS title search   (confidence: medium)
  Tier 4  manual queue (log and continue, no API call)

Results land in the publications + planet_publications tables.
Resumable via backfill_state (key: 'citations').

Prerequisite: apply etl/migrations/005_citation_graph.sql AND
etl/migrations/006_add_arxiv_resolved_via.sql to your DB.

Run:
  python -m etl.resolve_citations              # incremental (default)
  python -m etl.resolve_citations --all        # re-resolve every planet
  python -m etl.resolve_citations --dry-run    # show plan, no writes/API calls
  python -m etl.resolve_citations --max-planets 50  # stop early (debug)

History: a Crossref-by-DOI tier existed when ADS daily quota was the
bottleneck during initial backfill. Once ADS coverage hit ~99% on a
single fresh-quota run, Crossref produced strictly worse data than ADS
and was removed. The DB CHECK on publications.resolved_via still
permits 'crossref_doi' for forward compatibility, but no code writes
it. The arXiv tier (Tier 2) was added later to mop up the long tail of
arXiv-only preprints that ADS's bibcode lookup doesn't index.
"""

from __future__ import annotations

import argparse
import logging
import os
import re
import sys
import time
from datetime import date
from typing import Any
from urllib.parse import unquote

import psycopg
from dotenv import load_dotenv
from psycopg.types.json import Jsonb

from etl.sources import ads, arxiv

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ── Backfill state ──────────────────────────────────────────────────────────

BATCH_STATE_SQL = """
INSERT INTO backfill_state (
    batch_id, last_processed_key, total_targets, processed_count, error_count,
    last_updated_at, status, notes
) VALUES (
    %(batch_id)s, %(last_processed_key)s, %(total_targets)s, %(processed_count)s,
    %(error_count)s, now(), %(status)s, %(notes)s
)
ON CONFLICT (batch_id) DO UPDATE SET
    last_processed_key = EXCLUDED.last_processed_key,
    total_targets      = EXCLUDED.total_targets,
    processed_count    = EXCLUDED.processed_count,
    error_count        = EXCLUDED.error_count,
    last_updated_at    = now(),
    status             = EXCLUDED.status,
    notes              = EXCLUDED.notes
"""


def _ensure_connection(conn):
    """Reconnect to Postgres if the connection has been closed (Neon idle timeout)."""
    if conn.closed or conn.broken:
        log.warning("Postgres connection lost — reconnecting")
        return psycopg.connect(os.environ["DATABASE_URL"])
    return conn


def _save_state(conn, batch_id: str, *, last_key: str, total: int,
                processed: int, errors: int, status: str, notes: dict) -> None:
    with conn.cursor() as cur:
        cur.execute(BATCH_STATE_SQL, {
            "batch_id": batch_id,
            "last_processed_key": last_key,
            "total_targets": total,
            "processed_count": processed,
            "error_count": errors,
            "status": status,
            "notes": Jsonb(notes),
        })
    conn.commit()


# ── Publications upsert ─────────────────────────────────────────────────────

PUB_UPSERT_SQL = """
INSERT INTO publications (
    bibcode, doi, arxiv_id, title, authors, abstract, journal, pub_date,
    citation_count, citation_count_updated_at, resolved_via, confidence, updated_at
) VALUES (
    %(bibcode)s, %(doi)s, %(arxiv_id)s, %(title)s, %(authors)s, %(abstract)s,
    %(journal)s, %(pub_date)s, %(citation_count)s::INT,
    CASE WHEN %(citation_count)s::INT IS NOT NULL THEN now() ELSE NULL END,
    %(resolved_via)s, %(confidence)s, now()
)
ON CONFLICT (bibcode) WHERE bibcode IS NOT NULL DO UPDATE SET
    doi                       = COALESCE(EXCLUDED.doi, publications.doi),
    arxiv_id                  = COALESCE(EXCLUDED.arxiv_id, publications.arxiv_id),
    title                     = COALESCE(EXCLUDED.title, publications.title),
    authors                   = COALESCE(EXCLUDED.authors, publications.authors),
    abstract                  = COALESCE(EXCLUDED.abstract, publications.abstract),
    journal                   = COALESCE(EXCLUDED.journal, publications.journal),
    pub_date                  = COALESCE(EXCLUDED.pub_date, publications.pub_date),
    citation_count            = COALESCE(EXCLUDED.citation_count, publications.citation_count),
    citation_count_updated_at = CASE WHEN EXCLUDED.citation_count IS NOT NULL THEN now()
                                     ELSE publications.citation_count_updated_at END,
    resolved_via              = EXCLUDED.resolved_via,
    confidence                = EXCLUDED.confidence,
    updated_at                = now()
RETURNING pub_id
"""

PUB_UPSERT_DOI_SQL = """
INSERT INTO publications (
    bibcode, doi, arxiv_id, title, authors, abstract, journal, pub_date,
    citation_count, citation_count_updated_at, resolved_via, confidence, updated_at
) VALUES (
    %(bibcode)s, %(doi)s, %(arxiv_id)s, %(title)s, %(authors)s, %(abstract)s,
    %(journal)s, %(pub_date)s, %(citation_count)s::INT,
    CASE WHEN %(citation_count)s::INT IS NOT NULL THEN now() ELSE NULL END,
    %(resolved_via)s, %(confidence)s, now()
)
ON CONFLICT (doi) WHERE doi IS NOT NULL DO UPDATE SET
    bibcode                   = COALESCE(publications.bibcode, EXCLUDED.bibcode),
    arxiv_id                  = COALESCE(EXCLUDED.arxiv_id, publications.arxiv_id),
    title                     = COALESCE(EXCLUDED.title, publications.title),
    authors                   = COALESCE(EXCLUDED.authors, publications.authors),
    abstract                  = COALESCE(EXCLUDED.abstract, publications.abstract),
    journal                   = COALESCE(EXCLUDED.journal, publications.journal),
    pub_date                  = COALESCE(EXCLUDED.pub_date, publications.pub_date),
    citation_count            = COALESCE(EXCLUDED.citation_count, publications.citation_count),
    citation_count_updated_at = CASE WHEN EXCLUDED.citation_count IS NOT NULL THEN now()
                                     ELSE publications.citation_count_updated_at END,
    confidence                = EXCLUDED.confidence,
    updated_at                = now()
RETURNING pub_id
"""

JUNCTION_SQL = """
INSERT INTO planet_publications (pl_name, pub_id, role)
VALUES (%(pl_name)s, %(pub_id)s, 'discovery')
ON CONFLICT DO NOTHING
"""

# Self-cleanup: when a planet finally resolves via any tier, drop any stale
# row it had in citation_manual_queue from a previous run. Keeps the queue an
# accurate source of truth for "planets still needing triage."
QUEUE_DELETE_SQL = """
DELETE FROM citation_manual_queue WHERE pl_name = %(pl_name)s
"""

MANUAL_QUEUE_SQL = """
INSERT INTO citation_manual_queue (pl_name, disc_refname, notes)
VALUES (%(pl_name)s, %(disc_refname)s, %(notes)s)
ON CONFLICT (pl_name) DO UPDATE SET
    disc_refname = EXCLUDED.disc_refname,
    notes        = EXCLUDED.notes
"""


# ── Bibcode extraction (reuse enrich_ads logic) ─────────────────────────────

def _extract_bibcode(refname: str | None) -> str | None:
    m = re.search(r"abs/([^/]+)/abstract", refname or "")
    return unquote(m.group(1)) if m else None


# ── Resolution tiers ────────────────────────────────────────────────────────

def _pub_params(data: dict[str, Any], resolved_via: str, confidence: str) -> dict[str, Any]:
    return {
        "bibcode":        data.get("bibcode"),
        "doi":            data.get("doi"),
        "arxiv_id":       data.get("arxiv_id"),
        "title":          data.get("title"),
        "authors":        Jsonb(data.get("authors") or []),
        "abstract":       data.get("abstract"),
        "journal":        data.get("journal"),
        "pub_date":       data.get("pub_date"),
        "citation_count": data.get("citation_count"),
        "resolved_via":   resolved_via,
        "confidence":     confidence,
    }


def _upsert_pub(cur, params: dict[str, Any]) -> int:
    """Upsert publication, keying on bibcode if present, else doi. Returns pub_id."""
    if params.get("bibcode"):
        cur.execute(PUB_UPSERT_SQL, params)
    else:
        cur.execute(PUB_UPSERT_DOI_SQL, params)
    row = cur.fetchone()
    return row[0]


def _try_tier1(planet: dict, api_key: str) -> dict[str, Any] | None:
    """Tier 1: extract bibcode from disc_refname, fetch from ADS."""
    if ads.quota_status() is not None:
        return None
    bibcode = _extract_bibcode(planet.get("disc_refname"))
    if not bibcode:
        return None
    try:
        docs = ads.fetch_by_bibcodes([bibcode], api_key)
        if not docs:
            return None
        data = ads.normalize_doc(docs[0])
        data["resolved_via"] = "ads_bibcode"
        data["confidence"]   = "high"
        # Ensure bibcode is set even if ADS echoes a slightly different form
        data.setdefault("bibcode", bibcode)
        return data
    except Exception as exc:
        log.warning("Tier 1 ADS fetch failed for %s: %s", bibcode, exc)
        return None


def _try_tier2(planet: dict) -> dict[str, Any] | None:
    """Tier 2: arXiv API for arXiv-form bibcodes ADS doesn't index.

    Only fires when the bibcode extracted from disc_refname matches the
    arXiv pattern (e.g. 2010arXiv1007.4552J). Multi-planet papers that
    share the same bibcode benefit from the publications.bibcode UPSERT
    on the second-and-subsequent calls — arXiv is hit per planet but
    only once per unique bibcode does any DB write happen.
    """
    bibcode = _extract_bibcode(planet.get("disc_refname"))
    if not bibcode or "arXiv" not in bibcode:
        return None
    try:
        data = arxiv.fetch_by_bibcode(bibcode)
        if not data:
            return None
        data["resolved_via"] = "arxiv"
        data["confidence"]   = "high"
        return data
    except Exception as exc:
        log.warning("Tier 2 arXiv fetch failed for %s: %s", bibcode, exc)
        return None


def _try_tier3(planet: dict, api_key: str) -> dict[str, Any] | None:
    """Tier 3: ADS title search using title from discovery_papers."""
    if ads.quota_status() is not None:
        return None
    title   = planet.get("title")
    authors = planet.get("authors") or []
    first_author = authors[0] if authors else ""
    if not title or not first_author:
        return None
    try:
        doc = ads.fetch_by_title(title, first_author, api_key)
        if not doc:
            return None
        data = ads.normalize_doc(doc)
        data["resolved_via"] = "ads_title"
        data["confidence"]   = "medium"
        return data
    except Exception as exc:
        log.warning("Tier 3 ADS title search failed for '%s': %s", title, exc)
        return None


# ── Main resolution loop ─────────────────────────────────────────────────────

def _load_planets(conn, *, refresh_all: bool) -> list[dict]:
    """Load planets to resolve, with existing paper data joined from discovery_papers."""
    with conn.cursor(row_factory=psycopg.rows.dict_row) as cur:
        if refresh_all:
            already_resolved: set[str] = set()
        else:
            cur.execute("SELECT pl_name FROM planet_publications WHERE role = 'discovery'")
            already_resolved = {row["pl_name"] for row in cur.fetchall()}

        cur.execute("""
            SELECT
                pc.pl_name,
                pc.disc_refname,
                dp.doi,
                dp.title,
                dp.authors
            FROM planets_current pc
            LEFT JOIN discovery_papers dp
                ON dp.bibcode = replace(
                    substring(pc.disc_refname FROM 'abs/([^/]+)/abstract'),
                    '%26', '&'
                )
            ORDER BY pc.pl_name
        """)
        all_planets = cur.fetchall()

    planets = [p for p in all_planets if p["pl_name"] not in already_resolved]
    log.info(
        "%d planets total · %d already resolved · %d to resolve",
        len(all_planets), len(already_resolved), len(planets),
    )
    return planets


def resolve(
    conn,
    *,
    api_key: str,
    refresh_all: bool,
    max_planets: int | None,
    dry_run: bool,
) -> dict[str, Any]:
    if dry_run:
        # Count without touching the (potentially non-existent) citation tables
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM planets_current")
            total = cur.fetchone()[0]
        log.info(
            "DRY RUN — %d planets in catalog. "
            "Tier 1 (disc_refname bibcode) expected to cover ~99%%.",
            total,
        )
        return {"total": total, "dry_run": True}

    planets = _load_planets(conn, refresh_all=refresh_all)
    if not planets:
        log.info("Nothing to do.")
        return {"total": 0, "tier1": 0, "tier2": 0, "tier3": 0, "queued": 0}

    if max_planets:
        planets = planets[:max_planets]

    batch_id = f"citations-{date.today().isoformat()}"
    total = len(planets)
    counts = {"tier1": 0, "tier2": 0, "tier3": 0, "queued": 0, "errors": 0}
    processed = 0
    last_key = ""

    _save_state(conn, batch_id, last_key="", total=total, processed=0,
                errors=0, status="in_progress", notes={})

    for planet in planets:
        pl_name = planet["pl_name"]
        data: dict[str, Any] | None = None
        tier_hit = ""

        # Tier 1: bibcode from disc_refname → ADS
        data = _try_tier1(planet, api_key)
        if data:
            tier_hit = "tier1"

        # Tier 2: arXiv API (only fires for arXiv-form bibcodes ADS rejected)
        if not data:
            data = _try_tier2(planet)
            if data:
                tier_hit = "tier2"

        # Tier 3: ADS title search (last resort; short-circuits on ADS quota exhaustion)
        if not data:
            time.sleep(0.1)
            data = _try_tier3(planet, api_key)
            if data:
                tier_hit = "tier3"

        try:
            conn = _ensure_connection(conn)
            with conn.cursor() as cur:
                if data:
                    params = _pub_params(data, data["resolved_via"], data["confidence"])
                    pub_id = _upsert_pub(cur, params)
                    cur.execute(JUNCTION_SQL, {"pl_name": pl_name, "pub_id": pub_id})
                    cur.execute(QUEUE_DELETE_SQL, {"pl_name": pl_name})
                    counts[tier_hit] += 1
                else:
                    cur.execute(MANUAL_QUEUE_SQL, {
                        "pl_name": pl_name,
                        "disc_refname": planet.get("disc_refname"),
                        "notes": "All automated tiers failed",
                    })
                    counts["queued"] += 1
            conn.commit()
        except Exception as exc:
            try:
                conn.rollback()
            except Exception:
                pass
            log.error("DB write failed for %s: %s", pl_name, exc)
            counts["errors"] += 1

        processed += 1
        last_key = pl_name

        if processed % 100 == 0:
            log.info("Progress: %d/%d resolved", processed, total)
            conn = _ensure_connection(conn)
            _save_state(conn, batch_id, last_key=last_key, total=total,
                        processed=processed, errors=counts["errors"],
                        status="in_progress", notes=dict(counts))

    _save_state(conn, batch_id, last_key=last_key, total=total,
                processed=processed, errors=counts["errors"],
                status="completed", notes=dict(counts))

    log.info(
        "Done · tier1=%d tier2=%d tier3=%d queued=%d errors=%d",
        counts["tier1"], counts["tier2"], counts["tier3"],
        counts["queued"], counts["errors"],
    )
    return {"total": total, **counts}


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve planet→publication citation graph")
    parser.add_argument("--all", dest="refresh_all", action="store_true",
                        help="Re-resolve every planet, even those already linked")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show plan without hitting APIs or writing to DB")
    parser.add_argument("--max-planets", type=int, default=None,
                        help="Stop after N planets (debug)")
    args = parser.parse_args()

    api_key = os.environ.get("ADS_API_TOKEN")
    if not api_key and not args.dry_run:
        raise SystemExit("ADS_API_TOKEN environment variable is required")

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        resolve(
            conn,
            api_key=api_key or "",
            refresh_all=args.refresh_all,
            max_planets=args.max_planets,
            dry_run=args.dry_run,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
