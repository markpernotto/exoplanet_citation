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
    if (pl_eqt > 1200) return { bodyType, fillColor: '#c43a14', glow: true, description: 'Molten surface; thermal emission visible.' };
    if (pl_eqt > 600) return { bodyType, fillColor: '#5a3a30', glow: false, description: 'Hot rocky surface, possible silicate clouds.' };
    if (pl_eqt > 273) return { bodyType, fillColor: '#a8865a', glow: false, description: 'Mars/Venus regime; rocky surface visible.' };
    if (pl_eqt > 200) return { bodyType, fillColor: '#9bbac4', glow: false, description: 'Near water freezing; possible ice with rocky patches.' };
    return { bodyType, fillColor: '#dde8ee', glow: false, description: 'Frozen surface, possibly methane/N2 ice.' };
  }

  if (bodyType === 'icy') {
    if (pl_eqt > 700) return { bodyType, fillColor: '#d8a247', glow: false, description: 'Sodium/potassium absorption dominates.' };
    if (pl_eqt > 300) return { bodyType, fillColor: '#a8c6d8', glow: false, description: 'Hazy cyan atmosphere.' };
    if (pl_eqt > 150) return { bodyType, fillColor: '#7eb1c7', glow: false, description: 'Pale blue-cyan ice/water world.' };
    return { bodyType, fillColor: '#a4cad8', glow: false, description: 'Frozen ice world with possible methane tint.' };
  }

  if (bodyType === 'gas_giant') {
    if (pl_eqt > 2200) return { bodyType, fillColor: '#d34d2c', glow: true, description: 'Ultra-hot Jupiter; thermal emission detectable.' };
    if (pl_eqt > 1500) return { bodyType, fillColor: '#3b3a8c', glow: false, description: 'TiO/VO molecules absorb red — appears deep blue/violet.' };
    if (pl_eqt > 1000) return { bodyType, fillColor: '#d39a4a', glow: false, description: 'Sodium D-line absorption — appears yellow-orange.' };
    if (pl_eqt > 500) return { bodyType, fillColor: '#a87650', glow: false, description: 'Sulfur compounds; orange-brown banding.' };
    if (pl_eqt > 200) return { bodyType, fillColor: '#cab28a', glow: false, description: 'Jupiter-like cream-and-tan ammonia clouds.' };
    if (pl_eqt > 100) return { bodyType, fillColor: '#5b8aa8', glow: false, description: 'Methane absorbs red — appears Neptune-blue.' };
    return { bodyType, fillColor: '#bcd0d8', glow: false, description: 'Cold ice giant; methane fully condensed.' };
  }

  return { bodyType, fillColor: '#8a8a8a', glow: false, description: 'Insufficient data; rendered as data-sparse indicator.' };
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

// Rough Teff → BP-RP for fallback when Gaia photometry isn't available.
function bp_rp_from_teff(teff: number): number {
  if (teff > 10000) return -0.2;
  if (teff > 7500) return 0.2;
  if (teff > 6000) return 0.6;
  if (teff > 5000) return 1.0;
  if (teff > 4000) return 1.4;
  if (teff > 3000) return 2.0;
  return 3.5;
}
