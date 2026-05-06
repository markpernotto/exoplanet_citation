# Retro Display Themes

Optional CRT and early-digital display themes for the exoplanet_citation
frontend. Six themes, each evoking a specific era of computing hardware.

---

## Why

The confirmed-exoplanet catalog begins in earnest in the 1990s, but the
*dream* of finding planets around other stars is older — it's a fixture of
the same era that produced phosphor monitors, 8-bit DOS machines, and amber
terminals. The themes are a nod to anyone who grew up with those screens and
also grew up wondering whether the dots of light overhead had planets of
their own.

The themes are optional and decorative. They don't alter any data, change
the procedural rendering logic, or affect the planet visuals (see
[What is intentionally not themed](#what-is-intentionally-not-themed)).

---

## How it works

### URL parameter

Themes are activated via the `?theme=` query parameter:

```
/?theme=phosphor-green
/?theme=amber
/?theme=cga
/?theme=ega
/?theme=hgc
/?theme=plasma
```

Any unknown value is silently ignored and the default dark theme is shown.
Omitting the parameter entirely shows the default. No cookies, no
localStorage — the URL is the complete source of truth, so themed views are
fully shareable.

The `?theme=` parameter coexists with the `?q=` search parameter:

```
/?q=TRAPPIST&theme=amber
```

The SearchBar, planet list links, and planet detail links all preserve
`?theme=` across navigation so the theme follows the user through the app.

### CSS custom properties

Every theme overrides the same set of CSS custom properties:

| Token | Default | Role |
|---|---|---|
| `--bg` | `#0b0d12` | Page background |
| `--bg-elev` | `#131722` | Elevated surfaces (cards, inputs) |
| `--fg` | `#e8eaf0` | Primary text |
| `--fg-muted` | `#9099aa` | Secondary text, metadata |
| `--accent` | `#6db4ff` | Links, active states, badges |
| `--border` | `#1e2330` | Card borders, dividers |
| `--tier-a` | `#6db4ff` | Tier-A parameter change badge |
| `--tier-b` | `#4a7a9b` | Tier-B parameter change badge |
| `--new` | `#3dba7a` | "New planet" badge |
| `--removed` | `#e05a5a` | "Removed" badge |

Theme blocks are `html[data-theme="slug"]` selectors appended to
`web/src/index.css`. The `ThemeApplier` React component sets
`document.documentElement.dataset.theme` when the URL param is present and
removes it when absent.

### ThemeSwitcher UI

Six small colored rectangles in the top-right of the header, one per theme.
Clicking the active theme removes `?theme=` and returns to default. Clicking
any other theme sets it. The URL updates with `replace: false` so
browser-back works naturally.

### Self-hosted fonts

All theme fonts are loaded via `@font-face` in `web/src/index.css` from
`web/public/fonts/`. Vite serves `public/` at `/`, so
`/fonts/VT323-Regular.woff2` resolves correctly in both dev and production.

No Google CDN, no external network request on page load, no tracking ping,
works offline.

All fonts are licensed under the SIL Open Font License (OFL) and committed
directly to the repo.

| Font | File(s) in `web/public/fonts/` | OFL source |
|---|---|---|
| VT323 | `VT323-Regular.woff2` | github.com/jens-kutilek/vt323 |
| IBM Plex Mono | `IBMPlexMono-Regular.woff2`, `IBMPlexMono-SemiBold.woff2` | github.com/IBM/plex |
| Silkscreen | `Silkscreen-Regular.woff2`, `Silkscreen-Bold.woff2` | github.com/plain-bread/silkscreen |

---

## Theme catalog

<!-- Screenshots to be added -->

### P1 Phosphor (`?theme=phosphor-green`)

**Era:** Apple II, VT100, DEC terminals (late 1970s – mid 1980s)\
**Font:** VT323 at 20px\
**Palette:** `#0a120a` background, `#33ff33` text\
**Effects:** CRT scanline overlay (`body::after` with `repeating-linear-gradient`), phosphor glow (`text-shadow` on body and all text elements)\
**Detail:** The glow uses three shadow layers (4px tight, 12px medium, 24px diffuse) to approximate a phosphor dot that hasn't fully decayed between frames.

---

### P3 Phosphor (`?theme=amber`)

**Era:** Wyse WY-50, Kaypro, IBM 3101 terminals (early–mid 1980s)\
**Font:** VT323 at 20px\
**Palette:** `#110900` background, `#ffb000` text\
**Effects:** CRT scanlines, amber phosphor glow\
**Detail:** Uses the same scanline and glow technique as P1 Phosphor but in the warmer amber/orange color of P3 phosphor compounds. Subjectively reads as "IBM office" where green reads as "hobbyist/home."

---

### CGA (`?theme=cga`)

**Era:** IBM Color Graphics Adapter, DOS, WordPerfect (1981 – early 1990s)\
**Font:** Silkscreen at 16px\
**Palette:** `#0000aa` background, `#ffffff` text, `#ffff55` accent\
**Effects:** No CRT effects (CGA was digital output to RGB monitors, not analog phosphor). Card borders use a double-line box style (`border` + `box-shadow`) that recalls DOS text-mode UI boxes.\
**Detail:** The blue + white + yellow palette is the classic CGA text-mode default. Silkscreen is a pixel-grid bitmap font that captures the character-cell rendering feel of the era without being an exact replica of the IBM ROM charset.

---

### EGA (`?theme=ega`)

**Era:** IBM Enhanced Graphics Adapter (1984 – early 1990s)\
**Font:** Silkscreen at 16px\
**Palette:** `#000000` background, `#55ffff` text, `#ffff55` accent\
**Effects:** No CRT effects. Double-line card borders in cyan.\
**Detail:** EGA introduced 64 colors and is associated with early color games and scientific software. Cyan as primary text is a signature EGA combination; the border technique is the same as CGA.

---

### HGC (`?theme=hgc`)

**Era:** Hercules Graphics Card, monochrome professional workstations (1982 – early 1990s)\
**Font:** IBM Plex Mono at 15px\
**Palette:** `#000000` background, `#f0f0f0` text, `#888888` muted\
**Effects:** None — monochrome, no glow, clean.\
**Detail:** IBM Plex Mono (from IBM's own type library) gives this theme a precise, technical character that matches the HGC's reputation as the card serious DOS users chose for text work. No color, no CRT artifacting — just crisp white-on-black.

---

### Plasma (`?theme=plasma`)

**Era:** Gas plasma display panels — Compaq Portable, GRiD Compass (1982 – late 1980s)\
**Font:** IBM Plex Mono at 15px\
**Palette:** `#0d0400` background, `#ff6600` text\
**Effects:** Plasma glow (`text-shadow` in orange) — subtler than the phosphor themes because plasma displays had sharper dot resolution than CRT phosphors.\
**Detail:** Gas plasma panels glowed orange-red by nature of the neon/xenon gas mixture. The GRiD Compass used one; it flew on the Space Shuttle. That connection made this theme feel appropriate for a space-data project.

---

## What is intentionally not themed

The procedural planet visuals are **immune to theming**. All six themes leave
the planet cards and orbital views unchanged.

This is by design. The planet visuals are computed from measured astrophysical
properties (equilibrium temperature, bulk density, radius) and rendered as
inline SVGs with hardcoded fill values per body type and temperature regime.
They don't use CSS custom properties or `currentColor` — theme overrides have
no path in.

See [docs/PROCEDURAL_RENDERING.md](PROCEDURAL_RENDERING.md) for how the
planet visuals are computed.

---

## Adding a new theme

1. Pick a slug (e.g. `vga`). Add it to `VALID_THEMES` in
   `web/src/App.tsx` and to the `THEMES` array in
   `web/src/components/ThemeSwitcher.tsx`.

2. Add the theme CSS block at the bottom of `web/src/index.css`:

   ```css
   html[data-theme="vga"] {
     --bg: ...;
     /* all 10 custom properties */
     font-size: ...px;
     line-height: ...;
   }

   html[data-theme="vga"] body {
     font-family: '...', monospace;
   }
   ```

   The `body` rule is required in addition to the `html` rule because the
   base stylesheet declares `font-family` explicitly on `html, body`, which
   prevents CSS inheritance from `html[data-theme]` alone.

3. Add a `.theme-btn--vga { background: ...; }` rule in the same file.

4. If using a new font, add the woff2 file to `web/public/fonts/` and
   declare it with `@font-face` at the top of `web/src/index.css`. Verify
   the font is OFL-licensed before committing.

5. If the theme uses CRT effects, look at how the `phosphor-green` and
   `amber` blocks apply `body::after` for scanlines and multi-layer
   `text-shadow` for glow.
