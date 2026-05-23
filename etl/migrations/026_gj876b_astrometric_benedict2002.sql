-- GJ 876 b astrometric measurements from Benedict et al. 2002 (manual deep dive,
-- 2026-05-23; 2002ApJ...581L.115B, Table 5, verified via ADS). This was the first
-- astrometrically-determined mass of any exoplanet (HST FGS3 + RV). Recorded in
-- the general planet_derived_measurements table:
--   orbital_inclination = 84 +/- 6 deg (Omega = 25 +/- 4 deg) -- the astrometric
--     orbit inclination, which is NOT in the catalog and sits in known tension
--     with the later dynamical determinations (Rivera 2010 / Nelson 2016 favor a
--     smaller, ~59 deg system inclination).
--   mass = 1.89 +/- 0.34 M_Jup -- the astrometric mass (M* = 0.32 +/- 0.05 Msun).
--     The catalog adopts a later dynamical mass; this row preserves the historic
--     astrometric value with its provenance.
--
-- Benedict 2002 is already linked to GJ 876 b in the citation graph
-- (etl/seed_followup_citations.py, contribution='mass'); these rows carry the
-- same bibcode as provenance.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 876 b', 'orbital_inclination', 84, 6, 6, 'deg', 'astrometric (HST FGS3)',
     '2002ApJ...581L.115B',
     'Benedict et al. 2002. First astrometric inclination of an exoplanet orbit '
     '(ascending node Omega = 25 +/- 4 deg). In tension with later dynamical fits '
     '(Rivera 2010, Nelson 2016), which favor a smaller system inclination (~59 deg).'),
    ('GJ 876 b', 'mass', 1.89, 0.34, 0.34, 'M_jup', 'astrometric + RV (HST FGS3)',
     '2002ApJ...581L.115B',
     'Benedict et al. 2002. First astrometrically-determined mass of an exoplanet '
     '(1.9 +/- 0.5 M_Jup including the M* = 0.32 +/- 0.05 Msun uncertainty). The '
     'catalog adopts a later dynamical mass; this preserves the astrometric value.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
