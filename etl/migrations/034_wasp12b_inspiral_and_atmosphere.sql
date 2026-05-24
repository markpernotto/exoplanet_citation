-- WASP-12 b deep dive (manual literature review, 2026-05-23). A hot Jupiter on a
-- 1.09-day orbit that is measurably spiraling into its star and overflowing its
-- Roche lobe. Molecule detections go to planet_atmospheres; the orbital-decay
-- scalars go to planet_derived_measurements. Values read from the cited papers;
-- bibcodes verified via ADS. Citations linked role='characterization' in
-- etl/seed_followup_citations.py.
--
--   Yee et al. 2020 (transit timing) -- the transit interval is shrinking by
--     29 +/- 2 ms/yr: decisive evidence for orbital decay (favored over apsidal
--     precession by a Bayes factor of 70,000); the planet is inspiraling.
--   Patra et al. 2017 (transit timing) -- P/Pdot = 3.2 Myr to destruction;
--     implies a stellar tidal quality factor Q_star ~ 2e5.
--   Kreidberg et al. 2015 (HST/WFC3) -- H2O in transmission; revisits the debated
--     high C/O (>1) inferred from earlier dayside emission.
--   Fossati et al. 2010 (HST/COS NUV) -- Mg II 2800 resonance absorption: metals
--     in the escaping/overflowing exosphere.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-12 b', 'H2O', 'detected', 'HST/WFC3', '2015ApJ...814...66K', NULL,
     'Kreidberg et al. 2015. H2O in the near-IR transmission spectrum (six HST/WFC3 '
     'transits); constrains the debated high C/O (>1) inferred from earlier dayside emission.'),
    ('WASP-12 b', 'Mg II', 'detected', 'HST/COS', '2010ApJ...714L.222F', NULL,
     'Fossati et al. 2010. Mg II 2800 A resonance-line absorption in the NUV: metals in '
     'the escaping, overflowing exosphere of this Roche-lobe-filling hot Jupiter.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('WASP-12 b', 'orbital_decay_rate', -29, 2, 2, 'ms_per_yr', 'transit timing',
     '2020ApJ...888L...5Y',
     'Yee et al. 2020. The transit interval is shrinking by 29 +/- 2 ms/yr - decisive '
     'evidence the orbit is decaying (favored over apsidal precession, Bayes factor '
     '70,000). The planet is spiraling into its star.'),
    ('WASP-12 b', 'orbital_decay_timescale', 3.2, NULL, NULL, 'Myr', 'P / dP-dt',
     '2017AJ....154....4P',
     'Patra et al. 2017. P/Pdot = 3.2 Myr remaining if the decay continues; the implied '
     'stellar tidal quality factor is Q_star ~ 2e5.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
