"""SIMBAD binary-companion enrichment via spatial cross-match.

For every hostname in `planets_current` with `sy_snum >= 2`, queries SIMBAD's
TAP service for any stellar object within 200 arcsec of the host's coordinates,
then filters by parallax similarity (physically-bound stars have matching
distance from us — within ~20% relative tolerance). Surviving neighbors are the
candidate companions.

This replaces an earlier name-suffix matching approach (which got ~5% coverage)
with a coordinate-based one that gets ~60-70%. The fundamental limitation: many
exoplanet host binaries are unresolved spectroscopic pairs (otype SB*/EB*) —
the secondary has no separate position, so it can't be placed as a "second
sun" in the VR scene. Those systems are flagged but not enumerated here.

Prerequisite: apply etl/migrations/007_binary_companions.sql to your DB.

Run:
  python -m etl.enrich_binaries                   # incremental (default)
  python -m etl.enrich_binaries --refresh-all     # re-resolve every system
  python -m etl.enrich_binaries --dry-run         # plan only
  python -m etl.enrich_binaries --limit 10        # smoke test
"""

from __future__ import annotations

import argparse
import logging
import math
import os
import time
from typing import Any

import httpx
import psycopg
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_exponential

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

SIMBAD_TAP        = "https://simbad.cds.unistra.fr/simbad/sim-tap/sync"
SLEEP_BETWEEN     = 0.4         # be polite to SIMBAD
SEARCH_RADIUS_DEG = 200 / 3600  # 200 arcsec; covers visual binaries comfortably
PLX_REL_TOL       = 0.20        # 20% relative parallax match → physical pair
SELF_RADIUS_ARCSEC = 5          # rows within this of host coords = "self"
NO_PLX_FALLBACK_ARCSEC = 30     # if host parallax unknown, only trust very close
COMPANION_LETTERS = ["B", "C", "D", "E"]

STELLAR_OTYPES = (
    "*", "**", "PM*", "LM*", "BD*", "PMS*", "SB*", "EB*", "BY*", "RS*",
    "HMS*", "HVS*", "WD*", "BH", "NS", "Pu*",
)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=30))
def simbad_spatial(host_ra: float, host_dec: float) -> list[dict[str, Any]]:
    """All stellar objects within SEARCH_RADIUS_DEG of (ra, dec)."""
    otype_list = ", ".join(f"'{o}'" for o in STELLAR_OTYPES)
    adql = f"""
        SELECT b.oid, b.main_id, b.ra, b.dec, b.otype, b.sp_type,
               b.plx_value, f.V AS mag_v
        FROM basic b
        LEFT JOIN allfluxes f ON f.oidref = b.oid
        WHERE CONTAINS(POINT('ICRS', b.ra, b.dec),
                       CIRCLE('ICRS', {host_ra}, {host_dec}, {SEARCH_RADIUS_DEG})) = 1
          AND b.otype IN ({otype_list})
          AND b.ra IS NOT NULL
    """
    resp = httpx.post(
        SIMBAD_TAP,
        data={"REQUEST": "doQuery", "LANG": "ADQL", "FORMAT": "json", "QUERY": adql},
        timeout=30,
        follow_redirects=True,
    )
    resp.raise_for_status()
    payload = resp.json()
    if isinstance(payload, dict) and "data" in payload:
        cols = [c["name"] for c in payload["metadata"]]
        return [dict(zip(cols, r, strict=True)) for r in payload["data"]]
    return payload or []


def angular_separation_arcsec(ra1: float, dec1: float, ra2: float, dec2: float) -> float:
    r1, d1, r2, d2 = (math.radians(x) for x in (ra1, dec1, ra2, dec2))
    inner = math.sin(d1) * math.sin(d2) + math.cos(d1) * math.cos(d2) * math.cos(r1 - r2)
    return math.degrees(math.acos(min(1.0, max(-1.0, inner)))) * 3600.0


def position_angle_deg(ra1: float, dec1: float, ra2: float, dec2: float) -> float:
    r1, d1, r2, d2 = (math.radians(x) for x in (ra1, dec1, ra2, dec2))
    dra = r2 - r1
    y = math.sin(dra) * math.cos(d2)
    x = math.cos(d1) * math.sin(d2) - math.sin(d1) * math.cos(d2) * math.cos(dra)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


UPSERT_SQL = """
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation,
     separation_arcsec, position_angle_deg,
     component_mass_msun, component_teff_k, component_mag_v, component_spectype,
     source_catalog, source_bibcode)
VALUES
    (%(hostname)s, %(component)s, %(primary)s,
     %(sep_arcsec)s, %(pa_deg)s,
     NULL, NULL, %(mag_v)s, %(spectype)s,
     'SIMBAD', NULL)
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation = EXCLUDED.primary_designation,
    separation_arcsec   = EXCLUDED.separation_arcsec,
    position_angle_deg  = EXCLUDED.position_angle_deg,
    component_mag_v     = EXCLUDED.component_mag_v,
    component_spectype  = EXCLUDED.component_spectype,
    source_catalog      = EXCLUDED.source_catalog,
    retrieved_at        = now()
"""


def process_hostname(hostname: str, ra: float, dec: float) -> list[dict[str, Any]]:
    """Resolve companions for one host via spatial + parallax filtering."""
    try:
        rows = simbad_spatial(ra, dec)
    except Exception as exc:
        log.warning("  SIMBAD lookup failed for %s: %s", hostname, exc)
        return []

    if not rows:
        return []

    # Identify "self" — the row closest to host coords within SELF_RADIUS_ARCSEC.
    # We anchor on this row's parallax and exclude it from companions.
    self_row = None
    self_sep = float("inf")
    for row in rows:
        sep = angular_separation_arcsec(ra, dec, row["ra"], row["dec"])
        if sep < self_sep and sep <= SELF_RADIUS_ARCSEC:
            self_row, self_sep = row, sep
    if self_row is None:
        log.info("  %s: no SIMBAD entry within %d\" of catalog coords",
                 hostname, SELF_RADIUS_ARCSEC)
        return []

    host_plx = self_row.get("plx_value")
    primary_designation = "A"   # planet host = A by exoplanet-archive convention

    # Filter neighbors → likely physical companions
    candidates: list[tuple[float, dict[str, Any]]] = []
    for row in rows:
        if row["oid"] == self_row["oid"]:
            continue
        sep = angular_separation_arcsec(self_row["ra"], self_row["dec"],
                                        row["ra"], row["dec"])
        if sep < 1.0:
            continue   # cataloging duplicate of self
        plx = row.get("plx_value")
        if host_plx is not None:
            if plx is None:
                continue
            if abs(plx - host_plx) / abs(host_plx) > PLX_REL_TOL:
                continue
        else:
            # No anchor parallax — only trust very close neighbors and don't filter on plx
            if sep > NO_PLX_FALLBACK_ARCSEC:
                continue
        candidates.append((sep, row))

    if not candidates:
        return []

    # Sort by separation; closest = B, next = C, etc.
    candidates.sort(key=lambda x: x[0])
    out: list[dict[str, Any]] = []
    for letter, (sep, comp) in zip(COMPANION_LETTERS, candidates, strict=False):
        out.append({
            "hostname":   hostname,
            "component":  letter,
            "primary":    primary_designation,
            "sep_arcsec": sep,
            "pa_deg":     position_angle_deg(self_row["ra"], self_row["dec"],
                                             comp["ra"], comp["dec"]),
            "mag_v":      comp.get("mag_v"),
            "spectype":   comp.get("sp_type"),
        })
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Enrich binary_companions from SIMBAD")
    parser.add_argument("--refresh-all", action="store_true",
                        help="Re-resolve every multi-star host")
    parser.add_argument("--dry-run", action="store_true", help="Plan only")
    parser.add_argument("--limit", type=int, default=None, help="Stop after N hosts")
    args = parser.parse_args()

    db_url = os.environ["DATABASE_URL"]

    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT hostname, ra, dec
                FROM planets_current
                WHERE sy_snum >= 2 AND ra IS NOT NULL AND dec IS NOT NULL
                ORDER BY hostname
            """)
            hosts = cur.fetchall()
        log.info("%d multi-star hostnames in catalog (with coords)", len(hosts))

        if args.refresh_all:
            todo = hosts
        else:
            with conn.cursor() as cur:
                cur.execute("SELECT DISTINCT hostname FROM binary_companions")
                already = {r[0] for r in cur.fetchall()}
            todo = [h for h in hosts if h[0] not in already]
            log.info("%d already cached, %d to fetch", len(already), len(todo))

    if args.limit:
        todo = todo[: args.limit]
    if args.dry_run:
        log.info("DRY RUN — would resolve %d hostnames", len(todo))
        return
    if not todo:
        log.info("Nothing to do.")
        return

    fetched = wrote = 0
    for i, (hostname, ra, dec) in enumerate(todo, 1):
        log.info("[%d/%d] %s", i, len(todo), hostname)
        rows = process_hostname(hostname, ra, dec)
        if rows:
            with psycopg.connect(db_url) as wconn:
                with wconn.cursor() as cur:
                    cur.executemany(UPSERT_SQL, rows)
                wconn.commit()
            wrote += len(rows)
            log.info("  → %d companion(s)", len(rows))
        fetched += 1
        if i < len(todo):
            time.sleep(SLEEP_BETWEEN)

    log.info("Done — resolved %d hostnames, wrote %d companion rows", fetched, wrote)


if __name__ == "__main__":
    main()
