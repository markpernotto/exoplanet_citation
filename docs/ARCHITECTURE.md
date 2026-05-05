# Architecture

How exoplanet_citation is put together: data flow, components, storage layout,
hosting, idempotency guarantees, and provenance.

For the why-this-project framing see [01-exoplanets.md](../01-exoplanets.md).
For implementation details see [PLAN.md](../PLAN.md).

---

## High-level data flow

```
┌──────────────────┐    ┌─────────────────┐    ┌──────────────┐
│ NASA Exoplanet   │    │ Crossref / arXiv│    │ Gaia DR3     │
│ Archive (TAP)    │    │ NASA ADS        │    │ TAP service  │
└────────┬─────────┘    └────────┬────────┘    └──────┬───────┘
         │ pscomppars            │ DOI / arXiv ID     │ source_id
         │ (Phase 1+2)           │ / bibcode (Phase 2)│ (Phase 2)
         ▼                       │                    │
   ┌──────────────────────┐      │                    │
   │   Cloudflare R2      │      │                    │
   │   (raw landing)      │      │                    │
   │                      │      │                    │
   │ snapshots/           │      │                    │
   │   YYYY-MM-DD.csv     │      │                    │
   └──────────┬───────────┘      │                    │
              │ etl/load.py      │                    │
              ▼                  ▼                    ▼
   ┌────────────────────────────────────────────────────────┐
   │              Postgres (Neon free tier)                 │
   │                                                         │
   │  public.                                                │
   │    planets_snapshots         raw landing, 28 typed cols │
   │    discovery_changes         diff events                │
   │    publications              [Phase 2]                  │
   │    planet_publications       [Phase 2 — citation graph] │
   │    host_stars_gaia           [Phase 2]                  │
   │    backfill_state            [Phase 2]                  │
   │                                                         │
   │  staging.                    dbt views                  │
   │    stg_pscomppars                                       │
   │                                                         │
   │  marts.                      [Phase 2 — dbt tables]     │
   │    dim_planet, dim_publication                          │
   │    fact_discovery, fact_parameter_revision              │
   └─────────┬───────────────────────────┬───────────────────┘
             │ etl/diff.py + publish.py  │ FastAPI (Day 8)
             ▼                           ▼
   ┌────────────────────────┐   ┌──────────────────────┐
   │  static feeds          │   │  REST API            │
   │                        │   │                      │
   │  public/rss.xml        │   │  /api/discoveries/.. │
   │  public/discoveries    │   │  /api/planets/...    │
   │       .json            │   │  /api/publications.. │
   │  public/health.json    │   │  /api/health         │
   └──────────┬─────────────┘   └────────┬─────────────┘
              │                          │
              └─────────┬────────────────┘
                        ▼
                ┌────────────────────┐
                │  Vercel            │
                │                    │
                │  Static hosting    │
                │  + Python          │
                │  serverless        │
                │  + React frontend  │
                │  (web/, Day 9)     │
                └────────────────────┘
```

---

## Nightly pipeline

The full pipeline runs in this exact order on a GitHub Actions cron at
06:00 UTC. The same sequence is runnable locally with `make pipeline`.

1. **Extract** — `python -m etl.extract` queries the NASA Exoplanet Archive's
   TAP service for `pscomppars`, uploads the CSV to R2, appends a manifest
   entry to `data/MANIFEST.jsonl` with sha256 + row count + source URL.
2. **Load** — `python -m etl.load` reads the latest manifest entry,
   downloads from R2, verifies the checksum, parses with pandas, and
   UPSERTs into `planets_snapshots`. 28 typed columns plus the full
   row preserved as JSONB.
3. **dbt run** — refreshes the `staging.stg_pscomppars` view from the
   newly-loaded snapshot.
4. **Diff** — `python -m etl.diff` compares the two most recent
   `snapshot_date` values, emits `NEW` / `REMOVED` / `PARAMETER_CHANGE`
   events to `discovery_changes` per the field-tier rules below.
5. **Publish** — `python -m etl.publish` reads recent surfaced changes
   and produces `public/rss.xml`, `public/discoveries.json`, and
   `public/health.json`.
6. **Commit + push** — the GitHub Actions runner commits the updated
   `data/MANIFEST.jsonl` and `public/` files back to `main` with
   `[skip ci]` to avoid retriggering.

Failure at any step opens a GitHub issue automatically (`actions/github-script@v7`,
`if: failure()`).

Phase 2 will add a parallel resolution branch (`etl/resolve_citation.py`)
plus Gaia enrichment (`etl/enrich_gaia.py`) running after diff. Both
backfill jobs are designed resumable so they can be paused mid-run.

---

## Field tier rules (diff)

Every measured column from pscomppars is classified for change-event handling:

- **Tier A** — surfaced in RSS / public change feeds.
  - 6 fields: `discoverymethod`, `disc_year`, `disc_facility`,
    `pl_orbper`, `pl_rade`, `pl_bmasse`
  - Float fields use 1% relative tolerance; sub-tolerance changes are
    **demoted to Tier B** (logged but not surfaced)
- **Tier B** — logged to `discovery_changes` but NOT surfaced.
  - 13 fields after the Phase-1.x expansion: planet/star/system measured
    quantities like `pl_orbsmax`, `pl_dens`, `st_teff`, `st_lum`,
    `sy_dist`, `st_spectype`, etc.
  - Float fields use 1% relative tolerance; sub-tolerance changes are
    **suppressed entirely**
- **Tier C** — preserved in `raw_row` JSONB but never diffed.
  - Everything else (hundreds of error-bound columns, alternate
    parameter sources, display formatting, internal IDs)
  - Identity-stable columns intentionally excluded from diffing despite
    being typed: `ra`, `dec`, `gaia_dr3_id`

See [docs/DATA_CATALOG.md](DATA_CATALOG.md) for the complete column
classification.

---

## Components

| Module | Role | Phase |
|---|---|---|
| `etl/sources/exoplanet_archive.py` | NASA Exoplanet Archive TAP client | 1 |
| `etl/sources/gaia.py` | Gaia DR3 TAP client | 2 (scaffolded) |
| `etl/sources/crossref.py` | Crossref REST client | 2 (TBD) |
| `etl/sources/arxiv.py` | arXiv API client | 2 (TBD) |
| `etl/sources/ads.py` | NASA ADS API client | 2 (TBD) |
| `etl/r2.py` | Cloudflare R2 helper (boto3 wrapper) | 1 |
| `etl/extract.py` | Orchestrates fetch → R2 → manifest | 1 |
| `etl/load.py` | Loads R2 snapshot into Postgres (UPSERT) | 1 |
| `etl/diff.py` | Field-tier-aware diff between two snapshots | 1 |
| `etl/publish.py` | Generates RSS + JSON feeds + health snapshot | 1 |
| `etl/transform/` | dbt project (staging now, marts in Phase 2) | 1+2 |
| `etl/resolve_citation.py` | 4-tier DOI/bibcode resolver | 2 (TBD) |
| `etl/enrich_gaia.py` | Per-host-star Gaia DR3 lookup | 2 (TBD) |
| `etl/backfill_citations.py` | Resumable citation backfill | 2 (TBD) |
| `etl/backfill_gaia.py` | Resumable Gaia backfill | 2 (TBD) |
| `etl/inspect.py` | Local-dev tool for browsing raw_row by planet | dev |
| `etl/check_setup.py` | Connectivity smoke test (Neon + R2) | dev |
| `etl/smoke_gaia.py` | One-shot Gaia DR3 client smoke test | dev |
| `api/index.py` | FastAPI app (7 endpoints + OpenAPI/Swagger) deployed as Vercel Python serverless | 1 |
| `api/models.py` | Pydantic response models | 1 |
| `web/` | Vite + React + TypeScript SPA — search, discoveries feed, procedural planet detail | 1 |
| `web/src/procedural.ts` | Body-type/temperature → color mapping (see `docs/PROCEDURAL_RENDERING.md`) | 1 |
| `vocabularies/` | Controlled vocabularies (SKOS-lite YAML) | 1 |

---

## Storage layout

### Cloudflare R2 — raw landing zone

Bucket: `exoplanet-citation-snapshots`

```
snapshots/
  2026-05-04.csv    ~80 MB, ~6,300 rows × ~370 columns
  2026-05-05.csv
  ...
```

Manifest in git (`data/MANIFEST.jsonl`) tracks per-snapshot:
`snapshot_date`, `r2_key`, `byte_count`, `row_count`,
`checksum_sha256`, `source_url`, `source_retrieved_at`,
`extraction_version`. The actual snapshot CSVs are *not* committed to git —
they live in R2 and are referenced by the manifest.

### Postgres (Neon)

Three logical layers, separated by schema:

```
public.            ← raw landing (load.py + diff.py + Phase 2 writes here)
  planets_snapshots
  discovery_changes
  publications              [Phase 2]
  planet_publications       [Phase 2]
  host_stars_gaia           [Phase 2]
  backfill_state            [Phase 2]

staging.           ← dbt views (clean, typed projection of raw)
  stg_pscomppars

marts.             ← dbt tables (analytical models)
  dim_planet                [Phase 2]
  dim_publication           [Phase 2]
  fact_discovery            [Phase 2]
  fact_parameter_revision   [Phase 2]
```

Schema separation makes it easy to drop and rebuild marts without
touching raw data, and clearly delineates the boundary between
"things load.py owns" and "things dbt owns."

### Static feed output

`public/` directory in the repo, regenerated nightly by `etl/publish.py`:

- `rss.xml` — RSS 2.0; surfaces NEW + REMOVED + Tier-A `PARAMETER_CHANGE`
  events from the last 30 days (configurable via `--days`)
- `discoveries.json` — JSON; same set as RSS plus full prev/new value
  payloads and freshness metadata
- `health.json` — pipeline status snapshot for external uptime monitoring

These files are committed back to `main` by the nightly cron and served
statically.

---

## Hosting

| Concern | Service | Tier | Cost |
|---|---|---|---|
| Postgres warehouse | Neon | free | $0 |
| Object storage | Cloudflare R2 | free (10 GB / 1M Class A ops/mo) | $0 |
| Orchestration | GitHub Actions cron | free for public repos | $0 |
| API + frontend | Vercel | free hobby tier | $0 |
| CI / version control | GitHub | free for public repos | $0 |

Total monthly hosting cost at Phase 1 scale: **$0**.

The free-tier choice is deliberate. Each service was selected against
"this is what data engineering job listings actually mention" rather than
"what's free for portfolio projects." Postgres + dbt + GitHub Actions +
FastAPI + Vercel mirrors a small startup's stack.

---

## Idempotency and safety

Every step in the pipeline is safe to re-run:

- **`extract.py`** — skips if today's `snapshot_date` is already in the
  manifest, unless `--force` is passed. Re-running with `--force` overwrites
  the R2 object (same checksum if the source hasn't changed) and appends a
  fresh manifest entry.
- **`load.py`** — `INSERT ... ON CONFLICT (snapshot_date, pl_name) DO UPDATE`.
  Safe to re-run on the same snapshot indefinitely; it just re-writes the
  same rows.
- **`diff.py`** — guarded by a unique index
  `(source_snapshot_date, pl_name, change_type, COALESCE(field_name, ''))`
  with `ON CONFLICT DO NOTHING`. Re-running produces the same change records;
  duplicates are silently skipped.
- **`publish.py`** — purely derivative; just regenerates files from current DB
  state.
- **dbt** — views are recreated from scratch on every `dbt run`.

The `extraction_version` field on each row in `planets_snapshots` lets us
track schema/coercion changes over time without breaking existing data.

---

## Provenance

The library-science backbone of the project: every value can be traced
back to its origin.

Every row in `planets_snapshots` carries:

- `source_url` — the exact TAP query URL that produced it
- `source_retrieved_at` — UTC timestamp of the extract
- `source_checksum` — sha256 of the source CSV bytes
- `extraction_version` — pipeline version that processed it
- `raw_row` — the full original CSV row as JSONB (no fields dropped)

Every row in `discovery_changes` carries:

- `source_snapshot_date` — the snapshot whose comparison produced it
- `field_tier` (for `PARAMETER_CHANGE`) — A or B classification
- `prev_value` / `new_value` (JSONB) — the actual transition

Every Phase 2 row in `publications` will carry:

- `resolved_via` — `crossref` | `arxiv` | `ads`
- `resolved_at` — when the resolver ran
- `source_record` — raw API response

Every Phase 2 row in `planet_publications` will carry:

- `confidence` — `high` | `medium` | `low`
- `confidence_reason` — human-readable rationale
- `extracted_from` — `disc_refname` | `pl_refname` | `manual` | `ads_query`

Anyone consuming the data can answer "where did this value come from?"
deterministically. That's the project's distinguishing technical bet.

---

## Code organization

```
exoplanet_citation/
├── .github/workflows/
│   ├── nightly.yml          # cron + workflow_dispatch
│   └── ci.yml               # ruff + pytest on push/PR
├── etl/
│   ├── sources/             # one module per upstream API
│   ├── transform/           # dbt project root
│   ├── migrations/          # one-off SQL migrations
│   ├── extract.py
│   ├── load.py
│   ├── diff.py
│   ├── publish.py
│   ├── r2.py
│   ├── schema.sql           # canonical fresh-install schema
│   ├── inspect.py           # dev tool
│   ├── check_setup.py       # dev tool
│   └── smoke_gaia.py        # dev tool
├── vocabularies/            # SKOS-lite YAML
├── api/                     # FastAPI (Day 8)
├── web/                     # React + Vite (Day 9)
├── data/
│   └── MANIFEST.jsonl       # snapshot index (R2 keys + checksums)
├── public/                  # generated static feeds (nightly)
├── tests/                   # pytest unit tests (64 currently)
├── docs/
│   ├── ARCHITECTURE.md      # this file
│   ├── DATA_CATALOG.md
│   └── PROCEDURAL_RENDERING.md
├── infra/                   # Terraform (TBD)
├── Dockerfile
├── docker-compose.yml       # local Postgres for dev
├── Makefile                 # task runner
├── pyproject.toml
└── PLAN.md                  # implementation roadmap
```

`Makefile` is the canonical entry point for all common commands. Run
`make help` to see the targets.
