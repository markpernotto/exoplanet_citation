"""Phase 1 publish step.

Reads recent discovery_changes from Postgres, generates static feeds:
  public/rss.xml          — RSS 2.0, Tier A surfaced changes only
  public/discoveries.json — JSON, all surfaced changes (Tier A + NEW + REMOVED)
  public/health.json      — freshness measurement against the SLO

Run after diff.py in the nightly pipeline.

Run: python -m etl.publish [--days 30] [--out-dir public]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.etree.ElementTree import Element, SubElement

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

# Phase 1 SLO target: published data fresh within 26 hours of source. The
# clock is currently approximated as "time since last extract" (Clock A).
# Upgrading to true Clock B (time since upstream `last_modified`) is tracked
# as Phase-1.x work; doing it requires a metadata query against the Exoplanet
# Archive that the TAP service doesn't expose cleanly today.
SLO_FRESHNESS_HOURS = 26


def fetch_surfaced_changes(conn: psycopg.Connection, days: int) -> list[dict]:
    """Pull changes worth surfacing publicly: NEW, REMOVED, and Tier A
    PARAMETER_CHANGEs from the last N days, newest first. Tier B parameter
    changes are excluded — they're logged but not feed-worthy."""
    cutoff = datetime.now(UTC) - timedelta(days=days)
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            SELECT change_id, observed_at, pl_name, change_type, field_name,
                   field_tier, prev_value, new_value, diff_summary, source_snapshot_date
            FROM discovery_changes
            WHERE observed_at >= %s
              AND (
                  change_type IN ('NEW', 'REMOVED')
                  OR field_tier = 'A'
              )
            ORDER BY observed_at DESC
            LIMIT 500
            """,
            (cutoff,),
        )
        return list(cur.fetchall())


def fetch_freshness(conn: psycopg.Connection) -> dict | None:
    """Compute freshness against the SLO. Clock A approximation.

    Returns None if no snapshots exist yet."""
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            "SELECT source_retrieved_at, snapshot_date FROM planets_snapshots "
            "ORDER BY snapshot_date DESC LIMIT 1"
        )
        row = cur.fetchone()
    if row is None:
        return None
    retrieved_at = row["source_retrieved_at"]
    if retrieved_at.tzinfo is None:
        retrieved_at = retrieved_at.replace(tzinfo=UTC)
    age_hours = round((datetime.now(UTC) - retrieved_at).total_seconds() / 3600, 2)
    return {
        "snapshot_date": row["snapshot_date"].isoformat(),
        "source_retrieved_at": retrieved_at.isoformat(),
        "freshness_hours": age_hours,
        "slo_freshness_hours": SLO_FRESHNESS_HOURS,
        "status": "ok" if age_hours <= SLO_FRESHNESS_HOURS else "stale",
        "clock": "A (time since last extract)",
        "note": (
            "Clock A approximation. Phase-1.x work upgrades to Clock B "
            "(time since upstream last_modified)."
        ),
    }


def _rfc822(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.strftime("%a, %d %b %Y %H:%M:%S +0000")


def _change_title(c: dict) -> str:
    if c["change_type"] == "NEW":
        return f"New exoplanet confirmed: {c['pl_name']}"
    if c["change_type"] == "REMOVED":
        return f"Exoplanet removed: {c['pl_name']}"
    return f"Parameter update — {c['pl_name']}: {c['field_name']}"


def build_rss(changes: list[dict]) -> str:
    rss = Element("rss", version="2.0")
    channel = SubElement(rss, "channel")
    SubElement(channel, "title").text = "Exoplanet Discoveries"
    SubElement(channel, "link").text = "https://github.com/markpernotto/exoplanet_citation"
    SubElement(channel, "description").text = (
        "Newly confirmed and revised exoplanet records from the NASA Exoplanet Archive, "
        "diffed nightly. Surfaces NEW / REMOVED / Tier-A parameter changes only."
    )
    SubElement(channel, "language").text = "en-us"
    SubElement(channel, "lastBuildDate").text = _rfc822(datetime.now(UTC))
    SubElement(channel, "ttl").text = "1440"  # 24h cache hint

    for c in changes:
        item = SubElement(channel, "item")
        SubElement(item, "title").text = _change_title(c)
        SubElement(item, "guid", isPermaLink="false").text = f"change-{c['change_id']}"
        SubElement(item, "pubDate").text = _rfc822(c["observed_at"])
        SubElement(item, "description").text = c.get("diff_summary") or _change_title(c)

    ET.indent(rss, space="  ")
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(rss, encoding="unicode")


def build_json_feed(changes: list[dict], freshness: dict | None) -> dict:
    return {
        "feed_version": "1.0",
        "generated_at": datetime.now(UTC).isoformat(),
        "freshness": freshness,
        "change_count": len(changes),
        "changes": [
            {
                "change_id": c["change_id"],
                "observed_at": c["observed_at"].isoformat(),
                "pl_name": c["pl_name"],
                "change_type": c["change_type"],
                "field_name": c["field_name"],
                "field_tier": c["field_tier"],
                "prev_value": c["prev_value"],
                "new_value": c["new_value"],
                "diff_summary": c["diff_summary"],
                "source_snapshot_date": c["source_snapshot_date"].isoformat(),
            }
            for c in changes
        ],
    }


def build_health(freshness: dict | None, change_count: int) -> dict:
    return {
        "status": (freshness["status"] if freshness else "no_data"),
        "checked_at": datetime.now(UTC).isoformat(),
        "freshness": freshness,
        "recent_change_count": change_count,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate RSS + JSON feeds from discovery_changes")
    parser.add_argument("--days", type=int, default=30,
                        help="How far back to include changes (default 30)")
    parser.add_argument("--out-dir", default="public",
                        help="Output directory (default public/)")
    args = parser.parse_args()

    load_dotenv()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        changes = fetch_surfaced_changes(conn, args.days)
        freshness = fetch_freshness(conn)

    print(f"Surfaced changes (last {args.days} days): {len(changes)}")
    if freshness:
        print(f"Freshness: {freshness['freshness_hours']}h since last extract "
              f"(SLO ≤ {SLO_FRESHNESS_HOURS}h, status: {freshness['status']})")
    else:
        print("No snapshots yet — empty feeds.")

    rss_path = out_dir / "rss.xml"
    rss_path.write_text(build_rss(changes), encoding="utf-8")
    print(f"  ✓ wrote {rss_path}")

    json_path = out_dir / "discoveries.json"
    json_path.write_text(
        json.dumps(build_json_feed(changes, freshness), indent=2, default=str),
        encoding="utf-8",
    )
    print(f"  ✓ wrote {json_path}")

    health_path = out_dir / "health.json"
    health_path.write_text(
        json.dumps(build_health(freshness, len(changes)), indent=2, default=str),
        encoding="utf-8",
    )
    print(f"  ✓ wrote {health_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
