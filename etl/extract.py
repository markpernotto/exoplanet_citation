"""Phase 1 extract step.

Fetches pscomppars from NASA Exoplanet Archive, uploads the CSV to R2 under
snapshots/YYYY-MM-DD.csv, and appends a record to data/MANIFEST.jsonl.

Run: python -m etl.extract [--dry-run] [--force] [--snapshot-date YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import date, datetime, timezone
from pathlib import Path

from dotenv import load_dotenv

from etl import r2
from etl.sources.exoplanet_archive import fetch_pscomppars

EXTRACTION_VERSION = "0.1.0"
MANIFEST_PATH = Path("data/MANIFEST.jsonl")


def build_user_agent() -> str:
    project = os.environ.get(
        "USER_AGENT_PROJECT",
        "exoplanet_citation/0.1 (+https://github.com/markpernotto/exoplanet_citation)",
    )
    email = os.environ.get("USER_AGENT_EMAIL", "")
    return f"{project} (mailto:{email})" if email else project


def manifest_has_date(snapshot_date: date) -> bool:
    if not MANIFEST_PATH.exists():
        return False
    target = snapshot_date.isoformat()
    with MANIFEST_PATH.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if json.loads(line).get("snapshot_date") == target:
                return True
    return False


def upload_to_r2(body: bytes, key: str) -> None:
    r2.upload_object(r2.get_client(), key, body, content_type="text/csv")


def append_manifest(entry: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    with MANIFEST_PATH.open("a") as f:
        f.write(json.dumps(entry) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract pscomppars to R2")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch and report sizing/checksum without uploading or writing the manifest",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-extract even if a manifest entry already exists for the snapshot date",
    )
    parser.add_argument(
        "--snapshot-date",
        default=None,
        help="Override snapshot date (YYYY-MM-DD); default is today UTC",
    )
    args = parser.parse_args()

    load_dotenv()

    snapshot_date = (
        date.fromisoformat(args.snapshot_date)
        if args.snapshot_date
        else datetime.now(timezone.utc).date()
    )

    if manifest_has_date(snapshot_date) and not args.force and not args.dry_run:
        print(f"Snapshot for {snapshot_date} already in manifest. Pass --force to re-extract.")
        return 0

    user_agent = build_user_agent()
    print(f"Fetching pscomppars (User-Agent: {user_agent})...")
    response = fetch_pscomppars(user_agent=user_agent)
    print(f"  bytes:  {len(response.body):,}")
    print(f"  rows:   {response.row_count:,}")
    print(f"  sha256: {response.checksum_sha256}")

    r2_key = f"snapshots/{snapshot_date.isoformat()}.csv"

    if args.dry_run:
        print(f"--dry-run: would upload to r2://{r2.get_bucket()}/{r2_key}")
        return 0

    print(f"Uploading to r2://{r2.get_bucket()}/{r2_key}...")
    upload_to_r2(response.body, r2_key)

    entry = {
        "snapshot_date": snapshot_date.isoformat(),
        "r2_bucket": r2.get_bucket(),
        "r2_key": r2_key,
        "byte_count": len(response.body),
        "row_count": response.row_count,
        "checksum_sha256": response.checksum_sha256,
        "source_url": response.source_url,
        "source_retrieved_at": datetime.now(timezone.utc).isoformat(),
        "extraction_version": EXTRACTION_VERSION,
    }
    append_manifest(entry)
    print(f"Manifest appended: {MANIFEST_PATH}")
    print("Extract complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
