-- GJ 504 b deep dive (manual literature review, 2026-05-23). A cold (~510-544 K),
-- wide-orbit (43.5 au) directly-imaged companion to a Sun-like star -- famously the
-- first "T-dwarf-type" exoplanet: cool and blue enough (J-H = -0.23) that its clouds
-- have largely dissipated and methane has appeared, the L->T transition that defines
-- the T spectral class. It bridges the gap between the first imaged planets (~1000 K)
-- and Jupiter (~130 K). The value-add is the characterization: a methane detection
-- plus the effective temperature, a superstellar metallicity (evidence for a
-- planet-like origin), and the bolometric luminosity. NB its mass and planet-vs-BD
-- status hinge on the disputed system age (160 Myr -> ~4 Mjup planet per Kuzuhara
-- 2013; Bonnefoy 2018 finds 21 Myr or considerably older from interferometry, which
-- would push it toward 3-30 Mjup). Molecule -> planet_atmospheres; scalars ->
-- planet_derived_measurements. Values read from the cited papers; bibcodes verified
-- via ADS. Citation linked role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Kuzuhara et al. 2013 (Subaru/HiCIAO, SEEDS; discovery) -- Teff = 510 +30/-20 K,
--     ~4 Mjup at 160 Myr; bluer/cloud-free vs all earlier imaged (L-type) planets.
--   Skemer et al. 2016 (LBT/LBTI, L-band 3.71-4.00 um) -- first SED fit: Teff =
--     544 +/- 10 K, [M/H] = 0.60 +/- 0.12 (superstellar), log(L/Lsun) = -6.13 +/- 0.03,
--     R = 0.96 +/- 0.07 Rjup; the methane fundamental (3.3 um) marks it as the first
--     T-dwarf exoplanet.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('GJ 504 b', 'CH4', 'detected', 'LBT/LBTI', '2016ApJ...817..166S', NULL,
     'Skemer et al. 2016. L-band photometry (3.71/3.88/4.00 um) spanning the red end of the '
     'methane fundamental absorption (3.3 um). The appearance of methane plus the dissipation '
     'of clouds makes GJ 504 b the first directly-imaged exoplanet of T-dwarf type (the L->T '
     'transition); discovery already noted a blue, cloud-free atmosphere (Kuzuhara et al. 2013).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('GJ 504 b', 'effective_temperature', 544, 10, 10, 'K', 'L-band SED fit',
     '2016ApJ...817..166S',
     'Skemer et al. 2016: Teff = 544 +/- 10 K from custom model-atmosphere fits to the L-band '
     '+ literature photometry (discovery value 510 +30/-20 K; Kuzuhara et al. 2013). One of the '
     'coldest directly-imaged planets, between the first imaged planets (~1000 K) and Jupiter (~130 K).'),
    ('GJ 504 b', 'metallicity', 0.60, 0.12, 0.12, 'dex', 'L-band SED fit',
     '2016ApJ...817..166S',
     'Skemer et al. 2016: [M/H] = 0.60 +/- 0.12 dex -- a SUPERSTELLAR metallicity. Planet '
     'formation can create non-stellar metallicities while binary-star formation cannot, so '
     'this favors a planet-like (core-accretion) origin.'),
    ('GJ 504 b', 'bolometric_luminosity', -6.13, 0.03, 0.03, 'log_Lsun', 'L-band SED fit',
     '2016ApJ...817..166S',
     'Skemer et al. 2016: log(L/Lsun) = -6.13 +/- 0.03. Implies a hot-start mass of 3-30 Mjup '
     'over a conservative 0.1-6.5 Gyr age range; the planet-vs-brown-dwarf verdict depends on '
     'the disputed system age (Bonnefoy et al. 2018).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
