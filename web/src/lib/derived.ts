// Derived planet/star properties — anything we can compute or infer from
// the typed columns. These power the "Beyond the basics" card.

const EARTH_RADIUS_KM = 6371;
const EARTH_MASS_KG = 5.972e24;
const G = 6.674e-11; // m³ kg⁻¹ s⁻²

export type DerivedFact = { label: string; value: string; explain?: string };

// Surface gravity in m/s² (only meaningful for solid-bodied planets).
export function surfaceGravity(pl_bmasse: number | null, pl_rade: number | null): number | null {
  if (pl_bmasse == null || pl_rade == null || pl_rade <= 0) return null;
  const M = pl_bmasse * EARTH_MASS_KG;
  const r = pl_rade * EARTH_RADIUS_KM * 1000;
  return (G * M) / (r * r);
}

export function gravityFact(pl_bmasse: number | null, pl_rade: number | null, pl_dens: number | null): DerivedFact | null {
  const g = surfaceGravity(pl_bmasse, pl_rade);
  if (g == null) return null;
  // Skip for likely-gaseous planets; "surface gravity" means little there.
  if (pl_dens != null && pl_dens < 1.5) return null;
  const earthMultiple = g / 9.81;
  const weightOnPlanet = (earthMultiple * 70).toFixed(0);
  return {
    label: 'Surface gravity',
    value: `${earthMultiple.toFixed(2)}× Earth (${g.toFixed(1)} m/s²)`,
    explain: `A 70 kg person on Earth would weigh about ${weightOnPlanet} kg here.`,
  };
}

export function compositionFact(pl_dens: number | null): DerivedFact | null {
  if (pl_dens == null) return null;
  if (pl_dens > 5.5) return {
    label: 'Composition',
    value: 'Iron-dominated rocky',
    explain: 'High density suggests an iron-rich core, similar to Mercury (5.43 g/cc).',
  };
  if (pl_dens > 3.5) return {
    label: 'Composition',
    value: 'Rocky with iron core',
    explain: 'Density consistent with an Earth-like silicate-and-iron composition (Earth is 5.51 g/cc, Mars is 3.93).',
  };
  if (pl_dens > 2) return {
    label: 'Composition',
    value: 'Rock & ice mix',
    explain: 'Density between rock and pure ice — likely a silicate mantle wrapped in water/ice layers.',
  };
  if (pl_dens > 1) return {
    label: 'Composition',
    value: 'Water/ice world',
    explain: 'Low density consistent with substantial water content (Europa is 3.01, but icy moons can run lower).',
  };
  if (pl_dens > 0.5) return {
    label: 'Composition',
    value: 'Gas/ice giant',
    explain: 'Density similar to Saturn (0.69) or Jupiter (1.33) — gaseous envelope around a small core.',
  };
  return {
    label: 'Composition',
    value: 'Puffy gas giant',
    explain: 'Extremely low density. The atmosphere is heavily inflated, possibly heated and expanded by stellar irradiation.',
  };
}

export function tidalLockingFact(pl_orbsmax: number | null, st_mass: number | null): DerivedFact | null {
  if (pl_orbsmax == null) return null;
  if (pl_orbsmax < 0.05) return {
    label: 'Tidal locking',
    value: 'Very likely locked',
    explain: 'Orbits this close to a star are almost always tidally locked — one face perpetually faces the host star, with permanent day and night sides.',
  };
  if (st_mass != null && st_mass < 0.5 && pl_orbsmax < 0.15) return {
    label: 'Tidal locking',
    value: 'Likely locked',
    explain: 'Close orbit around a low-mass (M-dwarf) star — these systems tidally lock quickly.',
  };
  if (pl_orbsmax < 0.1) return {
    label: 'Tidal locking',
    value: 'Possibly locked',
    explain: 'Depending on the planet\'s age and orbital history, tidal locking is plausible at this distance.',
  };
  return null;
}

export function solarSystemAnalogFact(pl_rade: number | null, pl_bmasse: number | null): DerivedFact | null {
  if (pl_rade == null && pl_bmasse == null) return null;
  let analog = '';
  if (pl_rade != null) {
    if (pl_rade < 0.4) analog = 'smaller than Mercury';
    else if (pl_rade < 0.7) analog = 'between Mars and Mercury in size';
    else if (pl_rade < 1.3) analog = 'similar in size to Earth';
    else if (pl_rade < 1.8) analog = 'a "super-Earth" — bigger than Earth, smaller than Neptune';
    else if (pl_rade < 3.0) analog = 'a "mini-Neptune" — between Earth and Neptune in size';
    else if (pl_rade < 4.5) analog = 'similar in size to Neptune (3.88 R⊕)';
    else if (pl_rade < 8) analog = 'a "sub-Saturn" — between Neptune and Saturn (9.45 R⊕)';
    else if (pl_rade < 13) analog = 'similar in size to Jupiter (11.21 R⊕)';
    else analog = 'larger than Jupiter — a "super-Jupiter"';
  }
  if (!analog) return null;
  return {
    label: 'Size class',
    value: analog,
  };
}

export function sunlightFact(pl_insol: number | null): DerivedFact | null {
  if (pl_insol == null) return null;
  let comparison = '';
  if (pl_insol > 1000) comparison = 'extremely intense — surface-roasting';
  else if (pl_insol > 50) comparison = 'far more intense than Mercury (~6.7× Earth)';
  else if (pl_insol > 4) comparison = 'comparable to Mercury';
  else if (pl_insol > 1.5) comparison = 'warmer than Earth (Venus receives 1.91× Earth)';
  else if (pl_insol > 0.4) comparison = 'within the optimistic habitable zone';
  else if (pl_insol > 0.1) comparison = 'colder than Mars (which receives 0.43× Earth)';
  else comparison = 'extremely cold and dim, far outer system';
  return {
    label: 'Sunlight received',
    value: `${pl_insol < 10 ? pl_insol.toFixed(2) : pl_insol.toFixed(0)}× Earth`,
    explain: comparison,
  };
}

export function yearLengthFact(pl_orbper: number | null): DerivedFact | null {
  if (pl_orbper == null) return null;
  let value: string, explain: string;
  if (pl_orbper < 1) {
    value = `${(pl_orbper * 24).toFixed(1)} hours`;
    explain = 'Faster than the Moon orbits Earth — extremely close orbit.';
  } else if (pl_orbper < 30) {
    value = `${pl_orbper.toFixed(1)} Earth days`;
    explain = 'Far closer to its star than Mercury is to the Sun (88 days).';
  } else if (pl_orbper < 200) {
    value = `${pl_orbper.toFixed(1)} Earth days`;
    explain = 'Closer to its star than Earth is to the Sun.';
  } else if (pl_orbper < 500) {
    value = `${pl_orbper.toFixed(0)} Earth days`;
    explain = 'Comparable to Earth\'s 365-day year.';
  } else {
    value = `${(pl_orbper / 365.25).toFixed(2)} Earth years`;
    explain = pl_orbper < 4500 ? 'Slower than Mars (1.88 yr) but still in the inner system.' : 'Slow outer-system orbit.';
  }
  return { label: 'Year length', value, explain };
}

export function temperatureFact(pl_eqt: number | null): DerivedFact | null {
  if (pl_eqt == null) return null;
  const celsius = (pl_eqt - 273.15).toFixed(0);
  let comparison = '';
  if (pl_eqt > 1500) comparison = 'hot enough to melt iron';
  else if (pl_eqt > 800) comparison = 'hotter than Venus\'s surface (737 K)';
  else if (pl_eqt > 400) comparison = 'between Mercury and Venus in surface temperature';
  else if (pl_eqt > 280) comparison = 'within Earth-like temperature range';
  else if (pl_eqt > 200) comparison = 'colder than Earth, closer to Mars (210 K)';
  else if (pl_eqt > 100) comparison = 'colder than Mars';
  else comparison = 'extremely cold — outer Solar System temperatures';
  return {
    label: 'Equilibrium temperature',
    value: `${pl_eqt.toFixed(0)} K (${celsius}°C)`,
    explain: comparison,
  };
}

export function atmosphericChemistryFact(pl_eqt: number | null, pl_dens: number | null): DerivedFact | null {
  if (pl_eqt == null) return null;
  const isGasGiant = pl_dens != null && pl_dens < 1.5;

  if (isGasGiant) {
    if (pl_eqt > 2200) return { label: 'Atmospheric chemistry', value: 'Rock-vapor regime', explain: 'Iron and silicates can vaporize at these temperatures. Atmosphere may exhibit detectable thermal emission.' };
    if (pl_eqt > 1500) return { label: 'Atmospheric chemistry', value: 'TiO/VO absorption', explain: 'Titanium oxide and vanadium oxide molecules absorb red wavelengths strongly — the planet appears blue or violet to a hypothetical observer.' };
    if (pl_eqt > 1000) return { label: 'Atmospheric chemistry', value: 'Sodium D-line', explain: 'Sodium and potassium absorption (the famous 589 nm D-line) dominates the visible spectrum, tinting the atmosphere yellow-orange.' };
    if (pl_eqt > 500) return { label: 'Atmospheric chemistry', value: 'Alkali + sulfur', explain: 'Sulfur compounds and alkali metals shape coloration — orange-brown banding similar to a hotter Jupiter.' };
    if (pl_eqt > 200) return { label: 'Atmospheric chemistry', value: 'Ammonia clouds', explain: 'Cool enough for ammonia clouds to condense, like Jupiter. Atmospheric banding likely from differential rotation.' };
    if (pl_eqt > 100) return { label: 'Atmospheric chemistry', value: 'Methane absorption', explain: 'Methane absorbs red light, giving the planet a Neptune-like pale blue tint.' };
    return { label: 'Atmospheric chemistry', value: 'Hydrocarbon ices', explain: 'Cold enough for methane and other hydrocarbons to condense.' };
  }

  if (pl_eqt > 1500) return { label: 'Surface conditions', value: 'Magma ocean likely', explain: 'Surface temperature exceeds the melting point of most silicates. The dayside is probably partially molten.' };
  if (pl_eqt > 700) return { label: 'Surface conditions', value: 'Silicate clouds possible', explain: 'Hot rocky world, possibly with silicate clouds. Surface temperatures comparable to Venus or hotter.' };
  if (pl_eqt > 373) return { label: 'Surface conditions', value: 'Above water boiling', explain: 'Hotter than 100°C; any liquid water would require very high atmospheric pressure (or wouldn\'t exist).' };
  if (pl_eqt > 273) return { label: 'Surface conditions', value: 'Liquid water possible', explain: 'Within the temperature range where water can be liquid, given sufficient atmospheric pressure.' };
  if (pl_eqt > 200) return { label: 'Surface conditions', value: 'Frozen water world', explain: 'Cold enough to freeze water, but warm enough that CO₂/N₂ atmospheres remain gaseous.' };
  return { label: 'Surface conditions', value: 'Cryogenic', explain: 'At these temperatures, even atmospheric nitrogen can begin to condense.' };
}

// Collect all the facts that aren't null, in display order.
export function collectFacts(planet: {
  pl_eqt: number | null;
  pl_dens: number | null;
  pl_rade: number | null;
  pl_bmasse: number | null;
  pl_orbsmax: number | null;
  pl_orbper: number | null;
  pl_insol: number | null;
  st_mass: number | null;
}): DerivedFact[] {
  return [
    compositionFact(planet.pl_dens),
    solarSystemAnalogFact(planet.pl_rade, planet.pl_bmasse),
    gravityFact(planet.pl_bmasse, planet.pl_rade, planet.pl_dens),
    temperatureFact(planet.pl_eqt),
    atmosphericChemistryFact(planet.pl_eqt, planet.pl_dens),
    sunlightFact(planet.pl_insol),
    yearLengthFact(planet.pl_orbper),
    tidalLockingFact(planet.pl_orbsmax, planet.st_mass),
  ].filter((f): f is DerivedFact => f != null);
}
