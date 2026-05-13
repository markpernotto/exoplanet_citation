# Starfield Plan

Canonical plan for the starfield + galactic-sky rendering — supersedes
earlier drafts (the original Gaia-reprojection sketch and a separate
WebXR Milky-Way architectural pass). This doc is the union of those
drafts plus the hard lessons from a long VR-debugging session on Quest 3
that reshaped the rendering strategy.

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

## Open questions

- **Dust extinction in Layer 1+2 rasterization** — for galactic-center vantages, stars on the far side of the bulge are heavily reddened. The current bp_rp colors don't account for dust along the new line of sight. Acceptable simplification for Phase 1-3; revisit in Phase 4 alongside the diffuse shader's dust handling.
- **Texture resolution vs file size** — 4096×2048 PNG is ~2-4 MB. 8192×4096 is ~10 MB but resolves stars at 0.045° (within Quest 3's per-pixel resolution). Phase 1 tests with 4096; bump if visibly aliased.
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
