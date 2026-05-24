-- TOI-849 b deep dive (manual literature review, 2026-05-23). The "exposed core":
-- a ~39 M_earth, Earth-density planet smaller than Neptune sitting in the
-- hot-Neptune desert -- interpreted as the remnant core of a giant planet. Its
-- mass and density are already in the catalog; the value-add is the H/He envelope
-- fraction, which quantifies the "exposed core" nature. No molecular atmosphere
-- data exists. Value read from Armstrong et al. 2020 (the discovery paper, already
-- the discovery cite, so no new citation is added). Bibcode verified via ADS.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('TOI-849 b', 'envelope_mass_fraction', 3.9, 0.8, 0.9, 'wt_pct', 'interior structure (H/He upper limit)',
     '2020Natur.583...39A',
     'Armstrong et al. 2020. Any pure-H/He envelope is <= 3.9% of the planet mass -- TOI-849 b '
     'is the remnant core of a giant planet in the hot-Neptune desert (mass 39 M_earth, density '
     '~5.2 g/cm3, similar to Earth). It either lost its envelope (thermal self-disruption or '
     'giant-planet collisions) or never accreted much gas.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
