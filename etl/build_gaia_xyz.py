"""Build Gaia DR3 heliocentric-XYZ catalog for per-vantage starfield rendering.

Queries the ESA Gaia archive's TAP service for stars with reliable parallax
measurements and emits `data/gaia_xyz.parquet`, a columnar catalog the
per-vantage starfield endpoint reads at request time. Each row stores the
star's heliocentric Cartesian position (parsecs), absolute G magnitude, and
Gaia BP-RP color index — everything the server needs to reproject the sky
from an arbitrary host system's vantage point.

Output schema (float32 throughout for compactness):
    x_pc, y_pc, z_pc  heliocentric Cartesian position, parsecs
    abs_g_mag         absolute G-band magnitude
    bp_rp             Gaia BP - RP color index

Row 0 is always Sol at (0, 0, 0). With Sol's well-known absolute G magnitude
(4.67) and BP-RP color (0.82) seeded as row 0, any per-vantage reprojection
naturally treats Sol as just another field star from elsewhere in the galaxy.

Default query: phot_g_mean_mag < 10 AND parallax > 0.5 mas. That's roughly
300k–400k stars within ~2 kpc — the solar neighborhood + nearby galactic
disk. Stars with poorer parallax are excluded because their inferred 3-D
positions would be unreliable for reprojection. Deeper coverage of the
galactic bulge is the procedural-particle layer's job (Layer 2 in
docs/STARFIELD_PLAN.md), not this catalog.

Run (one-shot, regenerate when ready to refresh):

    python -m etl.build_gaia_xyz                       # default mag<10, plx>0.5
    python -m etl.build_gaia_xyz --mag-limit 8         # smaller/faster
    python -m etl.build_gaia_xyz --output /tmp/x.parquet
"""

from __future__ import annotations

import argparse
import logging
import math
from pathlib import Path
from typing import Any

import httpx
import pandas as pd
from tenacity import retry, stop_after_attempt, wait_exponential

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

GAIA_TAP = "https://gea.esac.esa.int/tap-server/tap/sync"

# Sol's photometric properties expressed in Gaia bands. Both are well-
# constrained: abs G from Casagrande & VandenBerg 2018; BP-RP from
# Mamajek's revised stellar-color table (the de facto reference for
# main-sequence dwarf colors).
SOL_ABS_G_MAG = 4.67
SOL_BP_RP = 0.82

# Query: stars brighter than mag limit with parallax > min threshold.
#   parallax > 0.5 mas  →  distance < 2000 pc
# Stars with poorer parallax become unreliable for XYZ reprojection.
ADQL = """
SELECT ra, dec, parallax, phot_g_mean_mag, bp_rp
FROM gaiadr3.gaia_source
WHERE phot_g_mean_mag < {mag_limit}
  AND parallax > {min_parallax_mas}
  AND bp_rp IS NOT NULL
"""


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=60))
def fetch_stars(mag_limit: float, min_parallax_mas: float) -> list[dict[str, Any]]:
    log.info("Querying Gaia DR3: G < %s, parallax > %s mas …", mag_limit, min_parallax_mas)
    resp = httpx.post(
        GAIA_TAP,
        data={
            "REQUEST": "doQuery",
            "LANG": "ADQL",
            "FORMAT": "json",
            "QUERY": ADQL.format(mag_limit=mag_limit, min_parallax_mas=min_parallax_mas),
        },
        timeout=600,
    )
    resp.raise_for_status()
    payload = resp.json()
    if isinstance(payload, dict) and "data" in payload:
        cols = [c["name"] for c in payload["metadata"]]
        rows = [dict(zip(cols, r, strict=True)) for r in payload["data"]]
    else:
        rows = payload
    log.info("Got %d stars", len(rows))
    return rows


def equatorial_to_xyz(ra_deg: float, dec_deg: float, parallax_mas: float) -> tuple[float, float, float]:
    """Equatorial RA/Dec/parallax (Gaia native frame) → heliocentric XYZ in parsecs.

    Convention: +X toward (RA=0, Dec=0), +Y toward (RA=90°, Dec=0),
    +Z toward Dec=+90° (north celestial pole). Same convention as
    astropy.coordinates.ICRS Cartesian.
    """
    distance_pc = 1000.0 / parallax_mas
    ra_rad = math.radians(ra_deg)
    dec_rad = math.radians(dec_deg)
    cos_dec = math.cos(dec_rad)
    x = distance_pc * cos_dec * math.cos(ra_rad)
    y = distance_pc * cos_dec * math.sin(ra_rad)
    z = distance_pc * math.sin(dec_rad)
    return x, y, z


def apparent_to_absolute_g(g_mag: float, parallax_mas: float) -> float:
    """Apparent G magnitude + parallax → absolute G magnitude.

    Standard distance modulus: M = m - 5 * log10(d_pc / 10).
    """
    distance_pc = 1000.0 / parallax_mas
    return g_mag - 5.0 * math.log10(distance_pc / 10.0)


def build_xyz_dataframe(stars: list[dict[str, Any]]) -> pd.DataFrame:
    """Convert raw Gaia rows into a Sol-prepended DataFrame with XYZ + photometry.

    Skips rows missing any of ra/dec/parallax/phot_g_mean_mag/bp_rp.
    Skips rows with non-positive parallax (Gaia occasionally reports
    negative parallax from noisy fits; these are physically meaningless).
    """
    rows: list[tuple[float, float, float, float, float]] = [
        (0.0, 0.0, 0.0, SOL_ABS_G_MAG, SOL_BP_RP),
    ]
    skipped = 0
    for s in stars:
        try:
            ra = float(s["ra"])
            dec = float(s["dec"])
            parallax = float(s["parallax"])
            g_mag = float(s["phot_g_mean_mag"])
            bp_rp = float(s["bp_rp"])
        except (TypeError, ValueError, KeyError):
            skipped += 1
            continue
        if parallax <= 0:
            skipped += 1
            continue
        x, y, z = equatorial_to_xyz(ra, dec, parallax)
        abs_mag = apparent_to_absolute_g(g_mag, parallax)
        rows.append((x, y, z, abs_mag, bp_rp))

    if skipped:
        log.info("Skipped %d rows (missing/invalid/non-positive parallax)", skipped)

    df = pd.DataFrame(rows, columns=["x_pc", "y_pc", "z_pc", "abs_g_mag", "bp_rp"])
    return df.astype({
        "x_pc": "float32",
        "y_pc": "float32",
        "z_pc": "float32",
        "abs_g_mag": "float32",
        "bp_rp": "float32",
    })


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build Gaia DR3 heliocentric-XYZ parquet for per-vantage starfield",
    )
    parser.add_argument("--mag-limit", type=float, default=10.0,
                        help="Apparent G magnitude cutoff (default 10 → ~300k stars)")
    parser.add_argument("--min-parallax-mas", type=float, default=0.5,
                        help="Min parallax in mas (default 0.5 → < 2 kpc)")
    parser.add_argument("--output", default="data/gaia_xyz.parquet",
                        help="Output parquet path (default: data/gaia_xyz.parquet)")
    args = parser.parse_args()

    stars = fetch_stars(args.mag_limit, args.min_parallax_mas)
    df = build_xyz_dataframe(stars)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(out, compression="snappy", index=False)

    size_mb = out.stat().st_size / (1024 * 1024)
    log.info("Wrote %s — %.2f MB (%d rows including Sol)", out, size_mb, len(df))


if __name__ == "__main__":
    main()
