-- LHS 1140 b deep dive (manual literature review, 2026-05-23). The temperate
-- (Teq ~226 K) habitable-zone super-Earth sits in the radius valley; its low bulk
-- density made it either a mini-Neptune (~0.1% H2 by mass) or a water world
-- (9-19% water). Two JWST transmission programs settled it in favour of a water
-- world. The value-add is a scenario rule-out plus a bulk-composition scalar, not
-- a molecule list (no atmospheric species is confidently detected). Values read
-- from the cited papers; bibcodes verified via ADS. Citations linked
-- role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Damiano et al. 2024 (JWST/NIRSpec, 1.7-5.2 um) -- the spectrum is inconsistent
--     with H2-rich atmospheres (a H2-rich atmosphere would show prominent CH4 or
--     CO2, which are absent), leaving a high-mean-molecular-weight (possibly
--     N2-dominated) atmosphere / water world: "potentially habitable water world".
--   Cadieux et al. 2024 (JWST/NIRISS) -- same conclusion; quantifies a water world
--     at 9-19% water by mass (the spectrum is also affected by stellar faculae).
--
-- (The 2025 MIRI paper in the observation table, Fortune et al. 2025, is about
-- LHS 1140 c, not b -- held for a future LHS 1140 c pass.)
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('LHS 1140 b', 'H2', 'ruled_out', 'JWST/NIRSpec', '2024ApJ...968L..22D', NULL,
     'Damiano et al. 2024 ("LHS 1140 b Is a Potentially Habitable Water World"). The '
     'NIRSpec spectrum is inconsistent with H2-rich atmospheres -- such an atmosphere '
     'would show prominent CH4 or CO2 features, which are not seen -- leaving a '
     'high-mean-molecular-weight (possibly N2-dominated) atmosphere / water world. '
     'Cadieux et al. 2024 (NIRISS) reach the same conclusion.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('LHS 1140 b', 'water_mass_fraction', 14, 5, 5, 'wt_pct', 'water-world (bulk density + JWST H2 rule-out)',
     '2024ApJ...970L...2C',
     'Cadieux et al. 2024 (with Damiano et al. 2024). The low bulk density plus the JWST '
     'exclusion of a H2-rich atmosphere favour a water world with 9-19% water by mass '
     '(recorded as the midpoint with bounds) over a rocky or mini-Neptune interior.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
