# Procedural Rendering

How this project depicts exoplanets and host stars visually. The principle: **every visual is computed from measured properties**, not pulled from an artist's rendering library or a stock-image database.

---

## Why procedural

Three reasons we don't use artist renderings or stock imagery:

1. **Coverage.** Of ~6,300 confirmed exoplanets, fewer than 100 have an official artist's rendering. The rest would require either generic placeholders (which immediately reads as "we ran out of pictures") or a tier system where some planets feel real and others feel stubbed.
2. **Honesty.** Artist renderings are themselves a guess — usually informed, but still speculation about cloud cover, surface texture, and lighting that the data doesn't determine. Displaying them implies a level of certainty we don't have.
3. **Differentiation.** The visual *being* a function of the data is the project's strongest UX statement. A user can hover over a procedurally-rendered planet and see why it's the color it is. That's not possible with stock imagery.

The design contract is therefore:
- A planet's appearance is fully determined by its measured properties.
- The mapping from properties → appearance is documented, defensible from public exoplanet-atmosphere literature, and visible to users on demand.
- Where data is missing (NULL), the rendering uses a clearly-marked "uncertain" style rather than guessing.

---

## What drives a planet's appearance

The dominant signals for visible appearance are equilibrium temperature and bulk density. Secondary signals are insolation flux, stellar effective temperature (since the planet is illuminated by its host star's spectrum), and stellar metallicity (which weakly predicts cloud-formation likelihood). All of these are available in our typed columns of `planets_snapshots`.

| Property | Column | Drives |
|---|---|---|
| Equilibrium temperature | `pl_eqt` (Kelvin) | Atmospheric color (dominant signal) |
| Bulk density | `pl_dens` (g/cc) | Body type (rocky / icy / gas giant) |
| Radius | `pl_rade` (Earth radii) | On-screen size |
| Mass | `pl_bmasse` (Earth masses) | Cross-check on density classification |
| Insolation flux | `pl_insol` (× Earth's) | Brightness of the day side |
| Host star temperature | `st_teff` (Kelvin) | Color of incoming light → tints reflected color |
| Host star metallicity | `st_met` (raw_row) | Weak: cloud probability for gas giants |

---

## Step 1 — body type classification

Use bulk density to classify the planet's gross structure. This is the standard astrophysical taxonomy.

```
density >= 4.0 g/cc        →  ROCKY     (Mercury, Venus, Earth, Mars range; ~5.5 g/cc for Earth)
1.5 <= density < 4.0       →  ICY       (mini-Neptunes, water worlds, sub-Neptunes; ~1.6 g/cc for Neptune)
density < 1.5              →  GAS GIANT (Saturn, Jupiter, hot Jupiters; ~0.7 g/cc for Saturn, ~1.3 g/cc for Jupiter)
density NULL or unknown    →  UNCERTAIN (render with a marker indicating "not enough data")
```

If density is unknown but we have radius:
- `pl_rade < 1.6` Earth radii → ROCKY
- `1.6 <= pl_rade < 4.0` Earth radii → ICY
- `pl_rade >= 4.0` Earth radii → GAS GIANT
- All inputs NULL → UNCERTAIN

These thresholds aren't sharp; they're defensible cuts from the exoplanet-population
literature. Authoritative source: [`body_type_from_density()`](../api/scene.py).

---

## Step 2 — atmospheric color from temperature

For each body type, equilibrium temperature drives the dominant color. The mappings below are simplified but defensible from atmospheric-chemistry literature; they're approximations of what the dominant absorbing/scattering species would do at each temperature regime.

### Rocky planets

| Temp range (K) | Visual style | Dominant species / cause |
|---|---|---|
| > 1200 | Molten orange-red, glowing | Surface partially molten; thermal emission visible |
| 600 – 1200 | Dark gray with red glow on dayside | Hot rocky surface, cooling lava, possible silicate clouds |
| 273 – 600 | Tan / brown / gray | Mars-Venus regime; surface visible if low albedo |
| 200 – 273 | Frosted blue-white-gray | Near water freezing point; possible ice with darker rocky patches |
| < 200 | Pale icy white-blue | Frozen surface, possibly with methane/N2 ice |

If we have insolation flux and an estimate that water could be liquid (`pl_eqt` between ~273 K and ~373 K, plus `pl_insol` between ~0.5× and ~1.5× Earth's), we can apply a "temperate" tint with possible blue-green coloration suggesting oceans/vegetation — but **only as a possibility**, not as a claim. The tooltip would say "consistent with Earth-like temperatures."

### Ice/water worlds (mini-Neptunes, sub-Neptunes)

| Temp range (K) | Visual style |
|---|---|
| > 700 | Orange-yellow with gradient bands (sodium/potassium absorption) |
| 300 – 700 | Cream-and-blue, hazy |
| 150 – 300 | Pale blue-cyan, smooth |
| < 150 | Pale ice-blue with possible methane tint |

### Gas giants

This is where temperature most strongly dominates appearance, and the mappings have direct atmospheric-chemistry justification:

| Temp range (K) | Visual style | Dominant cause |
|---|---|---|
| > 2200 | Deep red-orange, glowing | Ultra-hot Jupiters; thermal emission detectable |
| 1500 – 2200 | **Deep blue / violet** | TiO and VO molecules absorb red wavelengths strongly |
| 1000 – 1500 | Yellow-orange | Sodium D-line absorption dominant |
| 500 – 1000 | Orange-brown, banded | Sulfur compounds, alkali metals |
| 200 – 500 | Cream-and-tan banding | Jupiter-analog regime; ammonia clouds |
| 100 – 200 | **Pale Neptune-blue** | Methane absorbs red light; remaining reflected light is blue |
| < 100 | Pale blue-white, smooth | Cold ice giants, methane fully condensed |

The "deep blue hot Jupiter" case is the most counterintuitive one and one of the project's most interesting visual stories. Many users assume hot = red. Hot gas giants are often blue or violet because the molecules in their atmosphere preferentially absorb red and reflect blue. Worth surfacing in the UI as a teachable moment.

---

## Step 3 — size scaling

Render planets at a size proportional to `pl_rade`, with the host star scaled by `st_rad` × ~109 (since 1 solar radius is ~109 Earth radii). For a planet detail page this gives a true-to-scale visual.

For overview pages where many planets need to be visible at once, use a logarithmic or capped scale — Earth (1 Earth radius) and a hot Jupiter (~12 Earth radii) shouldn't be rendered at literal scale or one will be invisible.

---

## Step 4 — eccentricity, inclination, and orbital geometry (system view)

For the "solar system view" of a host system showing all sibling planets:
- `pl_orbsmax` → orbital radius (in AU, scaled to fit the canvas)
- `pl_orbeccen` → orbit shape (0 = circle, > 0.5 = strongly elongated; render as actual ellipse)
- `pl_orbincl` → orbital tilt (for an oblique 3D view)
- `pl_orbper` → animation period if orbits are animated

---

## Host star color from Gaia DR3

The host star's color is determined by its surface temperature, which Gaia measures directly via the BP – RP color index (the difference between its blue and red apparent magnitudes). This is more precise than relying on `st_teff` from pscomppars (which can be a literature average).

```
BP - RP < 0          →  blue (O/B-type stars; surface temp > 10,000 K)
0 ≤ BP - RP < 0.5    →  blue-white (A-type stars; ~7500 – 10,000 K)
0.5 ≤ BP - RP < 1.0  →  white-yellow (F/G-type stars; ~5500 – 7500 K — our Sun is here)
1.0 ≤ BP - RP < 1.5  →  orange (K-type stars; ~4000 – 5500 K)
1.5 ≤ BP - RP < 3.0  →  red-orange (M-dwarfs; ~2500 – 4000 K)
BP - RP ≥ 3.0        →  deep red (very late M-dwarfs / brown dwarfs)
```

For stars without a Gaia BP-RP measurement, fall back to `st_teff` from pscomppars and apply the standard blackbody-temperature-to-RGB approximation. Mark these in the UI as "approximate color" so the user knows the difference.

The host star's apparent size on a planet detail page can be scaled by `st_rad` (solar radii); for the system view, the star is at the center and the planets orbit around it.

---

## Galactic positioning and the per-vantage sky

See [STARFIELD_PLAN.md](STARFIELD_PLAN.md) for the canonical plan covering
the starfield rendering, per-vantage Gaia reprojection, the diffuse Milky
Way fragment shader, and extragalactic anchors (LMC, SMC, M31). That doc
supersedes earlier sketches of the "here we are / here this planet is"
view: instead of placing the user on a top-down artist's-rendering of the
galaxy, we render the sky **from the planet's vantage point** — a
star-by-star equirectangular projection with the host star's galactic
XYZ as origin. From bulge-microlensing hosts this surrounds the user
with the galactic center; from solar-neighborhood hosts it's a slightly-
shifted Earth sky. The principle of procedural-from-data carries through:
no artist's renderings, all positions and brightnesses derived from
Gaia DR3 plus a published Milky-Way density model for the procedural
galactic-star layer.

---

## Honesty layer (visible to users)

Every procedurally-rendered visual carries a small "?" or "i" affordance that opens an explanation. Sample UI copy:

> **Why does this planet look like this?**
>
> This rendering is computed from the measurements we have, not photographed.
> - **Color**: Planet has an equilibrium temperature of ~1830 K and a bulk density below 0.5 g/cc, classifying it as a hot Jupiter. At this temperature, TiO and VO molecules in the atmosphere strongly absorb red wavelengths, leaving the planet appearing blue-violet to a hypothetical observer.
> - **Size**: Drawn at ~12.4 Earth radii, the measured radius.
> - **Star color**: The host star is a G-type star with Gaia BP-RP color of 0.82, similar to our Sun. Rendered as pale yellow.
>
> *What we don't know*: cloud cover, weather patterns, exact surface texture, day/night-side temperature contrast. These would require direct atmospheric spectroscopy that isn't yet available for most exoplanets.

This kind of transparency is a portfolio asset, not a weakness. It demonstrates literacy with the data and respect for what the measurements actually tell us.

---

## Implementation notes

- **Rendering technology**: three.js (via `@react-three/fiber`) for all planet/star visuals. Originally planned around SVG for static visuals but consolidated on three.js once the system view, surface view, and VR view were all on the books — same shader code drives the photosphere across all three modes. WebXR via `@react-three/xr` for the VR path.
- **Color computation**: per-fragment color happens in custom GLSL ShaderMaterials. The blackbody-temperature-to-RGB approximation (Tanner-Helland-derived) runs in JS for star colors (`teff_to_rgb_hex` in [api/scene.py](../api/scene.py)); per-planet body color from `bodyTypeToFillColor` lookup with temperature bucketing.
- **Fallbacks**: planets with insufficient data render via the `UNCERTAIN` body type — a flat gray with a low-contrast indicator. **Never invent values.**
- **Color-blindness**: temperature → color mapping has natural luminance variation (hot = bright, cold = dark) preserving information for color-blind users; verify with simulation tools before shipping.
- **Performance**: rendering ~6,300 planets simultaneously is not a current case (only system-view siblings render together, max ~8 planets); a future "all planets in the galaxy" view would require instanced rendering.

---

## The rendering pipeline (implementation reference)

This section documents the actual rendering code as it stands, since the
shaders and material configurations grew complex enough that the conceptual
mappings above don't capture all the choices. Authoritative source: every
component referenced is in [web/src/pages/ScenePage.tsx](../web/src/pages/ScenePage.tsx).

### View modes

The scene component supports three view modes off the same data:

- **System view (`viewMode === 'system'`).** Top-level overview. The host
  star sits at scene origin, planets orbit around it. `OrbitControls`
  for desktop drag-to-orbit; scroll-to-zoom. Animated when paused = false.
- **Surface view (`viewMode === 'surface'`).** "You are standing on the
  focal planet." `CameraFollowFocal` rides the focal planet's animated
  position; `FirstPersonLook` lets the user drag-rotate. Focal planet
  body is hidden (`hideFocal`). Sun arcs across the sky as the planet
  orbits.
- **VR view (immersive XR session).** Either system or surface mode plus
  an active WebXR session. The scene is uniformly scaled up by
  `<VRSceneScale>` (factor ≈ `6 / maxOrbit`, clamped to [2, 200]) so the
  host system fits comfortably in a room-scale VR view. User position
  comes from `<VRRig>` (an `<XROrigin>` group) at world position
  `[3, 0.5, 1.5]` meters; locomotion via `useXRControllerLocomotion`
  with speed `max(0.5, orbsmax * 3) AU/sec`.

### Star photosphere shader

The custom `Photosphere` material is what gives stars their "alive" look
rather than rendering as a flat colored disc. Composition per-fragment:

1. **HDR color base** — `uColor` is the star's blackbody color from
   `teff_to_rgb_hex`, with a **saturation push** for cool stars
   (G and B channels suppressed proportionally to a `cool` factor
   derived from `(5778 - teff) / 3278`) so M-dwarfs read as a deep
   saturated red rather than a wishy-washy orange.
2. **HDR boost** — `uHdr` is a per-star multiplier in roughly the range
   2.0× (Sun) to 5.0× (KELT-9 and hotter). Cool stars get a `warmth`
   bonus (up to ~2.8× for TRAPPIST-class M-dwarfs) because deep red has
   ~10× lower perceived contrast than white against black, so we need
   to push their HDR higher to get a visually comparable bloom-halo.
   Hot-star bonus is capped at `1.5×` (so KELT-9 hits ~5.0× total, not
   ~9×) to keep mipmapBlur from "doming" the entire frame.
3. **Granulation noise** — a 3D Perlin-like noise function sampled in
   world space, animated by `uTime`, produces the "boiling photosphere"
   surface. Modulation amplitude 0.10 — visible motion without bright
   peaks that bloom-smear into the corona.
4. **Limb darkening** — `mix(0.15, 1.0, pow(mu, 0.7))` where `mu` is the
   cosine of the angle between the surface normal and view direction.
   Floor of 0.15 (well past real-Sun ~0.4) is exaggerated so the
   photosphere edge fades almost to black before meeting the bloom
   corona, eliminating the hard-disc silhouette.

The photosphere renders in two passes:
- **Depth pre-pass** at `renderOrder=-100` with `colorWrite=false` — writes
  only depth, ensures planets behind the sun are culled before drawing.
- **Color pass** at `renderOrder=10` — the visible shader output.

### Bloom (post-processing)

Bloom is configured for "stellar corona" — the wide soft halo around
each photosphere that gives stars visual presence. Tuned config:

- `mipmapBlur` enabled for Gaussian-pyramid spread.
- `levels={4}` — caps the pyramid depth. At the default ~8 levels, the
  lowest mip is ~1 pixel and a single bright pixel domes the whole
  frame. Four levels gives a wide soft halo without that artifact.
- `luminanceThreshold={0.30}` — catches the full photosphere disc
  (including the limb-darkened edge ~0.5 luminance for cool stars,
  much higher for hot stars).
- `intensity={1.7}` + `radius={0.9}` — the wide intense corona look.

**Side effect:** companion stars (rendered via `meshBasicMaterial` with
`toneMapped:false`) and very-bright sunlit planets can also clear the
bloom threshold. Acceptable tradeoff for v1. Cleanly excluding them
would require selective bloom (a layer-based render-pass refactor that
the `@react-three/postprocessing` 2.19 + multi-Three-instance pipeline
makes difficult).

### Planet body shader

`buildPlanetBodyMaterial` produces per-planet ShaderMaterials cached by
`(bodyType, fillColor, glow, isCold)` tuple. Per-fragment:

- **Body color** from `uColor` (bucketed by temperature per the mappings
  above).
- **Latitude bands** for gas giants — three sinusoidal layers in latitude
  produce subtle horizontal banding without claiming specific patterns.
- **Polar ice caps** for cold rocky planets (`isCold && bodyType==='rocky'`)
  — smoothstep on `|sin(latitude)|` whitens the poles.
- **Emissive** for `glow=true` (hot lava worlds, hot Jupiters) — uniform
  emission baked into the body color so they read as "thermally bright"
  rather than just reflecting sunlight.

Gas giants additionally render a `PlanetAtmosphere` — a slightly larger
sphere (1.08× radius) with a fresnel-shader: alpha is high at the
silhouette (where you'd see through more atmospheric path) and 0 toward
the center (looking straight down through thin atmosphere). Sun-side
modulation darkens the far hemisphere.

### Scaling system

- `RSUN_IN_AU = 0.00465` — 1 solar radius in AU.
- `REARTH_IN_AU = 0.0000426` — 1 Earth radius in AU.
- `BODY_EXAG = 500` — all bodies (sun, planets, companions) are scaled
  up by this factor. Without it, true-to-scale planets at AU orbital
  distances are sub-pixel from any reasonable zoom.
- `MIN_PLANET_AU = 0.0008` — visibility floor; sub-Earth rocks need this
  or they vanish.
- `ORBIT_CAP_FRAC = 1 / 25` — a planet's display radius can't exceed
  this fraction of its orbital distance; prevents large planets from
  overlapping the sun in tight orbits.
- `SUN_PERIAPSIS_FRAC = 1 / 4` — sun display radius is capped at this
  fraction of the focal planet's periapsis distance; prevents the sun
  from engulfing inner planets at periapsis.

### VR-specific quirks (gotcha file)

WebXR + three.js + Quest 3 has a handful of quirks that aren't obvious
from the docs. Codified here so the next person doesn't relearn them:

- **`<EffectComposer>` black-screens XR sessions.** The post-process
  pipeline renders to a single 2D framebuffer; WebXR needs per-eye
  rendering. The `<PostProcessing>` component returns `null` while in
  an XR session, falling back to direct rendering (no bloom in VR).
- **`gl_PointSize` is unreliable in Quest's XR pipeline.** Some
  implementations clamp it aggressively or ignore it entirely. Use
  `InstancedMesh` or textured spheres instead of `<points>`.
- **Custom `ShaderMaterial` with `USE_LOGDEPTHBUF` renders incorrectly
  in XR.** The `logDepthBufFC` uniform isn't synced cleanly across
  per-eye projections. The Photosphere's VR fallback uses a plain
  `MeshBasicMaterial` to avoid this (loses granulation noise, limb
  darkening, and animated boil; tracked as a separate ticket to fix).
- **`scene.background = texture` requires
  `texture.mapping = THREE.EquirectangularReflectionMapping`.** Without
  it, three.js renders the background as a screen-aligned 2D quad
  that's head-locked in XR (looks like a wall of stars that follows
  the headset). With it, three.js treats the texture as a proper
  spherical environment sampled by view direction.
- **WebXR's default `depthFar` is 1000 meters.** `<XRDepthFar>` calls
  `session.updateRenderState({ depthNear: 0.01, depthFar: 1e9 })` on
  session start. Without it, anything past 1km is silently clipped.
  Quest's actual depth-far appears clamped below `1e9` despite the
  request (large meshes silently fail to render), so keep meshes
  under ~10,000 scene units.
- **`useXRControllerLocomotion`'s default target-Object path only
  translates X and Z**, not Y. For 6-DOF locomotion (flying down toward
  the orbital plane), use the callback form and apply `velocity.y` too.
- **`state.camera` in R3F may not reflect the XR camera's live pose.**
  For per-frame camera-following, use `gl.xr.getCamera()` when
  `gl.xr.isPresenting`, and call `getWorldPosition(target)` rather
  than reading `.position` directly.

---

## What we deliberately do NOT depict

- **Surface features** (continents, oceans, mountains, polar caps): we have no surface-resolution observations of any exoplanet. Rendering details would be invention.
- **Cloud patterns** (Jupiter-style banding for actual gas giants): for known Solar System gas giants the patterns are observed; for exoplanets they are not. Banding can be evoked through layered gradient textures without claiming specific patterns.
- **Atmospheres of rocky planets**: we generally don't know if rocky exoplanets even *have* atmospheres, let alone the composition. Render the surface, not an atmospheric haze.
- **Rings**: no exoplanet has a confirmed ring system. Don't render any.
- **Moons**: no exoplanet has confirmed moons (some candidates exist, but none confirmed as of 2026). Don't render any.

The discipline of "never invent" is what gives this approach its credibility — and what makes it more interesting than artist renderings, not less.

---

## Open questions

- Should the equilibrium temperature for color use `pl_eqt` or a recomputed value from `st_teff` + `pl_orbsmax` + assumed albedo? `pl_eqt` is widely available but its reported assumptions vary across discovery papers. A consistent recomputation might be more uniform across the catalog.
- For multi-planet systems, should the system view animate planets at proper-period speeds, or use a fixed cadence for visibility? Probably a slider.
- Should we surface the Earth-Similarity Index from the PHL Habitable Exoplanets Catalog (Phase 3 stretch source), and if so, render Earth-similar planets with a special visual marker?

These don't need answers before Day 23. Decide during frontend work.
