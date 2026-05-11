"""Build Gaia DR3 starfield binary assets for the VR scene.

Queries the ESA Gaia archive's TAP service for stars brighter than two magnitude
cutoffs and emits packed little-endian float32 binaries shipped as static
frontend assets. The VR scene reads these once at startup; no DB cost.

Two outputs:
  web/public/starfield_basic.bin   — mag < 8   (~50k stars,  ~1 MB)
  web/public/starfield_rich.bin    — mag < 10  (~300k stars, ~6 MB)

The basic file loads on every page that mounts the scene; the rich file is
lazy-loaded only when the user enters VR.

Binary format:
  bytes  0..7   ASCII magic   "STARV0\\0\\0"
  bytes  8..11  uint32 LE     star count N
  bytes 12..15  uint32 LE     fields per star (always 4 for v0)
  bytes 16..    float32 LE × (N × 4): ra_rad, dec_rad, g_mag, bp_rp_color

Run (one-shot — no cron):
  python -m etl.build_starfield                       # both files
  python -m etl.build_starfield --basic-only          # debug
  python -m etl.build_starfield --rich-only           # debug
  python -m etl.build_starfield --output-dir /tmp     # alternate output
"""

from __future__ import annotations

import argparse
import logging
import math
import struct
from pathlib import Path
from typing import Any

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

GAIA_TAP = "https://gea.esac.esa.int/tap-server/tap/sync"

# Gaia gives RA/Dec in degrees and BP-RP in magnitudes. We pack RA/Dec in
# radians so the JS side can pass them straight to three.js without conversion.
ADQL = """
SELECT ra, dec, phot_g_mean_mag, bp_rp
FROM gaiadr3.gaia_source
WHERE phot_g_mean_mag < {mag_limit}
  AND bp_rp IS NOT NULL
"""

MAGIC = b"STARV0\x00\x00"  # 8 bytes


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=60))
def fetch_stars(mag_limit: float) -> list[dict[str, Any]]:
    log.info("Querying Gaia DR3 for stars with G < %s …", mag_limit)
    resp = httpx.post(
        GAIA_TAP,
        data={
            "REQUEST": "doQuery",
            "LANG": "ADQL",
            "FORMAT": "json",
            "QUERY": ADQL.format(mag_limit=mag_limit),
        },
        timeout=300,  # large queries can take a while
    )
    resp.raise_for_status()
    payload = resp.json()
    # Gaia TAP JSON returns rows under either 'data' (positional) or as list of dicts.
    if isinstance(payload, dict) and "data" in payload:
        cols = [c["name"] for c in payload["metadata"]]
        rows = [dict(zip(cols, r)) for r in payload["data"]]
    else:
        rows = payload
    log.info("Got %d stars", len(rows))
    return rows


def pack_starfield(stars: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    valid = [s for s in stars
             if s.get("ra") is not None and s.get("dec") is not None
             and s.get("phot_g_mean_mag") is not None and s.get("bp_rp") is not None]
    n = len(valid)
    log.info("Packing %d stars into %s …", n, path)

    with path.open("wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<II", n, 4))
        for s in valid:
            ra_rad  = math.radians(float(s["ra"]))
            dec_rad = math.radians(float(s["dec"]))
            mag     = float(s["phot_g_mean_mag"])
            bp_rp   = float(s["bp_rp"])
            f.write(struct.pack("<ffff", ra_rad, dec_rad, mag, bp_rp))

    size_kb = path.stat().st_size / 1024
    log.info("Wrote %s — %.1f KB (%d stars)", path, size_kb, n)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Gaia DR3 starfield binaries")
    parser.add_argument("--basic-only", action="store_true", help="Skip rich (mag<10) build")
    parser.add_argument("--rich-only", action="store_true", help="Skip basic (mag<8) build")
    parser.add_argument("--output-dir", default="web/public",
                        help="Directory for the .bin files (default: web/public)")
    args = parser.parse_args()

    out = Path(args.output_dir)

    if not args.rich_only:
        stars = fetch_stars(8.0)
        pack_starfield(stars, out / "starfield_basic.bin")

    if not args.basic_only:
        stars = fetch_stars(10.0)
        pack_starfield(stars, out / "starfield_rich.bin")

    log.info("Done.")


if __name__ == "__main__":
    main()
