"""FastAPI app for exoplanet_citation.

All endpoints under /api/. Read-only over the Postgres warehouse.
Deploys as Python serverless functions on Vercel; runnable locally with
`make api` (uvicorn on port 8000).

Endpoints:
  GET /api/health                                 — pipeline health + freshness
  GET /api/stats                                  — top-level counts + breakdowns
  GET /api/discoveries/latest?days=30             — recent surfaced changes
  GET /api/discoveries/by-month/{yyyy-mm}         — historical month
  GET /api/planets?limit=50&offset=0&q=...        — paginated list
  GET /api/planets/{pl_name}                      — single planet detail
  GET /api/planets/{pl_name}/history              — all change events for a planet
  GET /api/planets/{pl_name}/host_star            — Gaia DR3 record for the host star

OpenAPI / interactive docs:
  /docs      — Swagger UI
  /redoc     — ReDoc
  /openapi.json
"""

from __future__ import annotations

import os
import re
from datetime import UTC, datetime, timedelta
from urllib.parse import unquote

import psycopg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Path, Query
from fastapi.middleware.cors import CORSMiddleware
from psycopg.rows import dict_row

from api.models import (
    AuthorPlanet,
    AuthorResponse,
    TopAuthor,
    TopAuthorsResponse,
    ChangeRecord,
    DiscoveriesResponse,
    DiscoveryPaper,
    FreshnessInfo,
    HealthResponse,
    HostStarGaia,
    PlanetDetail,
    PlanetHistoryResponse,
    PlanetsListResponse,
    PlanetSummary,
    StatsResponse,
)

load_dotenv()

SLO_FRESHNESS_HOURS = 26

app = FastAPI(
    title="exoplanet_citation",
    description=(
        "Public read-only API over the exoplanet_citation data warehouse. "
        "Daily-refreshed catalog of confirmed exoplanets from the NASA Exoplanet "
        "Archive, with field-tier-classified change events. Phase 2 will add "
        "the citation graph and Gaia DR3 host-star enrichment."
    ),
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


def _connect() -> psycopg.Connection:
    return psycopg.connect(os.environ["DATABASE_URL"], connect_timeout=10)


def _to_change_record(row: dict) -> ChangeRecord:
    return ChangeRecord(
        change_id=row["change_id"],
        observed_at=row["observed_at"],
        pl_name=row["pl_name"],
        change_type=row["change_type"],
        field_name=row["field_name"],
        field_tier=row["field_tier"],
        prev_value=row["prev_value"],
        new_value=row["new_value"],
        diff_summary=row["diff_summary"],
        source_snapshot_date=row["source_snapshot_date"],
    )


# ---------- Health ----------

@app.get("/api/health", response_model=HealthResponse, tags=["health"])
def health() -> HealthResponse:
    """Pipeline health and freshness measurement against the SLO."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT source_retrieved_at, snapshot_date FROM planets_snapshots "
                "ORDER BY snapshot_date DESC LIMIT 1"
            )
            snap = cur.fetchone()

            cutoff = datetime.now(UTC) - timedelta(days=30)
            cur.execute(
                "SELECT COUNT(*) AS c FROM discovery_changes "
                "WHERE observed_at >= %s "
                "AND (change_type IN ('NEW', 'REMOVED') OR field_tier = 'A')",
                (cutoff,),
            )
            recent_count = cur.fetchone()["c"]

    freshness: FreshnessInfo | None = None
    if snap:
        retrieved = snap["source_retrieved_at"]
        if retrieved.tzinfo is None:
            retrieved = retrieved.replace(tzinfo=UTC)
        age = round((datetime.now(UTC) - retrieved).total_seconds() / 3600, 2)
        freshness = FreshnessInfo(
            snapshot_date=snap["snapshot_date"],
            source_retrieved_at=retrieved,
            freshness_hours=age,
            slo_freshness_hours=SLO_FRESHNESS_HOURS,
            status="ok" if age <= SLO_FRESHNESS_HOURS else "stale",
            clock="A (time since last extract)",
            note="Clock A approximation. Phase-1.x work upgrades to Clock B (upstream last_modified).",
        )

    return HealthResponse(
        status=(freshness.status if freshness else "no_data"),
        checked_at=datetime.now(UTC),
        freshness=freshness,
        recent_change_count=recent_count,
    )


# ---------- Stats ----------

@app.get("/api/stats", response_model=StatsResponse, tags=["stats"])
def stats() -> StatsResponse:
    """Top-level counts and aggregations: snapshot range, totals, breakdowns
    by year and discovery method (uses the most recent snapshot)."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM planets_current) AS total_planets,
                    (SELECT COUNT(DISTINCT snapshot_date) FROM planets_snapshots) AS total_snapshots,
                    (SELECT COUNT(*) FROM discovery_changes) AS total_change_events,
                    (SELECT MIN(snapshot_date) FROM planets_snapshots) AS earliest,
                    (SELECT MAX(snapshot_date) FROM planets_snapshots) AS latest
                """
            )
            head = cur.fetchone()

            cur.execute(
                "SELECT disc_year, COUNT(*) AS c FROM planets_current "
                "WHERE disc_year IS NOT NULL GROUP BY disc_year ORDER BY disc_year"
            )
            by_year = {row["disc_year"]: row["c"] for row in cur.fetchall()}

            cur.execute(
                "SELECT discoverymethod, COUNT(*) AS c FROM planets_current "
                "WHERE discoverymethod IS NOT NULL GROUP BY discoverymethod "
                "ORDER BY c DESC"
            )
            by_method = {row["discoverymethod"]: row["c"] for row in cur.fetchall()}

    return StatsResponse(
        total_planets=head["total_planets"],
        total_snapshots=head["total_snapshots"],
        total_change_events=head["total_change_events"],
        earliest_snapshot=head["earliest"],
        latest_snapshot=head["latest"],
        discoveries_by_year=by_year,
        discoveries_by_method=by_method,
    )


# ---------- Discoveries (change events) ----------

@app.get("/api/discoveries/latest", response_model=DiscoveriesResponse, tags=["discoveries"])
def discoveries_latest(
    days: int = Query(30, ge=1, le=365, description="Days of history (1–365)"),
    limit: int = Query(500, ge=1, le=1000),
) -> DiscoveriesResponse:
    """Recent surfaced changes: NEW / REMOVED / Tier-A PARAMETER_CHANGE
    from the last `days` days, newest first."""
    cutoff = datetime.now(UTC) - timedelta(days=days)
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT change_id, observed_at, pl_name, change_type, field_name,
                       field_tier, prev_value, new_value, diff_summary, source_snapshot_date
                FROM discovery_changes
                WHERE observed_at >= %s
                  AND (change_type IN ('NEW', 'REMOVED') OR field_tier = 'A')
                ORDER BY observed_at DESC
                LIMIT %s
                """,
                (cutoff, limit),
            )
            rows = cur.fetchall()

    return DiscoveriesResponse(
        generated_at=datetime.now(UTC),
        window_days=days,
        change_count=len(rows),
        changes=[_to_change_record(r) for r in rows],
    )


@app.get(
    "/api/discoveries/by-month/{yyyy_mm}",
    response_model=DiscoveriesResponse,
    tags=["discoveries"],
)
def discoveries_by_month(
    yyyy_mm: str = Path(pattern=r"^\d{4}-\d{2}$", description="Format: YYYY-MM"),
) -> DiscoveriesResponse:
    """All surfaced changes within a calendar month."""
    try:
        year, month = (int(p) for p in yyyy_mm.split("-"))
        if not (1 <= month <= 12):
            raise ValueError("month out of range")
        start = datetime(year, month, 1, tzinfo=UTC)
        end = datetime(year + (month == 12), (month % 12) + 1, 1, tzinfo=UTC)
    except (ValueError, TypeError) as e:
        raise HTTPException(status_code=400, detail=f"Invalid month {yyyy_mm}: {e}") from e

    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT change_id, observed_at, pl_name, change_type, field_name,
                       field_tier, prev_value, new_value, diff_summary, source_snapshot_date
                FROM discovery_changes
                WHERE observed_at >= %s AND observed_at < %s
                  AND (change_type IN ('NEW', 'REMOVED') OR field_tier = 'A')
                ORDER BY observed_at DESC
                """,
                (start, end),
            )
            rows = cur.fetchall()

    return DiscoveriesResponse(
        generated_at=datetime.now(UTC),
        window_days=(end - start).days,
        change_count=len(rows),
        changes=[_to_change_record(r) for r in rows],
    )


# ---------- Planets ----------

_PLANET_SUMMARY_COLS = """
    pl_name, hostname, sy_pnum, discoverymethod, disc_year, disc_facility,
    pl_orbper, pl_orbsmax, pl_orbeccen, pl_rade, pl_bmasse, pl_eqt, sy_dist,
    (raw_row->>'cb_flag')::int AS cb_flag,
    gaia_dr3_id,
    (SELECT citation_count FROM discovery_papers
     WHERE bibcode = replace(substring(disc_refname FROM 'abs/([^/]+)/abstract'), '%%26', '&')
     LIMIT 1) AS disc_paper_citations
"""

_PLANET_DETAIL_COLS = """
    pl_name, hostname, sy_snum, sy_pnum,
    (raw_row->>'cb_flag')::int AS cb_flag,
    discoverymethod, disc_year, disc_facility, disc_telescope, disc_instrument, disc_refname,
    pl_orbper, pl_orbsmax, pl_orbeccen,
    pl_rade, pl_bmasse, pl_dens, pl_eqt, pl_insol,
    st_teff, st_rad, st_mass, st_lum, st_spectype, st_dist,
    sy_dist, ra, dec, gaia_dr3_id,
    snapshot_date, source_url, source_retrieved_at
"""


@app.get("/api/planets", response_model=PlanetsListResponse, tags=["planets"])
def planets_list(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    q: str | None = Query(None, description="Search planet name or host name (ILIKE)"),
    discovery_method: str | None = Query(None, description="Filter by discoverymethod"),
    year: int | None = Query(None, description="Filter by disc_year"),
) -> PlanetsListResponse:
    """Paginated list of planets from the latest snapshot."""
    where = ["snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)"]
    params: list = []
    if q:
        where.append("(pl_name ILIKE %s OR hostname ILIKE %s)")
        like = f"%{q}%"
        params.extend([like, like])
    if discovery_method:
        where.append("discoverymethod = %s")
        params.append(discovery_method)
    if year is not None:
        where.append("disc_year = %s")
        params.append(year)
    where_clause = " AND ".join(where)

    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"SELECT COUNT(*) AS c FROM planets_snapshots WHERE {where_clause}",
                params,
            )
            total = cur.fetchone()["c"]

            cur.execute(
                f"""
                SELECT {_PLANET_SUMMARY_COLS}
                FROM planets_snapshots
                WHERE {where_clause}
                ORDER BY pl_name
                LIMIT %s OFFSET %s
                """,
                [*params, limit, offset],
            )
            rows = cur.fetchall()

    return PlanetsListResponse(
        total=total,
        limit=limit,
        offset=offset,
        results=[PlanetSummary(**r) for r in rows],
    )


# NOTE: this route must be registered BEFORE `/api/planets/{pl_name}` so FastAPI
# matches `/api/planets/recent` to the static path, not as a `pl_name="recent"` lookup.
@app.get("/api/planets/recent", response_model=PlanetsListResponse, tags=["planets"])
def planets_recent(limit: int = Query(100, ge=1, le=500), offset: int = Query(0, ge=0)) -> PlanetsListResponse:
    """Most recently confirmed planets, ordered by discovery year (newest first)."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT COUNT(*) AS c FROM planets_snapshots "
                "WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)"
            )
            total = cur.fetchone()["c"]

            cur.execute(
                f"""
                SELECT {_PLANET_SUMMARY_COLS}
                FROM planets_snapshots
                WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)
                ORDER BY disc_year DESC NULLS LAST, pl_name
                LIMIT %s OFFSET %s
                """,
                (limit, offset),
            )
            rows = cur.fetchall()

    return PlanetsListResponse(
        total=total,
        limit=limit,
        offset=offset,
        results=[PlanetSummary(**r) for r in rows],
    )


@app.get("/api/planets/{pl_name}", response_model=PlanetDetail, tags=["planets"])
def planet_detail(pl_name: str) -> PlanetDetail:
    """Single planet from the latest snapshot, with all 28 typed columns."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT {_PLANET_DETAIL_COLS}
                FROM planets_snapshots
                WHERE pl_name = %s
                ORDER BY snapshot_date DESC
                LIMIT 1
                """,
                (pl_name,),
            )
            row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail=f"No planet named {pl_name!r}")
    return PlanetDetail(**row)


@app.get("/api/systems/{hostname}/planets", response_model=PlanetsListResponse, tags=["planets"])
def system_planets(hostname: str) -> PlanetsListResponse:
    """All planets orbiting a given host star (exact-match on hostname)."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT {_PLANET_SUMMARY_COLS}
                FROM planets_snapshots
                WHERE hostname = %s
                  AND snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)
                ORDER BY pl_name
                """,
                (hostname,),
            )
            rows = cur.fetchall()
    return PlanetsListResponse(
        total=len(rows),
        limit=len(rows),
        offset=0,
        results=[PlanetSummary(**r) for r in rows],
    )


@app.get(
    "/api/planets/{pl_name}/history",
    response_model=PlanetHistoryResponse,
    tags=["planets"],
)
def planet_history(pl_name: str) -> PlanetHistoryResponse:
    """Every change event for this planet, newest first."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            # Validate the planet exists at all (in any snapshot)
            cur.execute(
                "SELECT 1 FROM planets_snapshots WHERE pl_name = %s LIMIT 1",
                (pl_name,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail=f"No planet named {pl_name!r}")

            cur.execute(
                """
                SELECT change_id, observed_at, pl_name, change_type, field_name,
                       field_tier, prev_value, new_value, diff_summary, source_snapshot_date
                FROM discovery_changes
                WHERE pl_name = %s
                ORDER BY observed_at DESC
                """,
                (pl_name,),
            )
            rows = cur.fetchall()

    return PlanetHistoryResponse(
        pl_name=pl_name,
        change_count=len(rows),
        changes=[_to_change_record(r) for r in rows],
    )


@app.get(
    "/api/planets/{pl_name}/host_star",
    response_model=HostStarGaia,
    tags=["planets"],
)
def planet_host_star(pl_name: str) -> HostStarGaia:
    """Gaia DR3 record for the host star of the given planet."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT h.gaia_dr3_id, h.hostname,
                       h.parallax_mas, h.parallax_error,
                       h.pmra_mas_yr, h.pmdec_mas_yr, h.radial_velocity_km_s,
                       h.phot_g_mean_mag, h.phot_bp_mean_mag, h.phot_rp_mean_mag, h.bp_rp,
                       h.teff_gspphot, h.logg_gspphot, h.mh_gspphot, h.distance_gspphot_pc,
                       h.retrieved_at
                FROM planets_current p
                JOIN host_stars_gaia h ON h.hostname = p.hostname
                WHERE p.pl_name = %s
                LIMIT 1
                """,
                (pl_name,),
            )
            row = cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail=f"No Gaia host-star record for planet {pl_name!r}",
        )
    return HostStarGaia(**row)


_BIBCODE_SQL = "replace(substring(disc_refname FROM 'abs/([^/]+)/abstract'), '%%26', '&')"


@app.get("/api/authors/search", response_model=TopAuthorsResponse, tags=["authors"])
def authors_search(
    q: str = Query(..., min_length=2, description="Partial author name (ILIKE)"),
    limit: int = Query(20, ge=1, le=100),
) -> TopAuthorsResponse:
    """Search author names by partial match, ranked by planet count."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT author_name, COUNT(DISTINCT p.pl_name) AS planet_count
                FROM planets_current p
                JOIN discovery_papers dp
                    ON dp.bibcode = {_BIBCODE_SQL}
                CROSS JOIN jsonb_array_elements_text(dp.authors) AS author_name
                WHERE author_name ILIKE %s
                GROUP BY author_name
                ORDER BY planet_count DESC, author_name
                LIMIT %s
                """,
                (f"%{q}%", limit),
            )
            rows = cur.fetchall()
    return TopAuthorsResponse(
        authors=[TopAuthor(author=r["author_name"], planet_count=r["planet_count"]) for r in rows]
    )


@app.get("/api/authors/top", response_model=TopAuthorsResponse, tags=["authors"])
def authors_top(
    limit: int = Query(20, ge=1, le=100),
) -> TopAuthorsResponse:
    """Most prolific exoplanet discoverers ranked by confirmed-planet count."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT author_name, COUNT(DISTINCT p.pl_name) AS planet_count
                FROM planets_current p
                JOIN discovery_papers dp
                    ON dp.bibcode = {_BIBCODE_SQL}
                CROSS JOIN jsonb_array_elements_text(dp.authors) AS author_name
                GROUP BY author_name
                ORDER BY planet_count DESC, author_name
                LIMIT %s
                """,
                (limit,),
            )
            rows = cur.fetchall()

    return TopAuthorsResponse(
        authors=[TopAuthor(author=r["author_name"], planet_count=r["planet_count"]) for r in rows]
    )


@app.get("/api/authors/{author_name}", response_model=AuthorResponse, tags=["authors"])
def author_detail(author_name: str) -> AuthorResponse:
    """All confirmed-exoplanet discoveries for a given author (exact ADS name match)."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                f"""
                SELECT
                    p.pl_name, p.hostname, p.disc_year, p.discoverymethod,
                    dp.bibcode, dp.title AS paper_title, dp.journal,
                    dp.citation_count, dp.pub_date, dp.doi, dp.arxiv_id
                FROM planets_current p
                JOIN discovery_papers dp
                    ON dp.bibcode = {_BIBCODE_SQL}
                WHERE dp.authors @> jsonb_build_array(%s::text)
                ORDER BY p.disc_year DESC NULLS LAST, p.pl_name
                """,
                (author_name,),
            )
            rows = cur.fetchall()

    if not rows:
        raise HTTPException(
            status_code=404,
            detail=f"No confirmed discoveries found for author {author_name!r}",
        )

    return AuthorResponse(
        author=author_name,
        planet_count=len(rows),
        planets=[AuthorPlanet(**r) for r in rows],
    )


def _extract_bibcode(refname: str | None) -> str | None:
    m = re.search(r"abs/([^/]+)/abstract", refname or "")
    return unquote(m.group(1)) if m else None


@app.get(
    "/api/planets/{pl_name}/paper",
    response_model=DiscoveryPaper,
    tags=["planets"],
)
def planet_paper(pl_name: str) -> DiscoveryPaper:
    """Discovery paper metadata from NASA ADS for the given planet."""
    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT disc_refname FROM planets_current WHERE pl_name = %s LIMIT 1",
                (pl_name,),
            )
            row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail=f"No planet named {pl_name!r}")

    bibcode = _extract_bibcode(row["disc_refname"])
    if not bibcode:
        raise HTTPException(
            status_code=404,
            detail=f"No ADS bibcode found in disc_refname for {pl_name!r}",
        )

    with _connect() as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT bibcode, title, authors, abstract, citation_count,
                       pub_date, journal, doi, arxiv_id
                FROM discovery_papers
                WHERE bibcode = %s
                """,
                (bibcode,),
            )
            paper = cur.fetchone()

    if paper is None:
        raise HTTPException(
            status_code=404,
            detail=f"No cached paper for bibcode {bibcode!r}",
        )

    return DiscoveryPaper(
        bibcode=paper["bibcode"],
        title=paper["title"],
        authors=paper["authors"] or [],
        abstract=paper["abstract"],
        citation_count=paper["citation_count"],
        pub_date=paper["pub_date"],
        journal=paper["journal"],
        doi=paper["doi"],
        arxiv_id=paper["arxiv_id"],
    )


# ---------- Root ----------

@app.get("/", tags=["meta"])
def root() -> dict:
    """Service banner. Points at the OpenAPI docs."""
    return {
        "service": "exoplanet_citation",
        "version": "0.1.0",
        "docs": "/docs",
        "openapi": "/openapi.json",
        "endpoints": [
            "/api/health",
            "/api/stats",
            "/api/discoveries/latest",
            "/api/discoveries/by-month/{yyyy-mm}",
            "/api/planets",
            "/api/planets/{pl_name}",
            "/api/planets/{pl_name}/history",
            "/api/planets/{pl_name}/host_star",
            "/api/planets/{pl_name}/paper",
        ],
    }
