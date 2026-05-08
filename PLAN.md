# Exoplanet Discovery & Citation Warehouse

**Owner:** Mark Pernotto (mark@pernotto.com)
**Repo:** https://github.com/markpernotto/exoplanet_citation
**Status:** Phase 1 shipped. Phase 2 substantially complete. ETL pipeline live on nightly GitHub Actions cron with 5+ consecutive green runs since 2026-05-04; rolling 2-day snapshot prune keeps Neon storage steady; FastAPI deployed to Vercel with 22 endpoints and Swagger docs; React frontend with search (planet + author), procedurally-rendered planet detail, multi-planet "this paper also announced…" affordance, system orbital view, six retro display themes; Gaia DR3 enrichment complete for all 4,355 enrichable hosts; ADS-cached `discovery_papers` for ~1,250 unique bibcodes; **citation graph (`publications` + `planet_publications`) resolved for 5,856 / 6,286 planets (93%)** via a 4-tier resolver with quota-aware ADS circuit breaker; 78 unit tests + 13 dbt tests green. Remaining Phase 2 work is one more clean ADS-quota window to close the final 7%, plus Crossref-source consolidation. Phase 3 (follow-up paper graph) is the next major decision point.
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

### Phase 1 — shipped

- [x] Repo public on GitHub at `markpernotto/exoplanet_citation`
- [x] Nightly GitHub Action ingests NASA Exoplanet Archive's `pscomppars` table via TAP
- [x] Postgres (Neon) contains rolling 2-day window of snapshots; full
      historical record preserved in Cloudflare R2
- [x] Snapshots stored in Cloudflare R2; `data/MANIFEST.jsonl` in git tracks date / R2 key / sha256 / row count per snapshot
- [x] Diff job emits a feed of `NEW`, `REMOVED`, and `PARAMETER_CHANGE` events using the high-value field allowlist (see Field Allowlist section)
- [x] Public RSS feed of new confirmations (static + per-planet/system/author dynamic)
- [x] Public JSON endpoints: `/api/discoveries/latest`, `/api/discoveries/by-month/{yyyy-mm}`
- [x] `/api/health` endpoint exposes freshness measurement and Neon storage utilization
- [x] React page shows the last 30 days of new/changed planets, plus
      full catalog browser, planet/system/author detail pages
- [x] dbt project initialized and used for staging from Day 2
- [x] README with architecture diagram, data sources, attribution, how-to-run
- [x] `docs/DATA_CATALOG.md` entry for `pscomppars`
- [x] Controlled-vocabulary YAMLs for `discovery_method`, `discovery_facility`, `parameter_change_type`
- [x] Freshness SLO defined and met: published data ≤ 26 hours from upstream
- [x] pytest suite covers extract, transform idempotency, diff correctness, load idempotency, API response schema (78 tests)
- [x] Action has been green for 5 consecutive nights (since 2026-05-04)

### Phase 2 — substantially complete (final pass + cleanup pending)

- [x] Each confirmed planet linked to ≥1 discovery publication via ADS bibcode / DOI where resolvable (5,856 / 6,286 = 93% as of 2026-05-08)
- [x] Resolution provenance per row: `resolved_via` (`ads_bibcode`, `crossref_doi`, `ads_title`, `manual`) + `confidence` (`high` / `medium` / `low`)
- [x] NASA ADS metadata cached in `discovery_papers` (~1,250 unique bibcodes); citation graph in `publications` + `planet_publications`
- [x] **Gaia DR3 host-star enrichment**: every host with parsable `gaia_dr3_id` (4,355 hosts) enriched in `host_stars_gaia`
- [x] Public endpoints: `/api/planets/{name}`, `/api/planets/{name}/publications` (with `co_planets` for one-shot multi-planet UI), `/api/publications/{bibcode}`, `/api/authors/{name}/publications`, `/api/planets/{name}/host_star`
- [x] React UI: planet detail surfaces discovery paper, "this paper also announced N planets" multi-planet affordance, procedural rendering, system orbital view, retro themes; AuthorDetail page; per-feed RSS subscribe links
- [ ] Final 7% citation coverage closed (430 planets pending one more ADS-quota window)
- [ ] Crossref purge + ADS re-resolution to consolidate on a single source
- [ ] dbt marts: `dim_planet`, `dim_publication`, `fact_discovery`, `fact_parameter_revision` — deferred (not on critical path)
- [ ] dbt docs published to GitHub Pages or Vercel — deferred
- [x] `docs/DATA_CATALOG.md` extended with NASA ADS, Crossref, Gaia DR3 sections
- [ ] `docs/CITATION_RESOLUTION.md` (writeup) — optional, deferred
- [x] `docs/PROCEDURAL_RENDERING.md` documents the temperature/density/insolation → visual mapping
- [x] Backfill of all 6,286 existing planets via resumable scripts using `backfill_state` (citation + Gaia, runnable independently)
- [x] README v2 leads with the citation-graph contribution and the procedural-visualization differentiator

### Phase 3 (post-v1.0, decision after Phase 2 ships)
- [ ] For each discovery publication, query ADS for citing papers that mention the planet name in their abstract
- [ ] `planet_publications.relationship = 'follow_up'` rows populated
- [ ] UI: planet detail page shows follow-up papers grouped by year
- [ ] Resolution-rate sanity check: ≥50% of planets have ≥1 follow-up paper

---

## Day 0 / Pre-work — complete

All blocking dependencies are in place.

- [x] ADS API token approved and stored in `.env` / GitHub Actions secrets
- [x] Neon Postgres project provisioned, connection string in `.env`
- [x] Cloudflare R2 bucket `exoplanet-citation-snapshots` provisioned;
      access keys in `.env` / GitHub Actions secrets
- [x] Vercel project deployed (API + React frontend under one URL)
- [x] Python 3.12 venv set up at `.venv/`
- [x] `disc_refname` format inspected — turned out to be HTML-embedded
      ADS URLs, not free-text reference strings, which made Tier 1
      regex-based bibcode extraction trivially reliable

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

### `publications` (Phase 2 — implemented in migration `005_citation_graph.sql`)

The shipped shape is a tighter superset of the original plan: provenance
fields collapsed to `resolved_via` + `confidence`, raw API record
discarded (we trusted the normalized fields and didn't keep needing the
raw payload), `bibcode` and `doi` both serve as alternate uniques.

```sql
pub_id                    BIGSERIAL PRIMARY KEY
bibcode                   TEXT UNIQUE             -- ADS bibcode (primary key in ADS world)
doi                       TEXT UNIQUE
arxiv_id                  TEXT
title                     TEXT
authors                   JSONB                   -- ordered list of "Last, F." strings
abstract                  TEXT
journal                   TEXT
pub_date                  DATE
citation_count            INT
citation_count_updated_at TIMESTAMPTZ
resolved_via              TEXT NOT NULL           -- 'ads_bibcode' | 'crossref_doi' | 'ads_title' | 'manual'
confidence                TEXT NOT NULL           -- 'high' | 'medium' | 'low'
created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
```

### `planet_publications` (the citation graph — Phase 2)

```sql
pl_name                TEXT NOT NULL
pub_id                 BIGINT NOT NULL REFERENCES publications(pub_id) ON DELETE CASCADE
role                   TEXT NOT NULL DEFAULT 'discovery'  -- 'discovery' | 'follow_up'
PRIMARY KEY (pl_name, pub_id, role)
```

Confidence/extracted-from fields collapsed onto the parent `publications`
row instead of the junction — the `resolved_via` value tells you the
extraction method, and a single planet wouldn't disagree about the
confidence of the same paper.

### `citation_manual_queue` (Phase 2)

```sql
pl_name      TEXT PRIMARY KEY
disc_refname TEXT
notes        TEXT
created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
```

Tier 4 of the resolver: planets that fail all three automated tiers land
here for human triage.

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

Used by both `enrich_gaia.py` (`batch_id = 'gaia-enrich-YYYY-MM-DD'`) and
`resolve_citations.py` (`batch_id = 'citations-YYYY-MM-DD'`).

```sql
batch_id               TEXT PRIMARY KEY        -- e.g. "citations-2026-05-08"
last_processed_key     TEXT NOT NULL           -- pl_name or gaia_dr3_id
total_targets          INT NOT NULL
processed_count        INT NOT NULL
error_count            INT NOT NULL DEFAULT 0
last_updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
status                 TEXT NOT NULL           -- 'in_progress' | 'completed' | 'failed'
notes                  JSONB                   -- per-job stats (hits, misses, tier counts, etc.)
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

### Phase 2 additions (as built)
```
planets_snapshots (after diff)
        │
        ▼
  enrich_gaia.py         → for each host with parsable gaia_dr3_id, query Gaia DR3 TAP
        │                  → UPSERT into host_stars_gaia (resumable via backfill_state)
        ▼
  enrich_ads.py          → for each new bibcode in disc_refname, fetch from NASA ADS
        │                  → UPSERT into discovery_papers
        ▼
  resolve_citations.py   → 4-tier per planet:
        │                    Tier 1: ADS bibcode (from disc_refname regex)
        │                    Tier 2: Crossref by DOI (from discovery_papers)
        │                    Tier 3: ADS title search (fuzzy match)
        │                    Tier 4: insert into citation_manual_queue
        │                  → UPSERT publications + planet_publications
        │                  → ADS quota circuit breaker on X-RateLimit-Remaining: 0
        ▼
  publish.py             → regenerate rss.xml + discoveries.json + health.json
```

The two enrichment passes run sequentially in `nightly.yml`; they could
run in parallel but the data volume per night is small enough that
sequential is simpler. `resolve_citations.py` runs after `enrich_ads.py`
because Tier 2 (Crossref by DOI) reads DOIs that `enrich_ads.py` cached
into `discovery_papers`.

dbt marts (`dim_planet`, `dim_publication`, etc.) deferred — not on the
critical path; the API serves directly from the public schema.

---

## Citation Resolution Strategy (as shipped)

`disc_refname` is HTML-embedded, not free text. It looks like:
> `<a href="https://ui.adsabs.harvard.edu/abs/2011ApJ...736...19B/abstract" target=_blank>Borucki et al. 2011</a>`

That HTML envelope makes Tier 1 trivial: regex out the bibcode and call
ADS. Tiers 2 and 3 are fallbacks for the small fraction of planets where
either the bibcode is missing/malformed or ADS itself is rate-limited.

Tiers (per planet, stop at first success):

1. **Tier 1 — ADS bibcode from `disc_refname`.** Regex `abs/([^/]+)/abstract`
   on the embedded URL, decode `%26` → `&`. Confidence: `high`.
   `resolved_via='ads_bibcode'`. Covers ~99% of catalog rows.
2. **Tier 2 — Crossref by DOI.** Pulls the DOI we already cached in
   `discovery_papers` (during `enrich_ads.py`) and queries Crossref's
   `/works/{doi}` endpoint. Confidence: `high`. `resolved_via='crossref_doi'`.
   Used as the fallback when Tier 1 fails (typically: ADS quota
   exhausted that day; a transient error during the title search; a
   handful of malformed bibcodes).
3. **Tier 3 — ADS title search.** Fuzzy `title:"…" author:"…"` search
   ranked by relevance. Confidence: `medium`. `resolved_via='ads_title'`.
   Rarely hit in practice.
4. **Tier 4 — `citation_manual_queue` insert.** No `publications` row;
   logged for human triage. Currently ~50 planets, mostly from
   long-tail edge cases (in-press references, malformed HTML, etc.).

**Why Crossref will likely be retired:** most Crossref-resolved rows
exist because ADS was rate-limited that day, not because ADS lacks the
paper. After a clean ADS run with full quota we expect to delete those
rows and re-resolve via ADS, leaving a 3-tier resolver.

**Anti-goal:** doing real NLP. This is regex + structured-API lookups.
The library-science contribution is the provenance trail
(`resolved_via` + `confidence` per row), not the parsing.

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
ship-quality is not.

### Phase 1 — shipped

5 consecutive green nightly runs since 2026-05-04 (Star Wars Day);
storage held steady by the rolling 2-day prune; data products committed
back to `main` automatically.

- ETL pipeline: `extract.py` (Exoplanet Archive TAP → R2 + manifest),
  `load.py` (R2 → Postgres UPSERT), dbt staging (`stg_pscomppars`),
  `diff.py` (field-tier-aware NEW/REMOVED/PARAMETER_CHANGE + auto-prune),
  `publish.py` (RSS + JSON + health snapshot)
- Schema with 28 typed columns + JSONB raw row preservation, 13 dbt tests
- Cloudflare R2 raw landing zone with sha256 manifest in git
- Field tier rules: 6 Tier A (RSS-surfaced), 13 Tier B (logged-only),
  rest Tier C (preserved but not diffed); 1% relative tolerance for
  floats with Tier A demotion / Tier B suppression of sub-tolerance changes
- Nightly GitHub Actions cron at 06:00 UTC; auto-issue-on-failure;
  results auto-committed back to `main` with `[skip ci]`
- FastAPI: 22 endpoints + automatic OpenAPI/Swagger docs (Phase 1 +
  Phase 2 endpoints)
- React frontend (Vite + TypeScript): search (planet + author),
  infinite-scroll catalog, planet detail with **procedural rendering**,
  full-screen system orbital view (true AU scaling, scroll-to-zoom),
  six retro display themes
- Vercel deployment serving both API (Python serverless) and React static
  build under one project at `exoplanet-citation.vercel.app`
- 78 unit tests + 13 dbt tests, all green; CI workflow with ruff lint
- Provenance per row: `source_url`, `source_retrieved_at`,
  `source_checksum`, `extraction_version`, `raw_row` JSONB
- Documentation: ARCHITECTURE.md, DATA_CATALOG.md, PROCEDURAL_RENDERING.md,
  THEMING.md, controlled-vocabulary YAMLs

### Phase 2 — substantially complete (93% citation coverage; final pass pending)

**Citation resolution — implemented:**
- `etl/sources/ads.py` (NASA ADS client with quota-aware circuit breaker;
  reads `X-RateLimit-Reset` header)
- `etl/sources/crossref.py` (DOI lookup, polite-pool with `mailto`)
- Migration `005_citation_graph.sql` adding `publications`,
  `planet_publications`, `citation_manual_queue`
- `etl/resolve_citations.py` — 4-tier strategy:
  Tier 1 (ADS bibcode from `disc_refname`)
  → Tier 2 (Crossref by known DOI)
  → Tier 3 (ADS title search)
  → Tier 4 (insert into `citation_manual_queue`)
- Resumable via `backfill_state` (batch_id `'citations'`)
- 5,856 / 6,286 planets resolved (93%); 50 in manual queue; 430 awaiting
  next ADS-quota window
- The arXiv API client was deferred — ADS already exposes arXiv IDs
  for cached papers, so it's not on the critical path

**ADS discovery-paper enrichment — implemented:**
- `etl/sources/ads.py` shared client
- `etl/enrich_ads.py` populates `discovery_papers` (~1,250 unique
  bibcodes today) with title, authors, abstract, citation_count, DOI,
  arXiv ID
- Migration `004_discovery_papers.sql`

**Gaia DR3 enrichment — done:**
- `etl/sources/gaia.py` (TAP client, batched)
- Migration `002_phase2_host_stars_gaia.sql`
- `etl/enrich_gaia.py` — UPSERTs into `host_stars_gaia` with resumable
  cursor; complete for 4,355 / 4,355 hosts that have a parsable Gaia DR3
  source ID

**API + UI extensions — implemented:**
- Endpoints: `/api/planets/{name}/publications` (with `co_planets` per
  publication for one-shot multi-planet UI), `/api/publications/{bibcode}`
  (publication + linked planets), `/api/authors/{name}/publications`,
  `/api/planets/{name}/host_star`, `/api/planets/{name}/paper`,
  `/api/authors/top`, `/api/authors/search`, `/api/rss/{*}` (per-planet,
  per-system, per-author RSS), `/api/health` with storage warning
- Frontend: discovery section on PlanetDetail surfaces "this paper also
  announced N planets" with collapsible `+N more` expansion;
  AuthorDetail page; per-feed RSS subscribe links

**Phase 2 — remaining:**
- One more clean ADS run after the rolling 24h quota window resets, to
  close the final 7% citation coverage gap
- Crossref purge + ADS re-resolution: once ADS coverage hits 100%,
  `DELETE FROM publications WHERE resolved_via='crossref_doi'` and rerun
  to upgrade those rows with richer ADS metadata (abstract, ADS bibcode,
  ADS citation count). Then delete `etl/sources/crossref.py`.
- dbt marts (`dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`) — deferred; the API serves directly from
  the public schema today and the marts aren't blocking anything
- Optional: `docs/CITATION_RESOLUTION.md` writeup with confidence rubric
  and resolution-rate KPI tracking
- Optional: storage warning surfaced in the UI (data is in `/api/health`
  already, just needs a footer/header treatment)
- Optional: manual-queue triage UI for the ~50 queued planets

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
