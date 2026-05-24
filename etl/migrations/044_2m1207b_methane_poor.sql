-- 2M1207 b deep dive (manual literature review, 2026-05-23). Catalog name
-- '2MASS J12073346-3932539 b'; also known as TWA 27B. This is the FIRST exoplanet ever
-- directly imaged (Chauvin et al. 2004) -- a ~5 Mjup planetary-mass companion to a
-- young (~8 Myr, TW Hya association) brown dwarf. Its long-standing puzzle was
-- underluminosity (it looked too faint/small for its spectral type); Barman et al.
-- 2011 showed this is a purely atmospheric effect (clouds + non-equilibrium chemistry
-- + low gravity), not an edge-on disk or collision remnant. The headline value-add is
-- the counterintuitive molecule story confirmed by JWST: despite a cool ~1200 K
-- temperature it is METHANE-POOR (the CH4 fundamental band is absent) with only weak
-- CO -- non-equilibrium chemistry driven by youth. (Bonus, not stored here: Luhman
-- 2023 also found He I 1.083 um + Paschen emission, the first evidence of a
-- circumstellar disk accreting onto a planetary-mass object.) Molecules ->
-- planet_atmospheres; Teff -> planet_derived_measurements. Values read from the cited
-- papers; bibcodes verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Chauvin et al. 2004 (VLT/NACO; discovery) -- L5-L9.5, M = 5 +/- 2 Mjup, Teff ~1250 K.
--   Barman et al. 2011 -- the cloudy + non-equilibrium + low-gravity atmosphere that
--     explains the underluminosity and the methane-poor, T-dwarf-unlike spectrum.
--   Luhman et al. 2023 (JWST/NIRSpec, 1-5 um) -- CH4 fundamental band ABSENT, CO
--     fundamental band weak; cloudless ATMO fit ~1300 K (vs ~1200 K from luminosity+age).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('2MASS J12073346-3932539 b', 'CH4', 'ruled_out', 'JWST/NIRSpec', '2023ApJ...949L..36L', NULL,
     'Luhman et al. 2023. The CH4 fundamental band is ABSENT in the 1-5 um NIRSpec spectrum -- '
     'methane-poor despite a cool ~1200 K temperature. Part of a trend of weaker CH4 at younger '
     'ages (enhanced non-equilibrium chemistry), the atmospheric explanation Barman et al. 2011 '
     'proposed to resolve this object''s underluminosity.'),
    ('2MASS J12073346-3932539 b', 'CO', 'detected', 'JWST/NIRSpec', '2023ApJ...949L..36L', NULL,
     'Luhman et al. 2023. The CO fundamental band is present but WEAK; the weakness may reflect '
     'an age-dependent property such as the temperature gradient or cloud thickness.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('2MASS J12073346-3932539 b', 'effective_temperature', 1200, NULL, NULL, 'K',
     'luminosity + age (evolutionary)', '2023ApJ...949L..36L',
     'Luhman et al. 2023: ~1200 K expected from the luminosity and the ~8 Myr TW Hya age. A '
     'cloudless ATMO model with non-equilibrium chemistry fits the broad spectrum at 1300 K '
     '(slightly too hot); earlier AMES-Dusty fits gave ~1600 K (Patience et al. 2010), which '
     'implied an unphysically small radius -- the underluminosity puzzle resolved by clouds + '
     'non-equilibrium chemistry (Barman et al. 2011).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
