# Rubin Alert Layer — v0 Implementation Plan

## Context

This work extends the existing **exoplanetcitation** project (Next.js/React frontend, Postgres-backed, deployed on Vercel, OSS on GitHub) into a broader public-good data engineering layer over astronomical alert streams.

The NSF–DOE Vera C. Rubin Observatory began publishing its public alert stream on **25 February 2026**. The stream is expected to scale to ~10 million alerts per night over a 10-year survey. Eight-plus official community brokers (ALeRCE, AMPEL, ANTARES, Babamul, Fink, Lasair, Pitt-Google, SNAPS, POI Broker) ingest, classify, and redistribute alerts — but they are built for working astronomers, not consumers, educators, journalists, or indie developers.

**The v0 goal**: ship a working consumer-facing slice that subscribes to the Rubin alert stream via one broker, filters for **Near-Earth Object (NEO) alerts**, enriches them against authoritative solar system catalogs, persists them, and exposes them via a public API and feed page.

**Strategic goal**: produce a portfolio-grade artifact and an OSS foundation suitable for follow-on grant applications (NASA OSTFL, NSF POSE, Heising-Simons, Kavli, Sloan).

## Why this v0 scope

- NEO alerts are the highest-public-interest, most-enrichable subclass (clean cross-references via Minor Planet Center and JPL SBDB; clear risk semantics via JPL Sentry).
- Volume is manageable for v0 (small fraction of total alert stream).
- Patterns developed here (streaming subscribe → filter → enrich → persist → publish) generalize cleanly to other alert classes (supernovae, variable stars, microlensing) in v1+.
- Solar system events have a natural narrative for consumer surfaces, which strengthens the grant pitch.

## Architecture

```
Pitt-Google Pub/Sub topic (Rubin LSST alerts, Avro-encoded)
        │
        ▼
Subscriber service (long-running Node.js process)
        │  decode Avro → filter solar-system / NEO candidates
        ▼
Enrichment pipeline
        │  MPC identification, JPL SBDB orbital elements,
        │  JPL Sentry risk table cross-reference
        ▼
Postgres (extends existing schema; new tables, no breaking changes)
        │
        ▼
NestJS API module (added to existing API surface)
        │
        ▼
Public surfaces:
  - REST endpoints (list, detail, filter)
  - JSON feed (/alerts.json)
  - RSS feed (/alerts.rss)
  - React/Next.js feed page in existing frontend
```

A nightly background job reconciles persisted alerts against the latest JPL Sentry impact-risk table.

## Tech decisions (already made — do not re-litigate)

| Concern | Decision | Rationale |
|---|---|---|
| Broker | Pitt-Google | Streams via Google Pub/Sub; well-documented; free tier sufficient for filtered subscription; partnered with Rubin |
| Subscriber runtime | Node.js (TypeScript) | Matches existing stack; `@google-cloud/pubsub` is mature |
| Avro decoding | `avsc` library | De facto standard in Node ecosystem |
| Storage | Extend existing Postgres | Additive tables only; no schema breakage |
| API | NestJS module added to existing API | Matches existing stack |
| Frontend | Page added to existing Next.js/React app | Matches existing surface |
| Subscriber hosting | Railway, Fly.io, or AWS ECS Fargate task | **Vercel does not support long-running processes** — frontend stays on Vercel; subscriber must run elsewhere |
| Auth (v0) | None — fully public read-only | Reduces v0 surface; revisit at v1 |
| License | Match existing exoplanetcitation license | Continuity for grant story |

## Implementation notes (read before writing code)

- **Pitt-Google requires registration** to receive subscription credentials. Start that early — it can take days. See `https://pitt-broker.readthedocs.io/`.
- **Alert schema is versioned.** Pin to a known schema version; do not hardcode field paths beyond what the schema guarantees. The Rubin alert packet schema is published and evolves.
- **Pub/Sub delivery is at-least-once.** All writes must be idempotent. Use the alert's `alertId` as the natural key.
- **Do not persist the 30×30 pixel cutout FITS images in Postgres.** For v0, drop them on the floor. v1 can route them to S3/object storage if needed.
- **Cache aggressively against MPC and JPL APIs.** Both have rate limits and neither is fast. Local caching layer (Postgres or Redis) is required, not optional.
- **Filter aggressively at the subscriber.** Most alerts will not be solar system. Drop non-candidates before enrichment, before persistence, ideally before full Avro decode where possible (header inspection first).
- **Distinguish "raw alert" from "derived alert."** Persist a small JSONB blob of the original alert payload alongside the structured columns; this protects against schema changes upstream and supports replay.
- **The Pitt-Google broker subscribes you to a Google Pub/Sub topic in their GCP project.** Authentication is via service account JSON; do not check this into the repo.

## Phases & milestones

### Phase 0 — Setup (1–2 days)

- Apply for Pitt-Google broker access; obtain GCP service account credentials.
- Create new top-level module directory in repo (see "Repository structure" below).
- Add Postgres migrations for new tables (see "Schema" below).
- Add new env vars and secrets pattern matching existing project conventions.

**Done when**: credentials in hand; migrations applied locally; CI green.

### Phase 1 — Subscriber + persistence (≈1 week)

- Long-running subscriber connects to Pitt-Google topic.
- Avro decoder validates against pinned schema.
- Solar-system / NEO candidate filter runs before persistence (use broker-supplied classifications where available, fallback to Avro feature heuristics).
- Each accepted alert persisted to `alerts` and `alerts_raw` tables, idempotent on `alert_id`.
- Structured logging + minimal metrics (alerts received, filtered in, filtered out, persisted, errored).

**Done when**: a live process is consuming Rubin alerts, filtering NEO candidates, and writing them to Postgres with raw payload preserved. Local replay possible from `alerts_raw`.

### Phase 2 — Enrichment (≈1 week)

- MPC lookup service: given alert position + time, query MPC for known-object identification. Cache responses.
- JPL SBDB integration: for identified objects, fetch and persist orbital elements.
- Sentry reconciliation: nightly job pulls the JPL Sentry CSV and joins risk classifications onto persisted alerts.
- Enrichment is **decoupled** from ingest — it runs as a worker against the persisted alert table, not inline with the subscriber. This keeps the subscriber lean and replay-safe.

**Done when**: persisted alerts have populated MPC identification (where available) and Sentry risk score (where applicable). Enrichment is observable and replayable.

### Phase 3 — Public API + feed page (≈1 week)

- NestJS module exposes:
  - `GET /alerts` — paginated list, filterable by date range, risk class, object designation
  - `GET /alerts/:id` — full alert detail with enrichment
  - `GET /alerts.json` — JSON feed (latest 100, JSON Feed 1.1 spec)
  - `GET /alerts.rss` — RSS 2.0 feed
- OpenAPI spec generated and published.
- React/Next.js feed page in existing frontend, styled consistently with exoplanetcitation:
  - Recent NEO alerts list
  - Per-alert detail page with object info, close-approach data, sky position
  - Link to MPC and JPL pages for the canonical scientific record

**Done when**: a public URL renders the feed; both syndication feeds validate; OpenAPI doc published.

### Phase 4 — Polish & launch (3–5 days)

- README updated: what this is, how to run locally, how to contribute, data licensing.
- Subscriber deployed to chosen hosting target with monitoring.
- Custom subdomain or path on existing domain.
- A short public write-up (blog post or page) for launch and grant-application provenance.

**Done when**: the layer is live, documented, and reproducible from a clean clone.

## Repository structure

Adapt to actual existing layout. Assumed pattern:

```
/apps (or /packages)
  /alert-subscriber          NEW — long-running Pub/Sub subscriber + filter
  /alert-enrichment          NEW — enrichment worker (MPC, SBDB, Sentry)
  /api                       EXISTING — adds /alerts module
  /web                       EXISTING — adds /alerts route
/db
  /migrations                EXISTING — adds new migrations
/docs
  /alert-layer.md            NEW — this plan + ongoing design notes
```

## Postgres schema (additive)

```sql
-- Raw alert payload preserved for replay & schema-drift protection
CREATE TABLE alerts_raw (
  alert_id     TEXT PRIMARY KEY,
  received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_ver   TEXT NOT NULL,
  payload      JSONB NOT NULL
);

-- Structured projection for queries
CREATE TABLE alerts (
  alert_id          TEXT PRIMARY KEY REFERENCES alerts_raw(alert_id),
  observed_at       TIMESTAMPTZ NOT NULL,
  ra_deg            DOUBLE PRECISION NOT NULL,
  dec_deg           DOUBLE PRECISION NOT NULL,
  classification    TEXT,           -- broker-supplied
  is_neo_candidate  BOOLEAN NOT NULL DEFAULT false,
  mpc_designation   TEXT,           -- populated by enrichment
  sentry_risk_score NUMERIC,        -- populated by reconciliation
  enriched_at       TIMESTAMPTZ
);

CREATE INDEX alerts_observed_at_idx ON alerts (observed_at DESC);
CREATE INDEX alerts_mpc_idx ON alerts (mpc_designation) WHERE mpc_designation IS NOT NULL;
CREATE INDEX alerts_neo_idx ON alerts (observed_at DESC) WHERE is_neo_candidate;

-- Cached MPC/SBDB lookups
CREATE TABLE solar_system_objects (
  designation       TEXT PRIMARY KEY,
  orbital_elements  JSONB,
  fetched_at        TIMESTAMPTZ NOT NULL,
  source            TEXT NOT NULL   -- 'mpc' | 'sbdb'
);
```

## Acceptance criteria (whole-project)

1. A live subscriber process consumes the Rubin alert stream, filters NEO candidates, persists them idempotently with raw payloads.
2. Persisted alerts are enriched against MPC, JPL SBDB, and Sentry, observably and replayably.
3. A public REST API and two syndication feeds (JSON Feed, RSS) expose the data.
4. A consumer-friendly feed page is live on the existing exoplanetcitation domain.
5. README documents local setup, deployment, and licensing.
6. Codebase passes existing CI checks; no breaking changes to existing exoplanetcitation behavior.

## Out of scope for v0

- Other alert classes (supernovae, variable stars, microlensing, exoplanet transit hosts) — v1+
- Other brokers (ALeRCE, ANTARES, Fink, Lasair, etc.) — v1+, behind a broker-adapter interface
- ML re-classification beyond broker-supplied labels
- Push notifications (email, SMS, mobile)
- User accounts, subscriptions, saved searches
- Mobile app
- FITS cutout image storage and rendering
- Historical backfill from Rubin Data Preview releases

## Open questions for the human (resolve before Phase 1)

1. **Repo layout**: confirmed monorepo or separate frontend/backend repos? Plan assumes monorepo-ish; adjust if not.
2. **Hosting target for the long-running subscriber**: Railway, Fly.io, AWS ECS Fargate, or other? Cost and ops preference?
3. **Domain/subdomain**: `alerts.exoplanetcitation.[tld]`, a path on the existing domain, or a separate domain entirely?
4. **License**: continuing whatever exoplanetcitation uses, or relicensing for the broader project?
5. **Postgres**: shared instance with existing project or new logical database? Schema namespacing preference?
6. **Existing API conventions**: confirm NestJS is the existing API framework; if it's something else (Next.js API routes, Hono, Express), adapt the API layer accordingly.

## Reference links

- Rubin Observatory project: `https://rubinobservatory.org/`
- Rubin Prompt Products docs: `https://prompt-products.lsst.io/`
- Pitt-Google broker: `https://pitt-broker.readthedocs.io/`
- Minor Planet Center: `https://www.minorplanetcenter.net/`
- JPL Small-Body Database (SBDB) API: `https://ssd-api.jpl.nasa.gov/doc/sbdb.html`
- JPL Sentry impact risk table: `https://cneos.jpl.nasa.gov/sentry/`
- NASA Open Source funding opportunities: `https://science.nasa.gov/open-science/nasa-open-science-funding-opportunities/`
