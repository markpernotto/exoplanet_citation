# Project 3 — Central Oregon Satellite Pass Predictor

**Owner:** Mark Pernotto (mark@pernotto.com)
**Status:** Planning
**Target effort:** ~3 weeks part-time
**Repo (proposed):** `github.com/markpernotto/sky-pass-predictor`
**Prerequisite:** Projects 1 and 2 shipped — the chassis is mature; this project layers geospatial + sub-hourly cadence on top.

---

## One-paragraph pitch

A hyperlocal pass-prediction service for visible satellites — primarily the International Space Station and Starlink trains — over Central Oregon dark-sky locations (Bend, Sisters, Sunriver, Prineville Reservoir, Smith Rock). The pipeline ingests the public TLE catalog, computes pass predictions with `skyfield`, joins each predicted pass to NOAA's hourly cloud-cover forecast for the observer location, and publishes a "tonight in the sky" feed that says not just *what's passing* but *whether you'll actually see it*. Visually testable: the success criterion is "I walked outside at the predicted time and saw the predicted pass." The DE problems are real: TLE catalog curation across multiple sources, sub-hourly orchestration, and a geospatial join between point-observer and gridded-forecast data.

---

## Why this project

- **Most visually verifiable of the three.** The pipeline's correctness can be checked by walking outside. Hard to fake; great for portfolio screenshots ("here's the predicted pass / here's what I saw").
- **Hyperlocal Central Oregon angle.** Bend and surrounding areas are designated dark-sky communities; this is genuinely useful infrastructure for the local astronomy community, not just a portfolio piece.
- **Adds geospatial DE to the portfolio.** PostGIS, gridded-forecast joins, and a real-time-ish cadence are concretely different from Projects 1 and 2's daily batch pattern.
- **Library-science angle is present but quieter.** TLE catalog curation — deduplicating across CelesTrak, Space-Track, Heavens-Above; tracking element-set provenance — is bibliographic work applied to orbital data.
- **Fun.** This is the project that's most likely to get someone to actually click through your portfolio.

---

## Definition of Done

### Phase 1 (Weeks 1–2): ISS Pass Predictor for Bend
- [ ] Repo public on GitHub
- [ ] Hourly GitHub Action ingests TLE catalog from CelesTrak (Active Satellites set)
- [ ] Postgres+PostGIS (Neon) contains TLE history with full element-set provenance
- [ ] Pass-prediction job runs hourly, computes next 48 hours of ISS passes for Bend (44.0582° N, 121.3153° W)
- [ ] NOAA cloud-cover forecast fetched and joined to predicted passes
- [ ] Pass-quality scoring: max altitude, magnitude, illumination, *predicted cloud cover at pass time*
- [ ] Public RSS feed: "Visible from Bend tonight" (only passes that meet visibility thresholds)
- [ ] Public JSON endpoints: `/api/passes/upcoming?location=bend`, `/api/passes/upcoming?location={preset}`, `/api/satellites/{norad_id}`
- [ ] React page shows upcoming passes for the selected location with: start/peak/end time, max elevation, direction, magnitude, cloud-cover forecast, "visibility verdict" (Excellent / Good / Marginal / Skip)
- [ ] Five preset locations: Bend, Sisters, Sunriver, Prineville Reservoir, Smith Rock
- [ ] README with architecture diagram, data sources, attribution, how-to-run
- [ ] `DATA_CATALOG.md` entries for CelesTrak TLE catalog, NOAA NDFD/NBM
- [ ] Controlled-vocabulary files for `satellite_class`, `pass_quality`, `visibility_verdict`, `tle_source`
- [ ] Freshness SLO: TLE data ≤ 12 hours stale; cloud-cover forecast ≤ 6 hours stale
- [ ] pytest suite covers TLE parsing, pass prediction (with known good fixture), cloud-cover join, visibility scoring
- [ ] Action has been green for 5 consecutive days

### Phase 2 (Week 3): Starlink Trains + Multi-Satellite + Custom Locations
- [ ] Starlink train tracking — group recently-launched Starlink batches (within 30 days of launch) and predict the visible "train" passes
- [ ] Heavens-Above-style "all visible satellites tonight" feed — covers ISS, Tiangong (CSS), Hubble, NOAA satellites, ATV/Cygnus when present
- [ ] User-supplied location via lat/lon query parameter (`?lat=44.05&lon=-121.31`); preset shortcut still works
- [ ] Pass detail page: ground track on a map (Leaflet + PostGIS-rendered geometry)
- [ ] Historical pass log (passes that have already happened) — useful for "did I see this last night?" lookups
- [ ] iCal feed: subscribe to upcoming visible passes in your calendar app
- [ ] dbt project: `raw` → `staging` → `marts` with `dim_satellite`, `dim_tle_revision`, `fact_predicted_pass`, `fact_observation_window`
- [ ] dbt tests pass in CI; `dbt docs` published
- [ ] README v2 explains the geospatial join + sub-hourly orchestration explicitly

---

## Data Sources

All public. CelesTrak data is freely usable; Space-Track requires registration but is free; NOAA NDFD is public-domain US government data.

| Source | URL | Format | Update | Phase | Notes |
|---|---|---|---|---|---|
| CelesTrak Active Satellites TLEs | https://celestrak.org/NORAD/elements/gp.php?GROUP=active&FORMAT=tle | TLE | Several times daily | 1+2 | Primary TLE source. ~6,500 active satellites. No auth. |
| CelesTrak Stations | https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=tle | TLE | Several times daily | 1 | ISS, CSS, supply ships — focused subset. Use for Phase 1. |
| CelesTrak Starlink | https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=tle | TLE | Several times daily | 2 | Phase 2 — for train identification |
| Space-Track | https://www.space-track.org | TLE/JSON | Authoritative | 2 (optional) | Auth required (free); cross-check on CelesTrak provenance |
| NOAA National Digital Forecast Database (NDFD) — Sky Cover | https://digital.weather.gov/ | GRIB2 / DWML | Hourly | 1+2 | Gridded cloud-cover forecast. Use the API endpoint, not raw GRIB |
| NOAA National Blend of Models (NBM) | https://nomads.ncep.noaa.gov/pub/data/nccf/com/blend/prod/ | GRIB2 | Hourly | 2 (alt) | Higher-resolution alternative to NDFD |
| NOAA Aviation Weather METARs | https://aviationweather.gov/data/api/ | JSON | Hourly | 2 (optional) | Real-time observed cloud cover at Bend Airport (KBDN) — ground-truth |
| Heavens-Above (reference only) | https://www.heavens-above.com | HTML | — | — | Reference for the kind of UX we're building. We do not scrape this. |

### Source-of-truth notes
- TLEs are timestamped element sets; "current" TLE for any satellite is a function of `(norad_id, epoch)`. Same SCD-2 pattern as Project 2's orbit revisions.
- The relevant NOAA endpoint for our use case is the gridded `Sky Cover` forecast (sky cover percentage) at the requested lat/lon, hourly out to ~7 days.
- Local ground-truth via METAR is a stretch goal — useful for backtesting the cloud-cover join but not required for v1.0.

---

## Schema (Phase 1)

### `satellites` (slowly-changing reference)

```sql
norad_id               INT PRIMARY KEY
international_designator TEXT          -- e.g. "1998-067A" for ISS
name                   TEXT NOT NULL
satellite_class        TEXT            -- 'station' | 'transport' | 'starlink' | 'communications' | 'science' | ...
country                TEXT
launch_date            DATE
operational_status     TEXT            -- 'active' | 'decayed' | 'unknown'
notes                  TEXT
first_seen_at          TIMESTAMPTZ NOT NULL
last_seen_at           TIMESTAMPTZ NOT NULL
```

### `tle_revisions` (raw landing, SCD-2-flavored)

```sql
norad_id               INT NOT NULL
epoch                  TIMESTAMPTZ NOT NULL          -- TLE epoch from line 1
tle_line1              TEXT NOT NULL
tle_line2              TEXT NOT NULL
mean_motion            DOUBLE PRECISION
eccentricity           DOUBLE PRECISION
inclination_deg        DOUBLE PRECISION
raan_deg               DOUBLE PRECISION
arg_perigee_deg        DOUBLE PRECISION
mean_anomaly_deg       DOUBLE PRECISION
bstar                  DOUBLE PRECISION
tle_checksum           TEXT NOT NULL                  -- sha256 of the two-line set
source                 TEXT NOT NULL                  -- 'celestrak_active' | 'celestrak_stations' | 'space_track'
source_retrieved_at    TIMESTAMPTZ NOT NULL
PRIMARY KEY (norad_id, epoch, source)
```

### `observer_locations`

```sql
slug                   TEXT PRIMARY KEY               -- 'bend' | 'sisters' | 'sunriver' | 'prineville-reservoir' | 'smith-rock'
display_name           TEXT NOT NULL
geom                   GEOGRAPHY(POINT, 4326) NOT NULL
elevation_m            INT NOT NULL
timezone               TEXT NOT NULL DEFAULT 'America/Los_Angeles'
notes                  TEXT
```

### `predicted_passes`

```sql
pass_id                BIGSERIAL PRIMARY KEY
norad_id               INT NOT NULL REFERENCES satellites(norad_id)
location_slug          TEXT NOT NULL REFERENCES observer_locations(slug)
tle_epoch              TIMESTAMPTZ NOT NULL           -- which TLE revision generated this prediction
pass_start             TIMESTAMPTZ NOT NULL
pass_peak              TIMESTAMPTZ NOT NULL
pass_end               TIMESTAMPTZ NOT NULL
max_elevation_deg      DOUBLE PRECISION NOT NULL
start_azimuth_deg      DOUBLE PRECISION NOT NULL
peak_azimuth_deg       DOUBLE PRECISION NOT NULL
end_azimuth_deg        DOUBLE PRECISION NOT NULL
illuminated            BOOLEAN NOT NULL                -- is the satellite in sunlight while the observer is in darkness?
estimated_magnitude    DOUBLE PRECISION                -- standard satellite magnitude formula
ground_track           GEOGRAPHY(LINESTRING, 4326)     -- subsatellite track during the pass
predicted_at           TIMESTAMPTZ NOT NULL
UNIQUE (norad_id, location_slug, pass_start, tle_epoch)
INDEX (location_slug, pass_start), INDEX (norad_id, pass_start)
```

### `pass_forecasts`

Cloud-cover forecast joined to each predicted pass.

```sql
pass_id                BIGINT NOT NULL REFERENCES predicted_passes(pass_id)
forecast_issued_at     TIMESTAMPTZ NOT NULL
sky_cover_pct          INT NOT NULL                    -- 0–100
visibility_verdict     TEXT NOT NULL                   -- 'excellent' | 'good' | 'marginal' | 'skip'
verdict_reason         TEXT NOT NULL                   -- e.g. "max elev 67°, mag -3.1, sky cover 12%"
PRIMARY KEY (pass_id, forecast_issued_at)
```

---

## Schema (Phase 2 additions)

### `starlink_trains`

```sql
launch_designator      TEXT PRIMARY KEY                -- e.g. "Group 6-23"
launch_date            DATE NOT NULL
norad_ids              INT[] NOT NULL                  -- members of this train
train_window_days      INT NOT NULL DEFAULT 30         -- how long satellites stay grouped
notes                  TEXT
```

### `pass_observations` (user-reported, optional v2)

```sql
observation_id         BIGSERIAL PRIMARY KEY
pass_id                BIGINT NOT NULL REFERENCES predicted_passes(pass_id)
observed               BOOLEAN NOT NULL
notes                  TEXT
submitted_at           TIMESTAMPTZ NOT NULL
```

### dbt mart layer

- `dim_satellite` — current operational status, class, launch info
- `dim_tle_revision` — every TLE epoch with element values
- `fact_predicted_pass` — denormalized pass record with location + satellite + TLE provenance + cloud-cover verdict
- `fact_observation_window` — derived "best windows tonight" rollup per location

---

## Pipeline

### Phase 1

```
CelesTrak TLE catalog ─┐
                       │
                       ▼ hourly cron (GitHub Actions)
  fetch_tles.py    → tle_revisions (UPSERT keyed on norad_id + epoch + source)
                       │
                       ▼
  predict_passes.py → for each (satellite_of_interest, location), compute next 48h passes
                      using skyfield + the most recent TLE revision
                       │
                       ▼
  fetch_forecast.py → NOAA NDFD sky-cover forecast for each location, hourly grid
                       │
                       ▼
  join_forecast.py  → for each predicted pass, look up forecast at pass_peak time
                       │ → score visibility_verdict
                       ▼
                  pass_forecasts table
                       │
                       ▼
  publish.py       → regenerate /api/passes endpoints + visibletonight.rss
                       │
                       ▼
  FastAPI / Vercel
```

### Phase 2 additions

- Starlink train identification: a daily job groups Starlink TLEs by launch designator and seeds `starlink_trains`. Pass prediction runs additionally over each train's members; the UI groups them as "Starlink Group 6-23 train" rather than 22 individual passes.
- iCal generation: a separate worker rebuilds `.ics` files per location from `predicted_passes` filtered to `visibility_verdict IN ('excellent', 'good')`.

---

## Visibility Scoring Logic (Phase 1 — the synthesis interesting part)

Visibility is a function of multiple variables. Pure-function scoring rules:

1. **Excellent:** `max_elevation_deg ≥ 40` AND `estimated_magnitude ≤ -2.0` AND `sky_cover_pct ≤ 30` AND `illuminated = true`
2. **Good:** `max_elevation_deg ≥ 25` AND `estimated_magnitude ≤ -0.5` AND `sky_cover_pct ≤ 60` AND `illuminated = true`
3. **Marginal:** `max_elevation_deg ≥ 10` AND `estimated_magnitude ≤ +1.5` AND `sky_cover_pct ≤ 80` AND `illuminated = true`
4. **Skip:** anything else (object below horizon for most of pass, in Earth's shadow, or completely socked in)

The thresholds are documented in `docs/VISIBILITY_RULES.md` with rationale. **This is the synthesis layer that distinguishes the project** — anyone can predict an ISS pass, but joining predicted geometry to a forecasted weather grid and emitting a single human-readable verdict is the actual DE work.

Each verdict carries `verdict_reason` so the UI can show *why* a pass was rated the way it was. This is a UX move (transparency) that's also a debugging move (when our verdict is wrong, we know which input failed).

---

## Geospatial Notes

- PostGIS is the right tool. NOAA's NDFD is a 2.5 km grid; we extract a single grid cell per `observer_location` using ST_DWithin or by storing the cell index directly.
- Ground-track LINESTRINGs are computed by sampling skyfield's subpoint at 1-second intervals during a pass. ~60–600 points per pass — small enough to store directly as PostGIS LINESTRINGs without compression.
- For the map view in Phase 2, render passes as Leaflet polylines from PostGIS GeoJSON output — no PostGIS Tiles complexity needed.
- **Anti-goal:** building a generic geospatial platform. PostGIS is here because the join is real, not as showcase.

---

## Repository Layout

```
sky-pass-predictor/
├── .github/workflows/
│   ├── hourly-tles.yml
│   ├── hourly-forecast.yml
│   ├── pass-prediction.yml
│   └── ci.yml
├── etl/
│   ├── sources/
│   │   ├── celestrak.py
│   │   ├── space_track.py        # Phase 2 optional
│   │   ├── noaa_ndfd.py
│   │   └── noaa_metar.py         # stretch
│   ├── transform/                # dbt project
│   ├── fetch_tles.py
│   ├── fetch_forecast.py
│   ├── predict_passes.py         # skyfield-based core
│   ├── join_forecast.py
│   ├── publish.py
│   └── schema.sql
├── vocabularies/
│   ├── satellite_class.yaml
│   ├── pass_quality.yaml
│   ├── visibility_verdict.yaml
│   └── tle_source.yaml
├── api/
│   ├── main.py
│   └── models.py
├── web/
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── data/
│   ├── snapshots/                # TLE archives — small, daily tarballs
│   └── archive/
├── tests/
│   ├── test_tle_parse.py
│   ├── test_predict_passes.py    # against known-good ISS passes from past dates
│   ├── test_join_forecast.py
│   ├── test_visibility_score.py
│   └── fixtures/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_CATALOG.md
│   ├── DATA_SOURCES.md
│   ├── VISIBILITY_RULES.md       # the scoring methodology — portfolio gold
│   └── diagrams/
├── infra/
│   └── main.tf
├── Dockerfile
├── docker-compose.yml
├── LICENSE                        # MIT
├── LICENSE-DATA                   # CC-BY (TLE attribution to CelesTrak required)
├── PRIVACY.md
├── pyproject.toml
├── README.md
└── .env.example
```

---

## Three-Week Timeline

### Week 1 — TLE ingest + pass prediction (Phase 1 core)

**Day 1 (Mon)**
- Initialize repo, `pyproject.toml`, dependencies (`httpx`, `pandas`, `psycopg[binary]`, `pyyaml`, `pytest`, `python-dotenv`, `tenacity`, **`skyfield`**, **`shapely`**)
- Provision Neon DB; **enable PostGIS extension** (`CREATE EXTENSION postgis`)
- `schema.sql` for Phase 1 tables including PostGIS geography columns
- Seed `observer_locations` with the five Central Oregon presets
- Manually pull a CelesTrak Stations TLE file; commit as fixture

**Day 2 (Tue)**
- `etl/sources/celestrak.py` — wrap the GP API; parse two-line elements; checksum
- `fetch_tles.py` — UPSERT keyed on `(norad_id, epoch, source)`
- `tests/test_tle_parse.py` against fixture

**Day 3 (Wed)**
- `predict_passes.py` — skyfield-based prediction
  - For each satellite_of_interest (Phase 1: ISS only, NORAD 25544)
  - For each `observer_locations` row
  - Compute next 48 hours of passes
  - For each pass, compute start/peak/end times, azimuths, max elevation, illumination, ground-track LINESTRING
- `tests/test_predict_passes.py` — use a *known-good past pass* of ISS over Bend (look up in Heavens-Above archive or Stellarium) as a reference fixture; assert times match within 30 seconds and elevations within 1°. **This test is the project's correctness anchor.**

**Day 4 (Thu)**
- `etl/sources/noaa_ndfd.py` — fetch hourly Sky Cover forecast for each observer location
- `fetch_forecast.py` — write to a forecast cache table keyed by `(location_slug, valid_at, forecast_issued_at)`
- `tests/test_fetch_forecast.py` with mocked HTTP

**Day 5 (Fri)**
- `join_forecast.py` — for each predicted pass, look up the forecast for `pass_peak` valid time
- Implement visibility scoring rules; write `docs/VISIBILITY_RULES.md`
- `tests/test_visibility_score.py` — exhaustive cases per verdict

**Weekend buffer.**

### Week 2 — Publishing, UI, polish (Phase 1 ships)

**Day 6 (Mon)**
- `publish.py` — regenerate `public/visibletonight.rss` per location, plus `public/passes/{location}.json`
- TLE archive policy (commit daily snapshot tarball; keep 30 days loose)

**Day 7 (Tue)**
- `.github/workflows/hourly-tles.yml` — cron `5 * * * *`
- `.github/workflows/hourly-forecast.yml` — cron `15 * * * *` (offset to avoid collision)
- `.github/workflows/pass-prediction.yml` — cron `30 * * * *`
- DB URL in repo secret
- Verify all three workflows green over a 24-hour cycle; auto-issue-on-failure

**Day 8 (Wed)**
- FastAPI: `/api/passes/upcoming?location={slug}`, `/api/passes/upcoming?lat={f}&lon={f}` (preview), `/api/satellites/{norad_id}`, `/api/locations`
- Deploy to Fly.io

**Day 9 (Thu)**
- React: location selector, upcoming-passes table per location, per-pass detail panel showing verdict + reason, sky chart (compass-style svg showing pass arc)
- Deploy to Vercel

**Day 10 (Fri)**
- README v1 — architecture diagram, sources, visibility-rule explanation, freshness SLO, screenshot
- Populate `DATA_CATALOG.md`, `PRIVACY.md`, `LICENSE`, `LICENSE-DATA`
- Honest "field-test log" subsection in README: predicted vs observed for 3 ISS passes you actually went outside to watch. **This is what makes the portfolio piece memorable.**

**Days 11–14 (buffer):** Bug fixes. Don't call Phase 1 shipped until all three hourly workflows have been green 5 consecutive days. **At end of Week 2: Phase 1 is publicly shipped.**

### Week 3 — Starlink trains + custom locations + iCal (Phase 2)

**Day 15 (Mon)**
- Add CelesTrak Starlink TLE source
- `starlink_trains` table; daily job that groups recent launches into trains
- Train pass prediction (predict per train member, then group in mart layer)

**Day 16 (Tue)**
- Initialize dbt project under `etl/transform/`
- Staging + marts: `dim_satellite`, `dim_tle_revision`, `fact_predicted_pass`, `fact_observation_window`
- dbt tests including "every fact_predicted_pass has a valid TLE revision"

**Day 17 (Wed)**
- Custom-location support: `?lat=&lon=` query parameter
- Live forecast fetch for arbitrary coordinates (cache short — 1 hour TTL — so we don't hammer NOAA)
- Validation: reject coordinates outside the contiguous 48 (NDFD coverage); document the limitation

**Day 18 (Thu)**
- React: pass detail map view (Leaflet + ground-track polyline)
- iCal generation: `.ics` per location with the next 14 days of `excellent` and `good` passes
- Subscribe-to-calendar button in UI

**Day 19 (Fri)**
- README v2 — lead with the geospatial join and sub-hourly orchestration story
- Deploy `dbt docs`
- Update field-test log with Starlink-train sightings

**Days 20–21 (buffer):** Polish. Cut v1.0. **At end of Week 3: Phase 2 is publicly shipped.**

---

## Risk Register

| Risk | Mitigation |
|---|---|
| skyfield prediction disagrees with reality | Anchor tests against historical Heavens-Above passes; if predictions drift, the issue is almost always stale TLEs — verify TLE epoch is recent. |
| TLE catalog is unreachable for an extended period | Retain last-known TLEs and continue predicting (with degraded confidence). After 7 days stale, mark predictions as `degraded` and warn in UI. |
| NOAA NDFD endpoint changes or is down | Fallback to NBM. If both are out, predictions ship without cloud-cover (verdict downgrades to `unknown`). |
| Sub-hourly GH Actions cron is unreliable | Acceptable — the data only needs to be roughly fresh, not real-time. If reliability becomes an issue, move to Fly.io scheduled tasks. |
| PostGIS adds operational complexity | Keep PostGIS use minimal in v1.0: just `GEOGRAPHY(POINT)` and `GEOGRAPHY(LINESTRING)`. No tile-server, no spatial-index gymnastics. |
| Starlink train identification is fuzzy | Use `launch_date` from satellite metadata + a fixed 30-day train window. Document the heuristic. Don't try to track when trains "disperse" — that's research, not engineering. |
| Custom-location coordinates outside US | Validate against bounding box; return a clear error. NDFD covers contiguous 48 + Hawaii + Alaska only. |
| Repo gets clone-and-run requests from astronomy hobbyists | Welcome it; ensure README's "how to run locally" is exhaustive. This project is the most likely to attract real users. |
| Timeline slips | Acceptable to 4 weeks. Phase 2 can be cut to "Starlink trains only" if Week 3 runs tight; iCal and custom-locations move to v1.1. |

---

## Stretch Goals (post-v1.0, not in scope)

- Pass observation submissions (user reports "saw it" / "didn't see it" → `pass_observations`); over time this builds a verification corpus
- Mastodon bot for "ISS visible from Bend in 30 minutes"
- Iridium flares (mostly historical; the original Iridium constellation is deorbited but newer satellites have similar geometry)
- Aurora-substorm pass alerting (cross-reference with the NOAA SWPC Kp index — if Kp is high AND a pass is happening, double the visibility score)
- Smoke-aware visibility (Central Oregon summers — cross-reference with Oregon DEQ AQI)
- Light-pollution-aware location recommendations (overlay Bortle scale)

---

## Open Questions (resolve before Day 1)

1. **Space-Track account.** Free but requires manual approval. Apply early; Phase 1 doesn't need it but Phase 2 cross-checks benefit from it.
2. **NOAA endpoint choice.** NDFD (older, simpler) vs NBM (higher resolution). Recommend **NDFD** for v1.0 — simpler API, sufficient resolution for "is it cloudy in Bend at 9:47 PM" questions.
3. **Repo name.** `sky-pass-predictor` vs `bend-sky` vs `cascadia-sky` vs `central-oregon-passes`. First is most descriptive; second is most local-flavored.
4. **Sub-hourly cadence justification.** Hourly TLE ingest is overkill (CelesTrak updates several times daily, not hourly). Recommend: **TLE every 6 hours** but pass prediction every hour (so a fresh forecast triggers re-scoring even when TLEs haven't changed). Document the choice in `ARCHITECTURE.md`.
5. **Whether to ship a "tonight at a glance" homepage.** Strongly recommended: the homepage shows the next *good* visible pass at the user's selected location, with a countdown. This is the screenshot that goes in the portfolio meta-repo.

---

## What Not To Add

- Authentication / user accounts in v1.0
- Push notifications / SMS — RSS + iCal cover the use case; pagers go beyond scope
- Generic satellite tracking for non-visible objects (deep-space probes, geostationary comms) — visibility-from-Earth is the project's identity
- A mobile app — the responsive web UI is sufficient
- AR overlay / point-your-phone-at-the-sky — fun but a different project
- Telescope automation / GoTo integration — out of scope; this is a prediction service, not a control system
- Multi-region beyond US — NDFD limitation; if international support comes, that's a v2.0 redesign
