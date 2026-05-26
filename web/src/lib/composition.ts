// Formatting for literature-derived scalar measurements (migration 024 /
// planet_derived_measurements). Shared by the composition collection and the
// per-planet Composition block on the planet detail page.
import type { DerivedMeasurementRow } from '../api';

// Display labels for the controlled-vocabulary quantities. Quantities not listed
// (C/H, O/H, S/H, N/H elemental abundances) read fine as-is. Keep this in sync
// with the quantity strings used in planet_derived_measurements migrations.
const QUANTITY_LABEL: Record<string, string> = {
  // Composition / interior (migration 024, the original set)
  core_mass_fraction: 'Core mass fraction',
  fe_mg_molar: 'Fe/Mg (molar)',
  metal_mass_fraction: 'Metal mass fraction',
  total_metal_mass: 'Total metal mass',
  metals_from_solids: 'Metals from solids',
  metals_from_gas: 'Metals from gas',
  envelope_mass_fraction: 'Envelope mass fraction (H/He)',
  water_mass_fraction: 'Water mass fraction',
  // Temperatures
  effective_temperature: 'Effective temperature',
  dayside_temperature: 'Dayside temperature',
  nightside_temperature: 'Nightside temperature',
  atmospheric_temperature_10mbar: 'Atmospheric temperature at 10 mbar',
  morning_evening_temperature_diff: 'Morning to evening terminator ΔT',
  // Bulk atmospheric properties
  metallicity: 'Atmospheric metallicity',
  'C/O': 'Atmospheric C/O ratio',
  mean_molecular_weight: 'Mean molecular weight',
  bond_albedo: 'Bond albedo',
  geometric_albedo: 'Geometric albedo',
  bolometric_luminosity: 'Bolometric luminosity',
  // Planet / orbit
  mass: 'Mass',
  orbital_inclination: 'Orbital inclination',
  rotation_velocity: 'Rotation velocity (v sin i)',
  projected_obliquity: 'Projected obliquity (λ)',
  true_obliquity: 'True obliquity (ψ)',
  radial_velocity: 'Planetary radial velocity',
  internal_temperature: 'Internal temperature (T_int)',
  // Atmospheric dynamics
  terminator_wind_velocity: 'Terminator wind velocity',
  equatorial_jet_velocity: 'Equatorial jet velocity',
  vertical_mixing_kzz: 'Vertical mixing (log K_zz)',
  // Evolution / loss / accretion
  accretion_rate: 'Mass accretion rate',
  circumplanetary_disk_dust_mass: 'Circumplanetary disk dust mass',
  orbital_decay_rate: 'Orbital decay rate',
  orbital_decay_timescale: 'Orbital decay timescale',
  mass_loss_rate: 'Atmospheric mass loss rate',
  evaporation_timescale: 'Evaporation timescale',
  helium_tail_length: 'Helium tail length',
  // Observed scalars
  eclipse_depth: 'Secondary eclipse depth',
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
  dimensionless: '',
  K: 'K',
  dex: 'dex',
  deg: '°',
  ppm: 'ppm',
  g_per_mol: 'g/mol',
  planet_radii: 'R_planet',
  Myr: 'Myr',
  Gyr: 'Gyr',
  log_cm2_s: 'log cm²/s',
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
