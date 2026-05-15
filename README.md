# exoplanet_citation

[![DOI](https://zenodo.org/badge/1228082575.svg)](https://doi.org/10.5281/zenodo.20191479)


A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via NASA ADS and host-star enrichment via Gaia DR3.

**Live:** [exoplanet-citation.vercel.app](https://exoplanet-citation.vercel.app)
· [API docs (Swagger)](https://exoplanet-citation.vercel.app/docs)
· [Source on GitHub](https://github.com/markpernotto/exoplanet_citation)

**Status:** Phase 1 done. Phase 2 complete. Daily ingest pipeline running
on a GitHub Actions cron; 6,286 confirmed planets loaded into Postgres
with 7+ consecutive nightly runs since 2026-05-04; FastAPI serving 22
endpoints with automatic Swagger docs; React frontend deployed with
procedurally-rendered planet cards, multi-planet "this paper also
announced…" affordance, and a `/feeds` index for personalized RSS
subscriptions; Gaia DR3 host-star enrichment complete for all 4,355
enrichable hosts; **citation graph (`publications` +
`planet_publications`) resolved for 6,279 / 6,286 planets (99.89%)** via
a 4-tier resolver (ADS bibcode → arXiv API → ADS title search → manual
queue), with only 7 genuinely weird edge cases parked in
`citation_manual_queue` for human triage; 78 unit tests + 13 dbt tests
passing.

See [PLAN.md](PLAN.md) for the full implementation roadmap and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## What this is

A data engineering project applied to the largest active discovery effort
in modern astronomy. Three phases:

- **Phase 1** — Nightly diff watcher of the NASA Exoplanet Archive published
  as RSS, JSON, and a browseable UI. Detects newly confirmed planets,
  removed entries, and tier-classified parameter revisions.
- **Phase 2** — Citation graph: each confirmed planet linked to its discovery
  publication(s) via DOI / arXiv / ADS, with confidence scoring and
  human-readable provenance. Plus Gaia DR3 enrichment of host stars for
  precise distances, photometry, and procedural visualization data.
- **Phase 3** *(post-v1.0)* — Follow-up paper graph: query NASA ADS for
  papers that cite each discovery and mention the planet name, surfacing
  the discovery → follow-up edges in the UI.

The distinguishing technical bet is **provenance everywhere**: every row in
the warehouse carries source URL, retrieval timestamp, sha256 checksum, and
extraction version; every citation link will carry confidence + reason;
every visual rendered in the UI is computed from measured properties, not
from a stock-image library.

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

---

## Roadmap

### Phase 1 — done

- ETL pipeline: extract → load → dbt staging → diff → publish
- 28-column typed schema with JSONB raw preservation
- Nightly cron on GitHub Actions (06:00 UTC) — 5 consecutive green runs
  since 2026-05-04 (Star Wars Day)
- Field-tier-aware diff (Tier A surfaced, Tier B logged-only, Tier C ignored)
- Auto-prune of `planets_snapshots` to a rolling 2-day window so Neon
  storage stays steady at ~230 MB
- Cloudflare R2 raw landing with manifest in git (full historical record)
- React frontend: search (planet + author), infinite-scroll catalog,
  planet detail with procedural rendering, system orbital view (true AU
  scale, scroll-to-zoom), retro display themes
- Six retro display themes switchable via `?theme=` URL param; self-hosted
  OFL fonts; no CDN dependency; shareable links
- Vercel deployment for both API and frontend
- Documentation: data catalog, procedural rendering plan, architecture, theming
- CI with ruff lint

### Phase 2 — substantially complete

- ✅ **Gaia DR3 host-star enrichment** — `host_stars_gaia` populated for
  all 4,355 enrichable hosts (parallax, BP-RP color, Gaia-derived stellar
  parameters)
- ✅ **ADS discovery-paper enrichment** — `discovery_papers` populated for
  ~1,250 unique bibcodes (title, authors, abstract, citation count, DOI,
  arXiv ID)
- ✅ **Citation graph schema** — `publications` + `planet_publications` +
  `citation_manual_queue` with provenance (resolved_via, confidence)
- ✅ **4-tier resolver** — `etl/resolve_citations.py` (ADS bibcode → arXiv
  API → ADS title → manual queue) with quota-aware circuit breaker,
  resumable via `backfill_state`. The arXiv tier closes the long tail
  of arXiv-only preprints that ADS's bibcode lookup doesn't index.
  (A Crossref-by-DOI tier briefly existed during initial backfill while
  ADS daily quota was the bottleneck; retired once ADS Tier 1 alone
  hit 98.9%.)
- ✅ **API endpoints for the citation graph** — planet/publications,
  publication detail, author publications
- ✅ **Frontend multi-planet UI** — discovery section on PlanetDetail
  surfaces sibling planets announced in the same paper
- ✅ **`/api/health` storage monitoring** — Neon DB size + warning/critical
  thresholds at 80% / 95% of the 500 MB free-tier ceiling
- ✅ **78 unit tests + 13 dbt tests; resumable backfills via `backfill_state`**
- ✅ **arXiv resolver tier** — `etl/sources/arxiv.py` + Tier 2 in the
  resolver. Mops up arXiv-only preprints (60 planets cleared on first
  run). Polite-pool 3-second inter-call window enforced; user-agent
  carries project + contact email per arXiv ToS.
- 🔜 **Manual-queue triage UI** for the remaining 7 queued planets
  (3 non-arXiv bibcodes ADS rejects + 4 with non-ADS reference URLs)
- 🔜 **dbt marts** (`dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`) — deferred; the API doesn't need them yet.

### Phase 3 — post-v1.0

- Follow-up paper graph via NASA ADS citation queries
- Galactic positioning view ("Here we are / Here this planet is")
- Optional: PHL Habitable Exoplanets Catalog integration for
  Earth-Similarity Index tagging
- Manual-queue triage UI for the ~50 planets that fall through all four
  resolver tiers

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
