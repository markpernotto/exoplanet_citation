"""Phase 1 diff step.

Compares two consecutive snapshots in planets_snapshots and writes change
events to discovery_changes. Field-tier-aware:
  - Tier A changes are surfaced to RSS / public change feeds
  - Tier B changes are logged but NOT surfaced
  - Tier A floats below relative tolerance are demoted to Tier B
  - Tier B floats below relative tolerance are suppressed entirely
  - All other source columns (Tier C) are preserved in raw_row but never diffed

Run: python -m etl.diff [--prev YYYY-MM-DD] [--curr YYYY-MM-DD] [--dry-run]

Defaults:
  --curr: most recent snapshot_date in planets_snapshots
  --prev: the snapshot_date immediately before --curr
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from datetime import date
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb


@dataclass(frozen=True)
class FieldSpec:
    name: str
    tier: str  # 'A' or 'B'
    rel_tolerance: float | None = None  # only meaningful for floats


# Tier A — surfaced in RSS / public change feeds.
TIER_A_FIELDS: list[FieldSpec] = [
    FieldSpec("discoverymethod", tier="A"),
    FieldSpec("disc_year", tier="A"),
    FieldSpec("disc_facility", tier="A"),
    FieldSpec("pl_orbper", tier="A", rel_tolerance=0.01),
    FieldSpec("pl_rade", tier="A", rel_tolerance=0.01),
    FieldSpec("pl_bmasse", tier="A", rel_tolerance=0.01),
]

# Tier B — logged to discovery_changes but NOT surfaced.
# Sub-tolerance float changes are suppressed (vs. Tier A, which demotes to B).
# ra / dec / gaia_dr3_id are typed columns but intentionally excluded from
# diffing: ra/dec change too slowly (proper motion is parts-per-million per
# year), gaia_dr3_id is an identity reference that should not change.
TIER_B_FIELDS: list[FieldSpec] = [
    FieldSpec("sy_snum", tier="B"),
    FieldSpec("sy_pnum", tier="B"),
    FieldSpec("pl_orbsmax", tier="B", rel_tolerance=0.01),
    FieldSpec("pl_orbeccen", tier="B", rel_tolerance=0.01),
    FieldSpec("pl_dens", tier="B", rel_tolerance=0.01),
    FieldSpec("pl_eqt", tier="B", rel_tolerance=0.01),
    FieldSpec("pl_insol", tier="B", rel_tolerance=0.01),
    FieldSpec("st_teff", tier="B", rel_tolerance=0.01),
    FieldSpec("st_rad", tier="B", rel_tolerance=0.01),
    FieldSpec("st_mass", tier="B", rel_tolerance=0.01),
    FieldSpec("st_lum", tier="B", rel_tolerance=0.01),
    FieldSpec("st_spectype", tier="B"),
    FieldSpec("st_dist", tier="B", rel_tolerance=0.01),
    FieldSpec("sy_dist", tier="B", rel_tolerance=0.01),
]

ALL_FIELDS: list[FieldSpec] = TIER_A_FIELDS + TIER_B_FIELDS


@dataclass(frozen=True)
class ChangeClassification:
    is_change: bool
    tier: str  # '' if not a change


def classify_field_change(
    field: FieldSpec, prev_val: Any, curr_val: Any
) -> ChangeClassification:
    """Decide whether a per-field transition is a recorded change, and at which tier."""
    if prev_val == curr_val:
        return ChangeClassification(False, "")

    # NULL transitions: always emit at the field's natural tier.
    if prev_val is None or curr_val is None:
        return ChangeClassification(True, field.tier)

    if field.rel_tolerance is not None:
        try:
            p = float(prev_val)
            c = float(curr_val)
        except (TypeError, ValueError):
            return ChangeClassification(True, field.tier)

        denom = max(abs(p), abs(c), 1e-12)
        rel_diff = abs(p - c) / denom
        if rel_diff < field.rel_tolerance:
            if field.tier == "A":
                return ChangeClassification(True, "B")  # demote to B
            return ChangeClassification(False, "")  # Tier B sub-tolerance: suppress

    return ChangeClassification(True, field.tier)


def _json_safe(row: dict[str, Any]) -> dict[str, Any]:
    """Coerce non-JSON-serializable values (date, datetime) to ISO strings."""
    out: dict[str, Any] = {}
    for k, v in row.items():
        out[k] = v.isoformat() if hasattr(v, "isoformat") else v
    return out


def diff_rows(
    prev_row: dict[str, Any] | None,
    curr_row: dict[str, Any] | None,
    fields: list[FieldSpec],
    snapshot_date: str,
) -> list[dict[str, Any]]:
    """Compute change records between two row dicts. Returns plain dicts;
    JSONB wrapping is applied at the DB boundary in to_db_record()."""
    if prev_row is None and curr_row is None:
        return []
    if prev_row is None:
        assert curr_row is not None
        return [{
            "pl_name": curr_row["pl_name"],
            "change_type": "NEW",
            "field_name": None,
            "field_tier": None,
            "prev_value": None,
            "new_value": _json_safe(curr_row),
            "diff_summary": f"New planet: {curr_row['pl_name']}",
            "source_snapshot_date": snapshot_date,
        }]
    if curr_row is None:
        return [{
            "pl_name": prev_row["pl_name"],
            "change_type": "REMOVED",
            "field_name": None,
            "field_tier": None,
            "prev_value": _json_safe(prev_row),
            "new_value": None,
            "diff_summary": f"Removed planet: {prev_row['pl_name']}",
            "source_snapshot_date": snapshot_date,
        }]

    pl_name = curr_row["pl_name"]
    out: list[dict[str, Any]] = []
    for field in fields:
        prev_v = prev_row.get(field.name)
        curr_v = curr_row.get(field.name)
        result = classify_field_change(field, prev_v, curr_v)
        if not result.is_change:
            continue
        out.append({
            "pl_name": pl_name,
            "change_type": "PARAMETER_CHANGE",
            "field_name": field.name,
            "field_tier": result.tier,
            "prev_value": prev_v,
            "new_value": curr_v,
            "diff_summary": f"{pl_name} {field.name}: {prev_v} → {curr_v}",
            "source_snapshot_date": snapshot_date,
        })
    return out


def diff_snapshots(
    prev_rows: dict[str, dict[str, Any]],
    curr_rows: dict[str, dict[str, Any]],
    snapshot_date: str,
    fields: list[FieldSpec] = ALL_FIELDS,
) -> list[dict[str, Any]]:
    """Compute all change records between two snapshots keyed by pl_name."""
    out: list[dict[str, Any]] = []
    for pl_name in sorted(set(prev_rows) | set(curr_rows)):
        out.extend(diff_rows(prev_rows.get(pl_name), curr_rows.get(pl_name), fields, snapshot_date))
    return out


# ---- DB layer ----

INSERT_CHANGE_SQL = """
INSERT INTO discovery_changes (
    pl_name, change_type, field_name, field_tier,
    prev_value, new_value, diff_summary, source_snapshot_date
) VALUES (
    %(pl_name)s, %(change_type)s, %(field_name)s, %(field_tier)s,
    %(prev_value)s, %(new_value)s, %(diff_summary)s, %(source_snapshot_date)s
)
ON CONFLICT (source_snapshot_date, pl_name, change_type, COALESCE(field_name, ''))
DO NOTHING
"""


def to_db_record(rec: dict[str, Any]) -> dict[str, Any]:
    """Wrap JSONB-bound fields in psycopg's Jsonb adapter at the DB boundary."""
    out = dict(rec)
    out["prev_value"] = Jsonb(rec["prev_value"]) if rec["prev_value"] is not None else None
    out["new_value"] = Jsonb(rec["new_value"]) if rec["new_value"] is not None else None
    return out


_FETCH_COLS = [
    "pl_name", "hostname", "sy_snum", "sy_pnum", "discoverymethod",
    "disc_year", "disc_facility", "disc_telescope", "disc_instrument",
    "disc_refname",
    "pl_orbper", "pl_orbsmax", "pl_orbeccen",
    "pl_rade", "pl_bmasse", "pl_dens", "pl_eqt", "pl_insol",
    "st_teff", "st_rad", "st_mass", "st_lum", "st_spectype", "st_dist",
    "sy_dist",
]


def fetch_snapshot_rows(conn: psycopg.Connection, snapshot_date: date) -> dict[str, dict[str, Any]]:
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"SELECT {', '.join(_FETCH_COLS)} FROM planets_snapshots WHERE snapshot_date = %s",
            (snapshot_date,),
        )
        return {row["pl_name"]: row for row in cur.fetchall()}


def fetch_two_recent_dates(conn: psycopg.Connection) -> tuple[date | None, date | None]:
    """Return (prev_date, curr_date) — the two most recent distinct snapshot_date values."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT DISTINCT snapshot_date FROM planets_snapshots ORDER BY snapshot_date DESC LIMIT 2"
        )
        rows = cur.fetchall()
    if not rows:
        return None, None
    if len(rows) == 1:
        return None, rows[0][0]
    return rows[1][0], rows[0][0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Diff two snapshots into discovery_changes")
    parser.add_argument("--prev", default=None, help="Previous snapshot date (YYYY-MM-DD)")
    parser.add_argument("--curr", default=None, help="Current snapshot date (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true", help="Compute changes but don't insert")
    args = parser.parse_args()

    load_dotenv()

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        auto_prev, auto_curr = fetch_two_recent_dates(conn)
        prev_date = date.fromisoformat(args.prev) if args.prev else auto_prev
        curr_date = date.fromisoformat(args.curr) if args.curr else auto_curr

        if curr_date is None:
            print("No snapshots in planets_snapshots; run extract + load first.", file=sys.stderr)
            return 1
        if prev_date is None:
            print(f"Only one snapshot ({curr_date}) present — first run, no diff to compute.")
            return 0

        print(f"Diffing {prev_date} → {curr_date}")
        prev_rows = fetch_snapshot_rows(conn, prev_date)
        curr_rows = fetch_snapshot_rows(conn, curr_date)
        print(f"  prev: {len(prev_rows):,} rows")
        print(f"  curr: {len(curr_rows):,} rows")

        changes = diff_snapshots(prev_rows, curr_rows, snapshot_date=curr_date.isoformat())

        counts = {"NEW": 0, "REMOVED": 0, "PARAMETER_CHANGE": 0}
        tier_counts = {"A": 0, "B": 0}
        for c in changes:
            counts[c["change_type"]] += 1
            if c["field_tier"] in tier_counts:
                tier_counts[c["field_tier"]] += 1
        print(f"  changes: {counts}")
        if counts["PARAMETER_CHANGE"]:
            print(f"  parameter tier breakdown: {tier_counts}")

        if args.dry_run:
            print("--dry-run: not writing to discovery_changes")
            return 0

        if changes:
            db_records = [to_db_record(c) for c in changes]
            with conn.cursor() as cur:
                cur.executemany(INSERT_CHANGE_SQL, db_records)
            conn.commit()
            print(f"  ✓ wrote {len(changes)} change records (idempotent: duplicates skipped)")
        else:
            print("No changes to insert.")

    # Always prune after a successful diff, even on quiet nights — NASA data is
    # stable most days, and an early-return-on-no-changes would let snapshots
    # accumulate forever.
    _prune_old_snapshots(keep=2)

    return 0


def _prune_old_snapshots(keep: int = 2) -> None:
    """Delete snapshot rows older than the most recent `keep` dates.

    The diff only ever needs the current and previous snapshot. Beyond those
    two dates, raw_row JSONB accumulates ~50 MB/day and will exhaust the
    Neon free tier within weeks. The change events are already safely written
    to discovery_changes, so old raw rows carry no information.
    """
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM planets_snapshots
                WHERE snapshot_date < (
                    SELECT MIN(d) FROM (
                        SELECT DISTINCT snapshot_date AS d
                        FROM planets_snapshots
                        ORDER BY snapshot_date DESC
                        LIMIT %s
                    ) t
                )
                """,
                (keep,),
            )
            deleted = cur.rowcount
        conn.commit()
    if deleted:
        print(f"  ✓ pruned {deleted:,} old snapshot rows (kept {keep} most recent dates)")


if __name__ == "__main__":
    sys.exit(main())
