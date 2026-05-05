# exoplanet_citation

A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via Crossref, arXiv, and NASA ADS, and host-star enrichment via
Gaia DR3.

**Status:** Phase 1 in progress (Day 7 of 14 complete) — daily ingest
pipeline running on a GitHub Actions cron; ~6,300 confirmed planets loaded
into Postgres; 64 unit tests passing. The library-science differentiator
(citation graph) ships in Phase 2.

See [PLAN.md](PLAN.md) for the full implementation roadmap and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## What this is

A data engineering project applied to the largest active discovery effort in
modern astronomy. Three phases:

- **Phase 1** — Nightly diff watcher of the NASA Exoplanet Archive published
  as RSS, JSON, and a minimal browseable UI. Detects newly confirmed planets,
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
extraction version; every citation link carries confidence + reason; every
visual rendered in the UI is computed from measured properties, not from a
stock-image library.

---

## What works today

- **Nightly extract** pulls `pscomppars` from NASA Exoplanet Archive (TAP) →
  uploads CSV to Cloudflare R2 → appends sha256 manifest entry
- **Loader** UPSERTs into Postgres (Neon) with **28 typed columns** plus
  full raw row preserved as JSONB for downstream use
- **dbt project** transforms raw → staging (`stg_pscomppars` view) with
  13 data tests passing
- **Diff job** emits `NEW` / `REMOVED` / Tier-A / Tier-B `PARAMETER_CHANGE`
  events to `discovery_changes`, idempotent across re-runs via a unique index
- **Publisher** generates RSS 2.0, JSON, and health-snapshot feeds with
  freshness measurement against a 26-hour SLO
- **GitHub Actions** runs the full extract → load → dbt → diff → publish
  pipeline daily at 06:00 UTC, commits results back, opens an issue on failure
- **Phase 2 scaffold:** Gaia DR3 client tested end-to-end against real
  Kepler-22 data (returned BP-RP color, parallax, Gaia-derived Teff,
  metallicity — ready for Phase 2 enrichment)
- **64 unit tests** covering field-tier classification, NEW/REMOVED/CHANGE
  detection, NULL transitions, float-tolerance edges, idempotency, and
  Gaia source-ID parsing

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

# Apply schema (and the Phase-1.x migration)
psql "$DATABASE_URL" -f etl/schema.sql
psql "$DATABASE_URL" -f etl/migrations/001_phase1x_typed_columns.sql

# Verify connectivity
make check-setup

# Run the full pipeline locally
make pipeline

# Or step-by-step:
make extract     # NASA Exoplanet Archive → R2
make load        # R2 → Postgres planets_snapshots
make dbt-run     # raw → staging
make diff        # consecutive snapshots → discovery_changes
make publish     # → public/rss.xml, public/discoveries.json, public/health.json

# Other useful targets
make test        # pytest, 64 tests
make dbt-test    # 13 dbt data tests
make smoke-gaia  # one-shot Gaia DR3 client test against a real host
make help        # list all targets
```

---

## Documentation

- **[PLAN.md](PLAN.md)** — implementation roadmap, source of truth for
  what we're building
- **[01-exoplanets.md](01-exoplanets.md)** — portfolio framing (the "why
  this project")
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — system overview,
  data flow, components, hosting, idempotency guarantees
- **[docs/DATA_CATALOG.md](docs/DATA_CATALOG.md)** — pscomppars column
  families decoded, our tier mapping, source provenance, known quirks
- **[docs/PROCEDURAL_RENDERING.md](docs/PROCEDURAL_RENDERING.md)** —
  temperature / density / insolation → visual mapping for the planet UI

---

## Roadmap

### Done — Days 1–7 of Phase 1

- ETL pipeline: extract → load → dbt staging → diff → publish
- 28-column typed schema with JSONB raw preservation
- Nightly cron on GitHub Actions (06:00 UTC)
- Field-tier-aware diff (Tier A surfaced, Tier B logged-only, Tier C ignored)
- Cloudflare R2 raw landing with manifest in git
- Phase 2 scaffold: Gaia DR3 client + smoke test verified end-to-end
- Documentation: data catalog, procedural rendering plan, architecture doc
- 64 unit tests + 13 dbt tests, all green; CI workflow with ruff lint

### This week — Days 8–14 (Phase 1 ship)

- Verify first real nightly diff with two consecutive snapshots
  (Day 4 E2E confirmation)
- **FastAPI** (Day 8): `/api/discoveries/latest`,
  `/api/discoveries/by-month/{yyyy-mm}`, `/api/planets`,
  `/api/planets/{name}/history`, `/api/health`
- **Vercel deployment** of the API as Python serverless functions
- **React minimal frontend** (Day 9): discoveries feed (last 30 days,
  filterable by method + year), per-planet history page
- README v1 polish + LICENSE / LICENSE-DATA finalization (Day 10)
- **5 consecutive green nights** required before Phase 1 is declared shipped

### Next — Phase 2 (Weeks 3–4)

- **Citation resolution** via Crossref + arXiv + NASA ADS (4-tier strategy:
  direct DOI → ADS bibcode → Crossref title/author/year → manual queue)
- **dbt marts**: `dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`
- **Gaia DR3 host-star enrichment**: ~6,300 hosts queried by source ID,
  results in `host_stars_gaia` (parallax, BP-RP color, Gaia-derived
  stellar parameters)
- **Procedural rendering** in the React UI — planets and stars drawn from
  measured properties, not artist renderings
- **API endpoints** for the citation graph: `/api/planets/{name}/publications`,
  `/api/publications/{doi}/planets`
- **Resumable backfill** of all ~6,300 planets across Crossref + ADS

### Future — Phase 3 (post-v1.0)

- Follow-up paper graph via NASA ADS citation queries
- Optional: PHL Habitable Exoplanets Catalog integration for Earth-Similarity
  Index tagging

---

## Tech stack

| Layer | Tool | Why |
|---|---|---|
| Language | Python 3.12 | Primary across the pipeline |
| Warehouse | Postgres 16 (Neon free tier) | dbt-friendly, free tier sufficient |
| Object storage | Cloudflare R2 | S3-compatible, zero egress fees |
| Transform | dbt-postgres 1.11 | Industry-standard SQL transform layer |
| Orchestration | GitHub Actions cron | Daily batch is fine; no need for Airflow at this scale |
| API | FastAPI (Phase 1 Day 8) | Lightweight, typed, Python-native |
| Frontend | Vite + React + TypeScript (Phase 1 Day 9) | Mature toolchain, easy to deploy |
| Hosting | Vercel (frontend + API as Python serverless) | One provider for both, generous free tier |
| HTTP | httpx + tenacity | Async-capable + built-in retry |
| Testing | pytest + dbt tests | Progressive rigor |

Deliberately not used: Kubernetes, Spark, Kafka, paid cloud warehouses. Those
are solutions to problems this data volume doesn't have.

Total monthly hosting cost at Phase 1 scale: $0.

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
