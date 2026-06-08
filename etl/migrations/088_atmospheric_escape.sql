-- Curated mass-loss rates for atmospheric-escape exoplanets (manual deep
-- dive, 2026-05-31). Builds on the existing Kepler-1520 b entry (the
-- disintegrating rocky planet, from migration 036) so the renderer's
-- planetary comet-tail visual has a meaningful set to draw on.
--
-- Each row cites the discovery / measurement paper, and every numerical
-- value here was verified against the paper's abstract before landing —
-- bibcode and rate co-confirmed. The `model` column records the escape
-- mechanism (hydrodynamic hydrogen escape, thermal helium escape, Roche-lobe
-- overflow). Bibcodes verified via ADS.
--
-- Unit: M_earth_per_Gyr, matching Kepler-1520 b's existing entry. Conversion
-- factor used: 1 g/s = 5.286e-12 M_earth/Gyr (M_earth = 5.972e27 g, Gyr =
-- 3.156e16 s). The curator note records the original g/s figure from the
-- source paper's abstract for traceability.
--
-- Coverage gaps (intentionally NOT included here, to keep every row
-- properly cited): HD 209458 b (Vidal-Madjar 2003 detected escape but the
-- abstract does not quantify dM/dt; Salz 2016 and Koskinen 2013 modeling
-- papers also do not quantify in their abstracts) and WASP-12 b (Haswell
-- 2012 detected NUV absorption but no g/s in abstract; Lai 2010 Roche-lobe
-- overflow modeling is qualitative). These can be added later once a
-- modeling paper with an abstract-quoted dM/dt is identified.
--
-- Provenance is 'curated' (hand-entered, deep-dive). Idempotent via
-- ON CONFLICT DO NOTHING on the (pl_name, quantity, bibcode) primary key.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
VALUES

-- HD 189733 b — Lecavelier des Etangs et al. 2010, A&A 514, A72. Lyman-α
-- transit absorption (5.05 ± 0.75%) reveals escaping hydrogen; numerical
-- modeling of stellar-radiation-pressure-driven escape constrains the rate.
('HD 189733 b', 'mass_loss_rate', 0.053, NULL, NULL, 'M_earth_per_Gyr',
 'hydrodynamic hydrogen escape', '2010A&A...514A..72L',
 'Lecavelier des Etangs et al. 2010 (A&A 514, A72). Lyman-alpha transit '
 'absorption of 5.05 +/- 0.75%, exceeding the planetary-disc occultation '
 'at 3.5sigma. Numerical modeling of radiation-pressure-pushed hydrogen '
 'gives best-fit dM/dt = 1e10 g/s, with 1-sigma range 1e9 to 1e11 g/s '
 '(higher rates require higher EUV flux). Converted: 1e10 g/s * 5.286e-12 '
 '= 0.053 M_earth/Gyr.',
 'curated'),

-- GJ 436 b — Ehrenreich et al. 2015, Nature 522, 459. The famous "giant
-- comet-like cloud of hydrogen" detection — Lyman-α transit depths of
-- 56% extending 2-3 hr before and after the 1-hr optical transit.
('GJ 436 b', 'mass_loss_rate', 0.0016, NULL, NULL, 'M_earth_per_Gyr',
 'hydrodynamic hydrogen escape', '2015Natur.522..459E',
 'Ehrenreich et al. 2015 (Nature 522, 459). Giant comet-like hydrogen cloud, '
 'inferred from Lyman-alpha transit depths of 56% (vs 0.69% optical) lasting '
 '2-3 hr before and after the 1-hr optical transit. Mass-loss rate from the '
 'paper is reported as a range: ~1e8-1e9 g/s. Stored value uses the geometric '
 'midpoint (~3e8 g/s): 3e8 * 5.286e-12 = 0.0016 M_earth/Gyr. Slow-burn escape; '
 'sustainable over Gyr at this rate.',
 'curated'),

-- WASP-107 b — Spake et al. 2018, Nature 557, 68. First helium detection
-- at any exoplanet, via 1.083 micron He I metastable absorption.
('WASP-107 b', 'mass_loss_rate', 0.053, NULL, NULL, 'M_earth_per_Gyr',
 'thermal helium escape', '2018Natur.557...68S',
 'Spake et al. 2018 (Nature 557, 68). First detection of helium escape '
 'from any exoplanet via 1.083 um He I metastable absorption (4.5 sigma). '
 'Paper-reported mass-loss range: 1e10 to 3e11 g/s (0.1-4% of total mass '
 'per Gyr). Stored value uses the lower bound 1e10 g/s as conservative: '
 '1e10 * 5.286e-12 = 0.053 M_earth/Gyr. May have a comet-like radiation-'
 'pressure-shaped tail.',
 'curated'),

-- GJ 3470 b — Bourrier et al. 2018, A&A 620, A147. HST PanCET; extended
-- neutral-hydrogen halo around a warm Neptune at the edge of the
-- evaporation desert.
('GJ 3470 b', 'mass_loss_rate', 0.053, NULL, NULL, 'M_earth_per_Gyr',
 'hydrodynamic hydrogen escape', '2018A&A...620A.147B',
 'Bourrier et al. 2018 (A&A 620, A147). HST Pan-CET program. Three Lyman-'
 'alpha transits with consistent absorption signatures (35% in the blue '
 'wing, 23% in the red wing) reveal an extended neutral-hydrogen atmosphere. '
 'Best-fit escape rate from EVE-code modeling: ~1e10 g/s. Converted: '
 '1e10 * 5.286e-12 = 0.053 M_earth/Gyr. May have lost 4-35% of its current '
 'mass over its 2 Gyr lifetime.',
 'curated'),

-- HAT-P-32 b — Czesla et al. 2022, A&A 657, A6. CARMENES + XMM-Newton:
-- both energy-limited estimate and hydrodynamic modeling give the same
-- ~1e13 g/s rate, making this one of the highest mass-loss rates known.
('HAT-P-32 b', 'mass_loss_rate', 52.8, NULL, NULL, 'M_earth_per_Gyr',
 'thermal helium escape', '2022A&A...657A...6C',
 'Czesla et al. 2022 (A&A 657, A6). CARMENES H-alpha and He I 10833 detections '
 '(max depths 3.3% and 5.3%) plus XMM-Newton X-ray luminosity 2.3e29 erg/s. '
 'Both the energy-limited escape estimate AND independent 1D hydrodynamic '
 'modeling yield mass-loss rates on the order of 1e13 g/s. Converted: '
 '1e13 * 5.286e-12 = 52.8 M_earth/Gyr. Among the highest exoplanetary '
 'mass-loss rates known.',
 'curated'),

-- HAT-P-67 b — Gully-Santiago et al. 2024, AJ 167, 142. Extreme low-density
-- inflated hot Saturn with a 130-planet-radius leading helium tail.
('HAT-P-67 b', 'mass_loss_rate', 105.7, NULL, NULL, 'M_earth_per_Gyr',
 'thermal helium escape', '2024AJ....167..142G',
 'Gully-Santiago et al. 2024 (AJ 167, 142). HPF helium triplet 10833 detection '
 'with up to 10% depth; 13.8 hr of on-sky integration across 39 nights samples '
 'the entire planet orbit. Leading helium tail extends up to 130 planetary '
 'radii pre-transit, consistent with Roche-lobe overflow with the gas '
 'advected into the stellar rest frame. 1D Parker-wind modeling gives '
 'mass-loss rate ~2e13 g/s (large uncertainties from unknown XUV flux). '
 'Converted: 2e13 * 5.286e-12 = 105.7 M_earth/Gyr.',
 'curated'),

-- WASP-69 b — Lampon et al. 2023, A&A 673, A140. He I 10833 high-resolution
-- modeling that quantifies the previously-detected helium tail (Nortmann 2018).
('WASP-69 b', 'mass_loss_rate', 0.476, 0.264, 0.264, 'M_earth_per_Gyr',
 'thermal helium escape', '2023A&A...673A.140L',
 'Lampon et al. 2023 (A&A 673, A140). 1D hydrodynamic + non-LTE He I triplet '
 'modeling of high-resolution transmission spectra; abstract reports mass-loss '
 'rate (0.9 +/- 0.5) x 1e11 g/s at upper-atmosphere temperature 5250 +/- 750 K. '
 'Confirms WASP-69 b is in the recombination-limited hydrodynamic-escape regime '
 'and quantifies the helium tail first detected by Nortmann et al. 2018. '
 'Converted: 9e10 * 5.286e-12 = 0.476 M_earth/Gyr; +/- 0.5e11 g/s -> +/- 0.264 '
 'M_earth/Gyr.',
 'curated')

ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
