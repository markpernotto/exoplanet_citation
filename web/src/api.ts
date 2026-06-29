// API client for exoplanet_citation. Mirrors api/models.py.

export type FreshnessInfo = {
  snapshot_date: string;
  source_retrieved_at: string;
  freshness_hours: number;
  slo_freshness_hours: number;
  status: string;
  clock: string;
  note: string;
};

export type HealthResponse = {
  status: string;
  checked_at: string;
  freshness: FreshnessInfo | null;
  recent_change_count: number;
};

export type ChangeRecord = {
  change_id: number;
  observed_at: string;
  pl_name: string;
  change_type: 'NEW' | 'REMOVED' | 'PARAMETER_CHANGE';
  field_name: string | null;
  field_tier: 'A' | 'B' | null;
  prev_value: unknown;
  new_value: unknown;
  diff_summary: string | null;
  source_snapshot_date: string;
};

export type DiscoveriesResponse = {
  generated_at: string;
  window_days: number;
  change_count: number;
  changes: ChangeRecord[];
  latest_snapshot: string | null;
};

export type PlanetSummary = {
  pl_name: string;
  hostname: string;
  sy_pnum: number | null;
  sy_snum: number | null;
  cb_flag: number | null;
  gaia_dr3_id: string | null;
  discoverymethod: string | null;
  disc_year: number | null;
  disc_facility: string | null;
  pl_orbper: number | null;
  pl_orbsmax: number | null;
  pl_orbeccen: number | null;
  pl_rade: number | null;
  pl_bmasse: number | null;
  pl_eqt: number | null;
  sy_dist: number | null;
  disc_paper_citations: number | null;
  has_measured_geometry: boolean | null;
};

export type OrbitalGeometryRecord = {
  pl_name: string;
  reference_pl_name: string | null;
  mutual_inclination_deg: number | null;
  inclination_uncertainty_deg: number | null;
  method: string;
  bibcode: string | null;
  note: string | null;
};

export type SystemGeometryRow = {
  hostname: string;
  pl_name: string;
  reference_pl_name: string | null;
  mutual_inclination_deg: number | null;
  inclination_uncertainty_deg: number | null;
  method: string;
  bibcode: string | null;
  note: string | null;
};

export type InnerBinaryRow = {
  hostname: string;
  primary_mass_msun: number | null;
  component_mass_msun: number | null;
  separation_au: number | null;
  orbital_period_d: number | null;
  eccentricity: number | null;
  source_bibcode: string | null;
};

export type AtmosphereRow = {
  pl_name: string;
  molecule: string;
  detection: string;
  instrument: string | null;
  confidence_sigma: number | null;
  bibcode: string | null;
};

export type DerivedMeasurementRow = {
  pl_name: string;
  hostname: string | null;
  quantity: string;
  value: number | null;
  unc_hi: number | null;
  unc_lo: number | null;
  unit: string | null;
  model: string | null;
  bibcode: string | null;
  curator_note: string | null;
  provenance: string; // 'curated' | 'nasa_exoplanet_archive'
};

export type PlanetDetail = {
  pl_name: string;
  hostname: string;
  sy_snum: number | null;
  sy_pnum: number | null;
  cb_flag: number | null;
  discoverymethod: string | null;
  disc_year: number | null;
  disc_facility: string | null;
  disc_telescope: string | null;
  disc_instrument: string | null;
  disc_refname: string | null;
  pl_orbper: number | null;
  pl_orbsmax: number | null;
  pl_orbeccen: number | null;
  pl_orblper: number | null; // argument of periastron, degrees
  pl_rade: number | null;
  pl_bmasse: number | null;
  pl_dens: number | null;
  pl_eqt: number | null;
  pl_insol: number | null;
  st_teff: number | null;
  st_rad: number | null;
  st_mass: number | null;
  st_lum: number | null;
  st_spectype: string | null;
  st_dist: number | null;
  sy_dist: number | null;
  distance_manual_pc: number | null;
  distance_manual_source: string | null;
  ra: number | null;
  dec: number | null;
  gaia_dr3_id: string | null;
  snapshot_date: string;
  source_url: string;
  source_retrieved_at: string;
};

export type PlanetsListResponse = {
  total: number;
  limit: number;
  offset: number;
  results: PlanetSummary[];
};

export type PlanetHistoryResponse = {
  pl_name: string;
  change_count: number;
  changes: ChangeRecord[];
};

export type HostStarGaia = {
  gaia_dr3_id: string;
  hostname: string;
  parallax_mas: number | null;
  parallax_error: number | null;
  pmra_mas_yr: number | null;
  pmdec_mas_yr: number | null;
  radial_velocity_km_s: number | null;
  phot_g_mean_mag: number | null;
  phot_bp_mean_mag: number | null;
  phot_rp_mean_mag: number | null;
  bp_rp: number | null;
  teff_gspphot: number | null;
  logg_gspphot: number | null;
  mh_gspphot: number | null;
  distance_gspphot_pc: number | null;
  retrieved_at: string;
};

export type TopAuthor = {
  author: string;
  planet_count: number;
};

export type TopAuthorsResponse = {
  authors: TopAuthor[];
};

export type AuthorPlanet = {
  pl_name: string;
  hostname: string;
  disc_year: number | null;
  discoverymethod: string | null;
  bibcode: string;
  paper_title: string | null;
  journal: string | null;
  citation_count: number | null;
  pub_date: string | null;
  doi: string | null;
  arxiv_id: string | null;
};

export type AuthorResponse = {
  author: string;
  planet_count: number;
  planets: AuthorPlanet[];
};

export type DiscoveryPaper = {
  bibcode: string;
  title: string | null;
  authors: string[];
  abstract: string | null;
  citation_count: number | null;
  pub_date: string | null;
  journal: string | null;
  doi: string | null;
  arxiv_id: string | null;
};

export type Publication = {
  pub_id: number;
  bibcode: string | null;
  doi: string | null;
  arxiv_id: string | null;
  title: string | null;
  authors: string[];
  abstract: string | null;
  journal: string | null;
  pub_date: string | null;
  citation_count: number | null;
  resolved_via: 'ads_bibcode' | 'crossref_doi' | 'ads_title' | 'manual';
  confidence: 'high' | 'medium' | 'low';
};

export type PlanetPublication = Publication & {
  role: 'discovery' | 'follow_up' | 'prior_detection' | 'characterization';
  contribution: string | null;
  co_planets: string[];
};

export type PlanetPublicationsResponse = {
  pl_name: string;
  publications: PlanetPublication[];
};

export type SySnumAudit = {
  hostname: string;
  /** sy_snum value as reported by NASA Exoplanet Archive. */
  nasa_ea_sy_snum: number;
  /** Stellar-component count actually supported by primary literature. */
  supported_sy_snum: number;
  /** Prose explanation surfaced in the UI as a small footnote. */
  rationale: string;
  /** ADS bibcodes backing the override, rendered as clickable links. */
  source_bibcodes: string[];
};

export type BinaryCompanion = {
  component_designation: string;
  primary_designation: string;
  separation_arcsec: number | null;
  /** Projected separation in AU. Surfaced so the 3D scene can place
      companions whose discovery paper reports projected AU but no
      arcsec (e.g. PH1's outer Ba+Bb pair at ~1000 AU). The 3D scene
      falls back to this when separation_arcsec is null. */
  separation_au: number | null;
  position_angle_deg: number | null;
  component_mag_v: number | null;
  component_spectype: string | null;
  source_catalog: string;
  /** ADS bibcode of the paper this row's measurements were taken from.
      Surfaced as a clickable ADS link in the planet card so every
      companion carries visible attribution. NULL for legacy SIMBAD
      bulk-ingest rows predating the curation campaign. */
  source_bibcode: string | null;
  /** True when this row is a tight inner-binary partner (already rendered
      as one of the two suns of BinaryPhotospheres at the host position).
      The HUD suppresses arrows for these — they aren't a separate body
      to navigate to. */
  inner_binary?: boolean | null;
};

export type AtmosphericObservation = {
  spec_type: string | null;
  instrument: string | null;
  facility: string | null;
  min_wavelength_um: number | null;
  max_wavelength_um: number | null;
  bibcode: string | null;
};

export type AtmosphericMolecule = {
  molecule: string;
  detection: 'detected' | 'tentative' | 'upper_limit' | string;
  instrument: string | null;
  confidence_sigma: number | null;
  /** ADS bibcode of the paper this detection was harvested from. Surfaced
      as a clickable ADS link in the planet card so every molecule detection
      carries visible attribution. */
  bibcode: string | null;
};

export type PlanetAtmosphereResponse = {
  observations: AtmosphericObservation[];
  detections: AtmosphericMolecule[];
};

export type SceneHints = {
  sun_color_hex: string;
  sun_angular_size_deg: number | null;
  day_length_hours: number | null;
  insolation_relative_earth: number | null;
  insolation_label: string | null;
  body_type: 'rocky' | 'icy' | 'gas_giant' | 'uncertain' | string;
  death_seconds: number | null;
};

export type SceneResponse = {
  planet: PlanetDetail;
  host_star: HostStarGaia | null;
  siblings: PlanetDetail[];
  binary_companions: BinaryCompanion[];
  atmospheric_observations: AtmosphericObservation[];
  atmospheric_detections: AtmosphericMolecule[];
  orbital_geometry: OrbitalGeometryRecord[];
  derived_measurements: DerivedMeasurementRow[];
  scene_hints: SceneHints;
};

export type StatsResponse = {
  total_planets: number;
  total_snapshots: number;
  total_change_events: number;
  earliest_snapshot: string | null;
  latest_snapshot: string | null;
  discoveries_by_year: Record<string, number>;
  discoveries_by_method: Record<string, number>;
};

// Same-origin in production (Vercel rewrites /api/* to the FastAPI handler);
// proxied to localhost:8000 by Vite during `npm run dev`.
const API_BASE = '';

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}: ${path}`);
  }
  return res.json() as Promise<T>;
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}: ${path}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  health: () => get<HealthResponse>('/api/health'),
  stats: () => get<StatsResponse>('/api/stats'),
  submitFeedback: (input: { message: string; email?: string; page_url?: string; company?: string; elapsed_ms?: number }) =>
    post<{ ok: boolean }>('/api/feedback', input),
  discoveriesLatest: (days = 30) =>
    get<DiscoveriesResponse>(`/api/discoveries/latest?days=${days}`),

  systemGeometry: () => get<{ rows: SystemGeometryRow[] }>('/api/system-geometry'),

  innerBinaries: () => get<{ rows: InnerBinaryRow[] }>('/api/inner-binaries'),

  atmospheres: () => get<{ rows: AtmosphereRow[] }>('/api/atmospheres'),

  derivedMeasurements: (plName?: string, category?: 'composition') => {
    const qs = new URLSearchParams();
    if (plName) qs.set('pl_name', plName);
    if (category) qs.set('category', category);
    const s = qs.toString();
    return get<{ rows: DerivedMeasurementRow[] }>(`/api/derived-measurements${s ? `?${s}` : ''}`);
  },
  planetsList: (params: { limit?: number; offset?: number; q?: string; year?: number; discovery_method?: string; cb_flag?: number; has_geometry?: boolean; min_mass?: number; min_eccen?: number; sy_pnum_min?: number; sy_snum_min?: number; multi_paper?: boolean } = {}) => {
    const qs = new URLSearchParams();
    if (params.limit !== undefined) qs.set('limit', String(params.limit));
    if (params.offset !== undefined) qs.set('offset', String(params.offset));
    if (params.q) qs.set('q', params.q);
    if (params.year !== undefined) qs.set('year', String(params.year));
    if (params.discovery_method) qs.set('discovery_method', params.discovery_method);
    if (params.cb_flag !== undefined) qs.set('cb_flag', String(params.cb_flag));
    if (params.has_geometry) qs.set('has_geometry', 'true');
    if (params.min_mass !== undefined) qs.set('min_mass', String(params.min_mass));
    if (params.min_eccen !== undefined) qs.set('min_eccen', String(params.min_eccen));
    if (params.sy_pnum_min !== undefined) qs.set('sy_pnum_min', String(params.sy_pnum_min));
    if (params.sy_snum_min !== undefined) qs.set('sy_snum_min', String(params.sy_snum_min));
    if (params.multi_paper) qs.set('multi_paper', 'true');
    const query = qs.toString();
    return get<PlanetsListResponse>(`/api/planets${query ? '?' + query : ''}`);
  },
  planetsRecent: (limit = 100, offset = 0) =>
    get<PlanetsListResponse>(`/api/planets/recent?limit=${limit}&offset=${offset}`),
  systemPlanets: (hostname: string) =>
    get<PlanetsListResponse>(`/api/systems/${encodeURIComponent(hostname)}/planets`),
  planetDetail: (plName: string) =>
    get<PlanetDetail>(`/api/planets/${encodeURIComponent(plName)}`),
  planetHistory: (plName: string) =>
    get<PlanetHistoryResponse>(`/api/planets/${encodeURIComponent(plName)}/history`),
  planetHostStar: (plName: string) =>
    get<HostStarGaia>(`/api/planets/${encodeURIComponent(plName)}/host_star`),
  planetCompanions: (plName: string) =>
    get<BinaryCompanion[]>(`/api/planets/${encodeURIComponent(plName)}/companions`),
  planetSySnumAudit: (plName: string) =>
    get<SySnumAudit>(`/api/planets/${encodeURIComponent(plName)}/sy_snum_audit`),
  planetAtmosphere: (plName: string) =>
    get<PlanetAtmosphereResponse>(`/api/planets/${encodeURIComponent(plName)}/atmosphere`),
  planetPaper: (plName: string) =>
    get<DiscoveryPaper>(`/api/planets/${encodeURIComponent(plName)}/paper`),
  planetPublications: (plName: string) =>
    get<PlanetPublicationsResponse>(`/api/planets/${encodeURIComponent(plName)}/publications`),
  authorDetail: (authorName: string) =>
    get<AuthorResponse>(`/api/authors/${encodeURIComponent(authorName)}`),
  authorsTop: (limit = 20) =>
    get<TopAuthorsResponse>(`/api/authors/top?limit=${limit}`),
  authorsSearch: (q: string, limit = 20) =>
    get<TopAuthorsResponse>(`/api/authors/search?q=${encodeURIComponent(q)}&limit=${limit}`),
  planetScene: (plName: string) =>
    get<SceneResponse>(`/api/planets/${encodeURIComponent(plName)}/scene`),
};
