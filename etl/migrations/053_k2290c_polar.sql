-- K2-290 c spin-orbit obliquity ("Tilted & Tumbling" theme, manual literature review,
-- 2026-05-24). A warm Jupiter (~0.77 Mjup, 48 d) in a two-planet system around a
-- "backward-spinning" star: both K2-290 b and c are coplanar with each other, but the whole
-- planetary plane is tilted ~124 deg from the host star's spin axis. Because the two planets
-- SHARE the tilt (rather than being misaligned relative to each other), this is evidence for a
-- PRIMORDIAL disk misalignment -- the protoplanetary disk itself was tipped over, most likely
-- torqued by the wide stellar companion K2-290 B -- rather than the per-planet high-eccentricity
-- (Kozai / scattering) migration invoked for isolated misaligned hot Jupiters. A distinct origin
-- story for the theme. Obliquity values are NASA EA's (reflink Hjorth et al. 2021, the PNAS
-- "backward-spinning star" paper; distinct from the 2019 discovery cite); promoted (cited) into
-- planet_derived_measurements. Bibcode verified via ADS. Citation linked role='characterization',
-- contribution='obliquity' in etl/seed_followup_citations.py.
--
--   Hjorth et al. 2021 (PNAS): lambda = 153 +/- 8 deg, true obliquity psi = 124 +/- 6 deg.
--   (K2-290 b's obliquity is consistent but poorly constrained, 173 +45/-53 deg; not recorded.)
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('K2-290 c', 'projected_obliquity', 153, 8, 8, 'deg', 'Rossiter-McLaughlin',
     '2021PNAS..11817418H',
     'Hjorth et al. 2021: sky-projected spin-orbit angle lambda = 153 +/- 8 deg.'),
    ('K2-290 c', 'true_obliquity', 124, 6, 6, 'deg', 'Rossiter-McLaughlin',
     '2021PNAS..11817418H',
     'Hjorth et al. 2021: de-projected obliquity psi = 124 +/- 6 deg -- a strongly misaligned, '
     'backward (retrograde) configuration. Both K2-290 planets (b and c) are coplanar with each '
     'other but the whole plane is tilted ~124 deg from the stellar spin, pointing to a PRIMORDIAL '
     'tilt of the protoplanetary disk (likely torqued by the wide stellar companion K2-290 B) '
     'rather than per-planet scattering or Kozai migration.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
