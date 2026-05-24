# exoplanet_citation

[![DOI](https://zenodo.org/badge/1228082575.svg)](https://doi.org/10.5281/zenodo.20191479)


A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via NASA ADS and host-star enrichment via Gaia DR3.

**Live:** [exoplanetcitation.space](https://exoplanetcitation.space)
· [API docs (Swagger)](https://exoplanetcitation.space/docs)
· [Source on GitHub](https://github.com/markpernotto/exoplanet_citation)

**Status:** Live and maintained. Daily ingest pipeline running on
a GitHub Actions cron; 6,287 confirmed planets loaded into Postgres with
nightly runs since 2026-05-04; FastAPI serving 22 endpoints with
automatic Swagger docs; React + Three.js + WebXR frontend deployed at
[exoplanetcitation.space](https://exoplanetcitation.space) with
procedurally-rendered planet cards, an interactive 3D scene viewer with
per-vantage starfield reprojection (4K through 16K rendering knob;
default 6K), the multi-planet "this paper also announced…" affordance,
an imperial/metric units toggle, shareable URLs that round-trip camera
state, and a `/feeds` index for personalized RSS subscriptions; Gaia DR3
host-star enrichment complete for all 4,358 enrichable hosts; **citation
graph (`publications` + `planet_publications`) resolved for 6,287 /
6,287 planets (100%)** via a 4-tier automated resolver (ADS bibcode →
arXiv API → ADS title search → manual queue) plus a 7-row hand-resolved
final pass for edge-case journal references; 78 unit tests + 13 dbt
tests passing.

See [PLAN.md](PLAN.md) for the full implementation roadmap and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## What this is

A data engineering project applied to the largest active discovery effort
in modern astronomy. It does three things:

- **Watches** the NASA Exoplanet Archive nightly and publishes the diff as
  RSS, JSON, and a browseable UI: newly confirmed planets, removed entries,
  and tier-classified parameter revisions.
- **Links** each confirmed planet to the publications behind it via DOI /
  arXiv / ADS, with confidence scoring and human-readable provenance, plus
  Gaia DR3 enrichment of host stars for precise distances, photometry, and
  procedural visualization data.
- **Audits and enriches** what the archive ships: a per-system review of the
  circumbinary (`cb_flag`) population against the discovery literature,
  inner-binary parameters harvested from those papers, and a multi-role
  citation graph (discovery / follow-up / prior-detection / characterization)
  that credits every added data point to the paper it came from.

The project has shifted over time from mirroring the NASA Exoplanet Archive to
auditing and adding value to it. The distinguishing technical bet is
**provenance everywhere**: every row in the warehouse carries source URL,
retrieval timestamp, sha256 checksum, and extraction version; every citation
link carries a role, confidence, and reason; every visual rendered in the UI is
computed from measured properties, not from a stock-image library.

---

## What works today

- **Nightly extract** pulls `pscomppars` from the NASA Exoplanet Archive
  (TAP) → uploads CSV to Cloudflare R2 → appends sha256 manifest entry
- **Loader** UPSERTs into Postgres (Neon) with 28 typed columns plus
  the full raw row preserved as JSONB
- **dbt project** transforms raw → staging (`stg_pscomppars` view) with
  13 data tests passing
- **Diff job** emits `NEW` / `REMOVED` / Tier-A / Tier-B `PARAMETER_CHANGE`
  events to `discovery_changes`, idempotent across re-runs. Auto-prunes
  `planets_snapshots` to a rolling 2-day window after the diff commits,
  keeping Neon storage steady.
- **Gaia DR3 enrichment** — `etl/enrich_gaia.py` populates `host_stars_gaia`
  for every host with a parsable `gaia_dr3_id` (parallax, BP-RP color,
  Gaia-derived stellar parameters). Resumable via `backfill_state`.
- **ADS discovery-paper enrichment** — `etl/enrich_ads.py` caches paper
  metadata (title, authors, abstract, citation count, DOI, arXiv ID) in
  `discovery_papers`. Quota-aware; falls back gracefully when ADS rate
  limits are hit.
- **Citation graph resolver** — `etl/resolve_citations.py` runs a 4-tier
  strategy per planet: ADS bibcode from `disc_refname` → arXiv API for
  arXiv-form bibcodes ADS doesn't index → ADS title search → manual
  queue. Writes to `publications` + `planet_publications` with
  provenance (`resolved_via`, `confidence`). Resumable via
  `backfill_state`. Trips a circuit breaker on
  `X-RateLimit-Remaining: 0` and stops calling ADS until quota resets;
  arXiv tier respects the polite-pool 3-second inter-call window.
- **Circumbinary (cb_flag) audit + binary enrichment** — all 54 `cb_flag=1`
  planets across 44 host systems are reviewed against their discovery (and
  follow-up) literature in
  [`docs/cb_flag_audit.md`](docs/cb_flag_audit.md), the public per-host data
  record. Inner-binary parameters (component masses, radii, period,
  eccentricity) harvested from those papers are seeded into `binary_companions`
  via `etl/seed_inner_binaries.py`, where an `inner_binary` flag distinguishes
  the tight P-type-defining pair from the wide visual companions SIMBAD
  resolves. Because the audit draws data from papers beyond the original
  discovery, those papers are linked back into the citation graph with explicit
  roles (`prior_detection`, `characterization`) and a `contribution` tag for
  what each supplied (e.g. `binary_masses`, `distance`), so every enriched value
  is traceable to its source. Literature distances for hosts that both Gaia and
  the archive miss live in `host_distances_manual`. An analysis of the aggregate
  audit results is in preparation as a short Research Note.
- **Curated atmospheric and orbital-geometry data:** landmark literature results
  hand-harvested into `planet_atmospheres` (molecule detections with instrument,
  significance, and source paper) and `system_orbital_geometry` (measured mutual
  inclinations), each credited via a `characterization` citation. Includes the
  first detected exoplanet atmosphere (HD 209458 b) and JWST-era detections
  (WASP-39 b CO2/SO2, K2-18 b CH4/CO2). Non-detections are recorded too: the JWST
  TRAPPIST-1 campaign's bare-rock and ruled-out-atmosphere results (planets b
  through e) are curated as `ruled_out` / `inconclusive`, so the catalog states
  what has been excluded, not only what was found. This data feeds the 3D scene.
- **Publisher** generates RSS 2.0, JSON, and health-snapshot feeds with
  freshness measurement against a 26-hour SLO. Per-planet, per-system, and
  per-author RSS feeds are also exposed dynamically by the API.
- **GitHub Actions** runs the full pipeline daily at 06:00 UTC (extract →
  load → dbt → diff → Gaia → ADS → resolve_citations → publish), commits
  results back, opens an issue on failure.
- **FastAPI** with 22 endpoints + automatic OpenAPI/Swagger docs, deployed
  to Vercel as Python serverless functions. Citation graph endpoints
  (`/api/planets/{name}/publications`, `/api/publications/{bibcode}`,
  `/api/authors/{name}/publications`) expose the resolved graph.
  `/api/health` reports DB freshness AND Neon storage utilization with
  warning/critical thresholds.
- **React frontend** (Vite + TypeScript) deployed alongside the API on the
  same Vercel project — search bar (planet + author), infinite-scroll
  catalog, planet detail page with procedurally-rendered planet card,
  multi-planet discovery paper affordance ("this paper also announced X,
  Y, Z"), full change history, and six optional retro display themes (P1
  Phosphor, P3 Phosphor, CGA, EGA, HGC, Plasma) activated via `?theme=`
  URL param.
- **Three.js 3D scene** (`/planets/{name}/scene`) with three view modes:
  - **System view** — top-down orbital animation, sun + planets at true AU
    scale (bodies exaggerated for visibility), drag to orbit, scroll to
    zoom.
  - **Surface view** — first-person, standing on the focal planet, riding
    its orbit. Sun arcs across the sky as the planet orbits — particularly
    dramatic for high-eccentricity worlds.
  - **VR view** (WebXR via `@react-three/xr`) — enter immersive VR from
    any planet page on a Quest 3 / Quest 2 / other WebXR headset. Scene
    auto-scales to a comfortable room-scale view; 6-DOF locomotion via
    controller thumbsticks. See [`docs/PROCEDURAL_RENDERING.md`](docs/PROCEDURAL_RENDERING.md)
    for the rendering pipeline and the per-vantage starfield direction.
- **78 unit tests + 13 dbt tests** all green; CI workflow with ruff lint

---

## Quickstart (developers)

```bash
# Python 3.12 required
/opt/homebrew/bin/python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"

# Configure environment
cp .env.example .env
# edit .env with your Neon DATABASE_URL, R2 keys, and DBT_* fields

# Apply schema (in order)
psql "$DATABASE_URL" -f etl/schema.sql
psql "$DATABASE_URL" -f etl/migrations/001_phase1x_typed_columns.sql
psql "$DATABASE_URL" -f etl/migrations/002_phase2_host_stars_gaia.sql
psql "$DATABASE_URL" -f etl/migrations/003_fix_planets_current_view.sql
psql "$DATABASE_URL" -f etl/migrations/004_discovery_papers.sql
psql "$DATABASE_URL" -f etl/migrations/005_citation_graph.sql
psql "$DATABASE_URL" -f etl/migrations/006_add_arxiv_resolved_via.sql
psql "$DATABASE_URL" -f etl/migrations/007_binary_companions.sql
psql "$DATABASE_URL" -f etl/migrations/008_atmospheres.sql
psql "$DATABASE_URL" -f etl/migrations/009_system_orbital_geometry.sql
psql "$DATABASE_URL" -f etl/migrations/010_orbital_geometry_seed.sql
psql "$DATABASE_URL" -f etl/migrations/011_binary_companions_inner.sql
psql "$DATABASE_URL" -f etl/migrations/012_host_distances_manual.sql
psql "$DATABASE_URL" -f etl/migrations/013_planet_publications_prior_detection.sql
psql "$DATABASE_URL" -f etl/migrations/014_planet_publications_characterization.sql
psql "$DATABASE_URL" -f etl/migrations/015_old_cohort_enrichment.sql
psql "$DATABASE_URL" -f etl/migrations/016_landmark_atmospheres.sql
psql "$DATABASE_URL" -f etl/migrations/017_kepler_ttv_geometry_source_fix.sql
psql "$DATABASE_URL" -f etl/migrations/018_geometry_source_fix_round2.sql
psql "$DATABASE_URL" -f etl/migrations/019_kepler90_reconcile_and_source_fix.sql
psql "$DATABASE_URL" -f etl/migrations/020_trappist1_jwst_atmospheres.sql
psql "$DATABASE_URL" -f etl/migrations/021_trappist1_geometry_agol2021.sql
psql "$DATABASE_URL" -f etl/migrations/022_planet_interior_composition.sql
psql "$DATABASE_URL" -f etl/migrations/023_hr8799_atmospheres.sql
psql "$DATABASE_URL" -f etl/migrations/024_planet_derived_measurements.sql
psql "$DATABASE_URL" -f etl/migrations/025_betpic_atmosphere_and_derived.sql
psql "$DATABASE_URL" -f etl/migrations/026_gj876b_astrometric_benedict2002.sql
psql "$DATABASE_URL" -f etl/migrations/027_kepler11_envelopes_lopez2012.sql
psql "$DATABASE_URL" -f etl/migrations/028_wasp121b_atmosphere.sql
psql "$DATABASE_URL" -f etl/migrations/029_gj1214b_atmosphere_and_derived.sql
psql "$DATABASE_URL" -f etl/migrations/030_wasp107b_atmosphere.sql
psql "$DATABASE_URL" -f etl/migrations/031_lhs1140b_waterworld.sql
psql "$DATABASE_URL" -f etl/migrations/032_wasp76b_atmosphere.sql
psql "$DATABASE_URL" -f etl/migrations/033_pds70_forming_planets.sql
psql "$DATABASE_URL" -f etl/migrations/034_wasp12b_inspiral_and_atmosphere.sql
psql "$DATABASE_URL" -f etl/migrations/035_kelt9b_atmosphere.sql
psql "$DATABASE_URL" -f etl/migrations/036_kepler1520b_disintegrating.sql
psql "$DATABASE_URL" -f etl/migrations/037_toi849b_exposed_core.sql
psql "$DATABASE_URL" -f etl/migrations/038_51erib_cold_methane_giant.sql
psql "$DATABASE_URL" -f etl/migrations/039_kepler51_superpuffs.sql
psql "$DATABASE_URL" -f etl/migrations/040_wasp18b_thermal_inversion.sql
psql "$DATABASE_URL" -f etl/migrations/041_hip65426b_first_jwst_imaged.sql

# Verify connectivity
make check-setup

# Run the full pipeline locally
make pipeline

# Or step-by-step:
make extract                            # NASA Exoplanet Archive → R2
make load                               # R2 → Postgres planets_snapshots
make dbt-run                            # raw → staging
make diff                               # consecutive snapshots → discovery_changes (also auto-prunes)
python -m etl.enrich_gaia               # host_stars_gaia (resumable)
python -m etl.enrich_ads                # discovery_papers from NASA ADS
python -m etl.resolve_citations         # publications + planet_publications (4-tier resolver: ADS + arXiv)
python -m etl.clear_manual_queue        # hand-resolves the 7 historical edge cases the resolver can't reach
python -m etl.enrich_binaries           # binary_companions from SIMBAD (wide visual companions)
python -m etl.seed_inner_binaries --execute        # one-off: curated inner-binary backfill from the cb_flag audit (idempotent)
python -m etl.seed_followup_citations --execute     # one-off: link follow-up / prior-detection / characterization papers into the citation graph
python -m etl.enrich_publication_metadata --execute # backfill ADS authors/metadata for the hand-seeded citations
make publish                            # → public/rss.xml, public/discoveries.json, public/health.json

# Run the API locally
make api         # http://localhost:8000/docs

# Run the React frontend locally (in a separate terminal)
make web-install # one-time
make web         # http://localhost:5550 (proxies /api to :8000)

# Other targets
make test        # pytest, 64 tests
make dbt-test    # 13 dbt data tests
make smoke-gaia  # one-shot Gaia DR3 client test
make help        # list all targets
```

---

## Documentation

- **[PLAN.md](PLAN.md)** — implementation roadmap, source of truth for
  what we're building
- **[01-exoplanets.md](01-exoplanets.md)** — portfolio framing
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — system overview,
  data flow, components, hosting, idempotency guarantees
- **[docs/DATA_CATALOG.md](docs/DATA_CATALOG.md)** — pscomppars column
  families decoded, our tier mapping, source provenance, known quirks
- **[docs/PROCEDURAL_RENDERING.md](docs/PROCEDURAL_RENDERING.md)** —
  temperature / density / insolation → visual mapping for the planet UI,
  full rendering-pipeline reference for the 3D scene (photosphere shader,
  bloom, VR fallbacks), and an XR gotcha file
- **[docs/STARFIELD_PLAN.md](docs/STARFIELD_PLAN.md)** — canonical plan
  for the per-vantage sky / Milky Way rendering. Four-layer architecture
  (Gaia reprojection, procedural galactic particles, diffuse galaxy
  fragment shader, extragalactic anchors)
- **[docs/THEMING.md](docs/THEMING.md)** — retro display themes: design
  rationale, technical implementation, theme catalog, self-hosted fonts
- **[docs/cb_flag_audit.md](docs/cb_flag_audit.md)** — per-host circumbinary
  audit: every `cb_flag=1` system reviewed against its discovery literature,
  with harvested inner-binary parameters (public data record; aggregate
  analysis in preparation as a Research Note)

---

## Versioning & releases

Tagged releases are published under
[GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases),
with a human-readable history in [CHANGELOG.md](CHANGELOG.md). The project
follows [Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format, and each tagged release
also mints a version-specific
[Zenodo](https://doi.org/10.5281/zenodo.20191479) DOI for citation.

## What's next (unscheduled)

- Follow-up paper graph via NASA ADS citation queries: discovery to follow-up
  edges surfaced automatically, complementing the hand-curated roles now in the
  citation graph.
- A literature monitor that flags new per-system data for human verification
  before any write (detect, queue, verify; never auto-write).
- Gaia DR4 ingestion scaffolding; several circumbinary papers cite DR4
  astrometry as the path to refined masses and architectures.
- Galactic positioning view ("here we are / here this planet is").
- dbt marts (`dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`) once the API needs them.
- Optional PHL Habitable Exoplanets Catalog integration for Earth-Similarity
  tagging.

---

## Tech stack

| Layer | Tool | Why |
|---|---|---|
| Language (backend) | Python 3.12 | Primary across the pipeline |
| Language (frontend) | TypeScript + React 18 | Mature, well-typed |
| Warehouse | Postgres 16 (Neon free tier) | dbt-friendly, free tier sufficient |
| Object storage | Cloudflare R2 | S3-compatible, zero egress fees |
| Transform | dbt-postgres 1.11 | Industry-standard SQL transform layer |
| Orchestration | GitHub Actions cron | Daily batch is fine; no need for Airflow at this scale |
| API | FastAPI | Lightweight, typed, automatic OpenAPI docs |
| Frontend | Vite + React + TypeScript | Modern, fast, good DX |
| Hosting | Vercel | Serves both Python serverless API and static React build |
| HTTP | httpx + tenacity | Async-capable + built-in retry |
| Testing | pytest + dbt tests | Progressive rigor |

Deliberately not used: Kubernetes, Spark, Kafka, paid cloud warehouses.
Those are solutions to problems this data volume doesn't have.

Total monthly hosting cost: $0.

---

## Licenses

- **Code:** [MIT](LICENSE)
- **Data products:** [CC BY 4.0](LICENSE-DATA)
- Upstream attribution required per the
  [NASA Exoplanet Archive use policy](https://exoplanetarchive.ipac.caltech.edu/docs/acknowledge.html)

---

## Contact

Mark Pernotto — mark@pernotto.com

---

Built as part of [Facet Build, LLC](https://facetbuild.llc).
