-- HAT-P-7 b spin-orbit obliquity ("Tilted & Tumbling" theme, manual literature review,
-- 2026-05-24). A hot Jupiter (~1.8 Mjup, 2.2 d) on a near-POLAR orbit. One of the first hot
-- Jupiters found spin-orbit misaligned (Winn et al. 2009, simultaneously with WASP-17 b) --
-- the discovery that broke the assumption that hot Jupiters quietly migrate through their natal
-- disks. The sky-projected angle is ~retrograde (lambda ~ 182.5 deg) but the de-projected true
-- obliquity is near-polar (psi ~ 86 deg), hence Winn et al.'s title "a retrograde or polar orbit."
-- The same paper found a third body in the system; with HAT-P-7's wide stellar companion and a
-- host near the Kraft break (Teff ~6390 K), Kozai-Lidov migration is the favored origin. Obliquity
-- values are NASA EA's (reflink Winn et al. 2009, distinct from the 2008 discovery cite); promoted
-- (cited) into planet_derived_measurements. Bibcode verified via ADS. Citation linked
-- role='characterization', contribution='obliquity' in etl/seed_followup_citations.py.
--
--   Winn et al. 2009: lambda = 182.5 +/- 9.4 deg; true obliquity psi ~ 86.3 deg
--     (NASA EA lists no formal uncertainty on psi).
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HAT-P-7 b', 'projected_obliquity', 182.5, 9.4, 9.4, 'deg', 'Rossiter-McLaughlin',
     '2009ApJ...703L..99W',
     'Winn et al. 2009: sky-projected spin-orbit angle lambda = 182.5 +/- 9.4 deg '
     '(~anti-aligned / retrograde in projection).'),
    ('HAT-P-7 b', 'true_obliquity', 86.3, NULL, NULL, 'deg', 'Rossiter-McLaughlin',
     '2009ApJ...703L..99W',
     'Winn et al. 2009: de-projected obliquity psi ~ 86.3 deg -- a near-POLAR orbit (NASA EA lists '
     'no formal uncertainty). One of the first misaligned hot Jupiters (announced alongside '
     'WASP-17 b). A third body in the system plus HAT-P-7''s wide stellar companion, with a host '
     'near the Kraft break, favor a Kozai-Lidov migration origin.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
