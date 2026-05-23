-- Kepler-11 present-day envelope/volatile fractions from Lopez et al. 2012
-- (manual deep dive, 2026-05-23; 2012ApJ...761...59L, "Current Mass and
-- Composition" table, verified via ADS). Recorded in planet_derived_measurements.
-- These are the CURRENT compositions from the thermal-evolution models (not the
-- 10/100 Myr formation-history values in the paper's later tables). Kepler-11 g is
-- not modelled in that table, so it is omitted here.
--
--   Kepler-11 c, d, e, f: current H/He envelope mass fraction, 2-layer (H/He on
--     rock/iron "super-Earth") model. The paper's 3-layer sub-Neptune model gives
--     smaller fractions, noted per row.
--   Kepler-11 b: a 2-layer H/He model gives only ~0.3% and is implausible (b is
--     extremely vulnerable to H/He mass loss), so b's viable composition is a
--     water-world (~40% water by mass) -- recorded as water_mass_fraction.
--
-- Lopez 2012 is also added to the citation graph for these planets
-- (etl/seed_followup_citations.py, contribution='composition').
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('Kepler-11 b', 'water_mass_fraction', 40, 41, 29, 'wt_pct', 'water-world',
     '2012ApJ...761...59L',
     'Lopez et al. 2012, current composition. Kepler-11 b is best matched by a '
     'water-world (~40% water by mass); a 2-layer H/He model gives only ~0.3% and '
     'is implausible because b is extremely vulnerable to H/He mass loss.'),
    ('Kepler-11 c', 'envelope_mass_fraction', 4.6, 2.7, 2.3, 'wt_pct', '2-layer H/He',
     '2012ApJ...761...59L',
     'Lopez et al. 2012, current H/He envelope mass fraction (2-layer H/He on '
     'rock/iron model). A 3-layer sub-Neptune model gives ~0.3%.'),
    ('Kepler-11 d', 'envelope_mass_fraction', 8.2, 2.7, 2.4, 'wt_pct', '2-layer H/He',
     '2012ApJ...761...59L',
     'Lopez et al. 2012, current H/He envelope mass fraction (2-layer model). A '
     '3-layer sub-Neptune model gives ~1.3%.'),
    ('Kepler-11 e', 'envelope_mass_fraction', 17.2, 4.1, 4.2, 'wt_pct', '2-layer H/He',
     '2012ApJ...761...59L',
     'Lopez et al. 2012, current H/He envelope mass fraction (2-layer model); the '
     'most volatile-rich of the system. A 3-layer sub-Neptune model gives ~5.5%.'),
    ('Kepler-11 f', 'envelope_mass_fraction', 4.1, 1.8, 1.5, 'wt_pct', '2-layer H/He',
     '2012ApJ...761...59L',
     'Lopez et al. 2012, current H/He envelope mass fraction (2-layer model). A '
     '3-layer sub-Neptune model gives ~0.4%.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
