"""Pydantic response models for the FastAPI endpoints.

Defining these explicitly (rather than returning raw dicts) gives us
automatic OpenAPI schema generation visible at /docs, plus stable
field types for downstream consumers.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field


class FreshnessInfo(BaseModel):
    snapshot_date: date
    source_retrieved_at: datetime
    freshness_hours: float
    slo_freshness_hours: int
    status: str
    clock: str
    note: str


class HealthResponse(BaseModel):
    status: str
    checked_at: datetime
    freshness: FreshnessInfo | None
    recent_change_count: int


class ChangeRecord(BaseModel):
    change_id: int
    observed_at: datetime
    pl_name: str
    change_type: str
    field_name: str | None
    field_tier: str | None
    prev_value: Any | None
    new_value: Any | None
    diff_summary: str | None
    source_snapshot_date: date


class DiscoveriesResponse(BaseModel):
    generated_at: datetime
    window_days: int = Field(description="How many days of history are included")
    change_count: int
    changes: list[ChangeRecord]


class PlanetSummary(BaseModel):
    pl_name: str
    hostname: str
    discoverymethod: str | None
    disc_year: int | None
    disc_facility: str | None
    pl_orbper: float | None
    pl_rade: float | None
    pl_bmasse: float | None
    pl_eqt: float | None
    sy_dist: float | None


class PlanetDetail(BaseModel):
    pl_name: str
    hostname: str
    sy_snum: int | None
    sy_pnum: int | None
    discoverymethod: str | None
    disc_year: int | None
    disc_facility: str | None
    disc_telescope: str | None
    disc_instrument: str | None
    disc_refname: str | None
    pl_orbper: float | None
    pl_orbsmax: float | None
    pl_orbeccen: float | None
    pl_rade: float | None
    pl_bmasse: float | None
    pl_dens: float | None
    pl_eqt: float | None
    pl_insol: float | None
    st_teff: float | None
    st_rad: float | None
    st_mass: float | None
    st_lum: float | None
    st_spectype: str | None
    st_dist: float | None
    sy_dist: float | None
    ra: float | None
    dec: float | None
    gaia_dr3_id: str | None
    snapshot_date: date
    source_url: str
    source_retrieved_at: datetime


class PlanetsListResponse(BaseModel):
    total: int
    limit: int
    offset: int
    results: list[PlanetSummary]


class PlanetHistoryResponse(BaseModel):
    pl_name: str
    change_count: int
    changes: list[ChangeRecord]


class StatsResponse(BaseModel):
    total_planets: int
    total_snapshots: int
    total_change_events: int
    earliest_snapshot: date | None
    latest_snapshot: date | None
    discoveries_by_year: dict[int, int]
    discoveries_by_method: dict[str, int]
