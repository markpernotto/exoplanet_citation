# Exoplanet Discovery & Citation Warehouse

**Owner:** Mark Pernotto (mark@pernotto.com)
**Repo:** https://github.com/markpernotto/exoplanet_citation
**Status:** Phase 1 nearly complete. ETL pipeline live on nightly GitHub Actions cron; FastAPI deployed to Vercel with 7 endpoints and Swagger docs; React frontend deployed alongside with search, discoveries feed, and a procedurally-rendered planet detail page; Gaia DR3 client scaffolded for Phase 2; 64 unit tests + 13 dbt tests green. Remaining Phase 1 work is the formal ship bar (5 consecutive green nightly runs) and polish; Phase 2 (citation graph + Gaia enrichment) is the next major milestone.
**Plan finalized:** 2026-05-03
**Last updated:** 2026-05-05
**Target effort:** ~4 weeks part-time (target, not a deadline; daily breakdown is a guide)
**Portfolio context:** Project 1 of three. See [/Users/gmarqu3/Code/oc_data/PLAN.md](../oc_data/PLAN.md) for the broader portfolio strategy. (The portfolio meta-doc lives in `oc_data/` for now; this repo is the actual implementation.)

---

## One-paragraph pitch

A public data warehouse that ingests the NASA Exoplanet Archive, joins each confirmed exoplanet to the scientific paper(s) that announced it (via DOI / arXiv / NASA ADS), and publishes a browsable, citable catalog with a public API and a public alert feed for newly-confirmed exoplanets. The distinguishing move is the **citation graph**: every planet in the warehouse traces back to its discovery publication, with provenance and confidence scores on the joins. This is library science applied to the largest active discovery effort in modern astronomy.

---

## Three phases

| Phase | Scope | Ship target |
|---|---|---|
| **Phase 1** | New-exoplanet diff watcher: nightly ingest → diff → RSS + JSON API + minimal UI | End of Week 2 |
| **Phase 2** | Citation warehouse + Gaia enrichment: resolve discovery publications, build dim/fact marts via dbt, query Gaia DR3 for host star astrometry/photometry, expose citation graph + procedural rendering data in API + UI | End of Week 4 |
| **Phase 3** *(post-v1.0)* | Follow-up paper graph: query ADS for papers that cite each discovery and mention the planet, surface the discovery → follow-up edges in the UI | Decided post-v1.0 based on Phase 2 outcomes |

Phase 1 is independently shippable and useful. Phase 3 is gated on Phase 2's resolution rate being good enough to make a follow-up graph meaningful.

---

## Definition of Done

### Phase 1
- [ ] Repo public on GitHub at `markpernotto/exoplanet_citation`
- [ ] Nightly GitHub Action ingests NASA Exoplanet Archive's `pscomppars` table via TAP
- [ ] Postgres (Neon) contains historical snapshots of the archive
- [ ] Snapshots stored in Cloudflare R2; `data/MANIFEST.jsonl` in git tracks date / R2 key / sha256 / row count per snapshot
- [ ] Diff job emits a feed of `NEW`, `REMOVED`, and `PARAMETER_CHANGE` events using the high-value field allowlist (see Field Allowlist section)
- [ ] Public RSS feed of new confirmations
- [ ] Public JSON endpoints: `/api/discoveries/latest`, `/api/discoveries/by-month/{yyyy-mm}`
- [ ] `/api/health` endpoint exposes freshness measurement (Clock B — see Freshness SLO)
- [ ] Minimal React page shows the last 30 days of new/changed planets
- [ ] dbt project initialized and used for staging/marts from Day 2 (not bolted on later)
- [ ] README with architecture diagram, data sources, attribution, how-to-run
- [ ] `docs/DATA_CATALOG.md` entry for `pscomppars`
- [ ] Controlled-vocabulary YAMLs for `discovery_method`, `discovery_facility`, `parameter_change_type`
- [ ] Freshness SLO defined and met: published data ≤ 26 hours from upstream `last_modified`
- [ ] pytest suite covers extract success, transform idempotency, diff correctness, load idempotency, API response schema
- [ ] Action has been green for 5 consecutive nights

### Phase 2
- [ ] Each confirmed planet linked to ≥1 discovery publication via DOI or arXiv ID, where resolvable
- [ ] Resolution confidence per link (high / medium / low) with human-readable reason
- [ ] Crossref + arXiv + NASA ADS metadata cached in `publications` table
- [ ] **Gaia DR3 host-star enrichment**: every host star with a `gaia_dr3_id` queried against the Gaia TAP service; BP-RP photometry, parallax, proper motion, Gaia-derived stellar parameters cached in `host_stars_gaia` table
- [ ] dbt marts: `dim_planet`, `dim_publication`, `fact_discovery`, `fact_parameter_revision`
- [ ] Public endpoints: `/api/planets/{name}`, `/api/planets/{name}/publications`, `/api/publications/{doi}`, `/api/publications/{doi}/planets`, `/api/planets/{name}/host_star` (Gaia-enriched)
- [ ] Browsable React UI: planet detail page shows discovery paper, the planet rendered procedurally from typed columns, the host star colored from Gaia BP-RP; publication detail page shows all planets it discusses
- [ ] dbt tests pass in CI; `dbt docs` published to GitHub Pages or Vercel
- [ ] `docs/DATA_CATALOG.md` extended with publication sources (Crossref, arXiv, ADS) and Gaia DR3
- [ ] `docs/CITATION_RESOLUTION.md` documents tier strategy + current resolution rate as a KPI
- [ ] `docs/PROCEDURAL_RENDERING.md` documents the temperature/density/insolation → visual mapping
- [ ] Backfill of all ~6,300 existing planets completed via resumable batch script (citation + Gaia, runnable independently)
- [ ] README v2 leads with the citation-graph contribution and the procedural-visualization differentiator

### Phase 3 (post-v1.0, decision after Phase 2 ships)
- [ ] For each discovery publication, query ADS for citing papers that mention the planet name in their abstract
- [ ] `planet_publications.relationship = 'follow_up'` rows populated
- [ ] UI: planet detail page shows follow-up papers grouped by year
- [ ] Resolution-rate sanity check: ≥50% of planets have ≥1 follow-up paper

---

## Day 0 / Pre-work (do before Day 1)

These are blocking dependencies. Complete before starting Week 1.

- [ ] Sign up for ADS account and **request API token** at https://ui.adsabs.harvard.edu/user/settings/token (approval can take days; this is the long pole)
- [ ] Create Neon Postgres project (free tier), save connection string
- [ ] Create Cloudflare R2 account, create bucket `exoplanet-citation-snapshots`, save access keys
- [ ] Create Vercel account — deploys both the React frontend AND the FastAPI backend as Python serverless functions (Fly.io's free tier was retired; Vercel handles both for free)
- [ ] Confirm Python 3.12 available locally: `/opt/homebrew/bin/python3.12 --version`
- [ ] Pull the `disc_refname` sample (see Citation Resolution section) and skim it to validate the parser strategy assumption

---

## Data Sources

All public. Attribute the agency in README and in-app. Use a `User-Agent` identifying the project and a contact email. Respect rate limits.

| Source | URL | Format | Update | Phase | Notes |
|---|---|---|---|---|---|
| NASA Exoplanet Archive — `pscomppars` (Composite Parameters) | https://exoplanetarchive.ipac.caltech.edu/TAP | TAP / VOTable / CSV | Weekly | 1+2 | **Primary source.** One row per planet with archive-preferred parameter values. ~5,500 planets. |
| NASA Exoplanet Archive — `ps` (Planetary Systems, full) | same TAP | TAP / VOTable / CSV | Weekly | 2 | Multi-row per planet (one row per published parameter set). Used to populate `fact_parameter_revision`. |
| NASA Exoplanet Archive — TESS Project Candidates | same TAP | TAP / VOTable / CSV | Frequent | 2 (optional) | Candidates not yet confirmed; useful for "candidate vs confirmed" analytics |
| Crossref REST API | https://api.crossref.org/works/{doi} | JSON | On demand | 2 | Resolve DOI → publication metadata. Free, polite-pool with email |
| arXiv API | http://export.arxiv.org/api/query | Atom | On demand | 2 | Resolve arXiv ID → preprint metadata |
| NASA ADS API | https://api.adsabs.harvard.edu/v1 | JSON | On demand | 2 | Best-in-class astronomy citation database. Free with API key. |
| Gaia DR3 (ESA) | https://gea.esac.esa.int/tap-server/tap | TAP / VOTable | On demand | 2 | Per-host-star astrometry, photometry (BP-RP color → derived surface temp), parallax, proper motion. Cross-referenced via `gaia_dr3_id` already in pscomppars. Free, no API key. **Not duplicative of pscomppars** — pscomppars carries only the source ID and one magnitude; Gaia direct gives multi-band photometry, full-precision parallax, and Gaia-derived stellar parameters. |
| ROR (Research Org Registry) | https://api.ror.org/organizations | JSON | On demand | 2 (optional) | Normalize discovery facility names to ROR IDs |

### TAP query specifics

Phase 1 extract is a single ADQL query against `pscomppars`. Pull the field allowlist below plus all metadata fields. The query is committed in `etl/sources/exoplanet_archive.py` so changes are reviewable.

To pull a sample of `disc_refname` for the Day 0 parser-strategy check, hit this URL in a browser (no auth needed):
```
https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=SELECT+pl_name,disc_refname+FROM+pscomppars&format=csv
```

### Source-of-truth notes
- The Exoplanet Archive's `pl_pubdate` and `disc_refname` fields are starting points for citation resolution — they are **strings, not DOIs**. Converting them into structured citations is a meaningful piece of the project.
- ADS is the gold standard for astronomy bibliography but rate-limited; cache aggressively.
- Crossref is the gold standard for DOI resolution generally; combine with ADS for the best coverage.

---

## Field Allowlist

The `pscomppars` table has 100+ columns. We classify them into three tiers for diff handling:

### Tier A — surfaced in RSS / API change feeds (high-value)
Changes to these fields emit `PARAMETER_CHANGE` events and appear in the public RSS/JSON feeds.

- `discoverymethod`
- `disc_year`
- `disc_facility`
- `pl_orbper` (orbital period, days) — float threshold: >1% relative change
- `pl_rade` (radius, Earth radii) — float threshold: >1% relative change
- `pl_bmasse` (best mass, Earth masses) — float threshold: >1% relative change

### Tier B — logged to `discovery_changes` but NOT surfaced in feeds (mid-value)
Useful for analytics and the per-planet history page; too noisy for the public alert stream.

- `pl_orbsmax` (semi-major axis)
- `pl_orbeccen` (eccentricity)
- `pl_eqt` (equilibrium temperature)
- `pl_insol` (insolation flux)
- `st_teff` (stellar effective temperature)
- `st_rad` (stellar radius)
- `st_mass` (stellar mass)
- `st_dist` (distance to host star)
- `sy_snum`, `sy_pnum` (system star/planet counts)
- All Tier A floats with sub-1% changes

### Tier C — stored in `raw_row` JSONB, never diffed
Everything else. Preserves source fidelity without polluting the change feed. Includes upper/lower error bounds, alternate parameter sources, and fields where churn is mostly metadata bookkeeping (e.g. `rowupdate`).

The full pscomppars column list is documented in `docs/DATA_CATALOG.md` with each column's tier assignment.

---

## Schema

### `planets_snapshots` (raw landing — Phase 1)

```sql
snapshot_date          DATE NOT NULL
pl_name                TEXT NOT NULL          -- canonical planet name e.g. "Kepler-22 b"
hostname               TEXT NOT NULL          -- host star name
sy_snum                INT
sy_pnum                INT
discoverymethod        TEXT
disc_year              INT
disc_facility          TEXT
disc_telescope         TEXT
disc_instrument        TEXT
disc_refname           TEXT                   -- raw reference string from archive
pl_orbper              DOUBLE PRECISION
pl_rade                DOUBLE PRECISION
pl_bmasse              DOUBLE PRECISION
pl_eqt                 DOUBLE PRECISION
st_dist                DOUBLE PRECISION
raw_row                JSONB                  -- full source row
source_url             TEXT NOT NULL
source_retrieved_at    TIMESTAMPTZ NOT NULL
source_checksum        TEXT NOT NULL          -- sha256 of source CSV
extraction_version     TEXT NOT NULL
PRIMARY KEY (snapshot_date, pl_name)
```

`pscomppars` is one-row-per-planet so `(snapshot_date, pl_name)` is a safe PK with no row collapse.

### `discovery_changes` (derived — Phase 1)

```sql
change_id              BIGSERIAL PRIMARY KEY
observed_at            TIMESTAMPTZ NOT NULL
pl_name                TEXT NOT NULL
change_type            TEXT NOT NULL          -- NEW, REMOVED, PARAMETER_CHANGE
field_name             TEXT                   -- non-null for PARAMETER_CHANGE
field_tier             TEXT                   -- 'A' | 'B' (Tier C never reaches this table)
prev_value             JSONB
new_value              JSONB
diff_summary           TEXT                   -- human-readable
source_snapshot_date   DATE NOT NULL
INDEX (observed_at DESC), INDEX (pl_name), INDEX (change_type), INDEX (field_tier)
```

The `field_tier` column lets the RSS publisher filter to Tier A only without re-deriving classification.

### `publications` (Phase 2)

```sql
publication_id         BIGSERIAL PRIMARY KEY
doi                    TEXT UNIQUE
arxiv_id               TEXT UNIQUE
ads_bibcode            TEXT UNIQUE
title                  TEXT NOT NULL
authors                JSONB NOT NULL          -- ordered list of {given, family, orcid, ror}
journal                TEXT
year                   INT
abstract               TEXT
canonical_url          TEXT
source_record          JSONB NOT NULL          -- raw response from whichever API resolved it
resolved_via           TEXT NOT NULL           -- 'crossref' | 'arxiv' | 'ads'
resolved_at            TIMESTAMPTZ NOT NULL
```

### `planet_publications` (the citation graph — Phase 2)

```sql
pl_name                TEXT NOT NULL
publication_id         BIGINT NOT NULL REFERENCES publications(publication_id)
relationship           TEXT NOT NULL           -- 'discovery' | 'follow_up' (Phase 3) | 'parameter_revision'
confidence             TEXT NOT NULL           -- 'high' | 'medium' | 'low'
confidence_reason      TEXT NOT NULL
extracted_from         TEXT NOT NULL           -- 'disc_refname' | 'pl_refname' | 'manual' | 'ads_query'
extracted_at           TIMESTAMPTZ NOT NULL
PRIMARY KEY (pl_name, publication_id, relationship)
```

### `host_stars_gaia` (Phase 2 — Gaia DR3 enrichment)

```sql
gaia_dr3_id            TEXT PRIMARY KEY        -- matches planets_snapshots.gaia_dr3_id
hostname               TEXT NOT NULL           -- denormalized for convenience
parallax_mas           DOUBLE PRECISION        -- milliarcseconds; derive distance via 1000 / parallax = pc
parallax_error         DOUBLE PRECISION
pmra_mas_yr            DOUBLE PRECISION        -- proper motion in RA, mas/year
pmdec_mas_yr           DOUBLE PRECISION        -- proper motion in Dec, mas/year
radial_velocity_km_s   DOUBLE PRECISION        -- line-of-sight velocity, km/s
phot_g_mean_mag        DOUBLE PRECISION        -- Gaia G-band mean apparent magnitude
phot_bp_mean_mag       DOUBLE PRECISION        -- Gaia BP-band (blue) magnitude
phot_rp_mean_mag       DOUBLE PRECISION        -- Gaia RP-band (red) magnitude
bp_rp                  DOUBLE PRECISION        -- BP - RP color index → drives star color in UI
teff_gspphot           DOUBLE PRECISION        -- Gaia-derived effective temperature, K
logg_gspphot           DOUBLE PRECISION        -- Gaia-derived log surface gravity
mh_gspphot             DOUBLE PRECISION        -- Gaia-derived metallicity [M/H]
distance_gspphot_pc    DOUBLE PRECISION        -- Gaia-derived distance, parsecs
source_record          JSONB NOT NULL          -- raw Gaia TAP response
retrieved_at           TIMESTAMPTZ NOT NULL
```

### `backfill_state` (Phase 2 — for resumable backfill)

```sql
batch_id               TEXT PRIMARY KEY        -- e.g. "discovery-resolve-2026-W19"
last_processed_pl_name TEXT NOT NULL
total_targets          INT NOT NULL
processed_count        INT NOT NULL
last_updated_at        TIMESTAMPTZ NOT NULL
status                 TEXT NOT NULL           -- 'in_progress' | 'completed' | 'paused'
```

### dbt mart layer
- `dim_planet` — one row per planet with current "best" parameters and key dates
- `dim_publication` — one row per resolved publication
- `fact_discovery` — one row per (planet, discovery-publication) pair
- `fact_parameter_revision` — one row per observed parameter change

---

## Pipeline

### Phase 1
```
NASA Exoplanet Archive TAP
        │
        ▼ nightly GH Actions cron (06:00 UTC)
  extract.py       → pull pscomppars CSV → upload to R2 → write MANIFEST.jsonl entry
        │
        ▼
  load.py          → UPSERT into planets_snapshots (raw landing)
        │
        ▼
  dbt run          → staging models normalize / coerce / validate against vocabularies
        │
        ▼
  diff.py          → compare today vs. yesterday → discovery_changes (Tier A + B only)
        │
        ▼
  publish.py       → regenerate rss.xml (Tier A only) + discoveries.json + freshness measurement
        │
        ▼
  FastAPI / Vercel → /api/discoveries, /api/planets, /api/health, /rss.xml
```

### Phase 2 additions
```
discovery_changes (where change_type = NEW)
        │
        ▼
  resolve_citation.py    → Tier 1 (DOI direct) → Tier 3 (Crossref) → Tier 2 (ADS) → Tier 4 (queue)
        │                  → write to publications + planet_publications
        │
        │  (parallel branch)
        ▼
  enrich_gaia.py         → for each new host with gaia_dr3_id, query Gaia DR3 TAP
        │                  → write to host_stars_gaia
        ▼
  dbt run                → marts: dim_planet, dim_publication, fact_discovery, fact_parameter_revision
        │
        ▼
  publish.py             → regenerate citation-graph + procedural-rendering endpoints
```

Note tier ordering: Tier 2 (ADS) runs after Tier 3 (Crossref) intentionally because the ADS API key may not arrive by the time we start coding the resolver. Tier 2 reprocesses anything Tiers 1 and 3 left as low-confidence or unresolved.

Gaia enrichment runs as a parallel branch — it has no dependency on citation resolution. The two backfill jobs can run independently and concurrently (Gaia: ~6,300 hosts, batched lookups, ~hour of clock time; citations: ~6,300 planets across 3 APIs, several hours).

---

## Citation Resolution Strategy

The `disc_refname` field is a free-text bibliographic reference like:
> `Borucki W. J., et al. 2011, ApJ, 736, 19`

Tiered strategy:

1. **Tier 1 — direct DOI present.** Some entries already include a DOI. Trivial, mark `confidence='high'`, `extracted_from='disc_refname'`.
2. **Tier 3 — Crossref title/author search.** Parse first-author surname + year + journal abbreviation, query Crossref `/works` with structured filters. If exactly one result matches author+year+journal, mark `confidence='medium'`. (Numbered "3" because it's built second but is logically the third tier of confidence.)
3. **Tier 2 — ADS bibcode lookup.** Construct the bibcode from the reference string (`2011ApJ...736...19B`), query ADS, get DOI + metadata. Mark `confidence='high'` if ADS returns an exact match. Built last, runs across queue + low-confidence entries to upgrade them.
4. **Tier 4 — manual review queue.** Anything that can't be resolved with confidence goes into `data/unresolved.csv` for human review. Track resolution rate as a project KPI.

**Anti-goal:** doing real NLP. This is rule-based parsing with progressively wider nets. If a reference can't be resolved by Tier 3 (or upgraded by Tier 2), it goes to the queue.

**Tier 4 ergonomics:** `data/unresolved.csv` is a flat file. Manual workflow: open the file, fill in the DOI/bibcode column for entries you can resolve by hand, re-run `resolve_citation.py --from-manual data/unresolved.csv`. No UI.

**Day 0 sanity check:** before locking the Phase 2 timeline, pull a sample of `disc_refname` (URL above) and skim 100 values. If the long tail of weird formats (concatenated multi-references, "in press", URL-only, conference proceedings) is >30% of rows, the resolution-rate target needs to be honest about it (e.g. "we resolve 65% of references; the remaining 35% are documented in `docs/UNRESOLVED.md`").

---

## Backfill (Phase 2)

The nightly resolver only runs on `NEW` changes going forward. The ~5,500 existing planets need a one-time backfill, which at Crossref/ADS rate limits is hours of clock time.

`etl/backfill_citations.py`:
- Reads target planets from `planets_snapshots` (current snapshot)
- Processes in batches of 100, persists progress to `backfill_state` after each batch
- Resumable: if interrupted, resumes from `last_processed_pl_name`
- Run unattended overnight via `nohup` or a one-shot GitHub Actions job
- Polite-pool delays per source (Crossref: 50 req/sec; ADS: 1 req/sec; arXiv: 1 req/3sec)

---

## Freshness SLO

**Definition:** Published data is fresh if it is ≤26 hours old relative to the upstream `last_modified` timestamp on the `pscomppars` TAP table at publish time.

**Why this clock and not "time since last extract":** the latter is trivially met by any nightly cron. What users care about is "how stale is this data really?" — the gap between when NASA published a row and when our API serves it.

**Measurement:** `publish.py` records `(upstream_last_modified, published_at)` for each run. The delta is exposed in `/api/health` as `freshness_hours`. Weekly, an external uptime check (or a Tuesday GH Action) reads `/api/health` and opens an issue if `freshness_hours > 26`.

---

## Repository Layout

```
exoplanet_citation/
├── .github/workflows/
│   ├── nightly.yml
│   ├── citation-resolver.yml     # weekly, Phase 2
│   ├── freshness-check.yml       # weekly, reads /api/health
│   └── ci.yml
├── etl/
│   ├── sources/
│   │   ├── exoplanet_archive.py
│   │   ├── crossref.py
│   │   ├── arxiv.py
│   │   ├── ads.py
│   │   └── gaia.py               # Phase 2
│   ├── transform/                # dbt project root (used from Day 2)
│   │   ├── dbt_project.yml
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   └── marts/
│   │   └── tests/
│   ├── extract.py
│   ├── load.py
│   ├── diff.py
│   ├── resolve_citation.py       # Phase 2
│   ├── enrich_gaia.py            # Phase 2
│   ├── backfill_citations.py     # Phase 2
│   ├── backfill_gaia.py          # Phase 2
│   ├── publish.py
│   └── schema.sql
├── vocabularies/
│   ├── discovery_method.yaml
│   ├── discovery_facility.yaml
│   ├── parameter_change_type.yaml
│   └── citation_confidence.yaml
├── api/
│   ├── main.py
│   └── models.py
├── web/
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── data/
│   ├── MANIFEST.jsonl            # snapshot index (R2 holds the actual files)
│   └── unresolved.csv            # manual citation review queue (Phase 2)
├── tests/
│   ├── test_extract.py
│   ├── test_transform.py
│   ├── test_diff.py
│   ├── test_resolve_citation.py
│   └── fixtures/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_CATALOG.md
│   ├── DATA_SOURCES.md
│   ├── CITATION_RESOLUTION.md    # methodology doc
│   └── diagrams/
├── infra/
│   └── main.tf                   # R2 bucket, Vercel project, Neon project
├── Dockerfile
├── docker-compose.yml
├── LICENSE                        # MIT
├── LICENSE-DATA                   # CC-BY (Exoplanet Archive requires attribution)
├── PRIVACY.md
├── pyproject.toml
├── README.md
└── .env.example
```

---

## Phase status

Work is sequenced by phase, not by calendar day. Slip is acceptable;
ship-quality is not. Phase 1 must produce **5 consecutive green nightly
runs** before being declared shipped, regardless of calendar date.

### Phase 1 — done

- ETL pipeline: `extract.py` (Exoplanet Archive TAP → R2 + manifest),
  `load.py` (R2 → Postgres UPSERT), dbt staging (`stg_pscomppars`),
  `diff.py` (field-tier-aware NEW/REMOVED/PARAMETER_CHANGE),
  `publish.py` (RSS + JSON + health snapshot)
- Schema with 28 typed columns + JSONB raw row preservation, 13 dbt tests
- Cloudflare R2 raw landing zone with sha256 manifest in git
- Field tier rules: 6 Tier A (RSS-surfaced), 13 Tier B (logged-only),
  rest Tier C (preserved but not diffed); 1% relative tolerance for
  floats with Tier A demotion / Tier B suppression of sub-tolerance changes
- Nightly GitHub Actions cron at 06:00 UTC; auto-issue-on-failure;
  results auto-committed back to `main` with `[skip ci]`
- FastAPI: 7 endpoints + automatic OpenAPI/Swagger docs
- React frontend (Vite + TypeScript): search, recent-discoveries feed,
  planet detail page with **procedural rendering** from typed columns
- Vercel deployment serving both API (Python serverless) and React static
  build under one project at `exoplanet-citation.vercel.app`
- 64 unit tests + 13 dbt tests, all green; CI workflow with ruff lint
- Provenance per row: `source_url`, `source_retrieved_at`,
  `source_checksum`, `extraction_version`, `raw_row` JSONB
- Documentation: ARCHITECTURE.md, DATA_CATALOG.md (column families
  decoded), PROCEDURAL_RENDERING.md (visual mapping rationale),
  controlled-vocabulary YAMLs
- Phase 2 scaffold: Gaia DR3 client + smoke test verified end-to-end

### Phase 1 — remaining before "shipped"

- 5 consecutive green nightly cron runs (the formal Phase 1 ship bar)
- README v1 polish + ARCHITECTURE.md polish + diagrams under `docs/diagrams/`
- Real-data validation: at least one nightly cycle producing actual
  change events (gated on upstream NASA Exoplanet Archive cadence,
  which is approximately weekly)
- Optional: PRIVACY.md polish, `freshness-check.yml` weekly external
  uptime check

### Phase 2 — next major milestone

The library-science differentiator. Two parallel workstreams:

**Citation resolution:**
- `etl/sources/crossref.py`, `etl/sources/arxiv.py`, `etl/sources/ads.py`
  source clients (polite-pool with email, retry handling)
- `publications`, `planet_publications`, `backfill_state` schema migration
- `etl/resolve_citation.py` — 4-tier strategy:
  Tier 1 (direct DOI in `disc_refname`)
  → Tier 3 (Crossref title/author/year search)
  → Tier 2 (ADS bibcode lookup; built last because the API key is the
     long pole; runs across queue + low-confidence rows to upgrade them)
  → Tier 4 (manual queue at `data/unresolved.csv`)
- `etl/backfill_citations.py` — resumable batched backfill across all
  ~6,300 planets, runs overnight unattended
- `tests/test_resolve_citation.py` — ≥10 cases per tier including
  edge-case reference strings (in-press, conference proceedings,
  concatenated multi-references)
- `docs/CITATION_RESOLUTION.md` — methodology, decision tree, confidence
  rubric, current resolution rate KPI

**Gaia DR3 enrichment** (parallel branch, no dependency on citation work):
- `etl/sources/gaia.py` — already scaffolded
- `host_stars_gaia` schema migration
- `etl/enrich_gaia.py` — for each host with `gaia_dr3_id`, look up Gaia
  record, write to `host_stars_gaia`
- `etl/backfill_gaia.py` — resumable batched backfill across ~6,300 hosts,
  ~hour of clock time at default batch size

**dbt marts:**
- `dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision` (the last requires a one-time ingest of the
  full `ps` table)
- dbt tests: not_null, unique, relationships, plus custom tests like
  "every planet has at least one discovery publication or is in the
  unresolved queue"

**API + UI extensions:**
- New endpoints: `/api/planets/{name}/publications`,
  `/api/publications/{doi}`, `/api/publications/{doi}/planets`,
  `/api/planets/{name}/host_star`
- Frontend: planet detail page surfaces discovery paper(s) with confidence
  badge; publication detail page lists all planets discussed; host star
  rendered using Gaia BP-RP color (replaces the current `st_teff`
  fallback in `web/src/procedural.ts`); citation-graph-health panel
  showing resolution rate over time

### Phase 3 — post-v1.0

- Follow-up paper graph via NASA ADS citation queries (the most novel
  but also most open-ended piece — gated on Phase 2's resolution rate
  being good enough to make it meaningful)
- Galactic positioning view: "Here we are / Here this planet is" — 2D
  Milky Way map using `ra`, `dec`, `sy_dist` plus Gaia astrometry
- Optional: PHL Habitable Exoplanets Catalog integration for
  Earth-Similarity Index per planet

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Exoplanet Archive TAP endpoint changes | Use `astroquery.ipac.nexsci.NasaExoplanetArchive` if direct TAP becomes painful; cache responses to R2 |
| Citation resolution rate is embarrassingly low | Document honestly. Tier 4 manual queue is the explicit relief valve. README states the actual rate as a KPI. |
| ADS API key delayed | Tier 2 (ADS) is sequenced *after* Tier 3 (Crossref) in the build order so we're not blocked. ADS upgrades happen in a backfill pass once the key arrives. |
| `disc_refname` parsing harder than expected | Day 0 sample skim should surface this before Phase 2 starts. If >30% are weird, target rate is adjusted, not the timeline. |
| First-day snapshot has nothing to diff against | First run emits zero changes, not errors. Documented in README. |
| Schema drift in source data | `raw_row JSONB` preserves source row; transforms log unknown enum values rather than failing |
| Neon free tier pauses after inactivity | ~2s cold start, acceptable for nightly batch |
| Backfill takes longer than expected | Resumable + batched; can pause and resume across nights. Citation and Gaia backfills run independently — slow citation resolution doesn't block Gaia enrichment. |
| Gaia DR3 has no record for some host stars | Some recently-discovered or faint hosts won't have a `gaia_dr3_id` in pscomppars at all, and some that have an ID may not have Gaia-derived stellar parameters (`*_gspphot` columns are populated for ~470M of Gaia's 1.8B sources). UI falls back to pscomppars values for missing hosts; coverage rate tracked alongside citation resolution rate. |
| Scope creep into "build a NASA front-end" | UI scope locked: discoveries feed, planet detail, publication detail, resolution-rate panel. Nothing else in v1.0. |
| Timeline slips | Acceptable. Phase 1 ships on its own merits; Phase 2 ships when ready; Phase 3 is post-v1.0 by design. |

---

## What Not To Add (in v1.0)

- Authentication / user accounts
- Comments, reviews, or social features on planets/papers
- ML-based reference parsing
- Other catalogs (MAST, SIMBAD, Gaia)
- A "compare two planets" tool — feature creep
- A Twitter/Mastodon bot
- The follow-up paper graph (this is Phase 3, post-v1.0)

---

## Stretch Goals (post-v1.0, after Phase 3 decision)

- Author disambiguation via ORCID resolution
- Discovery-facility normalization to ROR IDs
- A "citation graph" GraphQL endpoint
- A Sankey diagram of "discovery method → facility → year"
- Cross-link to the Mikulski Archive (MAST) for raw observation data
