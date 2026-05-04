# Project 2 — Near-Earth Object Risk Warehouse

**Owner:** Mark Pernotto (mark@pernotto.com)
**Status:** Planning
**Target effort:** ~3 weeks part-time
**Repo (proposed):** `github.com/markpernotto/neo-warehouse`
**Prerequisite:** Project 1 (Exoplanet Warehouse) shipped — this project reuses the chassis (Postgres/Neon, dbt, GH Actions, FastAPI, React, R2, Fly, Vercel, Terraform).

---

## One-paragraph pitch

A public data warehouse and alerting feed for near-Earth objects (asteroids and comets that pass close to Earth's orbit). Daily ETL ingests NASA JPL's Small-Body Database, the CNEOS close-approach feed, and ESA's NEO Coordination Centre. The warehouse exposes "what's passing close this week, how big, how confident is the orbit determination, and how does it compare to historical close approaches." Public RSS/JSON alerts fire when something larger than 50 m passes inside the lunar distance. The framing is unambiguously public-service: this is the same data NASA's planetary-defense office monitors.

---

## Why this project

- **Cleanest "obvious DE" project of the three.** Tabular, well-documented APIs, clear update cadences, classic SCD-2 problem (orbit determinations are revised over time as more observations come in).
- **Public-service framing reads instantly.** "Planetary defense alerts" needs no explanation in a portfolio README.
- **Reuses ~80% of Project 1's chassis.** The toolchain investment from Project 1 pays the dividend here. Nightly cron, snapshot/diff/publish pattern, controlled-vocabulary discipline — all carry over.
- **Schema work is the interesting part.** Orbit elements have observational uncertainties. Modeling "the same object across multiple orbit-determination revisions" cleanly is genuinely a real DE problem.
- **No moral controversy whatsoever.** Asteroids are uniformly fascinating across the political spectrum.

---

## Definition of Done

### Phase 1 (Weeks 1–2): Close-Approach Watcher
- [ ] Repo public on GitHub
- [ ] Nightly GitHub Action ingests CNEOS close-approach data + JPL SBDB queries for any new objects
- [ ] Postgres (Neon) contains a historical record of every close approach observed
- [ ] Diff job emits `NEW_APPROACH`, `REVISED_APPROACH`, `NEW_OBJECT`, `RISK_CLASS_CHANGE` events
- [ ] Public RSS feed of close approaches in the next 60 days
- [ ] Public RSS feed of "noteworthy" approaches (≥50 m, inside lunar distance) — separate firehose
- [ ] Public JSON endpoints: `/api/approaches/upcoming`, `/api/approaches/recent`, `/api/objects/{designation}`
- [ ] Minimal React page shows upcoming approaches in a sortable table with columns: object, date, distance (LD), velocity, est. diameter, risk class
- [ ] README with architecture diagram, data sources, attribution, how-to-run
- [ ] `DATA_CATALOG.md` entries for SBDB and CNEOS
- [ ] Controlled-vocabulary files for `orbit_class`, `risk_class`, `approach_event_type`
- [ ] Freshness SLO: published data ≤ 26 hours stale from source
- [ ] pytest suite covers extract, transform, diff, load idempotency, alert-threshold logic
- [ ] Action has been green for 5 consecutive nights

### Phase 2 (Week 3): Risk Warehouse + Historical Comparator
- [ ] dbt project: `raw` → `staging` → `marts` with `dim_object`, `dim_orbit_revision`, `fact_close_approach`, `fact_risk_assessment`
- [ ] SCD-2 modeling for orbit determinations (each revision keyed by `solution_date`)
- [ ] ESA NEOCC risk list ingested and joined to JPL data (cross-agency reconciliation)
- [ ] Sentry impact-risk feed ingested (NASA's official risk list)
- [ ] Public endpoint: `/api/objects/{designation}/orbit-history` — full revision timeline
- [ ] Public endpoint: `/api/comparisons/{designation}` — "this approach is the Nth-closest of size class X since 1900"
- [ ] React UI gains: object detail page with orbit-revision timeline; "compare to historical" panel
- [ ] dbt tests pass in CI; `dbt docs` published
- [ ] README v2 explains the SCD-2 orbit-revision modeling explicitly — that's the portfolio gold here

---

## Data Sources

All public. Attribute the agency in README and in-app. NASA/JPL data is in the public domain; ESA NEOCC has its own attribution requirements.

| Source | URL | Format | Update | Phase | Notes |
|---|---|---|---|---|---|
| JPL Small-Body Database (SBDB) Query API | https://ssd-api.jpl.nasa.gov/sbdb_query.api | JSON | Continuous | 1+2 | Primary source for orbital elements + physical properties |
| JPL SBDB Lookup API | https://ssd-api.jpl.nasa.gov/sbdb.api | JSON | Continuous | 1+2 | Single-object lookup with full orbit-determination history |
| NASA CNEOS Close-Approach Data | https://ssd-api.jpl.nasa.gov/cad.api | JSON | Daily | 1+2 | THE close-approach feed; configurable by date range, distance, body |
| NASA Sentry Impact Risk | https://ssd-api.jpl.nasa.gov/sentry.api | JSON | Continuous | 2 | Official NASA list of objects with non-zero impact probability |
| NASA NEOWS (Near-Earth Object Web Service) | https://api.nasa.gov/neo/rest/v1/ | JSON | Daily | 1 (alt) | Friendlier API than SBDB; rate-limited but free with API key |
| ESA NEOCC Risk List | https://neo.ssa.esa.int/PSDB-portlet/download | JSON/CSV | Daily | 2 | European cross-check on NASA data |
| Minor Planet Center (MPC) MPCORB | https://www.minorplanetcenter.net/iau/MPCORB.html | DAT | Daily | 2 (optional) | Authoritative orbit catalog; large file, only worth it for completeness |

### Source-of-truth notes
- The CNEOS feed is the operational firehose. SBDB is the reference catalog. Use CNEOS for "what's coming up" and SBDB to enrich with physical properties.
- Sentry is its own list — only objects with computed impact probability > 0. Most NEOs are *not* on Sentry.
- ESA NEOCC and NASA Sentry sometimes disagree on risk classification; that disagreement is itself useful warehouse content (`fact_risk_assessment` joins both).

---

## Schema (Phase 1)

### `objects_snapshots` (raw landing)

```sql
snapshot_date          DATE NOT NULL
designation            TEXT NOT NULL          -- e.g. "(99942) Apophis", "2024 YR4", "C/2023 A3"
spkid                  TEXT NOT NULL          -- JPL SPK-ID, more stable than designation
full_name              TEXT
neo                    BOOLEAN                -- is this a near-Earth object
pha                    BOOLEAN                -- is this a potentially hazardous asteroid
orbit_class            TEXT                   -- "AMO", "APO", "ATE", "IEO" etc.
absolute_magnitude_h   DOUBLE PRECISION       -- H, used to estimate diameter
diameter_km            DOUBLE PRECISION       -- if directly measured
diameter_estimate_km   DOUBLE PRECISION       -- derived from H + albedo
albedo                 DOUBLE PRECISION
rotation_period_h      DOUBLE PRECISION
spec_class             TEXT                   -- spectral classification when known
first_observed         DATE
last_observed          DATE
observation_arc_days   INT
n_observations         INT
solution_date          DATE NOT NULL          -- date of orbit-determination solution
raw_row                JSONB
source_url             TEXT NOT NULL
source_retrieved_at    TIMESTAMPTZ NOT NULL
source_checksum        TEXT NOT NULL
extraction_version     TEXT NOT NULL
PRIMARY KEY (snapshot_date, spkid)
```

### `orbit_elements_snapshots` (raw landing)

Separated from `objects_snapshots` because orbit elements are revised independently and we want to track every revision.

```sql
spkid                  TEXT NOT NULL
solution_date          DATE NOT NULL          -- the revision identifier
epoch                  DOUBLE PRECISION       -- Julian Date
e                      DOUBLE PRECISION       -- eccentricity
a                      DOUBLE PRECISION       -- semi-major axis (AU)
i                      DOUBLE PRECISION       -- inclination (deg)
om                     DOUBLE PRECISION       -- longitude of ascending node
w                      DOUBLE PRECISION       -- argument of perihelion
ma                     DOUBLE PRECISION       -- mean anomaly
sigma_e                DOUBLE PRECISION       -- 1-sigma uncertainty in e
sigma_a                DOUBLE PRECISION
sigma_i                DOUBLE PRECISION
covariance             JSONB                  -- full covariance matrix when available
raw_row                JSONB
source_retrieved_at    TIMESTAMPTZ NOT NULL
PRIMARY KEY (spkid, solution_date)
```

### `close_approaches_snapshots` (raw landing)

```sql
snapshot_date          DATE NOT NULL
spkid                  TEXT NOT NULL
designation            TEXT NOT NULL
approach_date          TIMESTAMPTZ NOT NULL   -- the moment of closest approach
body                   TEXT NOT NULL          -- usually "Earth", but CNEOS includes Moon, Mars, etc.
distance_au            DOUBLE PRECISION NOT NULL
distance_ld            DOUBLE PRECISION       -- lunar distances
distance_min_au        DOUBLE PRECISION       -- 1-sigma minimum
distance_max_au        DOUBLE PRECISION       -- 1-sigma maximum
v_rel_km_s             DOUBLE PRECISION       -- relative velocity
v_inf_km_s             DOUBLE PRECISION       -- velocity at infinity
solution_date          DATE NOT NULL
raw_row                JSONB
source_retrieved_at    TIMESTAMPTZ NOT NULL
PRIMARY KEY (snapshot_date, spkid, approach_date, body)
```

### `approach_events` (derived)

```sql
event_id               BIGSERIAL PRIMARY KEY
observed_at            TIMESTAMPTZ NOT NULL
spkid                  TEXT NOT NULL
approach_date          TIMESTAMPTZ NOT NULL
event_type             TEXT NOT NULL          -- NEW_APPROACH, REVISED_APPROACH, RISK_CLASS_CHANGE, NEW_OBJECT
prev_value             JSONB
new_value              JSONB
diff_summary           TEXT
INDEX (observed_at DESC), INDEX (spkid), INDEX (approach_date)
```

---

## Schema (Phase 2 additions)

### `risk_assessments`

```sql
spkid                  TEXT NOT NULL
agency                 TEXT NOT NULL          -- 'NASA_SENTRY' | 'ESA_NEOCC'
risk_class             TEXT                   -- agency-specific (Torino, Palermo, ESA risk list rank)
torino_scale           INT                    -- 0–10 if NASA Sentry
palermo_scale          DOUBLE PRECISION
impact_probability     DOUBLE PRECISION
potential_impact_date  TIMESTAMPTZ
energy_mt              DOUBLE PRECISION       -- estimated impact energy (megatons TNT)
assessment_date        DATE NOT NULL
raw_row                JSONB NOT NULL
PRIMARY KEY (spkid, agency, assessment_date)
```

### dbt mart layer

- `dim_object` — one row per NEO with current best parameters and SCD-2 versioning on physical properties
- `dim_orbit_revision` — one row per (spkid, solution_date) pair with full element set + uncertainty
- `fact_close_approach` — one row per observed close approach, joined to the orbit revision that predicted it
- `fact_risk_assessment` — one row per (spkid, agency, assessment_date) with cross-agency comparison views
- `mart_upcoming_approaches` — denormalized "next 60 days" view for the public API to read directly

---

## Pipeline

### Phase 1

```
JPL CNEOS Close-Approach API ─┐
JPL SBDB Query API ───────────┼─► nightly cron (GitHub Actions, 06:30 UTC)
                              │
                              ▼
  extract.py       → data/snapshots/YYYY-MM-DD/{cad,sbdb}.json (committed for small days, R2 for large)
        │
        ▼
  transform.py     → normalize, coerce, validate against controlled vocabularies
        │
        ▼
  load.py          → UPSERT into objects_snapshots, orbit_elements_snapshots, close_approaches_snapshots
        │
        ▼
  diff.py          → compare today vs. yesterday → approach_events
        │
        ▼
  alerts.py        → check threshold rules → publish noteworthy.rss + noteworthy.json
        │
        ▼
  publish.py       → regenerate full feeds + endpoints
        │
        ▼
  FastAPI / Vercel
```

### Phase 2 additions

```
NASA Sentry + ESA NEOCC ─► risk_extract.py → risk_assessments
                                │
                                ▼
                          dbt run → marts
                                │
                                ▼
                          publish.py → /api/objects/{designation}/orbit-history,
                                       /api/comparisons/{designation}
```

---

## Alert Threshold Logic (Phase 1 — the operational interesting part)

The "noteworthy" RSS feed is the user-facing trust point. Threshold rules:

1. **Size + distance:** estimated diameter ≥ 50 m AND distance ≤ 1 lunar distance (LD)
2. **Very-close regardless of size:** distance ≤ 0.5 LD (≈ half the Earth-Moon distance)
3. **Newly-discovered with short observation arc:** any new object whose first close approach is within 30 days AND observation arc < 14 days (these are the "found late" objects — operationally interesting because their orbits are still uncertain)
4. **Risk class change:** Phase 2 only — anything that gets added to or moves up on the Sentry list

Each rule is implemented as a pure function in `etl/alerts.py`, fully tested with fixture data. The README documents the rules in plain English with rationale. **This is the part that earns the "operational DE" label** — alerting logic with documented thresholds, idempotent firing (don't re-alert on the same approach), and rule-by-rule provenance on each alert.

---

## SCD-2 Orbit-Revision Modeling (Phase 2 — the schema interesting part)

Orbit determinations are revised whenever new observations come in. For an actively-tracked NEO, this can happen weekly. The "current" orbit elements as of any given date are a function of `(spkid, solution_date)` — classic SCD-2.

The chassis from Project 1 doesn't fully exercise SCD-2; this project does. `dim_orbit_revision` keeps every revision keyed by `(spkid, solution_date)` with `valid_from` and `valid_to` columns. Queries against `fact_close_approach` join to the revision that was current at the time the approach was *predicted*, so the warehouse can answer "what did we think this orbit looked like last March, vs. what we know now?"

This is the kind of question operations teams actually ask. Documenting it well in `docs/SCD_MODELING.md` is the portfolio gold.

---

## Repository Layout

```
neo-warehouse/
├── .github/workflows/
│   ├── nightly.yml
│   ├── risk-refresh.yml          # daily, Phase 2 — Sentry/NEOCC pull
│   └── ci.yml
├── etl/
│   ├── sources/
│   │   ├── jpl_sbdb.py
│   │   ├── jpl_cneos.py
│   │   ├── jpl_sentry.py         # Phase 2
│   │   └── esa_neocc.py          # Phase 2
│   ├── transform/                # dbt project root
│   │   ├── dbt_project.yml
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   └── marts/
│   │   └── tests/
│   ├── extract.py
│   ├── load.py
│   ├── diff.py
│   ├── alerts.py
│   ├── publish.py
│   └── schema.sql
├── vocabularies/
│   ├── orbit_class.yaml          # AMO, APO, ATE, IEO, MCA, etc.
│   ├── risk_class.yaml           # Torino, Palermo, NEOCC scale terms
│   ├── approach_event_type.yaml
│   └── alert_rule.yaml
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
│   ├── test_alerts.py            # critical — these rules ship public alerts
│   └── fixtures/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_CATALOG.md
│   ├── DATA_SOURCES.md
│   ├── ALERT_RULES.md            # plain-English documentation of thresholds
│   ├── SCD_MODELING.md           # Phase 2 — the orbit-revision modeling writeup
│   └── diagrams/
├── infra/
│   └── main.tf
├── Dockerfile
├── docker-compose.yml
├── LICENSE                        # MIT
├── LICENSE-DATA                   # CC0 (NASA data is public domain; ESA attribution honored in README)
├── PRIVACY.md
├── pyproject.toml
├── README.md
└── .env.example
```

---

## Three-Week Timeline

### Week 1 — ETL core + first working diff (Phase 1)

**Day 1 (Mon)**
- Initialize repo, `pyproject.toml`, dependencies (`httpx`, `pandas`, `psycopg[binary]`, `pyyaml`, `pytest`, `python-dotenv`, `tenacity` for retries)
- Provision Neon DB (new schema in the same project as Project 1, or a fresh project — recommend fresh for clarity)
- `schema.sql` for Phase 1 tables
- Manually pull a sample CNEOS day + an SBDB sample for one famous object (Apophis is the canonical reference); commit as fixtures
- Stub vocabulary YAMLs

**Day 2 (Tue)**
- `etl/sources/jpl_cneos.py` — wrap the CAD API; pagination if needed
- `etl/sources/jpl_sbdb.py` — wrap SBDB Query for batch + Lookup for single-object enrichment
- Write `transform.py` against fixture data
- `tests/test_transform.py` with fixture JSON

**Day 3 (Wed)**
- `load.py` — UPSERTs across three tables
- `diff.py` — handle `NEW_APPROACH`, `REVISED_APPROACH`, `NEW_OBJECT`. Idempotent.
- `tests/test_diff.py` — ≥ 8 cases including idempotency

**Day 4 (Thu)**
- `alerts.py` — implement threshold rules 1, 2, 3 from the alert-logic section
- `tests/test_alerts.py` — exhaustive cases per rule (this is what users actually trust; over-test it)
- End-to-end test: empty DB → seed → diff → alerts

**Day 5 (Fri)**
- `DATA_CATALOG.md` entries for SBDB, CNEOS
- `docs/ALERT_RULES.md` — plain-English documentation
- `docs/ARCHITECTURE.md` Phase 1 diagram

**Weekend buffer.**

### Week 2 — Publishing, UI, polish (Phase 1 ships)

**Day 6 (Mon)**
- `publish.py` — regenerate `public/upcoming.rss`, `public/noteworthy.rss`, `public/upcoming.json`
- Snapshot retention (30 days loose + monthly tarball)

**Day 7 (Tue)**
- `.github/workflows/nightly.yml` — cron `30 6 * * *`
- DB URL in repo secret
- Manual test runs, verify green
- Auto-issue-on-failure

**Day 8 (Wed)**
- FastAPI: `/api/approaches/upcoming`, `/api/approaches/recent`, `/api/objects/{designation}`, `/api/objects/{designation}/approaches`
- Deploy to Fly.io

**Day 9 (Thu)**
- React: upcoming-approaches table (sortable by date, distance, size, velocity), noteworthy-only filter, per-object page
- Use a real diameter-vs-distance scatter plot — this is the kind of viz that makes a portfolio README screenshot pop
- Deploy to Vercel

**Day 10 (Fri)**
- README v1 — architecture diagram, sources, alert-rule explanation, freshness SLO, screenshot
- Populate `DATA_CATALOG.md`, `PRIVACY.md`, `LICENSE`, `LICENSE-DATA`

**Days 11–14 (buffer):** Bug fixes. Don't call Phase 1 shipped until nightly has been green 5 consecutive nights. **At end of Week 2: Phase 1 is publicly shipped.**

### Week 3 — Risk warehouse + historical comparator (Phase 2 ships)

**Day 15 (Mon)**
- `etl/sources/jpl_sentry.py` and `etl/sources/esa_neocc.py`
- Schema migration: `risk_assessments`
- Daily refresh workflow `risk-refresh.yml`

**Day 16 (Tue)**
- Initialize dbt project under `etl/transform/`
- `staging` models for all four sources
- `marts/dim_object`, `marts/dim_orbit_revision` (with SCD-2 logic)

**Day 17 (Wed)**
- `marts/fact_close_approach`, `marts/fact_risk_assessment`, `marts/mart_upcoming_approaches`
- dbt tests: not_null, unique, relationships, plus custom test "every fact_close_approach joins to a valid orbit revision"

**Day 18 (Thu)**
- `/api/objects/{designation}/orbit-history`
- `/api/comparisons/{designation}` — implement "Nth-closest of size class X since 1900" with a windowed query
- Cache aggressively; comparisons are read-heavy

**Day 19 (Fri)**
- React: object detail page gains orbit-revision timeline + historical-comparison panel
- Deploy `dbt docs` to GitHub Pages
- README v2 — lead with SCD-2 modeling and cross-agency reconciliation

**Days 20–21 (buffer):** Polish. Cut v1.0. **At end of Week 3: Phase 2 is publicly shipped.**

---

## Risk Register

| Risk | Mitigation |
|---|---|
| JPL APIs change response schema | `raw_row JSONB` preserves source row; transforms log unknown fields rather than failing |
| CNEOS rate limits or blocks our scraper | We're hitting public APIs at 1 request/day per endpoint — well within polite use. `User-Agent` identifies the project. If issues, switch to NEOWS as alt source. |
| Alert rules fire spuriously and erode trust | Test exhaustively. Document each rule and its rationale. Include a "false-alarm policy" in `ALERT_RULES.md`: alerts are NEVER retracted; corrections are appended. |
| Orbit revisions arrive faster than nightly cadence | Acceptable for v1.0. If needed, increase to 6-hourly for the CNEOS feed only. |
| ESA NEOCC and NASA Sentry disagree | This is content, not a bug. `fact_risk_assessment` exposes the disagreement explicitly. |
| Sentry list is empty or has very few entries | This is normal — most days, no objects have non-zero impact probability. UI must handle empty-list gracefully. |
| Schema drift in CNEOS solution_date semantics | Document the JPL convention in `docs/DATA_SOURCES.md`. Cite the JPL Horizons documentation. |
| Timeline slips | Acceptable to 4 weeks. Risk warehouse (Phase 2) can be cut to "Sentry only, no ESA" if Week 3 runs tight. |

---

## Stretch Goals (post-v1.0, not in scope)

- 3D orbit visualization in the UI (three.js + skyfield)
- Predicted-vs-observed close-approach reconciliation (compare last year's prediction for today vs. today's actual approach)
- Historical close-approach corpus extending to 1900 (requires Horizons API integration)
- Notification delivery beyond RSS — email, Mastodon bot, ATproto firehose

---

## Open Questions (resolve before Day 1)

1. **NASA API key for NEOWS.** Free, instant from https://api.nasa.gov. Get one even if we don't end up using NEOWS as primary — it's the fallback.
2. **Repo name.** `neo-warehouse` vs `planetary-defense-data` vs `near-earth-objects`. First is shortest; second is most evocative.
3. **Database isolation.** Same Neon project as Project 1 (different schema) vs new Neon project. Recommend: **new project**, so each repo is fully independent and easier to hand to a hiring manager who wants to clone-and-run.
4. **How far back to backfill close approaches.** CNEOS has data going back decades. Recommend backfilling 1 year of history on Day 1 to populate the UI; deeper history can wait for Phase 2 or stretch goals.

---

## What Not To Add

- Authentication / user accounts
- "Subscribe to alerts" infrastructure beyond RSS (no email service, no push, no SMS in v1.0)
- Predictive risk modeling — the agencies do this; we don't compete
- Any modification of NASA's risk classifications — we report, we don't reinterpret
- "Will this hit my city" calculators — irresponsible without rigor
- Comet-specific physical modeling (sublimation, tail dynamics) — out of scope, classic asteroid/NEO focus only
