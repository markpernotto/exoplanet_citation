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


class StorageInfo(BaseModel):
    bytes_used: int
    bytes_limit: int
    pct_used: float
    status: str  # "ok" | "warning" | "critical"


class FeedbackRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    email: str | None = Field(default=None, max_length=320)
    page_url: str | None = Field(default=None, max_length=2000)
    # Anti-spam: `company` is a honeypot (must stay empty); `elapsed_ms` is how
    # long the form was on screen before submit (bots submit near-instantly).
    company: str | None = Field(default=None, max_length=200)
    elapsed_ms: int | None = None


class FeedbackResponse(BaseModel):
    ok: bool


class HealthResponse(BaseModel):
    status: str
    checked_at: datetime
    freshness: FreshnessInfo | None
    recent_change_count: int
    storage: StorageInfo | None = None


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
    # Date of the most recent pipeline run (MAX snapshot_date). Lets clients show
    # only the latest run's changes and hide when that run produced none, rather
    # than persisting the last non-empty run's changes across quiet runs.
    latest_snapshot: date | None = None


class PlanetSummary(BaseModel):
    pl_name: str
    hostname: str
    sy_pnum: int | None
    sy_snum: int | None
    cb_flag: int | None
    gaia_dr3_id: str | None
    discoverymethod: str | None
    disc_year: int | None
    disc_facility: str | None
    pl_orbper: float | None
    pl_orbsmax: float | None
    pl_orbeccen: float | None
    pl_rade: float | None
    pl_bmasse: float | None
    pl_eqt: float | None
    sy_dist: float | None
    disc_paper_citations: int | None
    has_measured_geometry: bool | None


class PlanetDetail(BaseModel):
    pl_name: str
    hostname: str
    sy_snum: int | None
    sy_pnum: int | None
    cb_flag: int | None
    discoverymethod: str | None
    disc_year: int | None
    disc_facility: str | None
    disc_telescope: str | None
    disc_instrument: str | None
    disc_refname: str | None
    pl_orbper: float | None
    pl_orbsmax: float | None
    pl_orbeccen: float | None
    pl_orblper: float | None  # argument of periastron (deg), from raw_row
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
    # Literature-sourced distance for hosts with neither a Gaia nor a sy_dist
    # value (host_distances_manual). Last-resort fallback; null for everything else.
    distance_manual_pc: float | None = None
    distance_manual_source: str | None = None
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


class HostStarGaia(BaseModel):
    gaia_dr3_id: str
    hostname: str
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
    retrieved_at: datetime


class TopAuthor(BaseModel):
    author: str
    planet_count: int


class TopAuthorsResponse(BaseModel):
    authors: list[TopAuthor]


class AuthorPlanet(BaseModel):
    pl_name: str
    hostname: str
    disc_year: int | None
    discoverymethod: str | None
    bibcode: str
    paper_title: str | None
    journal: str | None
    citation_count: int | None
    pub_date: str | None
    doi: str | None
    arxiv_id: str | None


class AuthorResponse(BaseModel):
    author: str
    planet_count: int
    planets: list[AuthorPlanet]


class DiscoveryPaper(BaseModel):
    bibcode: str
    title: str | None
    authors: list[str]
    abstract: str | None
    citation_count: int | None
    pub_date: str | None
    journal: str | None
    doi: str | None
    arxiv_id: str | None


class StatsResponse(BaseModel):
    total_planets: int
    total_snapshots: int
    total_change_events: int
    earliest_snapshot: date | None
    latest_snapshot: date | None
    discoveries_by_year: dict[int, int]
    discoveries_by_method: dict[str, int]


class Publication(BaseModel):
    pub_id: int
    bibcode: str | None
    doi: str | None
    arxiv_id: str | None
    title: str | None
    authors: list[str]
    abstract: str | None
    journal: str | None
    pub_date: date | None
    citation_count: int | None
    resolved_via: str
    confidence: str


class PlanetPublication(Publication):
    role: str  # 'discovery' | 'follow_up' | 'prior_detection' | 'characterization'
    contribution: str | None = None  # data this paper supplied, e.g. 'binary_masses', 'distance'
    co_planets: list[str]  # other planets linked to this publication


class PlanetPublicationsResponse(BaseModel):
    pl_name: str
    publications: list[PlanetPublication]


class PublicationPlanetsResponse(Publication):
    planets: list[str]  # pl_name list


class BinaryCompanion(BaseModel):
    component_designation: str
    primary_designation: str
    separation_arcsec: float | None
    position_angle_deg: float | None
    component_mag_v: float | None
    component_spectype: str | None
    source_catalog: str
    # ADS bibcode of the paper this row's measurements were taken from.
    # Surfaced in the UI as a clickable ADS link so every companion
    # carries visible attribution. NULL for legacy SIMBAD bulk-ingest
    # rows that predate the curation campaign.
    source_bibcode: str | None = None
    # True when this row represents a tight inner-binary partner (the
    # second star of a close pair the planet orbits), not a wide
    # companion to navigate to. Inner-binary partners are already
    # rendered as the two suns of BinaryPhotospheres at the host's
    # position in the 3D scene, so the HUD should suppress arrows for
    # them.
    inner_binary: bool | None = None


class AtmosphericObservation(BaseModel):
    spec_type: str | None
    instrument: str | None
    facility: str | None
    min_wavelength_um: float | None
    max_wavelength_um: float | None
    bibcode: str | None


class AtmosphericMolecule(BaseModel):
    molecule: str
    detection: str
    instrument: str | None
    confidence_sigma: float | None


class OrbitalGeometryRecord(BaseModel):
    pl_name: str
    reference_pl_name: str | None
    mutual_inclination_deg: float | None
    inclination_uncertainty_deg: float | None
    method: str
    bibcode: str | None
    note: str | None


class SystemGeometryRow(BaseModel):
    hostname: str
    pl_name: str
    reference_pl_name: str | None
    mutual_inclination_deg: float | None
    inclination_uncertainty_deg: float | None
    method: str
    bibcode: str | None
    note: str | None


class SystemGeometryResponse(BaseModel):
    rows: list[SystemGeometryRow]


class InnerBinaryRow(BaseModel):
    hostname: str
    primary_mass_msun: float | None
    component_mass_msun: float | None
    separation_au: float | None
    orbital_period_d: float | None
    eccentricity: float | None
    source_bibcode: str | None


class InnerBinariesResponse(BaseModel):
    rows: list[InnerBinaryRow]


class AtmosphereRow(BaseModel):
    pl_name: str
    molecule: str
    detection: str
    instrument: str | None
    confidence_sigma: float | None
    bibcode: str | None


class AtmospheresResponse(BaseModel):
    rows: list[AtmosphereRow]


class DerivedMeasurementRow(BaseModel):
    pl_name: str
    hostname: str | None
    quantity: str
    value: float | None
    unc_hi: float | None  # +1 sigma
    unc_lo: float | None  # -1 sigma
    unit: str | None
    model: str | None  # modelling assumption / caveat
    bibcode: str | None
    curator_note: str | None
    provenance: str  # 'curated' | 'nasa_exoplanet_archive'


class DerivedMeasurementsResponse(BaseModel):
    rows: list[DerivedMeasurementRow]


class SceneHints(BaseModel):
    sun_color_hex: str
    sun_angular_size_deg: float | None
    day_length_hours: float | None
    insolation_relative_earth: float | None
    insolation_label: str | None
    body_type: str   # 'rocky' | 'icy' | 'gas_giant' | 'uncertain'
    death_seconds: int | None


class SceneResponse(BaseModel):
    planet: PlanetDetail
    host_star: HostStarGaia | None
    siblings: list[PlanetDetail]
    binary_companions: list[BinaryCompanion]
    atmospheric_observations: list[AtmosphericObservation]
    atmospheric_detections: list[AtmosphericMolecule]
    orbital_geometry: list[OrbitalGeometryRecord]
    derived_measurements: list[DerivedMeasurementRow]
    scene_hints: SceneHints
