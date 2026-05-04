"""Smoke test: pull a host's gaia_dr3_id from Neon, hit Gaia DR3, print results.

Validates that etl/sources/gaia.py works end-to-end against the real Gaia
TAP service before we wire up etl/enrich_gaia.py and the host_stars_gaia
table.

Run: python -m etl.smoke_gaia ["Planet Name"]
Default: Kepler-22 b
"""

from __future__ import annotations

import os
import sys

import psycopg
from dotenv import load_dotenv

from etl.sources.gaia import fetch_gaia_dr3_records, parse_source_id


def main() -> int:
    load_dotenv()
    pl_name = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Kepler-22 b"

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT pl_name, hostname, gaia_dr3_id FROM planets_snapshots "
                "WHERE pl_name = %s ORDER BY snapshot_date DESC LIMIT 1",
                (pl_name,),
            )
            row = cur.fetchone()

    if row is None:
        print(f"No planet named {pl_name!r} found in planets_snapshots.")
        return 1

    db_name, hostname, raw_gaia_id = row
    sid = parse_source_id(raw_gaia_id)
    print(f"  pl_name:     {db_name}")
    print(f"  hostname:    {hostname}")
    print(f"  gaia_dr3_id: {raw_gaia_id!r} -> {sid}")

    if sid is None:
        print(f"\nNo Gaia DR3 cross-reference for {hostname}; nothing to query.")
        return 0

    user_agent = os.environ.get(
        "USER_AGENT_PROJECT",
        "exoplanet_citation/0.1 smoke-test",
    )
    print(f"\nQuerying Gaia DR3 for source_id={sid}...")
    records = fetch_gaia_dr3_records([sid], user_agent=user_agent)

    if sid not in records:
        print(f"No Gaia DR3 record returned for source_id={sid}.")
        print("(This can happen if pscomppars carries a stale cross-reference.)")
        return 1

    rec = records[sid]
    print(f"\n--- Gaia DR3 record for {hostname} ---")
    print(f"  source_id:           {rec.source_id}")
    print(f"  RA, Dec (deg):       {rec.ra}, {rec.dec}")
    print(f"  parallax (mas):      {rec.parallax_mas}")
    if rec.parallax_mas:
        d_pc = 1000.0 / rec.parallax_mas
        print(f"  → distance:          {d_pc:.1f} pc  ({d_pc * 3.26:.1f} light-years)")
    print(f"  proper motion (RA):  {rec.pmra_mas_yr} mas/yr")
    print(f"  proper motion (Dec): {rec.pmdec_mas_yr} mas/yr")
    print(f"  radial vel:          {rec.radial_velocity_km_s} km/s")
    print(f"  G-band magnitude:    {rec.phot_g_mean_mag}")
    print(f"  BP-RP color:         {rec.bp_rp}")
    print(f"  Teff (Gaia):         {rec.teff_gspphot} K")
    print(f"  log(g) (Gaia):       {rec.logg_gspphot}")
    print(f"  metallicity [M/H]:   {rec.mh_gspphot}")
    print(f"  distance (Gaia):     {rec.distance_gspphot_pc} pc")

    return 0


if __name__ == "__main__":
    sys.exit(main())
