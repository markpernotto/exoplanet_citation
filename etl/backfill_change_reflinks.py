"""Backfill discovery_changes.prev_reflink / new_reflink for PARAMETER_CHANGE rows.

Migration 129 added the columns and backfilled NEW / REMOVED rows from their
own JSON. Parameter changes carry no reference, and planets_snapshots only
keeps the two most recent dates, so this reads the archived pscomppars CSVs
from R2 (via data/MANIFEST.jsonl):

  new_reflink   from the snapshot the change was generated from
                (source_snapshot_date)
  prev_reflink  from the latest archived snapshot before it, which is the
                snapshot the nightly diff compared against

Before writing anything it checks that those two snapshots reproduce the
change's prev_value and new_value. A row whose values don't match is reported
and left untouched rather than given a reference that might belong to a
different value.

Run: python -m etl.backfill_change_reflinks [--dry-run]

Idempotent: only rows with both reflinks NULL are considered, and the UPDATE
re-checks that condition.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
import sys
from collections import Counter, defaultdict
from typing import Any

import pandas as pd
import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

from etl import r2
from etl.diff import ALL_FIELDS
from etl.load import (
    MANIFEST_PATH,
    TYPED_FLOAT_COLS,
    TYPED_INT_COLS,
    _coerce_float,
    _coerce_int,
    _coerce_text,
)

FIELDS = {f.name: f for f in ALL_FIELDS}

SELECT_SQL = """
SELECT change_id, pl_name, field_name, prev_value, new_value, source_snapshot_date
FROM discovery_changes
WHERE change_type = 'PARAMETER_CHANGE'
  AND prev_reflink IS NULL
  AND new_reflink IS NULL
ORDER BY source_snapshot_date, change_id
"""

UPDATE_SQL = """
UPDATE discovery_changes
SET prev_reflink = %(prev_reflink)s, new_reflink = %(new_reflink)s
WHERE change_id = %(change_id)s
  AND prev_reflink IS NULL
  AND new_reflink IS NULL
"""


def coerce(field_name: str, value: Any) -> Any:
    """Coerce a raw CSV cell the way etl/load.py types it for planets_snapshots,
    so it compares like-for-like with the value the diff recorded."""
    if field_name in TYPED_INT_COLS:
        return _coerce_int(value)
    if field_name in TYPED_FLOAT_COLS:
        return _coerce_float(value)
    return _coerce_text(value)


def values_match(recorded: Any, archived: Any) -> bool:
    if recorded is None or archived is None:
        return recorded is None and archived is None
    if isinstance(recorded, (int, float)) and isinstance(archived, (int, float)):
        return math.isclose(float(recorded), float(archived), rel_tol=1e-9, abs_tol=1e-12)
    return str(recorded) == str(archived)


def resolve_reflinks(
    change: dict[str, Any],
    prev_row: dict[str, Any] | None,
    curr_row: dict[str, Any] | None,
) -> tuple[str | None, str | None] | str:
    """Return (prev_reflink, new_reflink) for a change, or a reason string when
    the archived snapshots can't be trusted to describe this change."""
    field = FIELDS.get(change["field_name"])
    if field is None:
        return f"unknown field {change['field_name']!r}"
    if field.ref_col is None:
        return "no_ref_col"
    if curr_row is None:
        return "planet missing from source snapshot"
    if prev_row is None:
        return "planet missing from previous snapshot"

    archived_new = coerce(field.name, curr_row.get(field.name))
    archived_prev = coerce(field.name, prev_row.get(field.name))
    if not values_match(change["new_value"], archived_new):
        return f"new_value {change['new_value']!r} != archived {archived_new!r}"
    if not values_match(change["prev_value"], archived_prev):
        return f"prev_value {change['prev_value']!r} != archived {archived_prev!r}"

    return _coerce_text(prev_row.get(field.ref_col)), _coerce_text(curr_row.get(field.ref_col))


def read_manifest() -> dict[str, dict]:
    with MANIFEST_PATH.open() as f:
        entries = [json.loads(line) for line in f if line.strip()]
    return {e["snapshot_date"]: e for e in entries}


def load_snapshot(client, entry: dict, columns: list[str]) -> dict[str, dict[str, Any]]:
    body = r2.download_object(client, entry["r2_key"])
    if hashlib.sha256(body).hexdigest() != entry["checksum_sha256"]:
        raise ValueError(f"checksum mismatch for {entry['r2_key']}")
    df = pd.read_csv(io.BytesIO(body), low_memory=False, comment="#")
    keep = [c for c in columns if c in df.columns]
    return {row["pl_name"]: row for row in df[keep].to_dict(orient="records")}


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill reference anchors on PARAMETER_CHANGE rows")
    parser.add_argument("--dry-run", action="store_true", help="Resolve and report, but don't write")
    args = parser.parse_args()

    load_dotenv()

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(SELECT_SQL)
            changes = cur.fetchall()
        print(f"{len(changes):,} PARAMETER_CHANGE rows without references")
        if not changes:
            return 0

        manifest = read_manifest()
        dates = sorted(manifest)
        columns = ["pl_name"] + sorted(
            {f.name for f in ALL_FIELDS} | {f.ref_col for f in ALL_FIELDS if f.ref_col}
        )

        by_date: dict[str, list[dict]] = defaultdict(list)
        for c in changes:
            by_date[c["source_snapshot_date"].isoformat()].append(c)

        client = r2.get_client()
        cache: dict[str, dict[str, dict[str, Any]]] = {}

        def snapshot(d: str) -> dict[str, dict[str, Any]]:
            if d not in cache:
                cache[d] = load_snapshot(client, manifest[d], columns)
            return cache[d]

        updates: list[dict] = []
        outcomes: Counter = Counter()
        problems: list[tuple] = []
        for d in sorted(by_date):
            earlier = [x for x in dates if x < d]
            if d not in manifest or not earlier:
                for c in by_date[d]:
                    outcomes["no archived snapshot pair"] += 1
                    problems.append((c, "no archived snapshot pair"))
                continue
            curr_rows, prev_rows = snapshot(d), snapshot(earlier[-1])
            print(f"  {d} (prev {earlier[-1]}): {len(by_date[d])} changes")
            for c in by_date[d]:
                result = resolve_reflinks(c, prev_rows.get(c["pl_name"]), curr_rows.get(c["pl_name"]))
                if isinstance(result, str):
                    outcomes["no_ref_col" if result == "no_ref_col" else "unverified"] += 1
                    if result != "no_ref_col":
                        problems.append((c, result))
                    continue
                prev_ref, new_ref = result
                outcomes["resolved" if (prev_ref or new_ref) else "resolved, NASA gave no reference"] += 1
                updates.append({"change_id": c["change_id"], "prev_reflink": prev_ref, "new_reflink": new_ref})
            # Only `d` can be the previous snapshot of a later change date.
            for k in [k for k in cache if k < d]:
                del cache[k]

        print("\nOutcome:")
        for k, v in outcomes.most_common():
            print(f"  {k}: {v:,}")
        if problems:
            print("\nNot written (values did not match the archive, or no snapshot):")
            for c, why in problems:
                print(f"  #{c['change_id']} {c['source_snapshot_date']} {c['pl_name']} {c['field_name']}: {why}")

        written = [u for u in updates if u["prev_reflink"] or u["new_reflink"]]
        if args.dry_run:
            print(f"\n--dry-run: would set references on {len(written):,} rows")
            for u in written[:5]:
                print(f"  #{u['change_id']}: {u['prev_reflink']!r} -> {u['new_reflink']!r}")
            return 0

        with conn.cursor() as cur:
            cur.executemany(UPDATE_SQL, written)
        conn.commit()
        print(f"\n✓ set references on {len(written):,} rows")

    return 0


if __name__ == "__main__":
    sys.exit(main())
