-- Atmosphere backlog batch 2: "fast-follow" systems (manual literature review, 2026-05-25).
-- These were already curated for obliquity/dynamics (migrations 051-056) but had no
-- molecule layer. Molecules + states taken from the cited papers' abstracts; bibcodes
-- verified via ADS where reachable. Per-molecule significances mostly need the papers'
-- tables (left NULL, noted inline for follow-up paste).
--
--   WASP-17 b  -- Vroom et al. 2024 (JWST MIRI/LRS emission): water marginally recovered.
--     Grant et al. 2023 (JWST MIRI/LRS transmission, user-pasted tables 2026-05-25):
--     quartz (SiO2) CLOUDS via the ~8.6 um feature, ~0.01 um grains, cloud-top ~10 ubar,
--     vertically extended; CO2 detected (log MMR ~-5.5); CH4/CO/SO2 unconstrained ->
--     upper_limit. Super-solar metallicity 30-100x solar, C/O ~0.4-0.7 (cloudy grid).
--   WASP-33 b  -- Haynes et al. 2015 (HST/WFC3 eclipse): water in EMISSION -> dayside
--     thermal inversion. Enriched 2026-05-25 from user-pasted Nugroho review + Cont 2022
--     tables: TiO detected (Nugroho 2017, contested by Serindag 2021); Fe I (Nugroho
--     2020, S/N 7.9 in Cont 2022); OH (Nugroho 2021 = FIRST OH in any exoplanet, S/N
--     4.4 in Cont 2022; H2O co-detected weakly = thermal dissociation); plus Ti I (6.3),
--     V I (4.8), Si I (4.4), Ti II (3.6) from Cont et al. 2022. Derived from Cont 2022:
--     [M/H] = 1.49 dex (~31x solar) and dayside T2 = 3424 K (T1 inversion top = 3981 K).
--   WASP-79 b  -- Sotzen et al. 2020 (HST/WFC3 + LDSS-3C + Spitzer, 0.6-5 um): water
--     detected (log H2O in -2.2..-1.55); retrieval also favors FeH and H- (FeH recorded
--     tentative; H- is continuum opacity / a modeling inference, kept in the note).
--   HAT-P-7 b  -- Wong et al. 2016 (Spitzer phase curves): dayside is a ~2667 K blackbody.
--     Now enriched (user-pasted Changeat 2022 table, 2026-05-25): dayside H2O / CO2 / FeH
--     detected (Spitzer-enabled in the HST+Spitzer free retrieval); CH4 / CO / TiO / VO
--     unconstrained; transit/terminator featureless. Derived (Changeat 2022): dayside T =
--     2562 +/- 253 K (contribution-function-weighted), log Z = 0.5 dex, C/O = 0.5.
--   HD 80606 b -- Steckloff et al. 2025 (JWST NIRSpec/G395H emission): across periastron
--     the spectrum turns from a featureless blackbody into one showing CO, CH4 and H2O
--     absorption ("seasonal" chemistry on the e=0.93 orbit). Complements the existing
--     periastron flash-heating dayside temperature (Laughlin 2009, migration 056).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-17 b', 'H2O', 'detected', 'JWST/MIRI-LRS', '2024AJ....168..123V', NULL,
     'Vroom et al. 2024: marginally recovered (supersolar) in the MIRI dayside emission spectrum. '
     'Grant et al. 2023 (transmission MIRI) gives a clean abundance: log H2O = -4.53 +0.37/-0.36 (POSEIDON) / '
     '-4.75 +0.33/-0.29 (petitRADTRANS).'),
    ('WASP-17 b', 'SiO2', 'detected', 'JWST/MIRI-LRS', '2023ApJ...956L..29G', NULL,
     'Grant et al. 2023: solid silica (quartz) CLOUD particles via the ~8.6 um SiO2 feature in the '
     'MIRI/LRS transmission spectrum, the first quartz-cloud detection in an exoplanet atmosphere. '
     'Mean particle radius log r ~ -1.91 um (~0.01 um grains); cloud-top pressure ~10 ubar (POSEIDON) / '
     'cloud base ~0.8 mbar (petitRADTRANS); vertically extended (dlog P ~2.4 bars). The same species '
     'Inglis et al. 2024 later found on HD 189733 b''s dayside. (Gas-phase SiO2 not detected; the SiO2 '
     'budget is in the clouds.) Super-solar atmospheric metallicity 30-100x solar in the PICASO+Virga '
     'cloudy grid retrieval; C/O ~0.4-0.7.'),
    ('WASP-17 b', 'CO2', 'detected', 'JWST/MIRI-LRS', '2023ApJ...956L..29G', NULL,
     'Grant et al. 2023: log mixing ratio -5.40 +0.56/-0.67 (POSEIDON) / -5.54 +0.53/-0.72 (petitRADTRANS), '
     'consistent across retrievers.'),
    ('WASP-17 b', 'CH4', 'upper_limit', 'JWST/MIRI-LRS', '2023ApJ...956L..29G', NULL,
     'Grant et al. 2023: not detected; log MMR posterior -8.52 +1.69/-2.23 (POSEIDON) / -10.21 +2.30/-2.36 '
     '(petitRADTRANS), broadly unconstrained / consistent with non-detection.'),
    ('WASP-17 b', 'CO', 'upper_limit', 'JWST/MIRI-LRS', '2023ApJ...956L..29G', NULL,
     'Grant et al. 2023: not detected; log MMR posterior -7.61 +2.53/-2.83 (POSEIDON) / -8.06 +3.15/-3.84 '
     '(petitRADTRANS), unconstrained.'),
    ('WASP-17 b', 'SO2', 'upper_limit', 'JWST/MIRI-LRS', '2023ApJ...956L..29G', NULL,
     'Grant et al. 2023: not detected; log MMR posterior -10.83 +2.22/-2.17 (petitRADTRANS), unconstrained.'),
    ('WASP-33 b', 'H2O', 'detected', 'HST/WFC3', '2015ApJ...806..146H', NULL,
     'Haynes et al. 2015: water in EMISSION (HST/WFC3), evidence for a dayside thermal inversion on the '
     'most-irradiated hot Jupiter (host is a delta-Scuti A-star). Nugroho et al. 2021 (IRD/Subaru NIR) '
     'also weakly co-detect H2O alongside OH, consistent with thermal dissociation of H2O at this dayside.'),
    ('WASP-33 b', 'TiO', 'detected', 'HDS/Subaru', '2017AJ....154..221N', NULL,
     'Nugroho et al. 2017: TiO emission via high-dispersion spectroscopy (R = 165,000), strong direct '
     'evidence for a dayside stratosphere / thermal inversion (the inversion driver Haynes 2015 proposed). '
     'Contested: Serindag et al. 2021 (2021A&A...645A..90S) reassessed and found a weaker case; '
     'supported by Cont et al. 2021 (Fe + evidence for TiO) and Cont et al. 2022 (Ti + V emission).'),
    ('WASP-33 b', 'Fe', 'detected', 'HDS/Subaru', '2020ApJ...898L..31N', NULL,
     'Nugroho et al. 2020: atomic iron (Fe I) emission from the dayside. The first atomic-line detection '
     'in an exoplanet around a variable (delta-Scuti) host, possible because the planet''s Doppler shift '
     'exceeds 100 km/s relative to the rapidly-rotating star (v sin i ~86 km/s). Cont et al. 2021 '
     'independently detected Fe.'),
    ('WASP-33 b', 'OH', 'detected', 'IRD/Subaru', '2021ApJ...910L...9N', NULL,
     'Nugroho et al. 2021: hydroxyl radical (OH) emission in the near-infrared. THE FIRST OH DETECTION '
     'IN ANY EXOPLANET ATMOSPHERE; H2O co-detected weakly, consistent with thermal dissociation in this '
     'ultra-hot atmosphere. A follow-up resolved two OH vibrational bands matching thermal equilibrium. '
     'Independently confirmed by Cont et al. 2022 (CARMENES NIR, 4.4 sigma).'),
    ('WASP-33 b', 'Ti', 'detected', 'CARMENES+HARPS-N+ESPaDOnS', '2022A&A...668A..53C', 6.3,
     'Cont et al. 2022: atomic titanium (Ti I) emission detected via cross-correlation across four '
     'high-resolution spectrographs (CARMENES VIS+NIR, HARPS-N, ESPaDOnS); the headline of "Detection '
     'of Ti and V emission." Kp = 226 km/s matches the planetary signal.'),
    ('WASP-33 b', 'V', 'detected', 'CARMENES+HARPS-N+ESPaDOnS', '2022A&A...668A..53C', 4.8,
     'Cont et al. 2022: atomic vanadium (V I) emission detected at 4.8 sigma alongside Ti I in the '
     'dayside spectrum.'),
    ('WASP-33 b', 'Si', 'detected', 'CARMENES NIR', '2022A&A...668A..53C', 4.4,
     'Cont et al. 2022: atomic silicon (Si I) emission, 4.4 sigma in the CARMENES near-IR (9600-17100 A).'),
    ('WASP-33 b', 'Ti II', 'detected', 'HARPS-N', '2022A&A...668A..53C', 3.6,
     'Cont et al. 2022: singly-ionized titanium (Ti II) emission, 3.6 sigma in HARPS-N (3830-6900 A). '
     'V II, Fe II, and Si II all non-detections in the same data.'),
    ('WASP-79 b', 'H2O', 'detected', 'HST/WFC3+LDSS-3C+Spitzer', '2020AJ....159....5S', NULL,
     'Sotzen et al. 2020: water detected, log(H2O) constrained to -2.2 .. -1.55 (0.6-5 um). The retrieval '
     'also favors FeH and H- (the latter a continuum-opacity inference, not a line detection).'),
    ('WASP-79 b', 'FeH', 'tentative', 'HST/WFC3+LDSS-3C+Spitzer', '2020AJ....159....5S', NULL,
     'Sotzen et al. 2020: the atmospheric retrieval favors including iron hydride (FeH); not a clean '
     'stand-alone detection.'),
    ('HD 80606 b', 'CO', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..105S', NULL,
     'Steckloff et al. 2025: appears in the dayside emission spectrum as the planet flash-heats through '
     'periastron (e=0.93); the spectrum shifts from a featureless blackbody to one with CO/CH4/H2O features.'),
    ('HD 80606 b', 'CH4', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..105S', NULL,
     'Steckloff et al. 2025: methane absorption emerges across periastron ("seasonal" disequilibrium chemistry).'),
    ('HD 80606 b', 'H2O', 'detected', 'JWST/NIRSpec G395H', '2025AJ....170..105S', NULL,
     'Steckloff et al. 2025: water absorption emerges across periastron.'),
    ('HAT-P-7 b', 'H2O', 'detected', 'HST/WFC3+Spitzer', '2022ApJS..260....3C', NULL,
     'Changeat et al. 2022 (25-planet population study, HST+Spitzer free retrieval, "full" case): '
     'dayside H2O detected once Spitzer is included alongside HST; retrieved log mixing ratio -6.0 '
     '+1.0/-3.4 (poorly constrained). Terminator/transit spectrum is featureless (no transmission detections).'),
    ('HAT-P-7 b', 'CO2', 'detected', 'HST/WFC3+Spitzer', '2022ApJS..260....3C', NULL,
     'Changeat et al. 2022: dayside CO2 detected (Spitzer-enabled), retrieved log mixing ratio -2.5 '
     '+0.3/-1.1, the most cleanly constrained of the three dayside molecules.'),
    ('HAT-P-7 b', 'FeH', 'detected', 'HST/WFC3+Spitzer', '2022ApJS..260....3C', NULL,
     'Changeat et al. 2022: dayside FeH (iron hydride) detected (Spitzer-enabled), log mixing ratio '
     '-4.8 +0.5/-0.6. Dayside CH4 (log < -6.9), CO (log < -3.8), TiO (log < -6.7) and VO (log < -8.1) '
     'are all unconstrained / upper limits in the same retrieval.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HAT-P-7 b', 'dayside_temperature', 2667, 57, 57, 'K', 'Spitzer 2-band blackbody',
     '2016ApJ...823..122W',
     'Wong et al. 2016: dayside brightness temperature ~2667 K from 3.6/4.5 um Spitzer secondary '
     'eclipses, well described by a single blackbody (no clean molecular feature at these two bands).'),
    ('HAT-P-7 b', 'dayside_temperature', 2562, 253, 253, 'K',
     'HST+Spitzer retrieval, contribution-function-weighted',
     '2022ApJS..260....3C',
     'Changeat et al. 2022 (25-planet population eclipse study): dayside T = 2562 +/- 253 K, '
     'contribution-function-weighted from a full HST+Spitzer atmospheric retrieval. Dayside profile is INVERTED.'),
    ('HAT-P-7 b', 'metallicity', 0.5, 1.1, 1.1, 'dex',
     'HST+Spitzer free retrieval ("full")',
     '2022ApJS..260....3C',
     'Changeat et al. 2022: log(Z) = 0.5 +1.1/-1.1 dex (~3x solar with wide 1σ band), HST+Spitzer free '
     'retrieval. Loosely constrained.'),
    ('HAT-P-7 b', 'C/O', 0.5, 0.2, 0.2, 'ratio',
     'HST+Spitzer free retrieval ("full")',
     '2022ApJS..260....3C',
     'Changeat et al. 2022: C/O = 0.5 +/- 0.2 (HST+Spitzer free retrieval), near solar.'),
    ('WASP-33 b', 'metallicity', 1.49, 0.83, 0.76, 'dex',
     'high-res emission-line atmospheric retrieval (Ti I, V I, OH, Fe I, Si I, Ti II)',
     '2022A&A...668A..53C',
     'Cont et al. 2022: [M/H] = 1.49 +0.83/-0.76 dex (~31x solar), atmospheric retrieval combining all '
     'detected emission lines. Consistent across "close to eclipse" (1.46) and "far from eclipse" (1.23) '
     'sub-retrievals.'),
    ('WASP-33 b', 'dayside_temperature', 3424, 107, 111, 'K',
     'two-point P-T retrieval (lower-altitude anchor T2 at ~0.8 mbar)',
     '2022A&A...668A..53C',
     'Cont et al. 2022: T2 = 3424 +107/-111 K at log p ~ -3.1 bar (~0.8 mbar), the lower of the two '
     'retrieved P-T anchors. Upper anchor T1 = 3981 +213/-108 K at log p ~ -5.1 bar (~8 ubar), the hot '
     'inversion top where Fe/Ti absorb stellar UV.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
