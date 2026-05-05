# Project 1 — Exoplanet Discovery & Citation Warehouse

**Owner:** Mark Pernotto (mark@pernotto.com)
**Status:** Phase 1 nearly complete as of 2026-05-05. ETL pipeline live on GitHub Actions cron; FastAPI + React frontend deployed to Vercel (live at exoplanet-citation.vercel.app); ~6,300 confirmed planets loaded; Gaia DR3 client scaffolded for Phase 2. Remaining Phase 1 work is the formal ship bar (5 consecutive green nights) and polish; Phase 2 is the next major milestone.
**Target effort:** ~4 weeks part-time (target, not deadline)
**Repo:** https://github.com/markpernotto/exoplanet_citation
**Implementation source-of-truth:** [PLAN.md](PLAN.md) — that file is authoritative for build details. This document is the portfolio-level framing.

---

## One-paragraph pitch

A public data warehouse that ingests the NASA Exoplanet Archive, joins each confirmed exoplanet to the scientific paper(s) that announced it (via DOI / arXiv / NASA ADS), and publishes a browsable, citable catalog with a public API and a public alert feed for newly-confirmed exoplanets. The distinguishing move is the **citation graph**: every planet in the warehouse traces back to its discovery publication and follow-up papers, with provenance and confidence scores on the joins. This is library science applied to the largest active discovery effort in modern astronomy.

---

## Why this project

- **Library-science angle is unmistakable.** A citation graph between observations and publications is *the* archetype of bibliographic work, applied to a domain (exoplanets) that hiring managers find immediately interesting.
- **The data is alive.** The Exoplanet Archive updates weekly; new exoplanets are confirmed multiple times per month. There's always something to alert on.
- **The DE problems are real, not toy.** Fuzzy entity resolution (matching planet names across catalogs), DOI/arXiv ID normalization, slowly-changing dimensions (planet parameters get refined over time), and joining heterogeneous APIs are all things that show up in real DE work.
- **Phased delivery works cleanly.** A small "newly-confirmed exoplanets" watcher ships in two weeks; the citation warehouse layered on top takes another two.

---

## Definition of Done

### Phase 1 (Weeks 1–2): "New Exoplanet" Watcher
- [ ] Repo public on GitHub at `markpernotto/exoplanet_citation`
- [ ] Nightly GitHub Action ingests NASA Exoplanet Archive's `pscomppars` (Composite Parameters) table via TAP
- [ ] Postgres (Neon) contains historical snapshots of the archive
- [ ] Snapshots stored in Cloudflare R2; `data/MANIFEST.jsonl` in git tracks date / R2 key / sha256 / row count per snapshot
- [ ] dbt project initialized and used for staging from Day 2 (not bolted on later)
- [ ] Diff job emits a feed of `NEW`, `REMOVED`, and `PARAMETER_CHANGE` events using a defined Tier A / Tier B / Tier C field allowlist (see PLAN.md for the list)
- [ ] Public RSS feed of new confirmations (Tier A only)
- [ ] Public JSON endpoint at `/api/discoveries/latest` and `/api/discoveries/by-month/{yyyy-mm}`
- [ ] `/api/health` exposes freshness measurement (Clock B — see PLAN.md)
- [ ] Minimal React page shows the last 30 days of new/changed planets
- [ ] README with architecture diagram, data sources, attribution, how-to-run
- [ ] `DATA_CATALOG.md` entry for `pscomppars` with per-column tier assignments
- [ ] Controlled-vocabulary files for `discovery_method`, `discovery_facility`, `parameter_change_type`
- [ ] Freshness SLO: published data ≤ 26 hours from upstream `last_modified` (not from extract time)
- [ ] pytest suite covers extract success, transform idempotency, diff correctness, load idempotency, API response schema
- [ ] Action has been green for 5 consecutive nights

### Phase 2 (Weeks 3–4): Citation Warehouse
- [ ] Each confirmed planet linked to ≥1 discovery publication via DOI or arXiv ID, where resolvable
- [ ] Resolution confidence score per link (high / medium / low) with human-readable reason
- [ ] Crossref + arXiv + NASA ADS metadata cached in `publications` table
- [ ] dbt marts: `dim_planet`, `dim_publication`, `fact_discovery`, `fact_parameter_revision`
- [ ] Backfill of all ~5,500 existing planets completed via resumable batched script
- [ ] Public endpoints: `/api/planets/{name}`, `/api/planets/{name}/publications`, `/api/publications/{doi}`, `/api/publications/{doi}/planets`
- [ ] Browsable React UI: planet detail page shows discovery paper; publication detail page shows all planets it discusses
- [ ] dbt tests pass in CI; `dbt docs` published to GitHub Pages or Vercel
- [ ] `DATA_CATALOG.md` extended with publication sources (Crossref, arXiv, ADS)
- [ ] `docs/CITATION_RESOLUTION.md` documents tier strategy + current resolution rate
- [ ] README v2 explains the citation-graph contribution explicitly

### Phase 3 (post-v1.0, decision after Phase 2 ships)
- [ ] For each discovery publication, query ADS for citing papers that mention the planet name in their abstract
- [ ] `planet_publications.relationship = 'follow_up'` rows populated
- [ ] UI: planet detail page shows follow-up papers grouped by year

The follow-up paper graph is the most novel piece of the project and the most open-ended (ADS rate limits, ranking, UI). Keeping it out of v1.0 lets v1.0 ship cleanly. Decision to actually build Phase 3 is made after Phase 2 based on resolution rate.

---

## Data Sources

All public. Attribute the agency in README and in-app. Use a `User-Agent` identifying the project and a contact email. Respect rate limits.

| Source | URL | Format | Update | Phase | Notes |
|---|---|---|---|---|---|
| NASA Exoplanet Archive — `pscomppars` (Composite Parameters) | https://exoplanetarchive.ipac.caltech.edu/TAP | TAP / VOTable / CSV | Weekly | 1+2 | **Phase 1 primary source.** One row per planet with archive-preferred parameter values. ~5,500 planets. |
| NASA Exoplanet Archive — `ps` (Planetary Systems, full) | same TAP | TAP / VOTable / CSV | Weekly | 2 | Multi-row per planet (one row per published parameter set). Used for `fact_parameter_revision` only. |
| NASA Exoplanet Archive — TESS Project Candidates | same TAP | TAP / VOTable / CSV | Frequent | 2 | Candidates not yet confirmed; useful for "candidate vs confirmed" analytics |
| Crossref REST API | https://api.crossref.org/works/{doi} | JSON | On demand | 2 | Resolve DOI → publication metadata. Free, polite-pool with email |
| arXiv API | http://export.arxiv.org/api/query | Atom | On demand | 2 | Resolve arXiv ID → preprint metadata |
| NASA ADS API | https://api.adsabs.harvard.edu/v1 | JSON | On demand | 2 | Best-in-class astronomy citation database. Free with API key. |
| ROR (Research Org Registry) | https://api.ror.org/organizations | JSON | On demand | 2 (optional) | Normalize discovery facility names to ROR IDs |

### Source-of-truth notes
- The Exoplanet Archive's own `pl_pubdate` and `pl_refname` fields are the starting point for citation resolution but they are **strings, not DOIs** — converting these into structured citations is a meaningful piece of the project.
- ADS is the gold standard for astronomy bibliography but rate-limited; cache aggressively.
- Crossref is the gold standard for DOI resolution generally; combine with ADS for the best coverage.

---

## Schema (Phase 1)

> **Note on PK choice:** `pscomppars` is one-row-per-planet so `(snapshot_date, pl_name)` is a safe primary key. The full `ps` table is *not* one-row-per-planet (multiple parameter sets per planet, per reference) and would silently collapse rows under this PK — that's why Phase 1 uses `pscomppars` and `ps` is deferred to Phase 2 for `fact_parameter_revision`. See [PLAN.md](PLAN.md) for full schema including `backfill_state` and field-tier columns.

### `planets_snapshots` (raw landing)

```sql
snapshot_date          DATE NOT NULL
pl_name                TEXT NOT NULL          -- canonical planet name e.g. "Kepler-22 b"
hostname               TEXT NOT NULL          -- host star name
sy_snum                INT                    -- number of stars in system
sy_pnum                INT                    -- number of planets in system
discoverymethod        TEXT                   -- e.g. "Transit", "Radial Velocity"
disc_year              INT
disc_facility          TEXT
disc_telescope         TEXT
disc_instrument        TEXT
disc_refname           TEXT                   -- raw reference string from archive
pl_orbper              DOUBLE PRECISION       -- orbital period (days)
pl_rade                DOUBLE PRECISION       -- radius (Earth radii)
pl_bmasse              DOUBLE PRECISION       -- mass (Earth masses)
pl_eqt                 DOUBLE PRECISION       -- equilibrium temperature (K)
st_dist                DOUBLE PRECISION       -- distance to host star (parsecs)
default_flag           BOOLEAN                -- "best" parameter row flag from source
raw_row                JSONB                  -- full source row
source_url             TEXT NOT NULL
source_retrieved_at    TIMESTAMPTZ NOT NULL
source_checksum        TEXT NOT NULL
extraction_version     TEXT NOT NULL
PRIMARY KEY (snapshot_date, pl_name)
```

### `discovery_changes` (derived)

```sql
change_id              BIGSERIAL PRIMARY KEY
observed_at            TIMESTAMPTZ NOT NULL
pl_name                TEXT NOT NULL
change_type            TEXT NOT NULL          -- NEW, REMOVED, PARAMETER_CHANGE
field_name             TEXT                   -- non-null for PARAMETER_CHANGE
prev_value             JSONB
new_value              JSONB
diff_summary           TEXT                   -- human-readable
source_snapshot_date   DATE NOT NULL
INDEX (observed_at DESC), INDEX (pl_name), INDEX (change_type)
```

### `planets_current` (view)

Plain view over the most recent snapshot — ~5,500 rows, materialization not worth it in Phase 1.

---

## Schema (Phase 2 additions)

### `publications`

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

### `planet_publications` (the citation graph)

```sql
pl_name                TEXT NOT NULL
publication_id         BIGINT NOT NULL REFERENCES publications(publication_id)
relationship           TEXT NOT NULL           -- 'discovery' | 'follow_up' | 'parameter_revision'
confidence             TEXT NOT NULL           -- 'high' | 'medium' | 'low'
confidence_reason      TEXT NOT NULL           -- e.g. "exact DOI from disc_refname"
extracted_from         TEXT NOT NULL           -- 'disc_refname' | 'pl_refname' | 'manual' | 'ads_query'
extracted_at           TIMESTAMPTZ NOT NULL
PRIMARY KEY (pl_name, publication_id, relationship)
```

### dbt mart layer

- `dim_planet` — one row per planet with current "best" parameters and key dates
- `dim_publication` — one row per resolved publication
- `fact_discovery` — one row per (planet, discovery-publication) pair
- `fact_parameter_revision` — one row per observed parameter change with the publication that motivated it (when resolvable)

---

## Pipeline

### Phase 1

```
NASA Exoplanet Archive TAP
        │
        ▼ nightly cron (GitHub Actions, 06:00 UTC)
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
  resolve_citation.py    → parse disc_refname → try DOI → try arXiv → try ADS
        │                  → write to publications + planet_publications
        ▼
  dbt run                → raw → staging → marts
        │
        ▼
  publish.py             → regenerate citation-graph endpoints
```

---

## Citation Resolution Strategy (Phase 2 — the interesting part)

The Exoplanet Archive's `disc_refname` field is a free-text bibliographic reference like:
> `Borucki W. J., et al. 2011, ApJ, 736, 19`

Resolving this to a DOI/arXiv ID is a real DE problem. Tiered strategy:

1. **Tier 1 — direct DOI present.** Some entries already include a DOI. Trivial, mark `confidence='high'`, `extracted_from='disc_refname'`.
2. **Tier 3 — Crossref title/author search.** Parse first-author surname + year + journal abbreviation, query Crossref `/works` with structured filters. If exactly one result matches author+year+journal, mark `confidence='medium'`. (Built second despite being labeled Tier 3 — see ordering note below.)
3. **Tier 2 — ADS bibcode lookup.** Construct the bibcode (`2011ApJ...736...19B`) from the reference string, query ADS, get DOI + metadata. Mark `confidence='high'` on exact match. Built last; runs across the queue and prior low-confidence rows to upgrade them.
4. **Tier 4 — manual review queue.** Anything unresolved goes into `data/unresolved.csv`. Manual workflow: open the CSV, fill in DOI/bibcode where you can resolve by hand, re-run `resolve_citation.py --from-manual`. No UI. Track resolution rate as a project KPI in the README.

**Tier ordering note:** Tier 2 (ADS) is the highest-coverage tier for astronomy citations but depends on the ADS API key, which can take days to be approved. We build Tier 1 + Tier 3 + Tier 4 first so we're not blocked, then add Tier 2 once the key is in hand. Tier 2 reprocesses anything earlier tiers left low-confidence or unresolved.

**Anti-goal:** doing real NLP. This is rule-based parsing with progressively wider nets. If a reference can't be resolved by Tier 3 (or upgraded by Tier 2), it goes to the queue — we don't train a model.

**Day 0 sanity check:** before locking the Phase 2 timeline, pull a sample of `disc_refname` (URL: `https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=SELECT+pl_name,disc_refname+FROM+pscomppars&format=csv`) and skim 100 values. If >30% are weird formats (concatenated multi-references, "in press", URL-only, conference proceedings), the resolution-rate target needs to be honest about it.

**Phase 3 (post-v1.0):** for each resolved discovery publication, query ADS for "papers that cite this paper AND mention this planet name in their abstract" to populate the `follow_up` relationship. This is where the project's output starts to look genuinely novel — and it's deferred out of v1.0 because it's open-ended.

---

## Repository Layout

```
exoplanet-warehouse/
├── .github/workflows/
│   ├── nightly.yml
│   ├── citation-resolver.yml     # weekly, Phase 2
│   └── ci.yml
├── etl/
│   ├── sources/
│   │   ├── exoplanet_archive.py
│   │   ├── crossref.py
│   │   ├── arxiv.py
│   │   └── ads.py
│   ├── transform/                # dbt project root
│   │   ├── dbt_project.yml
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   └── marts/
│   │   └── tests/
│   ├── extract.py
│   ├── load.py
│   ├── diff.py
│   ├── resolve_citation.py       # Phase 2
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
│   ├── snapshots/
│   └── archive/
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
│   ├── CITATION_RESOLUTION.md    # the methodology doc — this is portfolio gold
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

## Phases

This document is the **portfolio framing**. For the implementation status,
remaining-work breakdown, and component-level detail, see [PLAN.md](PLAN.md).

- **Phase 1 — done (formal ship pending 5 green nightly runs):** ETL pipeline,
  field-tier-aware diff, RSS+JSON+health feeds, FastAPI with 7 endpoints,
  React frontend with procedural planet rendering, all deployed to Vercel.
  64 unit tests + 13 dbt tests green.
- **Phase 2 — next:** citation resolution (Crossref + arXiv + ADS), Gaia DR3
  host-star enrichment, dbt marts (`dim_planet`, `dim_publication`, etc.),
  publication detail page, citation-graph health panel.
- **Phase 3 — post-v1.0:** follow-up paper graph via NASA ADS citation queries;
  galactic positioning view; optional PHL Habitable Exoplanets Catalog
  integration.

The "5 consecutive green nightly runs before Phase 1 ships" bar is intentional:
the project's distinguishing technical claim is reliability + provenance, so
the ship criterion is reliability-shaped, not feature-shaped.

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Exoplanet Archive TAP endpoint changes or rate-limits | Use `astroquery.ipac.nexsci.NasaExoplanetArchive` if direct TAP becomes painful; cache responses to R2 with snapshot retention |
| Citation resolution rate is embarrassingly low | Set a *target* in the README (e.g. "≥80% of discoveries have a resolved DOI"). If we can't hit it, document why honestly — that's a story too. |
| ADS API key access takes time | Apply on Day 1; in the meantime, Crossref + arXiv get us most of the way |
| Initial snapshot has nothing to diff against | First run emits zero changes, not errors. Document this in README. |
| Schema drift in source data | `raw_row JSONB` preserves source row; transforms log unknown enum values rather than failing |
| Neon free tier pauses after inactivity | ~2s cold start, acceptable for nightly batch |
| Committed snapshot CSVs bloat repo | 30 days loose, monthly tarball rollups |
| Scope creep into "build a NASA front-end" | Lock UI scope to: discoveries feed, planet detail, publication detail, resolution-rate panel. Nothing else in v1.0. |
| Timeline slips | Acceptable to 5 weeks. If 6+, ship Phase 1 alone and treat Phase 2 as a follow-on release. |

---

## Stretch Goals (post-v1.0, not in scope)

- Author disambiguation via ORCID resolution
- Discovery-facility normalization to ROR IDs
- A "citation graph" GraphQL endpoint
- A Sankey diagram of "discovery method → facility → year"
- Cross-link to the Mikulski Archive (MAST) for raw observation data

---

## Open Questions (resolved 2026-05-03)

1. **NASA ADS API key.** Apply ASAP at https://ui.adsabs.harvard.edu/user/settings/token. Day 0 / pre-work, not "before Day 1." Tier 2 of the citation resolver is sequenced *after* Tier 3 in build order so the project isn't blocked while approval is pending.
2. **Repo name.** `exoplanet_citation` (matches the GitHub URL the owner is using).
3. **Frontend hosting.** Vercel.
4. **Phase 1 historical backfill.** Yes — synthesize a month of "all NEW" events from `pl_pubdate` on Day 1. Tag synthetic-backfill rows clearly in the UI; flag in-app that `pl_pubdate` itself has data-quality issues.
5. **Phase 3 split.** The follow-up paper graph is split into Phase 3 (post-v1.0). Phase 2 ships citation resolution + dim/fact marts; Phase 3 adds the citing-paper graph if Phase 2's resolution rate makes it worthwhile.

---

## What Not To Add (in v1.0)

- Authentication / user accounts
- Comments, reviews, or social features on planets/papers
- ML-based reference parsing (Tier 4 unresolved goes to manual CSV queue, not a model)
- Other catalogs (MAST, SIMBAD, Gaia) — keep the source surface narrow
- A "compare two planets" tool — feature creep
- A Twitter/Mastodon bot — could be a separate weekend project but not part of v1.0
- The follow-up paper graph (this is Phase 3, post-v1.0 by design)
