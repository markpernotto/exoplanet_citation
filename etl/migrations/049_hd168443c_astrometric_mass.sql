-- HD 168443 c astrometric true mass (manual literature review, 2026-05-24). The outer
-- companion of the HD 168443 planet + brown-dwarf system. Radial velocities give only a
-- minimum mass m sin i = 18.1 Mjup (the catalog carries ~17.31); Reffert & Quirrenbach
-- 2011 detected the astrometric orbit in the re-reduced HIPPARCOS data and measured the
-- inclination, yielding a TRUE mass of 30.3 Mjup -- firmly a brown dwarf. The inner
-- planet HD 168443 b was not astrometrically detected (its astrometric upper limit is
-- unconstrained), so it keeps its RV m sin i and gets no true-mass row here. Value from
-- Reffert & Quirrenbach 2011 Table 2; bibcode verified via ADS. Citation linked
-- role='characterization', contribution='mass' in etl/seed_followup_citations.py.
--
--   Reffert & Quirrenbach 2011, Table 2: i = 36.8 deg (3 sigma 15.2-164.7),
--     m2 = 30.3 Mjup (3 sigma 18.1-71.0; the lower bound is the RV m sin i, because an
--     inclination of 90 deg cannot be excluded). The inclination is left unrecorded
--     (its 3 sigma range spans most angles and is uninformative); the mass is the result.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HD 168443 c', 'mass', 30.3, 40.7, 12.2, 'M_jup', 'Hipparcos astrometric orbit',
     '2011A&A...527A.140R',
     'Reffert & Quirrenbach 2011 (Table 2): astrometric true mass 30.3 Mjup (3 sigma 18.1-71.0), '
     'from the re-reduced HIPPARCOS orbit at i = 36.8 deg. Confirms HD 168443 c is a brown dwarf, '
     'above the RV lower limit m sin i = 18.1 Mjup (catalog ~17.31). The inner planet b was not '
     'astrometrically detected, so its mass stays at the RV m sin i.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
