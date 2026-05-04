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
density >= 3.0 g/cc        →  ROCKY     (Mercury, Venus, Earth, Mars range; ~5.5 g/cc for Earth)
0.5 <= density < 3.0       →  ICE/WATER (mini-Neptunes, water worlds, sub-Neptunes; ~1.6 g/cc for Neptune)
density < 0.5              →  GAS GIANT (Saturn, Jupiter, hot Jupiters; ~0.7 g/cc for Saturn, ~1.3 g/cc for Jupiter)
density NULL or unknown    →  UNCERTAIN (render with a marker indicating "not enough data")
```

If density is unknown but we have radius:
- `pl_rade < 1.6` Earth radii is *probably* rocky (Earth-Venus regime)
- `pl_rade > 4` Earth radii is *probably* gas giant
- In between: genuinely uncertain — render as UNCERTAIN

These thresholds aren't sharp; they're widely accepted as defensible cuts in the exoplanet-population literature.

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

## Galactic positioning ("Here we are / Here this planet is")

This view places Earth and the selected host star on a top-down rendering of the Milky Way. Inputs:

- Earth's position is fixed (~26,000 light-years from galactic center, in the Orion Spur — coordinates well-established in the literature).
- Host star's position is computed from `ra` (right ascension), `dec` (declination), and `sy_dist` (or `distance_gspphot_pc` from Gaia for higher precision).
- The standard ICRS → galactic Cartesian transformation is one matrix multiplication. `astropy.coordinates` does this in two lines of Python; equivalent JavaScript libraries exist for the frontend.

The Milky Way background image: a public-domain artist's rendering of the galaxy seen from above is fine here, because we're not claiming "this is what the galaxy looks like to a viewer" — we're using it as a reference frame. NASA/JPL-Caltech's "Artist's Concept of the Milky Way" by Robert Hurt is the canonical version and is in the public domain via NASA's image-use policy.

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

- **Rendering technology**: SVG for static planet visuals (lightweight, scalable, accessible); `<canvas>` or three.js for the system view and galactic view (need animation / 3D).
- **Color computation**: precompute color hex codes per body-type-and-temperature bucket; cache as a static lookup table. Keeps the frontend computation cheap.
- **Fallbacks**: any planet with insufficient data (no density, no radius, no temperature) renders as a "data sparse" indicator — a gray sphere with a question mark. **Never invent values.**
- **Color-blindness**: the temperature → color mapping has natural luminance variation (hot = bright, cold = dark) that should preserve information for color-blind users; verify with simulation tools before shipping.
- **Performance**: rendering 6,300 planets simultaneously in a list view requires batching. Single planet detail page is unconstrained.

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
