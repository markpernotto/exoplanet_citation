-- HD 95086 b deep dive (manual literature review, 2026-05-23). A young (10-17 Myr),
-- ~4-5 Mjup planet imaged at 56 au from the dusty A8 star HD 95086 -- at discovery the
-- lowest-mass exoplanet ever imaged around a star, and a close analog of the HR 8799 /
-- bet Pic systems: a giant planet sitting in the gap of a two-belt debris disk. Its
-- defining trait is an EXTREMELY red, dust-dominated atmosphere: the GPI K1 spectrum is
-- featureless (a smooth cloudy pseudo-continuum), over a magnitude redder than 2M1207 b
-- or HR 8799 c/d. So the value-add here is a cloud/dust non-detection plus a (broad,
-- dust-degenerate) effective temperature, not a molecule list. Molecule ->
-- planet_atmospheres; Teff -> planet_derived_measurements. Values read from the cited
-- paper; bibcode verified via ADS. Citation linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Rameau et al. 2013 (VLT/NaCo L'; discovery) -- 4-5 Mjup at 56 au; extremely red Ks-L'.
--   De Rosa et al. 2016 (Gemini/GPI; H phot + K1 R~66 spectrum) -- featureless cloudy
--     continuum; Teff = 800-1300 K, low gravity, high photospheric dust; spectral type
--     poorly constrained from early-L to late-T (an L/T-transition, very dusty object).
--   Malin et al. 2024 (JWST/MIRI 10.6/11.3/23 um) -- mid-IR detection of the planet plus
--     the inner disk (HR 8799-like) and outer belt; adds atmospheric constraints (already
--     in planet_atmospheric_observations).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('HD 95086 b', 'H2O', 'inconclusive', 'Gemini/GPI', '2016ApJ...824..121D', NULL,
     'De Rosa et al. 2016. The K1 (1.9-2.2 um, R~66) spectrum is featureless -- a monotonically '
     'rising pseudo-continuum consistent with a very cloudy, dust-rich atmosphere -- so no '
     'molecular features are seen, but the low resolution cannot rule them out. HD 95086 b is '
     'over a magnitude redder in K1-L'' than 2M1207 b and HR 8799 c/d.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HD 95086 b', 'effective_temperature', 1050, 250, 250, 'K', 'SED fit (dusty models)',
     '2016ApJ...824..121D',
     'De Rosa et al. 2016: Teff = 800-1300 K (range; midpoint here) from low-gravity, '
     'high-dust model atmospheres fit to the SED. The broad range reflects the L/T-transition '
     'dust degeneracy (spectral type unconstrained from early-L to late-T); JWST/MIRI mid-IR '
     'photometry later added constraints (Malin et al. 2024).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
