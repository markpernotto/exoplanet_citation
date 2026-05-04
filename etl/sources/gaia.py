"""Gaia DR3 TAP client.

Looks up host stars in ESA's Gaia Data Release 3 catalog by source ID.
Used by etl/enrich_gaia.py (Phase 2) to attach precise astrometry,
photometry, and Gaia-derived stellar parameters to each exoplanet host.

The pscomppars `gaia_dr3_id` column carries the cross-reference key (sometimes
as a bare integer, sometimes prefixed "Gaia DR3 ..."); use parse_source_id()
to normalize before passing to fetch_gaia_dr3_records().

API docs: https://gea.esac.esa.int/archive/documentation/GDR3/
TAP endpoint: https://gea.esac.esa.int/tap-server/tap
Schema docs (gaiadr3.gaia_source columns):
  https://gea.esac.esa.int/archive/documentation/GDR3/Gaia_archive/chap_datamodel/sec_dm_main_source_catalogue/ssec_dm_gaia_source.html
"""

from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

TAP_SYNC_URL = "https://gea.esac.esa.int/tap-server/tap/sync"

# Columns we pull from gaiadr3.gaia_source. Must stay in sync with the
# host_stars_gaia table schema in etl/schema.sql (Phase 2 migration).
GAIA_COLUMNS = [
    "source_id",
    "ra", "dec",
    "parallax", "parallax_error",
    "pmra", "pmdec",
    "radial_velocity",
    "phot_g_mean_mag", "phot_bp_mean_mag", "phot_rp_mean_mag",
    "bp_rp",
    "teff_gspphot", "logg_gspphot", "mh_gspphot",
    "distance_gspphot",
]

# How many source_ids to query in a single TAP request. Gaia's TAP service has
# both rate limits and a per-query size limit (~1MB ADQL); 100 keeps us well
# below either while minimizing round trips. ~6,300 hosts → ~63 requests for
# a full backfill.
DEFAULT_BATCH_SIZE = 100


@dataclass(frozen=True)
class GaiaRecord:
    """One row from gaiadr3.gaia_source, normalized for our pipeline.

    Field names match host_stars_gaia table columns, not Gaia's source-table
    column names (e.g. parallax_mas, not parallax). The raw dict is preserved
    in `raw` for provenance and for fields we don't promote to typed columns.
    """
    source_id: int
    ra: float | None
    dec: float | None
    parallax_mas: float | None
    parallax_error: float | None
    pmra_mas_yr: float | None
    pmdec_mas_yr: float | None
    radial_velocity_km_s: float | None
    phot_g_mean_mag: float | None
    phot_bp_mean_mag: float | None
    phot_rp_mean_mag: float | None
    bp_rp: float | None
    teff_gspphot: float | None
    logg_gspphot: float | None
    mh_gspphot: float | None
    distance_gspphot_pc: float | None
    raw: dict[str, Any]


_GAIA_DR3_PREFIX = re.compile(r"^\s*Gaia\s+DR3\s+", re.IGNORECASE)


def parse_source_id(raw: str | int | None) -> int | None:
    """Normalize a Gaia DR3 source ID to a bare integer.

    Accepts: bare integer, integer string, or "Gaia DR3 <id>" prefixed string.
    Returns None for None / empty / unparseable input — caller should treat
    None as "no Gaia cross-reference" and skip the lookup.
    """
    if raw is None:
        return None
    if isinstance(raw, int):
        return raw
    s = _GAIA_DR3_PREFIX.sub("", str(raw)).strip()
    if not s:
        return None
    try:
        return int(s)
    except ValueError:
        return None


def _build_query(source_ids: list[int]) -> str:
    cols = ", ".join(GAIA_COLUMNS)
    id_list = ", ".join(str(sid) for sid in source_ids)
    return f"SELECT {cols} FROM gaiadr3.gaia_source WHERE source_id IN ({id_list})"


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=30))
def _fetch_batch(source_ids: list[int], *, user_agent: str) -> list[dict[str, Any]]:
    """Fetch one batch of Gaia DR3 records.

    Gaia's /sync TAP endpoint returns column-major JSON when FORMAT=json:
        {"metadata": [{"name": "source_id", ...}, ...], "data": [[id1, ra1, ...], ...]}
    We zip those into row dicts before returning.
    """
    if not source_ids:
        return []
    params = {
        "REQUEST": "doQuery",
        "LANG": "ADQL",
        "FORMAT": "json",
        "QUERY": _build_query(source_ids),
    }
    headers = {"User-Agent": user_agent}
    with httpx.Client(timeout=httpx.Timeout(120.0), headers=headers) as client:
        response = client.get(TAP_SYNC_URL, params=params)
        response.raise_for_status()
    payload = response.json()
    columns = [m["name"] for m in payload.get("metadata", [])]
    rows = payload.get("data", [])
    return [dict(zip(columns, row, strict=False)) for row in rows]


def _record_from_dict(d: dict[str, Any]) -> GaiaRecord:
    def f(key: str) -> float | None:
        v = d.get(key)
        return None if v is None else float(v)

    return GaiaRecord(
        source_id=int(d["source_id"]),
        ra=f("ra"),
        dec=f("dec"),
        parallax_mas=f("parallax"),
        parallax_error=f("parallax_error"),
        pmra_mas_yr=f("pmra"),
        pmdec_mas_yr=f("pmdec"),
        radial_velocity_km_s=f("radial_velocity"),
        phot_g_mean_mag=f("phot_g_mean_mag"),
        phot_bp_mean_mag=f("phot_bp_mean_mag"),
        phot_rp_mean_mag=f("phot_rp_mean_mag"),
        bp_rp=f("bp_rp"),
        teff_gspphot=f("teff_gspphot"),
        logg_gspphot=f("logg_gspphot"),
        mh_gspphot=f("mh_gspphot"),
        distance_gspphot_pc=f("distance_gspphot"),
        raw=d,
    )


def fetch_gaia_dr3_records(
    source_ids: Iterable[int],
    *,
    user_agent: str,
    batch_size: int = DEFAULT_BATCH_SIZE,
) -> dict[int, GaiaRecord]:
    """Look up Gaia DR3 records for the given source IDs.

    Returns a dict keyed by source_id. IDs absent from the result either had
    no record in Gaia (rare, but possible for cross-references that haven't
    been validated against DR3) or were filtered out by the query. Callers
    should detect missing keys and decide how to handle them — typically log
    and leave the host_stars_gaia row absent for that host.

    Args:
        source_ids: iterable of bare integer Gaia DR3 source IDs
        user_agent: identification string per Gaia's polite-pool norms
        batch_size: how many IDs per TAP request (default 100)
    """
    ids = list(source_ids)
    out: dict[int, GaiaRecord] = {}
    for i in range(0, len(ids), batch_size):
        batch = ids[i : i + batch_size]
        for d in _fetch_batch(batch, user_agent=user_agent):
            rec = _record_from_dict(d)
            out[rec.source_id] = rec
    return out
