-- WASP-33 b spin-orbit obliquity ("Tilted & Tumbling" theme, manual literature review,
-- 2026-05-24). An ultra-hot Jupiter (~2.1 Mjup, 1.22 d) transiting a hot (7430 K, A5),
-- rapidly rotating (v sin i ~86 km/s) delta-Scuti star, on a RETROGRADE orbit. Both the
-- sky-projected obliquity (lambda) and the de-projected true obliquity (psi) are measured --
-- this is the first system in the theme to carry a true obliquity. The misalignment is
-- expected to survive here: the host is well above the Kraft break (~6250 K), so it lacks the
-- convective envelope needed to tidally realign the orbit. Obliquity values are NASA EA's
-- (reflink Collier Cameron et al. 2010, which is also the discovery cite); promoted (cited)
-- into planet_derived_measurements. The broad ~234-planet obliquity promotion stays a separate
-- v0.2 task. Bibcode verified via ADS. Citation linked role='characterization',
-- contribution='obliquity' in etl/seed_followup_citations.py.
--
--   Collier Cameron et al. 2010 (line-profile / Doppler-shadow tomography):
--     lambda = 251.2 +/- 1.0 deg; true obliquity psi = 108.19 +0.95/-0.97 deg.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-33 b', 'projected_obliquity', 251.2, 1.0, 1.0, 'deg', 'Doppler tomography',
     '2010MNRAS.407..507C',
     'Collier Cameron et al. 2010: sky-projected spin-orbit angle lambda = 251.2 +/- 1.0 deg '
     '(NASA EA convention; equivalently about -108.8 deg) -- a retrograde orbit, measured via '
     'line-profile (Doppler-shadow) tomography across the transit.'),
    ('WASP-33 b', 'true_obliquity', 108.19, 0.95, 0.97, 'deg', 'Doppler tomography',
     '2010MNRAS.407..507C',
     'Collier Cameron et al. 2010: de-projected 3D obliquity psi = 108.19 +0.95/-0.97 deg '
     '(>90 deg = retrograde). The host is a hot (7430 K), rapidly rotating A5 delta-Scuti star '
     'above the Kraft break, so it cannot tidally realign the orbit and the primordial '
     'misalignment is preserved.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
