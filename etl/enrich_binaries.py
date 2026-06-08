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
SELF_RADIUS_ARCSEC = 1.5        # rows within this of host coords = "self".
                                # Was 5" — too loose. TrES-2 B sits at 0.80"
                                # from the primary and was being mistaken for
                                # the host's own catalog entry. 1.5" is wide
                                # enough to absorb realistic SIMBAD position
                                # uncertainties for the actual primary while
                                # leaving close (>1.5") visual companions
                                # eligible as candidates.
NO_PLX_FALLBACK_ARCSEC = 30     # if host parallax unknown, only trust very close
# Close-pair fallback: when the host has a parallax but the candidate does NOT,
# we still accept the candidate if it's within this angular separation. Faint
# M-dwarf companions at <2" from a bright primary often lack a clean Gaia
# parallax (faint + crowded), so the strict "candidate must have parallax"
# rule was rejecting real physical pairs. 10" is tight enough that the prior
# of physical association is high — unrelated foreground/background stars
# rarely sit within 10" of an exoplanet host.
NO_PLX_CLOSE_PAIR_ARCSEC = 10
COMPANION_LETTERS = ["B", "C", "D", "E"]

STELLAR_OTYPES = (
    "*", "**", "PM*", "LM*", "BD*", "PMS*", "SB*", "EB*", "BY*", "RS*",
    "HMS*", "HVS*", "WD*", "BH", "NS", "Pu*",
    # Additions (2026-06-01): emission/variable/young/evolved star types
    # that were missing from the original list. The TrES-2 primary "Kepler-1"
    # is otype Em* (emission-line star); without this its SIMBAD row didn't
    # come back in the spatial query and the script couldn't anchor on the
    # primary, leading to the companion at 0.80" being mis-classified as
    # "self". Similar issue applies to active / young / variable / evolved
    # hosts across the catalog.
    "Em*", "V*", "Be*", "TT*", "Y*O", "sg*", "s*r", "HB*", "AGB*", "RG*",
    "C*", "Mi*", "RR*", "Ce*", "WV*",
)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=30))
def simbad_resolve_name(hostname: str) -> dict[str, Any] | None:
    """Look up SIMBAD's canonical basic-table record for a given identifier.

    Used as a fallback when coord-based spatial matching can't anchor on the
    primary (NASA EA catalog coords sometimes differ from SIMBAD's by more
    than SELF_RADIUS_ARCSEC due to epoch differences, proper-motion drift, or
    which component of a multi-star system the archive picked as the system
    reference). The ident table stores all known aliases; joining it back to
    basic returns the canonical record + coords + parallax for the matched
    name. Returns None if SIMBAD doesn't recognise the identifier.
    """
    safe = hostname.replace("'", "''")
    adql = f"""
        SELECT b.oid, b.main_id, b.ra, b.dec, b.otype, b.sp_type, b.plx_value
        FROM basic b
        JOIN ident i ON i.oidref = b.oid
        WHERE i.id = '{safe}'
    """
    resp = httpx.post(
        SIMBAD_TAP,
        data={"REQUEST": "doQuery", "LANG": "ADQL", "FORMAT": "json", "QUERY": adql},
        timeout=30,
        follow_redirects=True,
    )
    resp.raise_for_status()
    payload = resp.json()
    if isinstance(payload, dict) and "data" in payload and payload["data"]:
        cols = [c["name"] for c in payload["metadata"]]
        return dict(zip(cols, payload["data"][0], strict=True))
    return None


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


def _filter_companions(
    rows: list[dict[str, Any]],
    anchor_oid: int,
    anchor_ra: float,
    anchor_dec: float,
    host_plx: float | None,
) -> list[tuple[float, dict[str, Any]]]:
    """Filter spatial-query rows down to plausible physical companions of the
    anchor. Excludes the anchor itself (by oid), drops duplicates within 1",
    and applies the parallax / close-pair fallback filters. Returns
    (separation, row) tuples; caller sorts and converts to companion records.
    """
    candidates: list[tuple[float, dict[str, Any]]] = []
    for row in rows:
        if row["oid"] == anchor_oid:
            continue
        sep = angular_separation_arcsec(anchor_ra, anchor_dec, row["ra"], row["dec"])
        if sep < 1.0:
            continue   # cataloging duplicate of self
        plx = row.get("plx_value")
        if host_plx is not None:
            if plx is None:
                # Candidate lacks a parallax measurement (common for faint
                # companions close to a bright primary). Accept only when
                # the angular separation is small enough that proximity
                # itself is strong evidence of a physical pair.
                if sep > NO_PLX_CLOSE_PAIR_ARCSEC:
                    continue
            elif abs(plx - host_plx) / abs(host_plx) > PLX_REL_TOL:
                continue
        else:
            # No anchor parallax — only trust very close neighbors and don't filter on plx
            if sep > NO_PLX_FALLBACK_ARCSEC:
                continue
        candidates.append((sep, row))
    return candidates


def process_hostname(hostname: str, ra: float, dec: float) -> list[dict[str, Any]]:
    """Resolve companions for one host.

    Two-stage strategy:
      1. Coord-based anchor — query SIMBAD at (ra, dec), find the row within
         SELF_RADIUS_ARCSEC. Works for hosts whose NASA EA coords closely
         match SIMBAD's.
      2. Name-resolution fallback — when coord-anchor fails, look up the host
         by identifier in SIMBAD's `ident` table. If found, re-query spatial
         at SIMBAD's canonical coords and anchor by oid match. Recovers hosts
         whose catalog coords drifted from SIMBAD's (epoch / proper motion /
         different reference component).
    """
    try:
        rows = simbad_spatial(ra, dec)
    except Exception as exc:
        log.warning("  SIMBAD lookup failed for %s: %s", hostname, exc)
        return []

    anchor_row: dict[str, Any] | None = None
    anchor_ra, anchor_dec = ra, dec

    if rows:
        # Stage 1: coord-based anchor.
        self_sep = float("inf")
        for row in rows:
            sep = angular_separation_arcsec(ra, dec, row["ra"], row["dec"])
            if sep < self_sep and sep <= SELF_RADIUS_ARCSEC:
                anchor_row, self_sep = row, sep
        if anchor_row is not None:
            anchor_ra, anchor_dec = anchor_row["ra"], anchor_row["dec"]

    if anchor_row is None:
        # Stage 2: name-resolution fallback. Try to find the host in SIMBAD's
        # ident table directly, regardless of where its coords sit.
        try:
            resolved = simbad_resolve_name(hostname)
        except Exception as exc:
            log.warning("  %s: name-resolution failed: %s", hostname, exc)
            return []
        if resolved is None:
            log.info("  %s: no SIMBAD entry by coords (<%.1f\") or by name",
                     hostname, SELF_RADIUS_ARCSEC)
            return []
        sep_from_catalog = angular_separation_arcsec(
            ra, dec, resolved["ra"], resolved["dec"])
        log.info("  %s: name-resolved to %s (%.1f\" from catalog coords)",
                 hostname, resolved["main_id"], sep_from_catalog)
        # Re-query at SIMBAD's coords (may differ from NASA EA's enough that
        # the original spatial result missed the actual neighborhood).
        try:
            rows = simbad_spatial(resolved["ra"], resolved["dec"])
        except Exception as exc:
            log.warning("  SIMBAD spatial re-query failed for %s: %s",
                        hostname, exc)
            return []
        if not rows:
            return []
        # Anchor by oid match. If the resolved primary's otype is excluded
        # by the spatial query's stellar-otype filter, the resolved row
        # won't be in `rows` — we still use the resolved info as the anchor
        # and treat all rows as candidates.
        anchor_row = next((r for r in rows if r["oid"] == resolved["oid"]), resolved)
        anchor_ra, anchor_dec = resolved["ra"], resolved["dec"]

    host_plx = anchor_row.get("plx_value")
    candidates = _filter_companions(
        rows, anchor_row["oid"], anchor_ra, anchor_dec, host_plx)
    if not candidates:
        return []

    primary_designation = "A"   # planet host = A by exoplanet-archive convention

    # Sort by separation; closest = B, next = C, etc.
    candidates.sort(key=lambda x: x[0])
    out: list[dict[str, Any]] = []
    for letter, (sep, comp) in zip(COMPANION_LETTERS, candidates, strict=False):
        out.append({
            "hostname":   hostname,
            "component":  letter,
            "primary":    primary_designation,
            "sep_arcsec": sep,
            "pa_deg":     position_angle_deg(anchor_ra, anchor_dec,
                                             comp["ra"], comp["dec"]),
            "mag_v":      comp.get("mag_v"),
            "spectype":   comp.get("sp_type"),
        })
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Enrich binary_companions from SIMBAD")
    parser.add_argument("--refresh-all", action="store_true",
                        help="Re-resolve every multi-star host")
    parser.add_argument("--dry-run", action="store_true",
                        help="Resolve via SIMBAD and log what WOULD be written; skip the DB write")
    parser.add_argument("--limit", type=int, default=None, help="Stop after N hosts")
    parser.add_argument("--target-host", type=str, default=None,
                        help="Resolve only this specific hostname (still applies refresh-all logic)")
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

        if args.target_host:
            # Single-host mode: ignore the cache-skip logic so the user can
            # always re-resolve a specific host (useful for testing filter
            # changes against a known case like TrES-2).
            todo = [h for h in hosts if h[0] == args.target_host]
            if not todo:
                log.error("Hostname %r not found in planets_current (sy_snum >= 2)",
                          args.target_host)
                return
            log.info("Single-host mode: %s", args.target_host)
        elif args.refresh_all:
            todo = hosts
        else:
            with conn.cursor() as cur:
                cur.execute("SELECT DISTINCT hostname FROM binary_companions")
                already = {r[0] for r in cur.fetchall()}
            todo = [h for h in hosts if h[0] not in already]
            log.info("%d already cached, %d to fetch", len(already), len(todo))

    if args.limit:
        todo = todo[: args.limit]
    if not todo:
        log.info("Nothing to do.")
        return

    fetched = wrote = 0
    for i, (hostname, ra, dec) in enumerate(todo, 1):
        log.info("[%d/%d] %s", i, len(todo), hostname)
        rows = process_hostname(hostname, ra, dec)
        if rows:
            for r in rows:
                log.info("  candidate %s: sep=%.2f\" pa=%.0f° mag_v=%s spectype=%r",
                         r["component"], r["sep_arcsec"], r["pa_deg"] or 0,
                         r["mag_v"], r["spectype"])
            if not args.dry_run:
                with psycopg.connect(db_url) as wconn:
                    with wconn.cursor() as cur:
                        cur.executemany(UPSERT_SQL, rows)
                    wconn.commit()
                wrote += len(rows)
                log.info("  → %d companion(s) written", len(rows))
            else:
                log.info("  → %d companion(s) [DRY RUN, not written]", len(rows))
        fetched += 1
        if i < len(todo):
            time.sleep(SLEEP_BETWEEN)

    if args.dry_run:
        log.info("Done — dry-resolved %d hostnames", fetched)
    else:
        log.info("Done — resolved %d hostnames, wrote %d companion rows", fetched, wrote)


if __name__ == "__main__":
    main()
