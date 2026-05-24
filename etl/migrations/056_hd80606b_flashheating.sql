-- HD 80606 b ("Wild Orbits" theme, manual literature review, 2026-05-24). First entry in the
-- theme: extreme-eccentricity planets and the dynamics that produce them. HD 80606 b is the
-- archetype -- a ~4 Mjup planet on an e=0.93 orbit (a=0.47 AU) that swings from ~0.85 AU at
-- apastron in to ~0.03 AU at periastron, receiving 828x more irradiation at periastron. Spitzer
-- 8-um photometry across one periastron passage caught the dayside FLASH-HEATING in real time:
-- the brightness temperature shot from ~800 K to ~1500 K in six hours (Laughlin et al. 2009).
-- The extreme eccentricity itself is understood as Kozai-Lidov migration driven by the wide
-- stellar companion HD 80607 plus tidal dissipation (Wu & Murray 2003). The eccentricity is
-- already in the catalog; the value-add here is the measured flash-heating temperature (a new
-- derived datum) plus the dynamical-origin citation. Values from the cited papers; bibcodes
-- verified via ADS. Laughlin 2009 linked role='characterization', contribution='atmosphere';
-- Wu & Murray 2003 linked role='follow_up' in etl/seed_followup_citations.py.
--
--   Laughlin et al. 2009 (Spitzer 8 um): dayside brightness temp ~800 -> ~1500 K over 6 h at
--     periastron; secondary eclipse -> i ~ 90 deg, mass ~4 Mjup.
--   Wu & Murray 2003: Kozai migration (binary companion HD 80607 + tides) sets the eccentricity.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HD 80606 b', 'dayside_temperature', 1500, NULL, NULL, 'K', '8-um Spitzer photometry (periastron)',
     '2009Natur.457..562L',
     'Laughlin et al. 2009: PEAK dayside 8-um brightness temperature at periastron. The planet is '
     'flash-heated from ~800 K to ~1500 K in six hours as it swings through periastron of its '
     'e=0.93 orbit (828x more irradiation than at apastron) -- a transient peak, not a steady '
     'dayside temperature. The same secondary-eclipse detection fixes i ~ 90 deg and mass ~4 Mjup.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
