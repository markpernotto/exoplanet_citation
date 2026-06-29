# Exoplanet Citation Atlas

[![DOI](https://zenodo.org/badge/1228082575.svg)](https://doi.org/10.5281/zenodo.20191479)


A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via NASA ADS and host-star enrichment via Gaia DR3.

**Live:** [exoplanetcitation.space](https://exoplanetcitation.space)
· [API docs (Swagger)](https://exoplanetcitation.space/docs)
· [Source on GitHub](https://github.com/markpernotto/exoplanet_citation)

**Status:** Live and maintained. Daily ingest pipeline running on
a GitHub Actions cron; 6,287 confirmed planets loaded into Postgres with
nightly runs since 2026-05-04; FastAPI serving 22 endpoints with
automatic Swagger docs; React + Three.js + WebXR frontend deployed at
[exoplanetcitation.space](https://exoplanetcitation.space) with
procedurally-rendered planet cards, an interactive 3D scene viewer with
per-vantage starfield reprojection (4K through 16K rendering knob;
default 6K), the multi-planet "this paper also announced…" affordance,
an imperial/metric units toggle, shareable URLs that round-trip camera
state, and a `/feeds` index for personalized RSS subscriptions; Gaia DR3
host-star enrichment complete for all 4,358 enrichable hosts; **citation
graph (`publications` + `planet_publications`) resolved for 6,298 /
6,298 planets (100%)** via a 4-tier automated resolver (ADS bibcode →
arXiv API → ADS title search → manual queue) plus a 7-row hand-resolved
final pass for edge-case journal references; 167 unit tests + 12 dbt
tests passing.

See [PLAN.md](PLAN.md) for the full implementation roadmap and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## What this is

A data engineering project applied to the largest active discovery effort
in modern astronomy. It does three things:

- **Watches** the NASA Exoplanet Archive nightly and publishes the diff as
  RSS, JSON, and a browseable UI: newly confirmed planets, removed entries,
  and tier-classified parameter revisions.
- **Links** each confirmed planet to the publications behind it via DOI /
  arXiv / ADS, with confidence scoring and human-readable provenance, plus
  Gaia DR3 enrichment of host stars for precise distances, photometry, and
  procedural visualization data.
- **Audits and enriches** what the archive ships: a per-system review of the
  circumbinary (`cb_flag`) population against the discovery literature,
  inner-binary parameters harvested from those papers, and a multi-role
  citation graph (discovery / follow-up / prior-detection / characterization)
  that credits every added data point to the paper it came from.

The project has shifted over time from mirroring the NASA Exoplanet Archive to
auditing and adding value to it. The distinguishing technical bet is
**provenance everywhere**: every row in the warehouse carries source URL,
retrieval timestamp, sha256 checksum, and extraction version; every citation
link carries a role, confidence, and reason; every visual rendered in the UI is
computed from measured properties, not from a stock-image library.

---

## What works today

- **Nightly extract** pulls `pscomppars` from the NASA Exoplanet Archive
  (TAP) → uploads CSV to Cloudflare R2 → appends sha256 manifest entry
- **Loader** UPSERTs into Postgres (Neon) with 28 typed columns plus
  the full raw row preserved as JSONB
- **dbt staging + tests.** A single `stg_pscomppars` view over the latest raw
  snapshot, refreshed by `dbt run` in the nightly pipeline, plus 12 schema tests
  (not-null / unique / accepted-values) on the model and its sources. It is a
  data-quality check on the raw layer; the downstream tables and the API are
  built by SQL migrations and Python, not dbt models.
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
- **Circumbinary (cb_flag) audit + binary enrichment** — all 54 `cb_flag=1`
  planets across 44 host systems are reviewed against their discovery (and
  follow-up) literature in
  [`docs/cb_flag_audit.md`](docs/cb_flag_audit.md), the public per-host data
  record. Inner-binary parameters (component masses, radii, period,
  eccentricity) harvested from those papers are seeded into `binary_companions`
  via `etl/seed_inner_binaries.py`, where an `inner_binary` flag distinguishes
  the tight P-type-defining pair from the wide visual companions SIMBAD
  resolves. Because the audit draws data from papers beyond the original
  discovery, those papers are linked back into the citation graph with explicit
  roles (`prior_detection`, `characterization`) and a `contribution` tag for
  what each supplied (e.g. `binary_masses`, `distance`), so every enriched value
  is traceable to its source. Literature distances for hosts that both Gaia and
  the archive miss live in `host_distances_manual`. An analysis of the aggregate
  audit results is in preparation as a short Research Note.
- **S-type stellar-multiplicity audit campaign** — a parallel system-by-system
  close-out of the 174-host gap where the catalog's `sy_snum` advertised
  additional stellar components that `binary_companions` did not carry. Sixteen
  migrations (069-084) closed the 13-system priority list, executed a bulk
  attack on Mugrauer et al. 2019's Gaia DR2 SPHERE survey (~85 hosts in one
  migration), established three architectural patterns (ENRICH for missing data,
  SPLIT for combined SIMBAD entries, REPAIR for mislabelled or spurious rows),
  and normalized 9 paper-verbatim hostnames to the catalog's canonical forms so
  the renderer and Atlas joins resolve. The campaign repaired the 3D scene for
  systems that had been showing as a single star (V1298 Tau, WASP-12, LTT 1445 A,
  HD 110067, Kepler-444, 51 Eri, ...) and surfaced the real architecture of
  Proxima Cen and eps Ind A in place of bulk-load SIMBAD artefacts. A proper
  `planet_aliases` table is queued for v0.2; 7 of the 31 audit-surfaced
  planet-pub link gaps remain alias-only (the rest are truly not in the catalog).
- **Curated atmospheric and orbital-geometry data:** landmark literature
  results hand-harvested into `planet_atmospheres` (molecule detections with
  instrument, significance, and source paper) and `system_orbital_geometry`
  (measured mutual inclinations), each credited via a `characterization`
  citation. Includes the first detected exoplanet atmosphere (HD 209458 b) and
  the JWST-era sweep across warm Neptunes, rocky M-dwarf targets, hot
  Jupiters, directly-imaged young giants, and Neptune-desert / sub-Saturn
  oddballs (~30 systems across nine batches in migrations 060-068, plus the
  earlier per-system deep-dives in 020-048). Non-detections are recorded too:
  the JWST TRAPPIST-1 campaign's bare-rock and ruled-out-atmosphere results
  (planets b through e) and the LHS 1140 c / GJ 357 b primordial-envelope
  exclusions are curated as `ruled_out` / `inconclusive`, so the catalog
  states what has been excluded, not only what was found. Per-planet derived
  scalars (dayside temperature, metallicity, C/O ratio, spin, mass-loss rate,
  envelope fraction) live alongside in `planet_derived_measurements`. This
  data feeds the 3D scene and the curated "Could you live here?" survival
  profiles in `docs/survival_feature_candidates.md`.
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
- **167 unit tests + 12 dbt schema tests** all green; CI workflow with ruff lint

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

# Set up the database -- pick ONE path:

# RECOMMENDED: restore the latest release snapshot.
# Single command. Includes schema + curated data + NASA EA mirror
# state as of the release. Requires Postgres >= 17.
gunzip -c data/snapshots/v0.2.0.sql.gz | psql "$DATABASE_URL"

# ALTERNATIVE: replay the full migration history from scratch.
# Slower but reproduces every schema/data change in chronological order;
# useful for auditing or when you want a fresh start without the
# curated data.
psql "$DATABASE_URL" -f etl/schema.sql
for m in etl/migrations/[0-9]*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$m"
done

# When new migrations land between releases, apply them in numeric
# order on top of either path above. E.g. for migration 119:
# psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f etl/migrations/119_*.sql

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
python -m etl.clear_manual_queue        # hand-resolves the 7 historical edge cases the resolver can't reach
python -m etl.enrich_binaries           # binary_companions from SIMBAD (wide visual companions)
python -m etl.seed_inner_binaries --execute        # one-off: curated inner-binary backfill from the cb_flag audit (idempotent)
python -m etl.seed_followup_citations --execute     # one-off: link follow-up / prior-detection / characterization papers into the citation graph
python -m etl.enrich_publication_metadata --execute # backfill ADS authors/metadata for the hand-seeded citations
make publish                            # → public/rss.xml, public/discoveries.json, public/health.json

# Run the API locally
make api         # http://localhost:8000/docs

# Run the React frontend locally (in a separate terminal)
make web-install # one-time
make web         # http://localhost:5550 (proxies /api to :8000)

# Other targets
make test        # pytest -v, 167 tests
make dbt-test    # 12 dbt schema tests
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
- **[docs/cb_flag_audit.md](docs/cb_flag_audit.md)** — per-host circumbinary
  audit: every `cb_flag=1` system reviewed against its discovery literature,
  with harvested inner-binary parameters (public data record; aggregate
  analysis in preparation as a Research Note)

---

## Versioning & releases

Tagged releases are published under
[GitHub Releases](https://github.com/markpernotto/exoplanet_citation/releases),
with a human-readable history in [CHANGELOG.md](CHANGELOG.md). The project
follows [Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format, and each tagged release
also mints a version-specific
[Zenodo](https://doi.org/10.5281/zenodo.20191479) DOI for citation.

Starting with **v0.2.0**, every tagged release ships a frozen database
snapshot at `data/snapshots/<version>.sql.gz`. The snapshot contains the
complete schema for every table, all curated data (`binary_companions`,
`sy_snum_audit`, `planet_atmospheres`, `planet_derived_measurements`,
`host_distances_manual`, `publications`, `planet_publications`, etc.),
and the NASA EA `planets_snapshots` mirror filtered to the single
snapshot date that the released version of the site was rendering
against. Anyone with the gzipped dump can reproduce the production
database state of a release via:

```bash
createdb exoplanet_atlas
gunzip -c data/snapshots/v0.2.0.sql.gz | psql exoplanet_atlas
```

This makes the version DOI a self-contained reproducible scientific
receipt, not just a code archive. The snapshot is built via
`scripts/snapshot_release.sh <version>` at release time. Older NASA EA
mirror states are intentionally omitted from the snapshot to keep the
release archive small enough to live in git (typically < 20 MB
compressed); historical mirror states can be re-pulled from NASA EA
at any time if a user wants longitudinal comparison.

## What's next (unscheduled)

- Follow-up paper graph via NASA ADS citation queries: discovery to follow-up
  edges surfaced automatically, complementing the hand-curated roles now in the
  citation graph.
- A literature monitor that flags new per-system data for human verification
  before any write (detect, queue, verify; never auto-write).
- Gaia DR4 ingestion scaffolding; several circumbinary papers cite DR4
  astrometry as the path to refined masses and architectures.
- Galactic positioning view ("here we are / here this planet is").
- dbt marts (`dim_planet`, `dim_publication`, `fact_discovery`,
  `fact_parameter_revision`) once the API needs them.
- Optional PHL Habitable Exoplanets Catalog integration for Earth-Similarity
  tagging.

---

## Tech stack

| Layer | Tool | Why |
|---|---|---|
| Language (backend) | Python 3.12 | Primary across the pipeline |
| Language (frontend) | TypeScript + React 18 | Mature, well-typed |
| Warehouse | Postgres 16 (Neon free tier) | dbt-friendly, free tier sufficient |
| Object storage | Cloudflare R2 | S3-compatible, zero egress fees |
| Staging + data tests | dbt-postgres 1.11 | One `stg_pscomppars` view + schema tests on the raw snapshot; downstream transforms are SQL migrations + Python |
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

Mark A. Pernotto — mark@pernotto.com

---

Built as part of [Facet Build, LLC](https://facetbuild.llc).
