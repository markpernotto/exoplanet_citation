-- WASP-79 b spin-orbit obliquity ("Tilted & Tumbling" theme, manual literature review,
-- 2026-05-24; closes the theme, 5/5). A bloated hot Jupiter (~0.85 Mjup, 3.66 d) on a near-POLAR
-- orbit: the sky-projected spin-orbit angle lambda ~ -95 deg puts the orbit almost perpendicular
-- to the host star's spin. The host is a hot F-star (Teff ~6600 K, above the Kraft break), so it
-- lacks the convective envelope to tidally realign and the misalignment persists. Only the
-- projected obliquity is measured (no true obliquity). Value is NASA EA's (reflink Brown et al.
-- 2017, distinct from the 2012 discovery cite); promoted (cited) into planet_derived_measurements.
-- Bibcode verified via ADS. Citation linked role='characterization', contribution='obliquity' in
-- etl/seed_followup_citations.py.
--
--   Brown et al. 2017 (Rossiter-McLaughlin): lambda = -95.2 +0.9/-1.0 deg.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-79 b', 'projected_obliquity', -95.2, 0.9, 1.0, 'deg', 'Rossiter-McLaughlin',
     '2017MNRAS.464..810B',
     'Brown et al. 2017: sky-projected spin-orbit angle lambda = -95.2 +0.9/-1.0 deg -- a near-POLAR '
     '(perpendicular) orbit. The host is a hot F-star (Teff ~6600 K) above the Kraft break, so it '
     'cannot tidally realign the orbit and the misalignment persists. True obliquity not constrained.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
