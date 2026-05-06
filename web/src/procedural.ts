// Procedural rendering: maps measured exoplanet/star properties to visual style.
// See docs/PROCEDURAL_RENDERING.md for the full mapping rationale.

export type BodyType = 'rocky' | 'icy' | 'gas_giant' | 'uncertain';

export function classifyBody(pl_dens: number | null, pl_rade: number | null): BodyType {
  if (pl_dens != null) {
    if (pl_dens >= 3.0) return 'rocky';
    if (pl_dens >= 0.5) return 'icy';
    return 'gas_giant';
  }
  if (pl_rade != null) {
    if (pl_rade < 1.6) return 'rocky';
    if (pl_rade > 4.0) return 'gas_giant';
  }
  return 'uncertain';
}

// ---------------------------------------------------------------------------
// Color interpolation: temperature → smooth color across body-specific stops.
// Two planets that are e.g. 100K apart now render in slightly different colors,
// addressing the "everything looks like a Jupiter clone" problem caused by
// the previous discrete-bucket approach.
// ---------------------------------------------------------------------------

type ColorStop = { temp: number; color: string };

const GAS_GIANT_STOPS: ColorStop[] = [
  { temp: 80,   color: '#bcd0d8' }, // pale ice giant
  { temp: 130,  color: '#5b8aa8' }, // Neptune-blue (methane absorption)
  { temp: 220,  color: '#7398b6' }, // mid-blue
  { temp: 350,  color: '#cab28a' }, // Jupiter cream-tan (ammonia clouds)
  { temp: 600,  color: '#a87650' }, // orange-brown (alkali / sulfur)
  { temp: 900,  color: '#b78648' }, // warmer brown
  { temp: 1200, color: '#d39a4a' }, // sodium yellow-orange
  { temp: 1500, color: '#8a4f78' }, // transition into TiO regime (purple)
  { temp: 1800, color: '#3b3a8c' }, // deep blue/violet (TiO/VO)
  { temp: 2300, color: '#704270' }, // mixed thermal + TiO
  { temp: 2700, color: '#d34d2c' }, // ultra-hot, thermal red-orange
];

const ROCKY_STOPS: ColorStop[] = [
  { temp: 50,   color: '#e6f0f5' }, // frozen, pale ice
  { temp: 150,  color: '#b3c7d2' }, // cold ice + rocky patches
  { temp: 240,  color: '#9bbac4' }, // near water freezing
  { temp: 290,  color: '#6f9c8e' }, // habitable-zone temperate (greenish)
  { temp: 340,  color: '#a8865a' }, // Mars/Venus regime tan
  { temp: 500,  color: '#7a5240' }, // hot rock
  { temp: 800,  color: '#5a3a30' }, // very hot, dark
  { temp: 1100, color: '#8a3818' }, // melting silicates
  { temp: 1400, color: '#c43a14' }, // molten lava-orange
  { temp: 2000, color: '#e85a18' }, // heavily molten
];

const ICY_STOPS: ColorStop[] = [
  { temp: 80,   color: '#a4cad8' }, // cold ice world
  { temp: 200,  color: '#7eb1c7' }, // pale cyan
  { temp: 350,  color: '#a8c6d8' }, // hazy cyan
  { temp: 600,  color: '#b8a878' }, // warming, less blue
  { temp: 900,  color: '#d8a247' }, // sodium-tinted
];

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  return [
    parseInt(h.substring(0, 2), 16),
    parseInt(h.substring(2, 4), 16),
    parseInt(h.substring(4, 6), 16),
  ];
}

function rgbToHex(r: number, g: number, b: number): string {
  const c = (n: number) => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, '0');
  return '#' + c(r) + c(g) + c(b);
}

function lerpColor(c1: string, c2: string, t: number): string {
  const [r1, g1, b1] = hexToRgb(c1);
  const [r2, g2, b2] = hexToRgb(c2);
  return rgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t);
}

function interpolateStops(stops: ColorStop[], temp: number): string {
  if (temp <= stops[0].temp) return stops[0].color;
  if (temp >= stops[stops.length - 1].temp) return stops[stops.length - 1].color;
  for (let i = 0; i < stops.length - 1; i++) {
    if (temp <= stops[i + 1].temp) {
      const span = stops[i + 1].temp - stops[i].temp;
      const t = span > 0 ? (temp - stops[i].temp) / span : 0;
      return lerpColor(stops[i].color, stops[i + 1].color, t);
    }
  }
  return stops[stops.length - 1].color;
}

// Description (the prose under the orbit) is still bucketed — descriptions
// don't gradient, but color does.
function gasGiantDescription(pl_eqt: number): string {
  if (pl_eqt > 2200) return 'Ultra-hot Jupiter; thermal emission detectable.';
  if (pl_eqt > 1500) return 'TiO/VO molecules absorb red — appears deep blue/violet.';
  if (pl_eqt > 1000) return 'Sodium D-line absorption — appears yellow-orange.';
  if (pl_eqt > 500) return 'Sulfur compounds; orange-brown banding.';
  if (pl_eqt > 200) return 'Jupiter-like cream-and-tan ammonia clouds.';
  if (pl_eqt > 100) return 'Methane absorbs red — appears Neptune-blue.';
  return 'Cold ice giant; methane fully condensed.';
}

function rockyDescription(pl_eqt: number): string {
  if (pl_eqt > 1200) return 'Molten surface; thermal emission visible.';
  if (pl_eqt > 600) return 'Hot rocky surface, possible silicate clouds.';
  if (pl_eqt > 273) return 'Mars/Venus regime; rocky surface visible.';
  if (pl_eqt > 200) return 'Near water freezing; possible ice with rocky patches.';
  return 'Frozen surface, possibly methane/N₂ ice.';
}

function icyDescription(pl_eqt: number): string {
  if (pl_eqt > 700) return 'Sodium/potassium absorption dominates.';
  if (pl_eqt > 300) return 'Hazy cyan atmosphere.';
  if (pl_eqt > 150) return 'Pale blue-cyan ice/water world.';
  return 'Frozen ice world with possible methane tint.';
}

export type PlanetVisual = {
  bodyType: BodyType;
  fillColor: string;
  glow: boolean;
  description: string;
};

export function planetVisual(
  pl_eqt: number | null,
  pl_dens: number | null,
  pl_rade: number | null,
): PlanetVisual {
  const bodyType = classifyBody(pl_dens, pl_rade);

  if (pl_eqt == null) {
    return {
      bodyType,
      fillColor: '#888',
      glow: false,
      description: 'Insufficient temperature data to determine atmospheric color.',
    };
  }

  if (bodyType === 'rocky') {
    return {
      bodyType,
      fillColor: interpolateStops(ROCKY_STOPS, pl_eqt),
      glow: pl_eqt > 1200,
      description: rockyDescription(pl_eqt),
    };
  }
  if (bodyType === 'icy') {
    return {
      bodyType,
      fillColor: interpolateStops(ICY_STOPS, pl_eqt),
      glow: false,
      description: icyDescription(pl_eqt),
    };
  }
  if (bodyType === 'gas_giant') {
    return {
      bodyType,
      fillColor: interpolateStops(GAS_GIANT_STOPS, pl_eqt),
      glow: pl_eqt > 2200,
      description: gasGiantDescription(pl_eqt),
    };
  }
  return {
    bodyType,
    fillColor: '#8a8a8a',
    glow: false,
    description: 'Insufficient data; rendered as data-sparse indicator.',
  };
}

// Star color from BP-RP color index, or fall back to st_teff blackbody approximation.
export function starColor(bp_rp: number | null, st_teff: number | null): string {
  const x = bp_rp != null ? bp_rp : st_teff != null ? bp_rp_from_teff(st_teff) : null;
  if (x == null) return '#fff7d2';
  if (x < 0) return '#a4c8ff';     // O/B-type, blue
  if (x < 0.5) return '#dce6ff';   // A-type, blue-white
  if (x < 1.0) return '#fff7d2';   // F/G-type, white-yellow (Sun)
  if (x < 1.5) return '#ffd49a';   // K-type, orange
  if (x < 3.0) return '#ff9b6a';   // M-dwarf, red-orange
  return '#cf5040';                // late M / brown dwarf, deep red
}

function bp_rp_from_teff(teff: number): number {
  if (teff > 10000) return -0.2;
  if (teff > 7500) return 0.2;
  if (teff > 6000) return 0.6;
  if (teff > 5000) return 1.0;
  if (teff > 4000) return 1.4;
  if (teff > 3000) return 2.0;
  return 3.5;
}
