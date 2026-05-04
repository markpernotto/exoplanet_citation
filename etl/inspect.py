"""Browse what's actually in raw_row for a single planet.

Run: python -m etl.inspect [pl_name]
Default: Kepler-22 b (the famous Earth-sized habitable-zone planet)

Groups columns by prefix (pl_, st_, sy_, disc_, etc.) so you can see what
data the Exoplanet Archive actually provides per planet vs. what we're
exposing in our typed schema.
"""

from __future__ import annotations

import os
import sys
from collections import defaultdict

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row


def categorize(col: str) -> str:
    if col.startswith("pl_"):
        return "Planet"
    if col.startswith("st_"):
        return "Host star"
    if col.startswith("sy_"):
        return "System"
    if col.startswith("disc_") or col == "discoverymethod":
        return "Discovery"
    if col in ("ra", "dec", "ra_str", "dec_str", "glon", "glat", "elon", "elat"):
        return "Sky coordinates"
    if col == "hostname":
        return "System"
    if col == "pl_name":
        return "Identity"
    return "Metadata / other"


def fmt_value(v) -> str:
    if v is None:
        return "—"
    s = str(v)
    return s[:60] + "..." if len(s) > 60 else s


def main() -> int:
    load_dotenv()
    pl_name = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Kepler-22 b"

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT raw_row FROM planets_snapshots "
                "WHERE pl_name = %s "
                "ORDER BY snapshot_date DESC LIMIT 1",
                (pl_name,),
            )
            row = cur.fetchone()
            if row is None:
                print(f"No planet found with pl_name = {pl_name!r}.")
                print("Try one of these:")
                cur.execute(
                    "SELECT pl_name FROM planets_snapshots "
                    "WHERE pl_name ILIKE %s ORDER BY pl_name LIMIT 10",
                    (f"%{pl_name.split()[0]}%",),
                )
                for r in cur.fetchall():
                    print(f"  {r['pl_name']}")
                return 1

            raw = row["raw_row"]

            # Coverage stats: % of all planets with a non-null value for each column
            cur.execute("SELECT COUNT(*) FROM planets_snapshots")
            total = cur.fetchone()["count"]

    grouped = defaultdict(list)
    for col, val in sorted(raw.items()):
        grouped[categorize(col)].append((col, val))

    print(f"\n{'=' * 70}")
    print(f"  {pl_name}")
    print(f"  Showing all {len(raw)} columns from raw_row")
    print(f"{'=' * 70}\n")

    section_order = ["Identity", "Planet", "Host star", "System",
                     "Sky coordinates", "Discovery", "Metadata / other"]
    for section in section_order:
        if section not in grouped:
            continue
        print(f"\n--- {section} ({len(grouped[section])} columns) ---")
        for col, val in grouped[section]:
            print(f"  {col:30s}  {fmt_value(val)}")

    # Coverage hint
    print(f"\n{'=' * 70}")
    print(f"  Total planets in current snapshot: {total:,}")
    print(f"  Total columns per row: {len(raw)}")
    print("  Currently typed in planets_snapshots: 15")
    print(f"  Sitting in raw_row JSONB only: {len(raw) - 15}")
    print(f"{'=' * 70}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
