-- Kepler-1520 b deep dive (manual literature review, 2026-05-23). A
-- Mercury-sized rocky planet on a 15.7-hr orbit, catastrophically evaporating and
-- trailing a comet-like dust tail (the variable transit depth). The value-add is
-- the disintegration physics in planet_derived_measurements; there is no curated
-- molecular atmosphere (the obscuring material is mineral dust). Values read from
-- the cited papers; bibcodes verified via ADS. Citations linked in
-- etl/seed_followup_citations.py.
--
--   Rappaport et al. 2012 -- the ACTUAL discovery (KIC 12557548 b), four years
--     before the Morton et al. 2016 validation the warehouse uses as discovery;
--     mass-loss ~1 M_earth/Gyr, evaporation timescale ~0.2 Gyr (0.1 M_earth body).
--   Perez-Becker & Chiang 2013 -- catastrophic-evaporation model: present-day mass
--     <= 0.02 M_earth (< 2x the Moon); may have lost ~70% of its formation mass,
--     possibly down to a naked iron core.
--   van Werkhoven et al. 2014 -- dust-tail modelling; radius < 4600 km.
--
-- NB: the catalog mass/radius for this object (28 M_earth / 5.77 R_earth) describe
-- the transiting dust cloud, not the sub-Mercury planet -- captured in the notes.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('Kepler-1520 b', 'mass_loss_rate', 1, NULL, NULL, 'M_earth_per_Gyr', 'dust-tail occultation',
     '2012ApJ...752....1R',
     'Rappaport et al. 2012. Mass-loss ~1 M_earth/Gyr inferred from the variable, comet-like '
     'dust-tail occultations (depth 1.3% down to <0.2%); micron-sized pyroxene or Al2O3 grains '
     'in a thermal wind off the sublimating ~Mercury-sized planet.'),
    ('Kepler-1520 b', 'evaporation_timescale', 0.2, NULL, NULL, 'Gyr', 'for a 0.1 M_earth planet',
     '2012ApJ...752....1R',
     'Rappaport et al. 2012. ~0.2 Gyr to complete evaporation for a fiducial 0.1 M_earth body; '
     'the planet is in its final catastrophic mass-loss phase.'),
    ('Kepler-1520 b', 'mass', 0.02, NULL, NULL, 'M_earth', 'catastrophic evaporation (upper limit)',
     '2013MNRAS.433.2294P',
     'Perez-Becker & Chiang 2013. Present-day mass <= 0.02 M_earth (< 2x the Moon); may have lost '
     '~70% of its formation mass, possibly a naked iron core. The catalog mass/radius describe the '
     'transiting dust cloud, not the planet (van Werkhoven et al. 2014: radius < 4600 km).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
