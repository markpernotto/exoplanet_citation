"""Phase 2: Gaia DR3 host-star enrichment.

For each unique host in planets_current with a parsable gaia_dr3_id, look up
the Gaia DR3 record and UPSERT into host_stars_gaia. Idempotent and resumable
via the backfill_state table.

Prerequisite: apply etl/migrations/002_phase2_host_stars_gaia.sql to your DB.

Run:
  python -m etl.enrich_gaia                  # incremental — skip hosts already enriched
  python -m etl.enrich_gaia --refresh-all    # re-enrich every host (DR4 day, schema change, etc.)
  python -m etl.enrich_gaia --batch-size 50  # tune TAP request size
  python -m etl.enrich_gaia --max-batches 5  # stop early (debug / partial backfill)
  python -m etl.enrich_gaia --dry-run        # show plan without writing or hitting Gaia
"""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Callable, Iterable
from datetime import date
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.types.json import Jsonb

from etl.sources.gaia import (
    DEFAULT_BATCH_SIZE,
    GaiaRecord,
    fetch_gaia_dr3_records,
    parse_source_id,
)

UPSERT_HOST_STAR_SQL = """
INSERT INTO host_stars_gaia (
    gaia_dr3_id, hostname, parallax_mas, parallax_error,
    pmra_mas_yr, pmdec_mas_yr, radial_velocity_km_s,
    phot_g_mean_mag, phot_bp_mean_mag, phot_rp_mean_mag, bp_rp,
    teff_gspphot, logg_gspphot, mh_gspphot, distance_gspphot_pc,
    source_record, retrieved_at
) VALUES (
    %(gaia_dr3_id)s, %(hostname)s, %(parallax_mas)s, %(parallax_error)s,
    %(pmra_mas_yr)s, %(pmdec_mas_yr)s, %(radial_velocity_km_s)s,
    %(phot_g_mean_mag)s, %(phot_bp_mean_mag)s, %(phot_rp_mean_mag)s, %(bp_rp)s,
    %(teff_gspphot)s, %(logg_gspphot)s, %(mh_gspphot)s, %(distance_gspphot_pc)s,
    %(source_record)s, now()
)
ON CONFLICT (gaia_dr3_id) DO UPDATE SET
    hostname = EXCLUDED.hostname,
    parallax_mas = EXCLUDED.parallax_mas,
    parallax_error = EXCLUDED.parallax_error,
    pmra_mas_yr = EXCLUDED.pmra_mas_yr,
    pmdec_mas_yr = EXCLUDED.pmdec_mas_yr,
    radial_velocity_km_s = EXCLUDED.radial_velocity_km_s,
    phot_g_mean_mag = EXCLUDED.phot_g_mean_mag,
    phot_bp_mean_mag = EXCLUDED.phot_bp_mean_mag,
    phot_rp_mean_mag = EXCLUDED.phot_rp_mean_mag,
    bp_rp = EXCLUDED.bp_rp,
    teff_gspphot = EXCLUDED.teff_gspphot,
    logg_gspphot = EXCLUDED.logg_gspphot,
    mh_gspphot = EXCLUDED.mh_gspphot,
    distance_gspphot_pc = EXCLUDED.distance_gspphot_pc,
    source_record = EXCLUDED.source_record,
    retrieved_at = now()
"""

# UPSERT for backfill_state covers create-new-batch and resume-existing-batch
# in one statement (today's batch_id is reused if the script is run twice
# in the same day).
UPSERT_BATCH_STATE_SQL = """
INSERT INTO backfill_state (
    batch_id, last_processed_key, total_targets, processed_count, error_count,
    last_updated_at, status, notes
) VALUES (
    %(batch_id)s, %(last_processed_key)s, %(total_targets)s, %(processed_count)s,
    %(error_count)s, now(), %(status)s, %(notes)s
)
ON CONFLICT (batch_id) DO UPDATE SET
    last_processed_key = EXCLUDED.last_processed_key,
    total_targets = EXCLUDED.total_targets,
    processed_count = EXCLUDED.processed_count,
    error_count = EXCLUDED.error_count,
    last_updated_at = now(),
    status = EXCLUDED.status,
    notes = EXCLUDED.notes
"""

# DISTINCT ON + ORDER BY makes the chosen (hostname, gaia_dr3_id) pair
# deterministic when a Gaia ID is shared across multiple rows (multi-planet
# systems are the common case).
SELECT_HOSTS_SQL = """
SELECT DISTINCT ON (gaia_dr3_id) hostname, gaia_dr3_id
FROM planets_current
WHERE gaia_dr3_id IS NOT NULL
  AND gaia_dr3_id <> ''
ORDER BY gaia_dr3_id, hostname
"""


def filter_hosts(
    rows: Iterable[tuple[str, str | None]],
    already_done_ids: set[str],
    *,
    refresh_all: bool = False,
) -> tuple[list[tuple[str, int]], int, int]:
    """Filter raw (hostname, gaia_dr3_id) rows down to enrichment work.

    Pure function: parses each gaia_dr3_id, drops unparseable, and (unless
    refresh_all) drops hosts already present in host_stars_gaia.

    Returns (hosts_to_enrich, skipped_unparseable, skipped_already_done).
    """
    out: list[tuple[str, int]] = []
    skipped_unparseable = 0
    skipped_already_done = 0
    for hostname, raw_gaia_id in rows:
        sid = parse_source_id(raw_gaia_id)
        if sid is None:
            skipped_unparseable += 1
            continue
        if not refresh_all and str(sid) in already_done_ids:
            skipped_already_done += 1
            continue
        out.append((hostname, sid))
    return out, skipped_unparseable, skipped_already_done


def _record_params(record: GaiaRecord, hostname: str) -> dict[str, Any]:
    """Map a GaiaRecord + hostname to the UPSERT parameter dict.

    Pulled out of upsert_record() so tests can assert on the parameter shape
    without a live cursor.
    """
    return {
        "gaia_dr3_id": str(record.source_id),
        "hostname": hostname,
        "parallax_mas": record.parallax_mas,
        "parallax_error": record.parallax_error,
        "pmra_mas_yr": record.pmra_mas_yr,
        "pmdec_mas_yr": record.pmdec_mas_yr,
        "radial_velocity_km_s": record.radial_velocity_km_s,
        "phot_g_mean_mag": record.phot_g_mean_mag,
        "phot_bp_mean_mag": record.phot_bp_mean_mag,
        "phot_rp_mean_mag": record.phot_rp_mean_mag,
        "bp_rp": record.bp_rp,
        "teff_gspphot": record.teff_gspphot,
        "logg_gspphot": record.logg_gspphot,
        "mh_gspphot": record.mh_gspphot,
        "distance_gspphot_pc": record.distance_gspphot_pc,
        "source_record": Jsonb(record.raw),
    }


def _select_hosts_to_enrich(conn, *, refresh_all: bool) -> list[tuple[str, int]]:
    """DB-touching wrapper: load both query results, run filter_hosts."""
    with conn.cursor() as cur:
        cur.execute(SELECT_HOSTS_SQL)
        raw = cur.fetchall()
        if refresh_all:
            already_done: set[str] = set()
        else:
            cur.execute("SELECT gaia_dr3_id FROM host_stars_gaia")
            already_done = {row[0] for row in cur.fetchall()}

    hosts, skipped_unparseable, skipped_done = filter_hosts(
        raw, already_done, refresh_all=refresh_all,
    )
    if skipped_unparseable:
        print(f"  ! skipped {skipped_unparseable} host(s) with unparseable gaia_dr3_id")
    print(
        f"  {len(raw):,} hosts with Gaia ID · "
        f"{skipped_done:,} already enriched · {len(hosts):,} to do"
    )
    return hosts


def enrich(
    conn,
    *,
    refresh_all: bool,
    batch_size: int,
    max_batches: int | None,
    user_agent: str,
    dry_run: bool,
    fetcher: Callable[..., dict[int, GaiaRecord]] = fetch_gaia_dr3_records,
    today_fn: Callable[[], date] = date.today,
) -> dict[str, Any]:
    """Run the enrichment job. `fetcher` and `today_fn` are injection points for tests."""
    hosts = _select_hosts_to_enrich(conn, refresh_all=refresh_all)
    if not hosts:
        print("Nothing to do; host_stars_gaia is up to date.")
        return {"hosts": 0, "hits": 0, "misses": 0, "batches": 0}

    if dry_run:
        print(f"DRY RUN — would enrich {len(hosts):,} host(s) in batches of {batch_size}")
        return {"hosts": len(hosts), "hits": 0, "misses": 0, "batches": 0, "dry_run": True}

    batch_id = f"gaia-enrich-{today_fn().isoformat()}"
    print(f"Batch: {batch_id}")
    sid_to_host = {sid: host for host, sid in hosts}

    with conn.cursor() as cur:
        cur.execute(UPSERT_BATCH_STATE_SQL, {
            "batch_id": batch_id,
            "last_processed_key": "",
            "total_targets": len(hosts),
            "processed_count": 0,
            "error_count": 0,
            "status": "in_progress",
            "notes": Jsonb({}),
        })
        conn.commit()

    hit_count = 0
    miss_count = 0
    miss_ids: list[int] = []
    last_key = ""
    batches_run = 0

    try:
        for batch_idx, start in enumerate(range(0, len(hosts), batch_size)):
            if max_batches is not None and batch_idx >= max_batches:
                print(f"  stopping after {max_batches} batch(es) per --max-batches")
                break
            batch = hosts[start : start + batch_size]
            ids = [sid for _, sid in batch]
            print(f"  batch {batch_idx + 1}: requesting {len(ids)} source IDs from Gaia...")
            records = fetcher(ids, user_agent=user_agent)
            print(f"    received {len(records)} record(s)")

            with conn.cursor() as cur:
                for sid in ids:
                    rec = records.get(sid)
                    if rec is None:
                        miss_count += 1
                        miss_ids.append(sid)
                        continue
                    cur.execute(UPSERT_HOST_STAR_SQL, _record_params(rec, sid_to_host[sid]))
                    hit_count += 1
                last_key = str(ids[-1])
                cur.execute(UPSERT_BATCH_STATE_SQL, {
                    "batch_id": batch_id,
                    "last_processed_key": last_key,
                    "total_targets": len(hosts),
                    "processed_count": hit_count + miss_count,
                    "error_count": 0,
                    "status": "in_progress",
                    "notes": Jsonb({"hits_so_far": hit_count, "misses_so_far": miss_count}),
                })
                conn.commit()
            batches_run = batch_idx + 1

        with conn.cursor() as cur:
            cur.execute(UPSERT_BATCH_STATE_SQL, {
                "batch_id": batch_id,
                "last_processed_key": last_key,
                "total_targets": len(hosts),
                "processed_count": hit_count + miss_count,
                "error_count": 0,
                "status": "completed",
                "notes": Jsonb({
                    "hits": hit_count,
                    "misses": miss_count,
                    "miss_ids_sample": miss_ids[:20],
                }),
            })
            conn.commit()

        print(f"Done · {hit_count} enriched · {miss_count} miss(es)")
        if miss_ids:
            # A "miss" means pscomppars points at a Gaia DR3 ID that DR3 didn't
            # return — usually a stale cross-reference. Not an error condition;
            # the host just stays absent from host_stars_gaia.
            print(f"  (first few miss IDs: {miss_ids[:5]})")
        return {
            "hosts": len(hosts),
            "hits": hit_count,
            "misses": miss_count,
            "batches": batches_run,
        }

    except Exception as exc:
        # Persist failure so the next run can see where we stopped (cursor is
        # last_processed_key on the batch row). Then re-raise so the caller —
        # nightly cron, GitHub Actions, etc. — exits non-zero.
        print(f"Failed mid-batch: {exc}", file=sys.stderr)
        with conn.cursor() as cur:
            cur.execute(UPSERT_BATCH_STATE_SQL, {
                "batch_id": batch_id,
                "last_processed_key": last_key,
                "total_targets": len(hosts),
                "processed_count": hit_count + miss_count,
                "error_count": 1,
                "status": "failed",
                "notes": Jsonb({
                    "hits": hit_count,
                    "misses": miss_count,
                    "error": str(exc),
                }),
            })
            conn.commit()
        raise


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Enrich exoplanet host stars with Gaia DR3 data",
    )
    parser.add_argument(
        "--refresh-all", action="store_true",
        help="Re-enrich every host, not just those missing from host_stars_gaia",
    )
    parser.add_argument(
        "--batch-size", type=int, default=DEFAULT_BATCH_SIZE,
        help=f"How many source IDs per Gaia TAP request (default {DEFAULT_BATCH_SIZE})",
    )
    parser.add_argument(
        "--max-batches", type=int, default=None,
        help="Stop after N batches (default: process all hosts)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show plan without writing to Postgres or hitting Gaia",
    )
    args = parser.parse_args()

    load_dotenv()
    user_agent = os.environ.get(
        "USER_AGENT_PROJECT", "exoplanet_citation/0.1 enrich-gaia",
    )

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        enrich(
            conn,
            refresh_all=args.refresh_all,
            batch_size=args.batch_size,
            max_batches=args.max_batches,
            user_agent=user_agent,
            dry_run=args.dry_run,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
