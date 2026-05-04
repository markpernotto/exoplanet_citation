"""Phase 1 load step.

Reads a snapshot from R2 (per data/MANIFEST.jsonl), verifies its checksum,
parses the CSV, and UPSERTs into planets_snapshots in Postgres.

Run: python -m etl.load [--snapshot-date YYYY-MM-DD]

Default snapshot-date is the most recent entry in MANIFEST.jsonl.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
import sys
from datetime import date
from pathlib import Path
from typing import Any

import pandas as pd
import psycopg
from dotenv import load_dotenv
from psycopg.types.json import Jsonb

from etl import r2

MANIFEST_PATH = Path("data/MANIFEST.jsonl")

# Typed columns extracted from each CSV row into planets_snapshots.
TYPED_INT_COLS = ["sy_snum", "sy_pnum", "disc_year"]
TYPED_FLOAT_COLS = [
    "pl_orbper", "pl_orbsmax", "pl_orbeccen",
    "pl_rade", "pl_bmasse", "pl_dens", "pl_eqt", "pl_insol",
    "st_teff", "st_rad", "st_mass", "st_lum",
    "st_dist", "sy_dist",
    "ra", "dec",
]
TYPED_TEXT_COLS = [
    "pl_name",
    "hostname",
    "discoverymethod",
    "disc_facility",
    "disc_telescope",
    "disc_instrument",
    "disc_refname",
    "st_spectype",
    "gaia_dr3_id",
]
ALL_TYPED_COLS = TYPED_TEXT_COLS + TYPED_INT_COLS + TYPED_FLOAT_COLS

INSERT_SQL = """
INSERT INTO planets_snapshots (
    snapshot_date, pl_name, hostname,
    sy_snum, sy_pnum,
    discoverymethod, disc_year, disc_facility, disc_telescope, disc_instrument, disc_refname,
    pl_orbper, pl_orbsmax, pl_orbeccen,
    pl_rade, pl_bmasse, pl_dens, pl_eqt, pl_insol,
    st_teff, st_rad, st_mass, st_lum, st_spectype, st_dist,
    sy_dist, ra, dec, gaia_dr3_id,
    raw_row, source_url, source_retrieved_at, source_checksum, extraction_version
) VALUES (
    %(snapshot_date)s, %(pl_name)s, %(hostname)s,
    %(sy_snum)s, %(sy_pnum)s,
    %(discoverymethod)s, %(disc_year)s, %(disc_facility)s, %(disc_telescope)s, %(disc_instrument)s, %(disc_refname)s,
    %(pl_orbper)s, %(pl_orbsmax)s, %(pl_orbeccen)s,
    %(pl_rade)s, %(pl_bmasse)s, %(pl_dens)s, %(pl_eqt)s, %(pl_insol)s,
    %(st_teff)s, %(st_rad)s, %(st_mass)s, %(st_lum)s, %(st_spectype)s, %(st_dist)s,
    %(sy_dist)s, %(ra)s, %(dec)s, %(gaia_dr3_id)s,
    %(raw_row)s, %(source_url)s, %(source_retrieved_at)s, %(source_checksum)s, %(extraction_version)s
)
ON CONFLICT (snapshot_date, pl_name) DO UPDATE SET
    hostname = EXCLUDED.hostname,
    sy_snum = EXCLUDED.sy_snum,
    sy_pnum = EXCLUDED.sy_pnum,
    discoverymethod = EXCLUDED.discoverymethod,
    disc_year = EXCLUDED.disc_year,
    disc_facility = EXCLUDED.disc_facility,
    disc_telescope = EXCLUDED.disc_telescope,
    disc_instrument = EXCLUDED.disc_instrument,
    disc_refname = EXCLUDED.disc_refname,
    pl_orbper = EXCLUDED.pl_orbper,
    pl_orbsmax = EXCLUDED.pl_orbsmax,
    pl_orbeccen = EXCLUDED.pl_orbeccen,
    pl_rade = EXCLUDED.pl_rade,
    pl_bmasse = EXCLUDED.pl_bmasse,
    pl_dens = EXCLUDED.pl_dens,
    pl_eqt = EXCLUDED.pl_eqt,
    pl_insol = EXCLUDED.pl_insol,
    st_teff = EXCLUDED.st_teff,
    st_rad = EXCLUDED.st_rad,
    st_mass = EXCLUDED.st_mass,
    st_lum = EXCLUDED.st_lum,
    st_spectype = EXCLUDED.st_spectype,
    st_dist = EXCLUDED.st_dist,
    sy_dist = EXCLUDED.sy_dist,
    ra = EXCLUDED.ra,
    dec = EXCLUDED.dec,
    gaia_dr3_id = EXCLUDED.gaia_dr3_id,
    raw_row = EXCLUDED.raw_row,
    source_url = EXCLUDED.source_url,
    source_retrieved_at = EXCLUDED.source_retrieved_at,
    source_checksum = EXCLUDED.source_checksum,
    extraction_version = EXCLUDED.extraction_version
"""


def read_manifest_entry(snapshot_date: date | None) -> dict:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"{MANIFEST_PATH} does not exist; run extract first")

    entries: list[dict] = []
    with MANIFEST_PATH.open() as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    if not entries:
        raise ValueError(f"{MANIFEST_PATH} is empty; run extract first")

    if snapshot_date is None:
        return entries[-1]

    target = snapshot_date.isoformat()
    for entry in reversed(entries):
        if entry.get("snapshot_date") == target:
            return entry
    raise ValueError(f"No manifest entry for snapshot_date={target}")


def _clean(value: Any) -> Any:
    """Convert pandas NaN to None; pass through everything else."""
    if value is None:
        return None
    if isinstance(value, float) and math.isnan(value):
        return None
    return value


def _coerce_int(value: Any) -> int | None:
    value = _clean(value)
    if value is None or value == "":
        return None
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def _coerce_float(value: Any) -> float | None:
    value = _clean(value)
    if value is None or value == "":
        return None
    try:
        f = float(value)
        return None if math.isnan(f) else f
    except (TypeError, ValueError):
        return None


def _coerce_text(value: Any) -> str | None:
    value = _clean(value)
    if value is None or value == "":
        return None
    return str(value)


def build_row(csv_row: dict, manifest: dict) -> dict:
    """Map a raw CSV row dict + manifest metadata to INSERT parameters."""
    raw_row_clean = {k: _clean(v) for k, v in csv_row.items()}
    return {
        "snapshot_date": manifest["snapshot_date"],
        "pl_name": _coerce_text(csv_row.get("pl_name")),
        "hostname": _coerce_text(csv_row.get("hostname")),
        "sy_snum": _coerce_int(csv_row.get("sy_snum")),
        "sy_pnum": _coerce_int(csv_row.get("sy_pnum")),
        "discoverymethod": _coerce_text(csv_row.get("discoverymethod")),
        "disc_year": _coerce_int(csv_row.get("disc_year")),
        "disc_facility": _coerce_text(csv_row.get("disc_facility")),
        "disc_telescope": _coerce_text(csv_row.get("disc_telescope")),
        "disc_instrument": _coerce_text(csv_row.get("disc_instrument")),
        "disc_refname": _coerce_text(csv_row.get("disc_refname")),
        "pl_orbper": _coerce_float(csv_row.get("pl_orbper")),
        "pl_orbsmax": _coerce_float(csv_row.get("pl_orbsmax")),
        "pl_orbeccen": _coerce_float(csv_row.get("pl_orbeccen")),
        "pl_rade": _coerce_float(csv_row.get("pl_rade")),
        "pl_bmasse": _coerce_float(csv_row.get("pl_bmasse")),
        "pl_dens": _coerce_float(csv_row.get("pl_dens")),
        "pl_eqt": _coerce_float(csv_row.get("pl_eqt")),
        "pl_insol": _coerce_float(csv_row.get("pl_insol")),
        "st_teff": _coerce_float(csv_row.get("st_teff")),
        "st_rad": _coerce_float(csv_row.get("st_rad")),
        "st_mass": _coerce_float(csv_row.get("st_mass")),
        "st_lum": _coerce_float(csv_row.get("st_lum")),
        "st_spectype": _coerce_text(csv_row.get("st_spectype")),
        "st_dist": _coerce_float(csv_row.get("st_dist")),
        "sy_dist": _coerce_float(csv_row.get("sy_dist")),
        "ra": _coerce_float(csv_row.get("ra")),
        "dec": _coerce_float(csv_row.get("dec")),
        "gaia_dr3_id": _coerce_text(csv_row.get("gaia_dr3_id")),
        "raw_row": Jsonb(raw_row_clean),
        "source_url": manifest["source_url"],
        "source_retrieved_at": manifest["source_retrieved_at"],
        "source_checksum": manifest["checksum_sha256"],
        "extraction_version": manifest["extraction_version"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Load a pscomppars snapshot from R2 into Postgres")
    parser.add_argument(
        "--snapshot-date",
        default=None,
        help="Snapshot date (YYYY-MM-DD); default is the most recent manifest entry",
    )
    parser.add_argument(
        "--skip-checksum",
        action="store_true",
        help="Skip checksum verification (debug only)",
    )
    args = parser.parse_args()

    load_dotenv()

    snapshot_date = date.fromisoformat(args.snapshot_date) if args.snapshot_date else None
    manifest = read_manifest_entry(snapshot_date)
    print(f"Loading snapshot {manifest['snapshot_date']} from r2://{manifest['r2_bucket']}/{manifest['r2_key']}")

    client = r2.get_client()
    body = r2.download_object(client, manifest["r2_key"])
    actual_checksum = hashlib.sha256(body).hexdigest()
    if not args.skip_checksum and actual_checksum != manifest["checksum_sha256"]:
        print("  ✗ checksum mismatch", file=sys.stderr)
        print(f"    manifest: {manifest['checksum_sha256']}", file=sys.stderr)
        print(f"    actual:   {actual_checksum}", file=sys.stderr)
        return 1
    print("  ✓ checksum verified")

    df = pd.read_csv(io.BytesIO(body), low_memory=False, comment="#")
    print(f"  parsed: {len(df):,} rows × {len(df.columns)} cols")

    rows = [build_row(row, manifest) for row in df.to_dict(orient="records")]

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor() as cur:
            cur.executemany(INSERT_SQL, rows)
            conn.commit()
    print(f"  ✓ upserted {len(rows):,} rows into planets_snapshots")

    print("Load complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
