-- tau Boo b deep dive (manual literature review, 2026-05-24). One of the first
-- exoplanets found (Butler et al. 1997, a "51 Peg-type" hot Jupiter) and a landmark for
-- a different reason: it was the FIRST non-transiting planet to be atmospherically
-- characterized, via high-resolution spectroscopy that tracks the planet's own Doppler
-- shift. That technique also breaks the m sin i degeneracy: Brogi et al. 2012 measured
-- the orbital inclination (44.5 deg) and hence the true mass (5.95 Mjup, the value the
-- catalog now carries but does not cite). The composition is unusual: CO is firmly
-- detected but water is strongly DEPLETED, giving a Jupiter-like C/H but a high C/O.
-- The dayside has NO thermal inversion, attributed to the active host star's UV
-- destroying the inversion-causing compounds. Molecules -> planet_atmospheres; the
-- inclination and C/H -> planet_derived_measurements. Values read from the cited
-- papers; bibcodes verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Brogi et al. 2012 (VLT/CRIRES, R~100k, dayside) -- CO detected; i = 44.5 +/- 1.5 deg,
--     M = 5.95 +/- 0.28 Mjup; non-inverted temperature structure.
--   Rodler et al. 2012 (2.3 um) -- independent CO detection, i = 47 +7/-6, M = 5.6 +/- 0.7.
--   Lockwood et al. 2014 (Keck/NIRSPEC L-band) -- first H2O in a non-transiting hot
--     Jupiter (6 sigma); i = 45 +3/-4, M = 5.90 +0.35/-0.20.
--   Pelletier et al. 2021 (CFHT/SPIRou, R=70k, 0.95-2.5 um) -- CO firmly detected; H2O
--     strongly depleted (< 0.0072x solar); CH4/CO2/HCN/TiO/C2H2 upper limits; C/H =
--     5.85 x solar (Jupiter-like) -> high C/O.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('tau Boo b', 'CO', 'detected', 'VLT/CRIRES', '2012Natur.486..502B', NULL,
     'Brogi et al. 2012. Carbon monoxide in the thermal dayside spectrum (R~100,000) -- the '
     'first atmospheric detection for a NON-transiting planet, tracked via the planet''s own '
     'radial-velocity shift. Confirmed by Rodler et al. 2012 and Pelletier et al. 2021. The '
     'temperature decreases with altitude (no inversion), likely because the host star''s UV '
     'destroys the inversion-causing absorbers.'),
    ('tau Boo b', 'H2O', 'detected', 'Keck/NIRSPEC', '2014ApJ...783L..29L', 6.0,
     'Lockwood et al. 2014. First water-vapor detection in a non-transiting hot Jupiter (6 sigma, '
     'L-band cross-correlation). NB the abundance is anomalously low: Pelletier et al. 2021 find '
     'H2O strongly depleted (< 0.0072x the solar-composition value) -- the "where is the water?" puzzle.'),
    ('tau Boo b', 'CH4', 'upper_limit', 'CFHT/SPIRou', '2021AJ....162...73P', NULL,
     'Pelletier et al. 2021. Not detected; an upper limit (with CO2, HCN, TiO, C2H2). The strong '
     'water depletion plus a normal CO abundance yields a Jupiter-like C/H but a high C/O ratio.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('tau Boo b', 'orbital_inclination', 44.5, 1.5, 1.5, 'deg', 'CO radial-velocity tracking',
     '2012Natur.486..502B',
     'Brogi et al. 2012: i = 44.5 +/- 1.5 deg from tracking the CO lines through the orbit, ending '
     'a decade of disputed inclination for this non-transiting planet. Gives a true mass of '
     '5.95 +/- 0.28 Mjup (the catalog value). Rodler 2012 (47 +7/-6) and Lockwood 2014 (45 +3/-4) agree.'),
    ('tau Boo b', 'C/H', 5.85, 4.44, 2.82, 'x_solar', 'SPIRou high-res retrieval',
     '2021AJ....162...73P',
     'Pelletier et al. 2021: carbon abundance C/H = 5.85 x solar, Jupiter-like. Combined with the '
     'strong water (oxygen) depletion this implies a robustly super-solar C/O ratio.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
