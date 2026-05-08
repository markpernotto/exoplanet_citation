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
};

export type PlanetSummary = {
  pl_name: string;
  hostname: string;
  sy_pnum: number | null;
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
  role: 'discovery' | 'follow_up';
  co_planets: string[];
};

export type PlanetPublicationsResponse = {
  pl_name: string;
  publications: PlanetPublication[];
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

export const api = {
  health: () => get<HealthResponse>('/api/health'),
  stats: () => get<StatsResponse>('/api/stats'),
  discoveriesLatest: (days = 30) =>
    get<DiscoveriesResponse>(`/api/discoveries/latest?days=${days}`),
  planetsList: (params: { limit?: number; offset?: number; q?: string; year?: number; discovery_method?: string } = {}) => {
    const qs = new URLSearchParams();
    if (params.limit !== undefined) qs.set('limit', String(params.limit));
    if (params.offset !== undefined) qs.set('offset', String(params.offset));
    if (params.q) qs.set('q', params.q);
    if (params.year !== undefined) qs.set('year', String(params.year));
    if (params.discovery_method) qs.set('discovery_method', params.discovery_method);
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
};
