# Architecture

How exoplanet_citation is put together: data flow, components, storage layout,
hosting, idempotency guarantees, and provenance.

For the why-this-project framing see [01-exoplanets.md](../01-exoplanets.md).
For implementation details see [PLAN.md](../PLAN.md).

---

## High-level data flow

```
┌──────────────────┐    ┌─────────────────┐    ┌──────────────┐
│ NASA Exoplanet   │    │ NASA ADS +      │    │ Gaia DR3     │
│ Archive (TAP)    │    │ arXiv API       │    │ TAP service  │
└────────┬─────────┘    └────────┬────────┘    └──────┬───────┘
         │ pscomppars            │ bibcode / arXiv ID │ source_id
         │                       │                    │
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
   │    planets_snapshots         raw landing (rolling 2-day)│
   │    discovery_changes         diff events (append-only)  │
   │    discovery_papers          ADS-cached paper metadata  │
   │    publications              citation graph nodes       │
   │    planet_publications       citation graph junction    │
   │    citation_manual_queue     planets needing triage     │
   │    host_stars_gaia           Gaia DR3 host enrichment   │
   │    backfill_state            resumable backfill cursor  │
   │                                                         │
   │  staging.                    dbt views                  │
   │    stg_pscomppars                                       │
   │                                                         │
   │  marts.                      [Phase 2 — dbt tables]     │
   │    dim_planet, dim_publication                          │
   │    fact_discovery, fact_parameter_revision              │
   └─────────┬───────────────────────────┬───────────────────┘
             │ etl/diff.py + publish.py  │ FastAPI (22 routes)
             ▼                           ▼
   ┌────────────────────────┐   ┌──────────────────────┐
   │  static feeds          │   │  REST API            │
   │                        │   │                      │
   │  public/rss.xml        │   │  /api/discoveries/.. │
   │  public/discoveries    │   │  /api/planets/...    │
   │       .json            │   │  /api/publications/..│
   │  public/health.json    │   │  /api/authors/...    │
   │                        │   │  /api/rss/{*}        │
   │                        │   │  /api/health         │
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
   events to `discovery_changes` per the field-tier rules below, then
   prunes `planets_snapshots` to a rolling 2-day window so storage stays
   constant.
5. **Enrich (Gaia)** — `python -m etl.enrich_gaia` looks up new hosts in
   Gaia DR3 by `source_id` and UPSERTs into `host_stars_gaia`. Resumable
   via `backfill_state`.
6. **Enrich (ADS)** — `python -m etl.enrich_ads` fetches paper metadata
   from NASA ADS for any new bibcode found in `disc_refname` and caches
   it in `discovery_papers`.
7. **Resolve citations** — `python -m etl.resolve_citations` runs the
   4-tier resolver per planet (ADS bibcode → arXiv API → ADS title →
   manual queue), writing to `publications` + `planet_publications` with
   provenance. Trips a circuit breaker on ADS quota exhaustion and skips
   ADS-tier work until the next run. arXiv calls respect the
   polite-pool 3-second inter-call window. The nightly invocation passes
   `--max-planets 50` so a single quota window can never blow past the
   45-min job timeout.
8. **Publish** — `python -m etl.publish` reads recent surfaced changes
   and produces `public/rss.xml`, `public/discoveries.json`, and
   `public/health.json`.
9. **Commit + push** — the GitHub Actions runner commits the updated
   `data/MANIFEST.jsonl` and `public/` files back to `main` with
   `[skip ci]` to avoid retriggering.

Failure at any step opens a GitHub issue automatically (`actions/github-script@v7`,
`if: failure()`). Both enrichment and resolver jobs use `backfill_state`
so they can be paused mid-run and resumed later.

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
| `etl/sources/gaia.py` | Gaia DR3 TAP client | 2 |
| `etl/sources/ads.py` | NASA ADS API client (quota-aware circuit breaker) | 2 |
| `etl/sources/arxiv.py` | arXiv Atom-API client (polite-pool 3s window) | 2 |
| `etl/r2.py` | Cloudflare R2 helper (boto3 wrapper) | 1 |
| `etl/extract.py` | Orchestrates fetch → R2 → manifest | 1 |
| `etl/load.py` | Loads R2 snapshot into Postgres (UPSERT) | 1 |
| `etl/diff.py` | Field-tier-aware diff + rolling 2-day prune | 1 |
| `etl/enrich_gaia.py` | Per-host Gaia DR3 lookup (resumable) | 2 |
| `etl/enrich_ads.py` | ADS bibcode metadata cache (`discovery_papers`) | 2 |
| `etl/resolve_citations.py` | 4-tier citation resolver (ADS + arXiv) writing the citation graph | 2 |
| `etl/publish.py` | Generates RSS + JSON feeds + health snapshot | 1 |
| `etl/transform/` | dbt project (staging now, marts later) | 1+ |
| `etl/inspect.py` | Local-dev tool for browsing raw_row by planet | dev |
| `etl/check_setup.py` | Connectivity smoke test (Neon + R2) | dev |
| `etl/smoke_gaia.py` | One-shot Gaia DR3 client smoke test | dev |
| `etl/build_starfield.py` | One-shot Gaia DR3 starfield binary builder (`starfield_basic.bin`, `starfield_rich.bin`) for the 3D scene | 2 |
| `api/index.py` | FastAPI app (22 endpoints + OpenAPI/Swagger), Vercel serverless | 1+2 |
| `api/models.py` | Pydantic response models | 1+2 |
| `api/scene.py` | Per-planet scene_hints derivation (body type, day length, sun angular size, insolation label, survival estimate) | 2 |
| `web/` | Vite + React + TypeScript SPA — search, catalog, procedural planet detail with multi-planet citation affordance, system view (3D), surface view, VR view, retro themes | 1+2 |
| `web/src/pages/ScenePage.tsx` | Three.js + WebXR scene; system/surface/VR view modes (see `docs/PROCEDURAL_RENDERING.md`) | 2 |
| `web/src/components/ThemeSwitcher.tsx` | URL-param retro theme switcher (six themes; see `docs/THEMING.md`) | 1 |
| `web/src/procedural.ts` | Body-type/temperature → color mapping (see `docs/PROCEDURAL_RENDERING.md`) | 1 |
| `vocabularies/` | Controlled vocabularies (SKOS-lite YAML) | 1 |

---

## Frontend

The React frontend (`web/`) is a Vite + TypeScript SPA deployed to Vercel
alongside the API. It makes all data requests to `/api/*`, which Vercel
routes to the Python serverless functions in `api/`.

Key frontend design decisions:

**Procedural planet visuals.** Every planet card and system view is rendered
from measured astrophysical properties — no stock imagery. Color, size, and
orbital shape are computed from `pl_eqt`, `pl_dens`, `pl_rade`, and
`pl_orbsmax`. See [PROCEDURAL_RENDERING.md](PROCEDURAL_RENDERING.md).

**Three view modes for the scene** (planet detail's `/scene` route, in
[web/src/pages/ScenePage.tsx](../web/src/pages/ScenePage.tsx)):

- **System view** — top-down 3D of the host system. Sun at origin,
  planets on their elliptical orbits at true AU scale, body sizes
  exaggerated for visibility. OrbitControls for desktop. Default mode.
- **Surface view** — first-person, standing on the focal planet.
  Camera rides the planet's animated orbital position; sun arcs across
  the sky as the planet orbits. Useful for high-eccentricity planets
  where the sun's apparent size changes dramatically through the orbit.
- **VR view** — either system or surface mode plus an active WebXR
  session. Six-DOF locomotion via controller thumbsticks; the entire
  scene is uniformly scaled (factor ≈ `6 / maxOrbit`) so that any
  host system — from TRAPPIST-1's 0.06 AU outer orbit to HR 8799's
  70 AU outer orbit — fits a comfortable room-scale view. Tested on
  Quest 3; Quest 2 supported as a fallback. See the "VR / XR
  architecture" section below.

**Procedural starfield (current) → per-vantage starfield (planned).**
Today the sky in all three view modes is rasterized from a static Gaia
DR3 subset on the client. Phase 2 moves this to a server endpoint that
reprojects the stars from the host system's vantage, returning a per-
system PNG. See [STARFIELD_PLAN.md](STARFIELD_PLAN.md).

**Retro display themes.** Six optional CRT/early-digital themes (P1
Phosphor, P3 Phosphor, CGA, EGA, HGC, Plasma) switchable via `?theme=` URL
parameter. Implemented via CSS custom properties and `html[data-theme]`
selectors. No cookies or localStorage — the URL is the complete state.
Self-hosted woff2 fonts under OFL license; no CDN dependency. See
[THEMING.md](THEMING.md). Planet visuals are intentionally immune to theming
(planet/star colors come from procedural data-driven mappings, not from
CSS variables).

**URL-first state.** Search (`?q=`), theme (`?theme=`), and navigation
history are all encoded in the URL. This makes views shareable and keeps
React state minimal. All parameters coexist and are preserved across all
in-app navigation.

---

## VR / XR architecture

The VR path uses `@react-three/xr` (v6) on top of `@react-three/fiber`.
The scene tree inside `<Canvas>` for both desktop and VR (XR-specific
pieces only fire while a session is active):

```
<Canvas gl={{ logarithmicDepthBuffer: true, toneMapping: ACES }}>
  <XR store={xrStore}>
    <XRDepthFar />                  # session.updateRenderState
                                    # (depthNear=0.01, depthFar=1e9)
    <VRAutoPlay setPaused={...} />  # unpauses animation on session start
    <ambientLight />
    {viewMode === 'system'
      ? <OrbitControls />
      : <FirstPersonLook /> + <CameraFollowFocal />}
    <VRSceneScale maxOrbit={maxOrbit}>
      <SceneContents />             # sun, planets, orbits, companions
    </VRSceneScale>
    <Starfield />                   # OUTSIDE VRSceneScale: skydome at
                                    # world (not scaled) coordinates
    <VRRig initialPos={[3,0.5,1.5]} speed={...} />   # XROrigin + locomotion
    <PostProcessing />              # bloom; returns null in active XR session
  </XR>
</Canvas>
```

Key XR-only helper components, all in [`ScenePage.tsx`](../web/src/pages/ScenePage.tsx):

- **`<XRDepthFar>`** — overrides WebXR's default depthFar of 1000m via
  `session.updateRenderState({ depthNear: 0.01, depthFar: 1e9 })`. Without
  this, anything past 1km in scene units is silently clipped.
- **`<VRAutoPlay>`** — flips `paused` to `false` when an XR session
  starts. The HTML playback controls aren't reachable inside VR, so a
  user entering with the default paused=true would see a frozen system.
- **`<VRSceneScale>`** — wraps the visual scene contents in a `<group>`
  that scales by `min(200, max(2, 6 / maxOrbit))` while in XR, mapping
  AU-scale units to meters so the system reads at room scale. Outside
  XR, factor = 1 (no scaling).
- **`<VRRig>`** — drops an `<XROrigin>` at a comfortable starting world
  position and wires `useXRControllerLocomotion` to translate it. Uses
  a callback form so we get full XYZ free-flight (the default hook
  ignores Y, restricting users to the horizontal plane).
- **`<PostProcessing>`** — wraps `<EffectComposer><Bloom>...`. Returns
  `null` while in an active XR session because EffectComposer renders
  to a single 2D framebuffer, which black-screens stereo XR rendering.

The starfield (`<Starfield />`) sits OUTSIDE `<VRSceneScale>` deliberately,
so its skydome mesh's position can be updated each frame to follow the
XR camera in world coordinates without dividing by the scale factor.
The texture is an equirectangular `CanvasTexture` (4096×2048) rasterized
from Gaia DR3 data; the texture's `mapping = THREE.EquirectangularReflectionMapping`
is **required** for the `scene.background` fallback path to render as a
spherical environment instead of a head-locked 2D quad. (This was a
subtle XR-specific gotcha; see the gotcha file in
[PROCEDURAL_RENDERING.md](PROCEDURAL_RENDERING.md#vr-specific-quirks-gotcha-file).)

**Click handling.** Planet meshes have a transparent hit-mesh (oversized
sphere with `opacity:0` `MeshBasicMaterial`, NOT `visible:false` — R3F's
XR controller pointer filters out invisible meshes). Trigger-pull in VR
routes through R3F's onClick handler. The `jumpTo()` callback calls
`xrStore.getState().session?.end()` before navigating, since route
changes unmount the Canvas and would crash an active XR session
mid-frame.

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
public.            ← raw + enrichment (load.py, diff.py, enrich_*.py,
                     resolve_citations.py write here)
  planets_snapshots         rolling 2-day window of raw NASA snapshots
  discovery_changes         append-only diff event log
  discovery_papers          ADS metadata cache, keyed by bibcode
  publications              citation graph nodes (with provenance)
  planet_publications       planet ↔ publication junction (M:N)
  citation_manual_queue     planets that fell through all 4 resolver tiers
  host_stars_gaia           Gaia DR3 enrichment per host star
  backfill_state            resumable cursor for enrichment + resolver

staging.           ← dbt views (clean, typed projection of raw)
  stg_pscomppars

marts.             ← dbt tables (analytical models, deferred)
  dim_planet                [later]
  dim_publication           [later]
  fact_discovery            [later]
  fact_parameter_revision   [later]
```

**Storage budget.** Total DB size sits around ~230 MB against the Neon
free-tier 500 MB ceiling. The `planets_snapshots` table dominates (~210 MB
of typed columns + raw_row JSONB), held constant by the rolling 2-day
prune. Append-only tables grow by an estimated 5–15 MB/year combined.
`/api/health` exposes `storage.pct_used` and a `status` field that flips
to `warning` at 80% and `critical` at 95%.

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
  duplicates are silently skipped. The post-diff prune keeps the 2 most
  recent snapshot dates and is itself idempotent.
- **`enrich_gaia.py`** — UPSERTs by `gaia_dr3_id`. Skips already-enriched
  hosts unless `--refresh-all`. State stored under `backfill_state.batch_id
  = 'gaia-enrich-YYYY-MM-DD'`.
- **`enrich_ads.py`** — UPSERTs by `bibcode`. Skips already-cached papers
  unless `--refresh-all`.
- **`resolve_citations.py`** — skips planets already present in
  `planet_publications` unless `--all`. UPSERTs `publications` keyed by
  `bibcode` (primary) or `doi` (when no bibcode). On a successful resolve
  for a planet that was previously queued, the planet's row in
  `citation_manual_queue` is deleted in the same transaction so the
  queue stays a true source of truth for "planets still needing
  triage." Crashes from network / Postgres-idle disconnects can be
  resumed safely.
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

Every row in `publications` carries:

- `resolved_via` — `ads_bibcode` | `arxiv` | `ads_title` | `manual` (the
  CHECK constraint also accepts `crossref_doi` for forward
  compatibility, but no current code path writes it)
- `confidence` — `high` | `medium` | `low`
- `created_at` / `updated_at` — when the row was first written and last
  refreshed by the resolver
- `citation_count_updated_at` — when ADS last reported the citation count

Every row in `host_stars_gaia` carries:

- `source_record` JSONB — the raw Gaia DR3 record we resolved
- `retrieved_at` — when we pulled it

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
├── api/                     # FastAPI + Pydantic models
├── web/                     # React + Vite + TypeScript SPA
├── data/
│   └── MANIFEST.jsonl       # snapshot index (R2 keys + checksums)
├── public/                  # generated static feeds (nightly)
├── tests/                   # pytest unit tests (78 currently)
├── docs/
│   ├── ARCHITECTURE.md         # this file
│   ├── DATA_CATALOG.md         # column-by-column data dictionary
│   ├── PROCEDURAL_RENDERING.md # rendering pipeline (planets, stars, VR)
│   ├── STARFIELD_PLAN.md       # canonical plan for the per-vantage sky
│   └── THEMING.md              # retro CRT themes
├── infra/                   # Terraform (TBD)
├── Dockerfile
├── docker-compose.yml       # local Postgres for dev
├── Makefile                 # task runner
├── pyproject.toml
└── PLAN.md                  # implementation roadmap
```

`Makefile` is the canonical entry point for all common commands. Run
`make help` to see the targets.
