-- HIP 65426 b deep dive (manual literature review, 2026-05-23). A young (~14-17 Myr),
-- warm, dusty super-Jupiter on a wide ~92 au orbit around an A2 star -- and the FIRST
-- exoplanet ever imaged by JWST (Carter et al. 2023), as well as the first direct
-- detection of any exoplanet beyond 5 um. Its spectrum is L5-L7-dwarf-like (cloudy,
-- low surface gravity), so the value-add is the characterization scalars, not a long
-- molecule list: a medium-resolution K-band spectrum (Petrus 2021) pins Teff,
-- metallicity and C/O, while the JWST 2-16 um photometry (Carter 2023) ties down the
-- bolometric luminosity and hence a refined mass. The two K-band carriers (H2O, CO)
-- that the molecular-mapping re-detection and the C/O constraint rest on are recorded
-- in planet_atmospheres; the scalars go to planet_derived_measurements. Values read
-- from the cited papers; bibcodes verified via ADS. Citations linked
-- role='characterization', contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Chauvin et al. 2017 (VLT/SPHERE; discovery) -- warm dusty L5-L7 companion at
--     92 au; Teff 1300-1600 K, 6-12 Mjup, R ~1.5 Rjup (hot start).
--   Petrus et al. 2021 (VLT/SINFONI, K-band, R~5577) -- ForMoSA fit: Teff = 1560 +/- 100 K,
--     log g <= 4.40, [M/H] = 0.05 +0.24/-0.22, C/O <= 0.55 (solar/sub-solar -> solid
--     enrichment, core accretion beyond the snowline); planet re-detected via molecular
--     mapping (H2O + CO are the K-band carriers).
--   Carter et al. 2023 (JWST NIRCam 2-5 um + MIRI 11-16 um) -- first JWST exoplanet
--     image; empirical bolometric luminosity log(Lbol/Lsun) = -4.31 to -4.14, giving a
--     refined mass of 7.1 +/- 1.2 Mjup.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('HIP 65426 b', 'H2O', 'detected', 'VLT/SINFONI', '2021A&A...648A..59P', NULL,
     'Petrus et al. 2021. Water is one of the two K-band carriers shaping the R~5577 '
     'medium-resolution spectrum; the planet is re-detected via molecular mapping and '
     'H2O/CO together constrain C/O <= 0.55. (No per-molecule significance reported.)'),
    ('HIP 65426 b', 'CO', 'detected', 'VLT/SINFONI', '2021A&A...648A..59P', NULL,
     'Petrus et al. 2021. CO is the carbon carrier in the K-band molecular-mapping '
     're-detection; with H2O it sets the C/O <= 0.55 upper limit. (No per-molecule '
     'significance reported.)')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HIP 65426 b', 'effective_temperature', 1560, 100, 100, 'K', 'K-band spectrum (ForMoSA)',
     '2021A&A...648A..59P',
     'Petrus et al. 2021: Teff = 1560 +/- 100 K from a VLT/SINFONI K-band medium-resolution '
     'spectrum (BT-SETTL15 + Exo-REM). Consistent with the 1300-1600 K discovery estimate '
     '(Chauvin et al. 2017); an L5-L7-dwarf-like, cloudy atmosphere.'),
    ('HIP 65426 b', 'metallicity', 0.05, 0.24, 0.22, 'dex', 'K-band spectrum (ForMoSA)',
     '2021A&A...648A..59P',
     'Petrus et al. 2021: [M/H] = 0.05 +0.24/-0.22 dex (solar within errors), compatible with '
     'the bulk enrichment of massive Jovian planets in the Bern population models.'),
    ('HIP 65426 b', 'C/O', 0.55, NULL, NULL, 'ratio', 'K-band spectrum (ForMoSA)',
     '2021A&A...648A..59P',
     'Petrus et al. 2021: C/O <= 0.55 (upper limit). Solar-to-sub-solar C/O points to '
     'enrichment by solids if the planet formed beyond the water snowline (>=20 au) by core '
     'accretion, though gravitational instability is not excluded.'),
    ('HIP 65426 b', 'bolometric_luminosity', -4.23, 0.09, 0.08, 'log_Lsun', 'JWST 2-16 um SED',
     '2023ApJ...951L..20C',
     'Carter et al. 2023: empirical log(Lbol/Lsun) tightly constrained between -4.31 and -4.14 '
     'from JWST NIRCam+MIRI photometry spanning ~97% of the planet luminous range (model-'
     'independent; value here is the midpoint).'),
    ('HIP 65426 b', 'mass', 7.1, 1.2, 1.2, 'M_jup', 'luminosity + hot-start evolutionary models',
     '2023ApJ...951L..20C',
     'Carter et al. 2023: 7.1 +/- 1.2 Mjup from the JWST bolometric luminosity. Refines the '
     'catalog mass (~9 Mjup from older hot-start photometry); this is the first JWST-based mass '
     'for the first JWST-imaged exoplanet.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
