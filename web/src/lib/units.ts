import { useEffect, useState } from 'react';

export type UnitsMode = 'metric' | 'imperial';

const STORAGE_KEY = 'exoplanet:units-mode';

const KM_PER_EARTH_RADIUS = 6371;
const MI_PER_EARTH_RADIUS = 3958.756;
const KG_PER_EARTH_MASS = 5.972e24;
const LB_PER_EARTH_MASS = 1.31668e25;

const SUPERSCRIPT: Record<string, string> = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

function superscript(n: number): string {
  return String(n).split('').map((c) => SUPERSCRIPT[c] ?? c).join('');
}

function compact(n: number): string {
  if (!Number.isFinite(n) || n === 0) return '0';
  const abs = Math.abs(n);
  if (abs >= 1e6 || abs < 1e-2) {
    const exp = Math.floor(Math.log10(abs));
    const mantissa = n / Math.pow(10, exp);
    return `${mantissa.toFixed(2)} × 10${superscript(exp)}`;
  }
  if (abs >= 1000) return Math.round(n).toLocaleString();
  return n.toPrecision(3);
}

export function useUnitsMode(): [UnitsMode, (m: UnitsMode) => void] {
  const [mode, setMode] = useState<UnitsMode>(() => {
    if (typeof window === 'undefined') return 'metric';
    return window.localStorage.getItem(STORAGE_KEY) === 'imperial' ? 'imperial' : 'metric';
  });
  useEffect(() => {
    try { window.localStorage.setItem(STORAGE_KEY, mode); } catch { /* private mode */ }
  }, [mode]);
  return [mode, setMode];
}

export type Formatted = { value: string; unit: string; secondary?: string };

export function formatRadius(rade: number | null, mode: UnitsMode): Formatted | null {
  if (rade == null) return null;
  if (mode === 'imperial') return { value: compact(rade * MI_PER_EARTH_RADIUS), unit: 'mi' };
  return { value: compact(rade * KM_PER_EARTH_RADIUS), unit: 'km' };
}

export function formatMass(bmasse: number | null, mode: UnitsMode): Formatted | null {
  if (bmasse == null) return null;
  if (mode === 'imperial') return { value: compact(bmasse * LB_PER_EARTH_MASS), unit: 'lb' };
  return { value: compact(bmasse * KG_PER_EARTH_MASS), unit: 'kg' };
}

// Kelvin stays primary as the scientific standard; the parenthetical swaps
// between °C (metric) and °F (imperial).
export function formatTemperature(kelvin: number | null, mode: UnitsMode): Formatted | null {
  if (kelvin == null) return null;
  const c = kelvin - 273.15;
  const secondary = mode === 'imperial'
    ? `(${Math.round(c * 9 / 5 + 32)} °F)`
    : `(${Math.round(c)} °C)`;
  return { value: String(Math.round(kelvin)), unit: 'K', secondary };
}

// Picks the most readable unit for a duration given in hours. Caller renders
// `{value} {unit}`. Returning {value, unit} keeps this i18n-ready: a future
// translation layer can map the English unit strings without re-deriving scale.
export function humanizeHours(hours: number | null): Formatted | null {
  if (hours == null || !Number.isFinite(hours) || hours < 0) return null;
  const days = hours / 24;
  const years = days / 365.25;
  if (hours < 48) return { value: hours.toFixed(1), unit: 'hours' };
  if (days < 365) return { value: days.toFixed(1), unit: 'days' };
  if (years < 100) return { value: years.toFixed(1), unit: 'years' };
  if (years < 10000) return { value: Math.round(years).toLocaleString(), unit: 'years' };
  if (years < 1e6) return { value: (years / 1000).toFixed(1), unit: 'kyr' };
  return { value: (years / 1e6).toFixed(2), unit: 'Myr' };
}
