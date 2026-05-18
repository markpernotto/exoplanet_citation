# Starfield Plan

Canonical plan for the starfield + galactic-sky rendering — supersedes
earlier drafts (the original Gaia-reprojection sketch and a separate
WebXR Milky-Way architectural pass). This doc is the union of those
drafts plus the hard lessons from a long VR-debugging session on Quest 3
that reshaped the rendering strategy.

## Status: All five phases shipped (2026-05-13)

Phases 1-5 are in production. The original architecture below describes
Layer 3 as a frontend GLSL fragment shader; **in implementation, Layer 3
also moved to server-side rasterization** alongside Layers 1, 2, and 4.
Reason: a long debugging session showed that a custom `ShaderMaterial`
(and even `MeshBasicMaterial` extended via `onBeforeCompile`) silently
failed to compile inside the @react-three/xr 6 multiview pipeline on
Quest 3 — five different shader iterations all worked on desktop but
none rendered the diffuse layer in VR. The pattern matched this doc's
"N tiny meshes ≠ one big mesh" lesson: there's a class of WebGL
operations the headset rejects without error, and shader splicing
turned out to be one of them.

The pivot: port the GLSL `densityAt` + log-spaced line-of-sight march
to numpy in `api/starfield.py`, render the diffuse layer into the same
equirectangular PNG that Layers 1+2 already paint, ship one textured
sphere to the client. Tradeoff: per-vantage gen went from ~200ms (stars
only) to ~700ms-1.3s (stars + diffuse + extragalactic anchors + dust +
spiral arms + warmth tinting), cached forever after. Quest 3 renders
it identically to desktop because it's just `meshBasicMaterial.map` on
a sphere — exactly what was working in Phase 3.

What this means for the "Layer 3" row in the architecture table below:
the **Render strategy** column should read "Server-side numpy
rasterization, composited into the same PNG as Layers 1+2" rather than
"Fragment shader on the same skydome sphere." Same applies to Layer 4
— extragalactic anchors are server-rasterized Gaussian blobs in the
PNG, not three.js sprites. The Phase 4 / Phase 5 section near the
bottom of this doc reflects the original frontend plan; for current
behavior, read `api/starfield.py` (single source of truth).

---

## What we learned the hard way

Six VR-stars implementations that all failed on Quest 3 in the same session:

1. `THREE.Points` with `gl_PointSize=4.5px` — invisible (gl_PointSize clamped or ignored in XR multiview)
2. `THREE.Points` with 4× boost → 9-18 px — still invisible
3. `THREE.Points` with 15× boost → 67 px — still invisible
4. `InstancedMesh` of camera-facing transparent additive planes — invisible
5. `InstancedMesh` of solid `MeshBasicMaterial` planes (no transparency) — invisible
6. `InstancedMesh` of solid icosahedrons at 50× scale — invisible

All six rendered perfectly on desktop. The depth-clip override (`session.updateRenderState({ depthFar: 1e9 })`) didn't change the outcome. The scene scaling (mapping AU → meters) didn't change it. The pattern is unambiguous: **rendering 50k+ small individual objects as stars does not work in @react-three/xr 6 + three.js + Quest 3**, for reasons we couldn't isolate in-session (multiview rendering quirk most likely).

**The fundamental architectural rule for the starfield going forward:** stars are ONE mesh that wraps the user, not N tiny meshes scattered around. Same primitive as the planets, which always render fine.

This is also the VR industry standard. Every space game on every headset does skydomes/skyboxes for the same reason.

---

## Architecture — four layers, one rendering convention

Inherits the four-layer split from `webxr_milky_way_plan.md`. Adds an explicit rendering-strategy column that reflects the lesson above.

| Layer | Source | Render strategy | Role |
|---|---|---|---|
| **1. Local stars** | Gaia DR3 (heliocentric XYZ + mag + bp_rp) | Rasterized into the same equirectangular texture as Layer 2 (server-generated per vantage) | Recognizable nearby stars at correct apparent magnitudes; Sol as one of them |
| **2. Galactic stars** | Procedurally sampled from Bland-Hawthorn & Gerhard 2016 density model (~1M particles, server-side) | Rasterized into the same equirectangular texture; on bulge vantages this is where most of the visible "milky way" comes from | Bulk stellar population that gives the galactic plane its density |
| **3. Diffuse galaxy** | Fragment shader on the same skydome sphere | Volumetric line-of-sight integration through density profiles + dust | The smooth Milky-Way-band glow with dust lanes; what makes it look like a real galaxy from a bulge vantage |
| **4. Extragalactic** | Hand-placed catalog (LMC, SMC, M31, M33, Sgr dSph) | Billboards inside the skydome | Galaxies visible from inside the Milky Way |

All four layers render *inside the same skydome sphere*. Layer 1+2 share an equirectangular star texture. Layer 3 is a fragment-shader contribution on the same sphere mesh, composited with the texture. Layer 4 is a handful of billboard meshes inside the sphere. The skydome is the unified rendering primitive.

This is a meaningful divergence from both prior plans:

- My `GALACTIC_SKIES.md` only handled Layer 1, rendered as `<points>` reprojected client-side — would have hit the same wall in VR.
- The user's `webxr_milky_way_plan.md` proposes Layer 1+2 as `Points`, Layer 3 as a separate sphere, Layer 4 as billboards. After this debugging session, all "points/scattered things" become rasterized-into-texture. Otherwise architecturally identical.

---

## Layer 1+2: shared equirectangular texture (server-rendered per vantage)

The breakthrough idea: **don't ship Gaia/galactic particles as a point cloud to the client.** Ship a pre-rasterized equirectangular texture (4096×2048 PNG, ~2-5 MB compressed) generated per host system on the server.

### Server endpoint

`GET /api/starfield/:plName.png` — returns the equirectangular sky as seen from that host system.

Server-side generation per request:

1. Resolve host's galactic XYZ from `(ra, dec, sy_dist)` (or microlensing l/b + distance fallback).
2. Load cached Gaia-DR3-canonical-XYZ + galactic-particles-XYZ (precomputed binaries from the ETL).
3. For each star: subtract host XYZ → get vantage direction + distance → compute apparent magnitude → drop if dimmer than threshold.
4. For each surviving star: compute equirectangular (u, v) from direction; rasterize a dot of size ∝ apparent brightness into a Cairo/Pillow canvas; color from bp_rp.
5. Encode PNG (or KTX2 for VR-friendly GPU formats), emit with `Cache-Control: public, max-age=31536000, immutable`.

Expected latency: ~200-500 ms server-side for 1M+ stars. Cache hit after first viewer in a system is free.

### Client consumption

Trivial: fetch the PNG, set as `scene.background` (and/or as texture on a skydome sphere — see below), done. No `<Points>`, no `InstancedMesh`, no per-vantage transformation in the browser.

### Why server-side rendering

- **Solves the VR-stars problem definitively.** A textured sphere always renders in VR — we have direct evidence of this from our planet/sun rendering working fine.
- **Solves the 1M-particle perf problem too.** No 50 MB binary download, no per-vantage transform in a Web Worker, no instanced render path. Just a 2-5 MB PNG.
- **Solves the device-tier problem.** Quest 2 renders a textured sphere the same as Quest 3 — no degradation path needed for Layers 1+2.
- **Cost:** loses the dynamic per-frame transformation (if the user could move between vantages in real time). Acceptable trade — exoplanet vantages are discrete per system, not continuous.

---

## Layer 3: diffuse galaxy fragment shader (same skydome sphere)

Same skydome mesh, second material pass — or, more cleanly, a shader on the skydome sphere that composites the star texture with a procedural galactic diffuse contribution.

```glsl
// Pseudo-GLSL on the skydome
uniform sampler2D uStarTexture;
uniform vec3 uObserverGalacticXYZ;  // kpc

void main() {
  vec3 dir = normalize(vWorldPos);  // outward direction from sphere center
  // Layer 1+2: bright stars baked into texture
  vec3 stars = texture2D(uStarTexture, vUV).rgb;
  // Layer 3: diffuse galaxy via line-of-sight integration
  vec3 diffuse = marchGalaxy(uObserverGalacticXYZ, dir);
  gl_FragColor = vec4(stars + diffuse, 1.0);
}
```

The march function evaluates analytic Bland-Hawthorn & Gerhard density profiles per step. Math from `webxr_milky_way_plan.md` Layer 3 carries over unchanged. 64 steps on Quest 3, 32 on Quest 2 with half-resolution.

This is where the bulge-vantage demo lands: from OGLE-2005-BLG-390Lb, the diffuse layer fills the hemisphere with the actual galactic bulge glow, layered over individual Layer 1+2 stars from the texture.

---

## Layer 4: extragalactic anchors

Five-ish billboards (LMC, SMC, M31, M33, Sgr dSph) with known galactocentric XYZ. Same as `webxr_milky_way_plan.md`. Trivial perf cost.

Each billboard is a `<sprite>` or simple plane mesh inside the skydome sphere, positioned at the vantage-transformed direction from the host. ~5 draw calls total.

---

## ETL changes

```
etl/build_gaia_xyz.py            NEW
  — Reads existing Gaia snapshot, emits gaia_xyz.parquet
    (heliocentric XYZ pc + abs_mag + bp_rp), one row per star.
    Sol is row 0 at (0,0,0).
etl/build_galactic_particles.py  NEW
  — Procedural Monte Carlo sampler. Emits galactic_particles.parquet,
    1M rows × (xyz_kpc, abs_mag, color). Deterministic seed.
etl/build_extragalactic.py       NEW
  — Hand-curated YAML → JSON, ~5 entries.
api/starfield.py                 NEW
  — GET /api/starfield/:plName.png endpoint. Loads host galactic XYZ from
    DB, loads parquet caches, rasterizes equirectangular PNG, returns it.
    LRU in-memory cache for hot systems; HTTP Cache-Control for cold.
api/host_galactic_xyz.py         NEW
  — Resolves galactic XYZ for each host. Gaia parallax path + microlensing
    l/b fallback (per webxr_milky_way_plan.md).
```

Total: 5 new modules, ~600-1000 LOC. The Cairo/Pillow rasterization is straightforward; the procedural galactic sampler is the most novel piece (Galaxia-paper math, ~200 LOC).

---

## Effort estimate

**Honest:** 8-12 days focused work. Distributed as:

- ETL Gaia XYZ + galactic particles + extragalactic catalog: 2 days
- API endpoint + per-host XYZ resolver + rasterization: 2 days
- Frontend skydome integration (replace current Starfield component): 1 day
- Layer 3 diffuse shader: 3 days (most novel)
- Layer 4 extragalactic billboards: 0.5 days
- Acceptance criteria validation (Sol vantage, bulge vantage, perf): 1.5 days
- Buffer for surprises: 2 days

This is ~2-2.5 weeks of focused engineering, comparable to the 3-week estimate in `webxr_milky_way_plan.md`. My original `GALACTIC_SKIES.md` 6.5hr estimate was off by an order of magnitude — that's what scoping without prototyping costs.

---

## Phased shipping

### Phase 1: Sol-vantage skydome (Day 1-2, ships immediately)
- Drop the current `<Points>` Starfield.
- Build server endpoint that just rasterizes the existing Gaia snapshot from Sol's vantage (no per-vantage logic yet — every planet gets the Sol sky).
- Frontend: skydome sphere with texture, `scene.background` fallback.
- **Outcome:** stars work in VR everywhere. Looks the same on every planet. Solves the today-problem.

### Phase 2: Per-vantage Gaia reprojection (Day 3-5)
- Add `host_galactic_xyz` resolution.
- Endpoint reprojects Gaia stars from host's frame.
- **Outcome:** local-neighborhood planets show subtly shifted star fields. TRAPPIST-1's sky differs from Earth's, but only at the level of the closest dozen stars moving.

### Phase 3: Galactic particle layer (Day 6-8)
- ETL: procedural Milky Way sampler emits parquet of 1M particles.
- Endpoint rasterizes Gaia + galactic particles into combined texture.
- **Outcome:** the Milky Way band becomes a real density of points. Bulge planets start to look interesting.

### Phase 4: Diffuse galaxy shader (Day 9-12)
- Frontend skydome material upgrades from `MeshBasicMaterial` to a custom shader that composites texture + line-of-sight diffuse march.
- **Outcome:** the headline bulge-vantage experience. Galactic center fills the sky.

### Phase 5: Extragalactic anchors (Day 12)
- 5 billboards added to skydome. Quick win.

Each phase is independently shippable. Phase 1 alone resolves the VR-stars-don't-work issue we hit this session.

---

## Tuning render resolution

The starfield PNG is rendered at 6144 x 3072 equirectangular by default. The knob lives in `api/starfield.py`:

```python
DEFAULT_WIDTH = 6144
DEFAULT_HEIGHT = 3072
```

To render at a different resolution locally:

1. Edit `DEFAULT_WIDTH` and `DEFAULT_HEIGHT`. Use a 2:1 aspect ratio; the equirectangular projection assumes it.
2. Restart the API server (`make api`).
3. The next request for any host re-renders at the new resolution. The process-level LRU cache is keyed on dimensions, so prior entries are ignored without needing a manual flush.

That's it. No env vars, no command-line flags, no separate code path. Any width in `[1, 16384]` works.

### Resolution presets

Measured on the production catalog (~1.46M stars; Sol vantage; post-refactor in-place compositors with chunked sRGB encoding). PNG size varies by vantage (bulge views compress less than polar views).

| Preset | Dimensions      | Texels    | PNG     | Peak RSS  | Cold render | Browser texture | Texels / deg | Notes                                                              |
|--------|-----------------|-----------|---------|-----------|-------------|-----------------|--------------|--------------------------------------------------------------------|
| 4K     | 4096 x 2048     | 8.4M      | ~8 MB   | ~525 MB   | ~5 s        | 32 MB           | 11.4         | Fits any environment. Visibly soft in VR on Quest 3.               |
| 6K     | 6144 x 3072     | 18.9M     | ~16 MB  | ~940 MB   | ~5 s        | 72 MB           | 17.1         | Repo default. Fits Vercel Hobby 1024 MB function memory.           |
| 8K     | 8192 x 4096     | 33.6M     | ~24 MB  | ~1.3 GB   | ~6 s        | 128 MB          | 22.8         | Crisp in headset. Needs Vercel Pro for the hosted deploy.          |
| 12K    | 12288 x 6144    | 75.5M     | ~42 MB  | ~2.7 GB   | ~8 s        | 288 MB          | 34.1         | Studio-quality stills. Local-only; even Vercel Pro is too tight.   |
| 16K    | 16384 x 8192    | 134M      | ~63 MB  | ~4.3 GB   | ~11 s       | 512 MB          | 45.5         | GPU texture-size ceiling. Local-only. Screenshots / Zenodo / talks.|

The "texels per visual degree" column is the per-pixel sky-sampling density of the equirectangular PNG. Quest 3's per-eye display resolves about 18.8 px/deg, so 6K is already close to a 1:1 sampling match for in-headset viewing. Higher presets pay off for desktop screenshots, marketing stills, external 4K monitors, and any future headset that resolves more than the Quest 3's panel does.

### What changes as you go up

Memory is the practical constraint. The render pipeline holds one full-resolution float32 canvas during compositing (linear-light RGB), plus short-lived per-chunk transients during the sRGB encode. Peak RSS scales roughly linearly with texel count.

Locally none of these resolutions are a problem; even 16K's ~4.3 GB peak fits comfortably on any modern dev box. The "Peak RSS" column matters mostly for sizing Vercel function memory:

- **Vercel Hobby (free):** 1024 MB function memory. 6K fits; anything larger needs a memory bump.
- **Vercel Pro:** up to 3008 MB per function via `functions.memory` in `vercel.json`. Covers 8K comfortably; 12K is the practical hosted ceiling.
- **16K hosted:** outside the serverless model. Render offline, store the PNG as a static asset, or stand up dedicated infrastructure.

For local development, ignore the Vercel column entirely.

### Hard ceiling

The frontend skydome is a WebGL / WebXR sampled texture. WebGL caps single-texture dimensions at the device's `MAX_TEXTURE_SIZE`. On Quest 3, Apple Vision Pro, and most desktop GPUs (NVIDIA Ada / AMD RDNA 3 / Apple Silicon) this is **16384**. A 16384 x 8192 equirectangular skydome is the largest single texture the runtime can sample from; pushing the constants higher would either fail to upload or get silently truncated at the driver layer.

### Capturing a high-res render without serving it through the runtime

If the goal is a one-off image for a slide, poster, or Zenodo deposit rather than a runtime asset, render directly to PNG and save it:

```python
from api.starfield import load_catalog, render_png
catalog = load_catalog()
png_bytes = render_png(
    catalog,
    host_xyz_pc=(0.0, 0.0, 0.0),       # or any host's heliocentric ICRS pc
    width=16384,
    height=8192,
)
with open("starfield-16k-sol.png", "wb") as f:
    f.write(png_bytes)
```

`render_png` accepts explicit `width` and `height` keyword arguments, so a one-off high-resolution capture does not require changing the module-level defaults.

### Why a code change instead of an env var

The pair of constants lives at module import time so `@lru_cache` and the default-arg paths in `rasterize_skytexture` both see the same value without runtime branching. Reading from an env var would require either re-importing or threading the value through every call site; for a knob that is set once per environment, editing the constant is the cleaner approach.

---

## Open questions

- **Dust extinction in Layer 1+2 rasterization** — for galactic-center vantages, stars on the far side of the bulge are heavily reddened. The current bp_rp colors don't account for dust along the new line of sight. Acceptable simplification for Phase 1-3; revisit in Phase 4 alongside the diffuse shader's dust handling.
- **Real-time vs cached** — if a user moves between systems quickly, do we want to pre-fetch starfield textures? Probably not worth it; the 200-500ms gen time is fine for an interaction that happens at most once per minute.

---

## Stretch / v2 ideas

- **Sgr A\* marker** — small UI overlay pointing at the galactic center direction from the current vantage. Helps users orient themselves.
- **Earth pointer** — "Earth is in that direction" arrow when on a non-Sol vantage. Wonder-inducing.
- **Time-evolved sky** — Gaia stars at their 100kyr / 1Myr proper motions, slider in the UI. Cool but niche.
- **Switchable Milky Way photograph fallback** — for users on devices where the procedural diffuse shader is too expensive, swap in a static photograph baked into texture. Listed in `webxr_milky_way_plan.md` as a Quest 2 fallback; we can offer it as a "low-power mode" option universally.

---

## Lessons file (for future-me / next contributor)

When working on the VR scene:

- **N tiny meshes ≠ one big mesh.** Anything that depends on rendering hundreds-of-thousands of small objects is suspect in XR. If it must be done, validate the rendering primitive works at small scale FIRST.
- **Test deployed, not local.** WebXR requires HTTPS; that means Vercel-deployed code, not localhost. Local code changes don't reach the Quest until you commit + push + wait for the deploy. (See git log timing in [the conversation transcript that produced this plan].)
- **`gl_PointSize` is not reliable in XR.** Treat point sprites as desktop-only.
- **`scene.background` and skydome both work in XR.** Use either. Both is fine — skydome overdraws scene.background but acts as a fallback if scene.background is buggy on a specific device.
- **`session.updateRenderState({ depthFar: 1e9 })` is mandatory** for any scene with content past 1000 units. Add to any new XR scene reflexively.
- **Bloom (postprocessing's EffectComposer) black-screens XR.** Skip it inside an active XR session.
