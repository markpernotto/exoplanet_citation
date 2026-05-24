// Formatting for literature-derived scalar measurements (migration 024 /
// planet_derived_measurements). Shared by the composition collection and the
// per-planet Composition block on the planet detail page.
import type { DerivedMeasurementRow } from '../api';

// Display labels for the controlled-vocabulary quantities. Quantities not listed
// (C/H, O/H, S/H, N/H) read fine as-is.
const QUANTITY_LABEL: Record<string, string> = {
  core_mass_fraction: 'Core mass fraction',
  fe_mg_molar: 'Fe/Mg (molar)',
  metal_mass_fraction: 'Metal mass fraction',
  total_metal_mass: 'Total metal mass',
  metals_from_solids: 'Metals from solids',
  metals_from_gas: 'Metals from gas',
};

const UNIT_LABEL: Record<string, string> = {
  x_solar: '× solar',
  wt_pct: 'wt %',
  M_earth: 'M⊕',
  M_jup: 'M♃',
  M_earth_per_Gyr: 'M⊕/Gyr',
  M_jup_per_yr: 'M♃/yr',
  log_Lsun: 'log L⊙',
  km_s: 'km/s',
  ms_per_yr: 'ms/yr',
  ratio: '',
  fraction: '',
};

export function quantityLabel(q: string): string {
  return QUANTITY_LABEL[q] ?? q;
}

// e.g. "4.2 +0.9/−0.8 × solar". Uncertainty is asymmetric (unc_hi / unc_lo).
export function fmtMeasure(r: DerivedMeasurementRow): string {
  if (r.value == null) return '';
  const unc = r.unc_hi != null && r.unc_lo != null ? ` +${r.unc_hi}/−${r.unc_lo}` : '';
  const unit = r.unit ? (UNIT_LABEL[r.unit] ?? r.unit) : '';
  return `${r.value}${unc}${unit ? ` ${unit}` : ''}`;
}
