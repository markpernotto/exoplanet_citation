-- AB Pic b deep dive (manual literature review, 2026-05-23). An early-L companion on a
-- very wide (~190-260 au), highly inclined orbit around the young (~30 Myr,
-- Tucana-Horologium) K-type star AB Pic. At ~13-14 Mjup it straddles the
-- planet/brown-dwarf (deuterium-burning) boundary -- the discovery paper literally
-- asked "a massive planet or a minimum-mass brown dwarf?". The value-add is the
-- atmospheric/spin characterization: a refined effective temperature, the first C/O
-- ratio (solar-like), and the first projected rotation. The discovery/SINFONI papers
-- describe atmospheric-parameter fits rather than explicit per-molecule detections, so
-- nothing is asserted in planet_atmospheres; the scalars go to
-- planet_derived_measurements. Values read from the cited paper; bibcode verified via
-- ADS. Citation linked role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Chauvin et al. 2005 (VLT/NACO; discovery) -- early-L, 13-14 Mjup at ~30 Myr.
--   Bonnefoy et al. 2010 (VLT/SINFONI, R 1500-2000) -- L0-L1, intermediate gravity,
--     Teff = 2000 +100/-300 K, log g = 4 +/- 0.5.
--   Palma-Bifani et al. 2023 (ForMoSA on merged SINFONI K-band R~4000 + J/H/Lp +
--     HST/Spitzer) -- Exo-REM: Teff = 1700 +/- 50 K, log g = 4.5 +/- 0.3, C/O =
--     0.58 +/- 0.08 (first; solar-like), vsin(i) = 73 +11/-27 km/s (first), edge-on
--     orbit and a high inferred obliquity.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('AB Pic b', 'effective_temperature', 1700, 50, 50, 'K', 'Exo-REM forward model (ForMoSA)',
     '2023A&A...670A..90P',
     'Palma-Bifani et al. 2023: Teff = 1700 +/- 50 K with log g = 4.5 +/- 0.3 (Exo-REM). '
     'Refines the earlier SINFONI fit of 2000 +100/-300 K (Bonnefoy et al. 2010); an early-L, '
     'intermediate-gravity atmosphere. Posteriors are sensitive to wavelength range and model family.'),
    ('AB Pic b', 'C/O', 0.58, 0.08, 0.08, 'ratio', 'Exo-REM forward model (ForMoSA)',
     '2023A&A...670A..90P',
     'Palma-Bifani et al. 2023: C/O = 0.58 +/- 0.08, the first C/O measurement for AB Pic b and '
     'consistent with the solar value.'),
    ('AB Pic b', 'rotation_velocity', 73, 11, 27, 'km_s', 'spectral line broadening (vsin i)',
     '2023A&A...670A..90P',
     'Palma-Bifani et al. 2023: projected rotation vsin(i) = 73 +11/-27 km/s, the first for this '
     'object. Combined with the published 2.1 h rotation period it implies a high true obliquity '
     '(spin strongly tilted from the orbit).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
