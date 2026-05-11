# VR Experience — v0 Implementation Plan

## Context

This plan extends the existing **exoplanet_citation** project with a WebXR-based 3D viewer that lets users float around a confirmed exoplanet system as a "miniature god," see the host star(s) at correct color and apparent size, watch sibling planets orbit at true AU scale, and (where data permits) observe the planet's atmosphere tinted from real spectroscopy. It is delivered in-browser, with a one-button "Enter VR" path for Quest 3 (and any other WebXR-capable headset). No app store, no native code, no install friction.

**The v0 goal**: ship a curated set of **~120-150 hero planets** with rich visualizations that are 100% data-grounded — no stock space art, no AI-imagined surfaces, no fictional weather. The same procedural-rendering contract that governs the 2D site (see `docs/PROCEDURAL_RENDERING.md`) extends into 3D unchanged.

**Strategic goal**: a portfolio-grade demo of "data-driven scientific visualization in the browser" that doubles as the kind of public-engagement artifact that strengthens grant pitches and gets linked by astronomy media.

## What's in scope for v0

- A new route `/planets/:plName/scene` rendering the host system in 3D
- Free-orbit camera (zoom + pan + tilt), controllable via mouse/touch on desktop and via Quest controllers in VR
- Host star(s) at correct color (spectral class → blackbody RGB) and correct *angular size from the planet's orbit*
- Companion stars in multi-star systems (where catalog data exists) at correct separation, color, and brightness
- Sibling planets in the same system at true AU scale
- Procedural planet bodies using the same color logic as the 2D viewer, extended to a sphere shader
- Real-Gaia background starfield, projected from the planet's vantage
- Atmospheric tint where spectroscopy data exists; "uncertain" treatment otherwise
- HUD overlay with pl_name, equilibrium temperature, "you would die in X seconds" calc, orbital period, time-multiplier control
- "Enter VR" button, with Quest 3 as the explicit reference target

## Explicitly out of scope for v0

- Procedural surface terrain (you cannot land on the planet — orbit view only)
- Weather, lightning, volcanoes, oceans (no data → no rendering)
- Audio (defer)
- Walking around inside the scene with full locomotion (orbit camera only — comfort + scope)
- AI-generated content of any kind
- All ~6,300 planets (curated set only — quality over coverage for v0)

The "no surface" call is deliberate and important: the moment you put feet on the ground, you have to invent terrain. That breaks the project's contract. Floating in space lets us show *only what the data says* and still produce something jaw-dropping.

## Architecture

```
NASA Exoplanet Archive (existing)        Gaia DR3 archive (new)        Washington Double Star (new)
        │                                       │                                │
        │                                       │ one-time TAP query              │ bulk CSV
        ▼                                       ▼                                ▼
planets_snapshots / discovery_papers     starfield.bin (static asset       binary_companions
host_stars_gaia / publications            shipped in /web/public)             (new Postgres table)
        │                                       │                                │
        │   NASA Exoplanet Atmospheric           │                                │
        │   Spectroscopy table (new)             │                                │
        │           │                            │                                │
        │           ▼                            │                                │
        │   planet_atmospheres (new table)       │                                │
        │           │                            │                                │
        ▼           ▼                            │                                ▼
    FastAPI scene-aggregator endpoint  ──────────┴────── /api/planets/{name}/scene
                                                                  │
                                                                  ▼
                                              react-three-fiber + @react-three/xr
                                                  + drei (camera, controls, helpers)
                                                                  │
                                                                  ▼
                                                       /planets/:plName/scene
```

A single new endpoint — `/api/planets/{name}/scene` — composes everything the renderer needs into one round-trip. The frontend stays simple: fetch once, render.

## Tech decisions (already made — do not re-litigate)

| Concern | Decision | Rationale |
|---|---|---|
| 3D library | three.js via `@react-three/fiber` | Mature, idiomatic React, huge ecosystem |
| Helpers | `@react-three/drei` | Camera controls, environment, gizmos — saves weeks |
| VR | `@react-three/xr` (WebXR) | Native Quest 3 browser support; zero install |
| Starfield source | Gaia DR3 (ESA, free) | Authoritative, real, ~1M-source binary fits in 6 MB |
| Starfield delivery | Static binary asset in `/web/public/` | No DB cost; cached forever; zero per-request work |
| Binary star source | Washington Double Star Catalog (USNO, free CSV) | Standard astronomical reference |
| Atmospheric source (bulk) | NASA Exoplanet Archive `spectra` table via TAP | Tells us *which planets have been observed* — observation metadata only |
| Atmospheric source (detections) | Hand-curated `planet_atmospheres` rows for top ~30 planets | The `spectra` table doesn't include molecule-level detections; those live in published papers and must be curated |
| New tables | Additive only; no breaking changes to existing schema | Same pattern as Gaia and citation enrichment |
| Curated set | ~120-150 planets in v0; expand in v1 | Quality bar > coverage |
| Rendering contract | Identical to 2D: visuals computed from measured properties; NULL → "uncertain" | Extends `PROCEDURAL_RENDERING.md` unchanged |

## Data sources — concrete sizes and counts

Pulled from the live database 2026-05-10:

| Source | Planets affected | Storage cost | Pipeline cost |
|---|---|---|---|
| **WDS binary companions** | ~300-450 of 562 multi-star planets (estimated match rate) | <200 KB Postgres table | Bulk CSV download, one-time + monthly refresh |
| **NASA `spectra` table** (observation metadata) | ~150-200 unique planets (2026 estimate) | <1 MB Postgres table | TAP query, weekly refresh |
| **Curated molecule detections** | ~30 planets in v0 (grows over time) | <50 KB Postgres table | Hand-entered + LLM-extracted from `spectra` bibcodes; reviewed |
| **Gaia DR3 starfield** | All planets (background sky) | ~6 MB **static asset**, zero Neon cost | One-time TAP query, manual refresh on Gaia DR releases |

Total Neon impact: **<2 MB** added to a 182 MB / 500 MB DB. Zero risk to the storage budget.

## New database tables

### `binary_companions`
```sql
CREATE TABLE binary_companions (
    hostname              TEXT NOT NULL,
    component_designation TEXT NOT NULL,    -- 'A', 'B', 'C', etc.
    primary_designation   TEXT NOT NULL,    -- which component is the primary
    separation_arcsec     DOUBLE PRECISION,
    position_angle_deg    DOUBLE PRECISION,
    component_mass_msun   DOUBLE PRECISION,
    component_teff_k      DOUBLE PRECISION,
    component_mag_v       DOUBLE PRECISION,
    source_catalog        TEXT NOT NULL,    -- 'WDS' | 'SIMBAD' | 'manual'
    retrieved_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, component_designation)
);
```

### `planet_atmospheric_observations`
Bulk-loaded from the NASA `spectra` table via TAP. One row per observation campaign — tells us a planet has been *looked at*, not what was found.
```sql
CREATE TABLE planet_atmospheric_observations (
    pl_name           TEXT NOT NULL,
    spec_type         TEXT,                    -- 'transmission' | 'emission' | etc.
    instrument        TEXT,
    facility          TEXT,
    min_wavelength_um DOUBLE PRECISION,
    max_wavelength_um DOUBLE PRECISION,
    num_datapoints    INT,
    bibcode           TEXT,
    retrieved_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, bibcode, instrument)
);
```

### `planet_atmospheres`
Curated molecule detections — entered by hand or LLM-extracted from the bibcodes above and reviewed. Starts small (~30 planets in v0) and grows; this is the table the renderer reads to tint the sky.
```sql
CREATE TABLE planet_atmospheres (
    pl_name        TEXT NOT NULL,
    molecule       TEXT NOT NULL,            -- 'H2O', 'CO2', 'CH4', 'Na', etc.
    detection      TEXT NOT NULL,            -- 'detected' | 'tentative' | 'upper_limit'
    instrument     TEXT,                     -- 'JWST/NIRSpec', 'HST/STIS', etc.
    bibcode        TEXT,                     -- ADS reference for the detection
    confidence_sigma DOUBLE PRECISION,       -- statistical significance, when reported
    curated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, molecule)
);
```

All tables are intentionally narrow. The "rich" join lives in the API aggregator, not the schema.

## New ETL jobs

1. **`etl/enrich_binaries.py`** — downloads WDS bulk catalog, fuzzy-matches against `planets_current.hostname` for `sy_snum >= 2`, writes to `binary_companions`. Idempotent. Run weekly.
2. **`etl/enrich_atmospheric_observations.py`** — TAP query against NASA Exoplanet Archive's `spectra` table (`SELECT pl_name, spec_type, instrument, facility, minwavelng, maxwavelng, num_datapoints, bibcode FROM spectra`). Writes to `planet_atmospheric_observations`. Idempotent. Run weekly.
3. **`etl/build_starfield.py`** — one-shot script (not on cron). TAP query against Gaia DR3 for `phot_g_mean_mag < 10`, writes packed binary to `web/public/starfield.bin`. Re-run only when Gaia publishes a new DR.

All three follow the same patterns as `etl/enrich_ads.py`: dotenv config, batch + retry with `tenacity`, dry-run flag, incremental by default.

## New API surface

```
GET /api/planets/{pl_name}/scene
```

Single endpoint that composes everything the renderer needs:

```jsonc
{
  "planet": { /* existing PlanetDetail fields */ },
  "host_star": { /* existing host_stars_gaia fields */ },
  "siblings": [ /* PlanetSummary[] for the system */ ],
  "binary_companions": [ /* binary_companions rows for this hostname */ ],
  "atmosphere": { "molecules": [...] },        // null if no spectroscopy
  "scene_hints": {
    "sun_color_hex": "#ffd28a",                // computed from st_teff
    "sun_angular_size_deg": 0.42,              // computed from st_rad / pl_orbsmax
    "day_length_hours": 18.4,                  // pl_orbper or tidal-locking estimate
    "insolation_relative_earth": 1.04,         // pl_insol
    "death_seconds": 12,                       // derived from pl_eqt + pressure assumption
    "body_type": "rocky" | "icy" | "gas_giant" | "uncertain"
  }
}
```

The `scene_hints` block is **the new contract between data and visuals**. All derivation lives server-side in one place (testable, cacheable). The frontend is a pure renderer.

## Frontend — scene design

### Camera
- Default: 5× planet radius, looking at planet, sun behind camera shoulder
- Mouse/touch: orbit, pan, zoom (drei `OrbitControls`)
- VR: thumbstick locomotion (with vignette comfort) + grip-to-grab-and-drag the system

### Scale
- True AU between planet and host star — *no* log compression (consistent with the existing memory: "true linear AU scaling; zoom is the fix")
- Zoom range: enough to fit a hot-Jupiter system in the view OR fit just one planet at planet-scale
- Time control: 1 sec = 1 day default; HUD slider for {1 hr, 1 day, 1 week, 1 month}/sec

### Sun rendering
- Sphere with emissive material at the spectral-class blackbody RGB
- Real angular size from `st_rad` / `pl_orbsmax`
- A simple corona shader; no lens flare (cheap on Quest GPU)

### Planet rendering
- Sphere with the **same shader logic as the 2D procedural renderer**, ported to GLSL
- Body type from density (`pl_dens`) → drives texture (rocky / icy / gas-banded / uncertain)
- Atmospheric color tint from `planet_atmospheres` molecule list, when present; uncertain-stripe pattern when null

### Companion bodies
- Sibling planets at true AU positions, true relative sizes
- Companion stars (multi-star systems) at angular separation from `binary_companions`

### Background
- Starfield from `starfield.bin`, projected to be correct from the planet's vantage
- Re-projection of nearest ~50 stars to handle parallax shift

### HUD
- World-space panel that follows the user (in VR) or fixed (on desktop)
- Lines: planet name · equilibrium temp · day length · "you would die in N sec" · orbital period
- Time-multiplier slider
- "Jump to sibling" buttons for multi-planet systems

## WebXR / Quest 3 specifics

- WebXR feature detection on mount; "Enter VR" button only renders when supported
- Comfort settings on by default: vignette during locomotion, snap-rotate (not smooth)
- Foveated rendering at level 2 (Quest 3 supports it well via WebGL2)
- Test on Quest 3 browser explicitly each milestone — don't assume desktop performance translates
- Fallback: scene works fine on desktop without VR; "Enter VR" is additive, not required

## v0 launch curation strategy (~120-150 planets)

| Bucket | Count | Selection criterion |
|---|---|---|
| Has atmospheric spectroscopy | ~150 | Bring all of them — rare and meaningful data |
| Multi-star systems intersect with the above | ~30-40 | Atmospheric + Tatooine sky — flagship demos |
| Multi-planet systems with dramatic apparent sizes | ~20 | TRAPPIST-1, Kepler-90, Kepler-11, etc. |
| Visually extreme even without spectroscopy | ~15 | KELT-9 (sun half the sky), HD 80606 (eccentric → sun doubles in size), HR 8799 (directly imaged super-Jupiters) |
| Already in `FEATURED_CATEGORIES` on Home.tsx | ~30 | Editorial alignment — what we already promote |

Heavy overlap → final unique set is ~120-150. Other planets fall back to a "scene not yet curated" message with link to the standard 2D detail page; v1 expansion adds them.

## Quick existing-app win to fold into the same effort

The investigation that produced this plan also surfaced that **562 planets live in multi-star systems but only 54 are formally circumbinary**. The home page currently calls out the 54, but not the other 508. We'll add a `multi-star` pill (distinct from `circumbinary`) to `PlanetGrid` cards in Home.tsx — one-line code change, paid for by the binary-companions data we're already ingesting.

## Phasing

**Milestone 1 — Data foundation** (estimated 3-5 evenings)
- WDS ETL script + table + migration
- Atmospheres ETL script + table + migration
- Gaia starfield extraction script + binary asset shipped
- `multi-star` pill quick win on home page

**Milestone 2 — Scene API + headless render** (estimated 4-6 evenings)
- `/api/planets/{name}/scene` endpoint with full `scene_hints` derivation
- Server-side derivation tests (sun color, angular size, "death" math)
- React Three Fiber + drei dependencies installed; bare scene at `/planets/:plName/scene` showing a sphere and a sun, correctly sized

**Milestone 3 — Rich scene** (estimated 5-7 evenings)
- Procedural planet body shader (porting 2D logic to GLSL sphere)
- Sibling planets at true AU positions with orbit animation
- Companion stars for binary systems
- Starfield background with parallax-corrected nearest stars
- HUD overlay

**Milestone 4 — WebXR / Quest 3** (estimated 3-4 evenings)
- `@react-three/xr` integration + "Enter VR" button
- Controller locomotion with comfort options
- Test pass on Quest 3 device
- Performance pass (target: stable 72 fps in headset)

**Milestone 5 — Curation + launch** (estimated 3-4 evenings)
- Build the v0 hero set list
- Per-planet polish on top 20
- New "VR" featured collection on home page
- Documentation: extend `docs/PROCEDURAL_RENDERING.md` with the 3D extension contract

**Total: ~3-4 weeks of evening work.** Ships independently of any other arm.

## Resolved decisions

1. **WDS access** → CSV bulk download for v0. **v1 enrichment**: cross-reference against SIMBAD per-target for fresher / more authoritative astrometry. SIMBAD lookup logic gets its own ETL job after the v0 ships.
2. **Atmospheric data** → resolved via the TAP investigation: the `spectra` table is observation-metadata only (it tells us *which* planets have been observed and by what instrument). Molecule detections live in published papers and require curation. Two-table approach (above) reflects this.
3. **Gaia magnitude cutoff** → ship both. **Default load**: mag < 8, ~50k stars, ~1 MB (`starfield_basic.bin`). **Lazy-load on Enter VR**: mag < 10, ~300k stars, ~6 MB (`starfield_rich.bin`). Quest 3 has the GPU headroom for the rich version; lazy-load avoids paying the bandwidth on desktop visits that never enter VR.
4. **Locomotion** → orbit-only for v0. Free flight is a v1 conversation, gated on real comfort testing.
5. **Time pacing** → **smart per-planet default with comfort-first behavior**:
   - Target visual orbital cadence: **~60 seconds per orbit** at default speed. This makes WASP-12b (1.09-day orbit) and Kepler-22b (290-day orbit) feel like comparable experiences in the headset.
   - Computed multiplier: `time_per_real_second = pl_orbper / 60` (in days/sec).
   - **The scene starts paused.** User sees a still snapshot, with a play button. This defuses the "spinning around an enormous sun" disorientation the moment the VR session begins.
   - HUD slider exposes {0.25×, 1×, 4×, 16×} relative to the smart default. Going slower for contemplation, faster for systems with year-long orbits. The slider can pause too.
   - For outer planets (HR 8799b, ~430 yr orbit), 60 sec per orbit means watching ~7 years pass per real second. That's the right answer — the data point is the scale, and the pacing communicates it.
