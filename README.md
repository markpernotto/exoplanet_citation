# exoplanet_citation

A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via Crossref, arXiv, and NASA ADS, and host-star enrichment via
Gaia DR3.

**Live:** [exoplanet-citation.vercel.app](https://exoplanet-citation.vercel.app)
· [API docs (Swagger)](https://exoplanet-citation.vercel.app/docs)
· [Source on GitHub](https://github.com/markpernotto/exoplanet_citation)

**Status:** Phase 1 nearly complete. Daily ingest pipeline running on a
GitHub Actions cron; ~6,300 confirmed planets loaded into Postgres; FastAPI
serving 7 endpoints with automatic Swagger docs; React frontend deployed
with procedurally-rendered planet cards; 64 unit tests + 13 dbt tests
passing. Phase 2 (the library-science differentiator: citation graph) is
the next major milestone.

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
  events to `discovery_changes`, idempotent across re-runs
- **Publisher** generates RSS 2.0, JSON, and health-snapshot feeds with
  freshness measurement against a 26-hour SLO
- **GitHub Actions** runs the full pipeline daily at 06:00 UTC, commits
  results back, opens an issue on failure
- **FastAPI** with 7 endpoints + automatic OpenAPI/Swagger docs, deployed
  to Vercel as Python serverless functions
- **React frontend** (Vite + TypeScript) deployed alongside the API on the
  same Vercel project — search bar, recent-discoveries feed, planet
  detail page with procedurally-rendered planet card and full change history
- **Phase 2 scaffold:** Gaia DR3 client tested end-to-end against real
  data — ready for enrichment work
- **64 unit tests + 13 dbt tests** all green; CI workflow with ruff lint

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

# Apply schema
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

# Run the API locally
make api         # http://localhost:8000/docs

# Run the React frontend locally (in a separate terminal)
make web-install # one-time
make web         # http://localhost:5173 (proxies /api to :8000)

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
  temperature / density / insolation → visual mapping for the planet UI

---

## Roadmap

### Phase 1 — done

- ETL pipeline: extract → load → dbt staging → diff → publish
- 28-column typed schema with JSONB raw preservation
- Nightly cron on GitHub Actions (06:00 UTC)
- Field-tier-aware diff (Tier A surfaced, Tier B logged-only, Tier C ignored)
- Cloudflare R2 raw landing with manifest in git
- FastAPI: 7 endpoints + OpenAPI/Swagger docs
- React frontend: search, discoveries feed, planet detail with
  procedural rendering
- Vercel deployment for both API and frontend
- Phase 2 scaffold: Gaia DR3 client + smoke test verified end-to-end
- Documentation: data catalog, procedural rendering plan, architecture
- 64 unit tests + 13 dbt tests; CI with ruff lint

### Phase 1 — remaining before "shipped"

- 5 consecutive green nightly runs (the formal Phase 1 ship bar)
- ARCHITECTURE.md polish + diagrams in `docs/diagrams/`
- README v1 polish (this file)
- Real second-snapshot diff with actual change events (data driven by
  upstream NASA cadence)

### Phase 2 — next major milestone

- **Citation resolution** via Crossref + arXiv + NASA ADS (4-tier strategy:
  direct DOI → ADS bibcode → Crossref title/author/year → manual queue)
- **dbt marts**: `dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`
- **Gaia DR3 host-star enrichment**: ~6,300 hosts queried by source ID,
  results in `host_stars_gaia` (parallax, BP-RP color, Gaia-derived
  stellar parameters)
- **API endpoints** for the citation graph
- **Frontend** surfaces the citation graph + Gaia-enriched host star color
- **Resumable backfill** of all ~6,300 planets across Crossref + ADS

### Phase 3 — post-v1.0

- Follow-up paper graph via NASA ADS citation queries
- Galactic positioning view ("Here we are / Here this planet is")
- Optional: PHL Habitable Exoplanets Catalog integration for
  Earth-Similarity Index tagging

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
