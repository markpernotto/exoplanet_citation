-- WASP-17 b spin-orbit obliquity (manual literature review, 2026-05-24). First entry in
-- the "Tilted & Tumbling" theme: spin-orbit-misaligned (retrograde/polar) planets. WASP-17 b
-- was the first exoplanet found on a RETROGRADE orbit -- it orbits backwards relative to the
-- host star's spin. The sky-projected obliquity lambda = -148.5 deg (a prograde, aligned orbit
-- is 0 deg; |lambda| near 180 is retrograde). The discovery paper (Anderson et al. 2010, already
-- the catalog discovery cite) reported the probable retrograde orbit; Triaud et al. 2010 refined
-- the spin-orbit angle via the Rossiter-McLaughlin effect and argued such misalignments point to
-- high-eccentricity (Kozai-Lidov + tidal) migration rather than disk migration. The obliquity
-- value lives in NASA EA's raw_row but is not surfaced; this records it (cited) into the usable
-- planet_derived_measurements layer -- a curated down-payment on the v0.2 obliquity visual
-- (axial-tilt rendering). The broad promotion of all ~234 obliquities stays a separate v0.2 task.
-- Value sourced to Triaud et al. 2010 (the NASA EA reflink); bibcode verified via ADS. Citation
-- linked role='characterization', contribution='obliquity' in etl/seed_followup_citations.py.
--
--   Triaud et al. 2010 (HARPS Rossiter-McLaughlin) -- lambda = -148.5 +5.1/-4.2 deg.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-17 b', 'projected_obliquity', -148.5, 5.1, 4.2, 'deg', 'Rossiter-McLaughlin',
     '2010A&A...524A..25T',
     'Triaud et al. 2010: sky-projected spin-orbit angle lambda = -148.5 +5.1/-4.2 deg -- '
     'strongly retrograde. WASP-17 b (an ultra-low-density hot Jupiter) was the first planet '
     'found on a retrograde orbit (Anderson et al. 2010, discovery). The misalignment supports a '
     'high-eccentricity (Kozai-Lidov + tidal) migration origin. True obliquity not constrained '
     '(needs the stellar spin-axis inclination).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
