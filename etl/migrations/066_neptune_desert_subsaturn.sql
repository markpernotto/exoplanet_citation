-- Atmosphere backlog batch 6: Neptune desert + low-density sub-Saturn
-- (manual literature review, 2026-05-26). Four planets pulled from
-- docs/atmosphere_deep_dive_candidates.md. Bibcodes verified via ADS / arXiv
-- + journal landing pages (Radica 2024 ApJL, Coulombe 2025 NatAs, Nortmann
-- 2025 A&A, Kanumalla 2024 AJ, Davenport 2025 ApJL, Schlawin 2024 AJ, Tyler
-- 2024 ApJ).
--
--   LTT 9779 b -- the only known hot Neptune to have retained a significant
--     H/He atmosphere in the "Neptune desert."
--     Radica et al. 2024 (JWST NIRISS 0.6-2.85 um transmission): the spectrum
--     has MUTED features, rejecting a perfectly flat line at >5 sigma but
--     degenerate between H2O- and CH4-dominated scenarios; clouds at mbar
--     pressures preferred; atmospheric metallicity 20-850x solar. No clean
--     per-molecule detection -> not recorded as planet_atmospheres rows.
--     Coulombe et al. 2025 Nature Astronomy (JWST NIRISS/SOSS full phase
--     curve): asymmetric reflected dayside; geometric albedo 0.79+/-0.15 on
--     the WESTERN limb vs 0.41+/-0.10 on the EASTERN limb; consistent with
--     Mg2SiO4 / MgSiO3 SILICATE CLOUDS condensing on the cooler western
--     hemisphere. Equatorial jet redistributes heat.
--   WASP-127 b -- inflated low-density warm sub-Saturn.
--     Kanumalla et al. 2024 (IGRINS high-res emission): H2O detected at
--     8.67 sigma (log10 mixing ratio -1.23 +0.29/-0.49), CO at 4.34 sigma
--     (log10 X >= -2.20 at 2 sigma); atmospheric [M/H] = 1.59 +/- 0.30 dex
--     (~39x solar, super-solar); C/O < 0.68 (upper limit). Tentative H2S
--     depletion (photochemistry).
--     Nortmann et al. 2025 (CRIRES+ transmission): resolved a SUPERSONIC
--     EQUATORIAL JET at 7.7 +/- 0.2 km/s with cooler poles; morning-evening
--     terminator T difference -175 +133/-117 K; H2O + CO both detected via
--     double-peaked cross-correlation. Solar metallicity & C/O per their
--     retrieval (in tension with Kanumalla's super-solar; noted).
--   TOI-421 b -- hot sub-Neptune around a Sun-like star, distinct from the
--     M-dwarf sub-Neptunes JWST has dominated.
--     Davenport et al. 2025 (JWST NIRISS/SOSS + NIRSpec/G395M, 0.83-5 um
--     transmission): clear H2O features indicate a LOW MEAN MOLECULAR WEIGHT
--     atmosphere consistent with solar metallicity; HAZE-FREE (no appreciable
--     aerosol coverage); tentative SO2 and CO in NIRSpec/G395M (low S/N);
--     CO2 and CH4 NOT detected. Headline framing: sub-Neptunes hotter than
--     ~850 K (Teq ~920 K here) lack methane to photolyze, so no hydrocarbon
--     hazes form -> haze-free.
--   WASP-69 b -- inflated hot Saturn with a famous comet-like helium tail.
--     Schlawin et al. 2024 (JWST NIRCam + MIRI/LRS panchromatic 2-12 um
--     EMISSION): H2O, CO2, and CO detected via absorption features; CH4 NOT
--     detected (no strong evidence despite equilibrium predictions); dayside
--     brightness T ~1050 K (2.1-4 um) to ~950 K (>5 um) -> dayside T
--     GRADIENT; aerosols needed to fit the spectrum (silicate considered);
--     atmospheric metallicity 6-14x solar; C/O 0.65-0.94; geometric albedo
--     0.64 if the strong scattering solution holds.
--     Tyler et al. 2024 (Keck/NIRSPEC He I 10830 transit): the escaping HE
--     ENVELOPE is confined to a TAIL extending >= 7.5 planet radii behind the
--     planet (5.8e5 km), blue-shifted -23 km/s in the planet rest frame;
--     mass loss rate ~1 Mearth / Gyr; strongly sculpted by the stellar wind.
--     Independent of (and post-dating) Nortmann 2018's discovery He
--     detection; cited as the tail-extension follow-up.
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql.
-- Idempotent (ON CONFLICT DO UPDATE).

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('LTT 9779 b', 'silicate', 'detected', 'JWST/NIRISS-SOSS', '2025NatAs...9..512C', NULL,
     'Coulombe et al. 2025 Nature Astronomy (JWST NIRISS/SOSS phase curve, 0.6-2.8 um): inferred '
     'Mg2SiO4 and/or MgSiO3 silicate clouds, primarily on the cooler western hemisphere of the dayside, '
     'driving the asymmetric reflected-light geometric albedo (W=0.79+/-0.15 vs E=0.41+/-0.10, dayside-'
     'average 0.50+/-0.07; asymmetry significant at 3.1 sigma per the paper). Cloud-species preference '
     'is from a qualitative VIRGA/PICASO forward-model comparison (only silicate clouds reproduce the '
     'high albedo); the paper does NOT quote a Bayes factor or detection sigma for the cloud species '
     'itself, so confidence_sigma remains NULL by honest design.'),

    ('WASP-127 b', 'H2O', 'detected', 'IGRINS (Gemini-S) + CRIRES+ (VLT)', '2024AJ....168..201K', 8.67,
     'Kanumalla et al. 2024 (IGRINS R~45000 high-resolution emission): H2O detected at 8.67 sigma, '
     'log10 mixing ratio -1.23 +0.29/-0.49. Confirmed independently by Nortmann et al. 2025 (CRIRES+ '
     'transmission) via double-peaked cross-correlation, which also resolved the morning/evening '
     'terminator asymmetry. Earlier SPIRou recovery (Boucher 2023) and HST/STIS feature-rich spectrum '
     '(Skaf 2020) cited in note as part of the lineage.'),

    ('WASP-127 b', 'CO', 'detected', 'IGRINS (Gemini-S) + CRIRES+ (VLT)', '2024AJ....168..201K', 4.34,
     'Kanumalla et al. 2024 (IGRINS): CO detected at 4.34 sigma, log10 X >= -2.20 at 2 sigma. '
     'Nortmann et al. 2025 (CRIRES+) independently detects CO via cross-correlation. Together with '
     'H2O and the super-solar metallicity, CO is the second pillar of the carbon-bearing inventory.'),

    ('TOI-421 b', 'H2O', 'detected', 'JWST/NIRISS-SOSS', '2025ApJ...984L..44D', 4.51,
     'Davenport et al. 2025 Table 1 (baseline Aurora retrieval on exoTEDRF + Eureka! reduction): '
     'H2O detected at 4.51 sigma (paper notes a typical +/-0.1 sigma uncertainty across analyses; '
     'robust >3 sigma across all reductions). Drives the LOW MEAN MOLECULAR WEIGHT (H/He-dominated) '
     'retrieval consistent with solar metallicity.'),

    ('TOI-421 b', 'SO2', 'tentative', 'JWST/NIRSpec G395M', '2025ApJ...984L..44D', 1.66,
     'Davenport et al. 2025 Table 1 (baseline retrieval, NIRSpec G395M 2.8-5.0 um): SO2 at 1.66 sigma '
     '(marginal); rises to 2.35 sigma under the Fu+Deming reduction. The paper explicitly notes '
     '"existing observations are not sufficient to definitively constrain" SO2 or CO.'),

    ('TOI-421 b', 'CO', 'tentative', 'JWST/NIRSpec G395M', '2025ApJ...984L..44D', 1.28,
     'Davenport et al. 2025 Table 1 (baseline retrieval): CO at 1.28 sigma (marginal); rises to '
     '3.10 sigma under the Fu+Deming reduction. Same authorial caveat as SO2 about not being '
     'definitive.'),

    ('TOI-421 b', 'CO2', 'ruled_out', 'JWST/NIRSpec G395M', '2025ApJ...984L..44D', NULL,
     'Davenport et al. 2025: CO2 NOT included in the detection-significance Table 1 (only H2O, SO2, '
     'and CO have stated sigmas there) -> non-detection over the NIRSpec G395M coverage that '
     'includes the 4.3 um CO2 fundamental. Per-molecule non-detection sigma not quoted by the paper, '
     'so confidence_sigma NULL by honest design.'),

    ('TOI-421 b', 'CH4', 'ruled_out', 'JWST/NIRSpec G395M', '2025ApJ...984L..44D', NULL,
     'Davenport et al. 2025: CH4 not included in the detection-significance Table 1 (only H2O, SO2, '
     'and CO have stated sigmas). The non-detection is the headline result for this planet: sub-'
     'Neptunes hotter than ~850 K (TOI-421 b Teq ~920 K) lack methane to photolyze, so they do not '
     'form hydrocarbon hazes -> haze-free, distinct from cooler M-dwarf sub-Neptunes JWST has '
     'observed. No quantitative upper-limit sigma quoted.'),

    ('WASP-69 b', 'H2O', 'detected', 'JWST/NIRCam + MIRI/LRS', '2024AJ....168..104S', NULL,
     'Schlawin et al. 2024 (JWST panchromatic 2-12 um emission spectrum): H2O identified via clear '
     'absorption features at 2.8 um and 6.7-8.0 um. Confirmed by retrieval, but the paper presents '
     'retrieval results in figures (Figures 6-7) rather than per-molecule sigma tables -> no quotable '
     'detection sigma in the published form. confidence_sigma NULL by honest design (we checked the '
     'paper).'),

    ('WASP-69 b', 'CO2', 'detected', 'JWST/NIRCam + MIRI/LRS', '2024AJ....168..104S', NULL,
     'Schlawin et al. 2024: deep CO2 absorption visible at 4.3 um (the CO2 fundamental). Drives the '
     '6-14x solar metallicity retrieval. Same NULL-sigma caveat as H2O above (retrieval shown in '
     'figures, not sigma tables).'),

    ('WASP-69 b', 'CO', 'detected', 'JWST/NIRCam + MIRI/LRS', '2024AJ....168..104S', NULL,
     'Schlawin et al. 2024: excess absorption due to CO near 4.7 um, at the red edge of the CO2 '
     'feature. With H2O + CO2 + CO the carbon-bearing inventory is fully populated. Same NULL-sigma '
     'caveat.'),

    ('WASP-69 b', 'CH4', 'ruled_out', 'JWST/NIRCam + MIRI/LRS', '2024AJ....168..104S', NULL,
     'Schlawin et al. 2024: "no obvious CH4 feature at 3.3 um" and "our data do not show any strong '
     'CH4 features near 3.3 um nor 7.7 um" despite equilibrium predictions for this ~960 K Teq '
     'atmosphere -> direct evidence of disequilibrium chemistry, paralleling WASP-43 b (Bell 2024). '
     'No quantitative upper-limit sigma quoted.'),

    ('WASP-69 b', 'silicate', 'detected', 'JWST/NIRCam + MIRI/LRS', '2024AJ....168..104S', NULL,
     'Schlawin et al. 2024: aerosols required to fit the spectrum across all retrieval families '
     'tested; silicate (high-altitude) aerosols are the favoured candidate. The model that invokes '
     'strong scattering also requires an unexpectedly high geometric albedo 0.64. No detection-sigma '
     'quoted (model preference, not line detection).'),

    ('WASP-69 b', 'He', 'detected', 'Keck/NIRSPEC', '2024ApJ...960..123T', 6.8,
     'Tyler et al. 2024 (Keck/NIRSPEC He I 10830 transit): in-transit absorption depth 2.7% +/- 0.4% '
     '-> ~6.8 sigma (depth/uncertainty); peak equivalent width 40.7 +/- 6.8 mAA, mean in-transit EW '
     '27.8 +/- 2.5 mAA, SNR ~55 per reduced pixel. The escaping helium envelope is confined to a '
     'comet-like TAIL extending >= 7.5 planet radii (5.8e5 km) behind the planet, blue-shifted '
     '-23 km/s in the planet rest frame; outflow strongly sculpted by the stellar wind. Discovery '
     'He cite is Nortmann et al. 2018; Tyler 2024 is the tail-extension follow-up.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('LTT 9779 b', 'metallicity', 130, 720, 110, 'x_solar',
     'JWST NIRISS/SOSS transmission, 1D atmospheric retrieval',
     '2024ApJ...962L..20R',
     'Radica et al. 2024: atmospheric metallicity 20-850x solar (broad 1-sigma range from a free '
     'retrieval on the muted-feature spectrum; H2O- and CH4-dominated scenarios both viable). '
     'Value 130 is the geometric midpoint of the log range; unc_hi/unc_lo span the FULL constraint, '
     'not a Gaussian sigma. The honest reading is "super-solar, poorly constrained."'),

    ('LTT 9779 b', 'geometric_albedo', 0.79, 0.15, 0.15, 'dimensionless',
     'JWST NIRISS/SOSS phase curve (western dayside limb)',
     '2025NatAs...9..512C',
     'Coulombe et al. 2025 Nature Astronomy: dayside reflected-light geometric albedo is ASYMMETRIC: '
     '0.79 +/- 0.15 on the western limb (recorded value), 0.41 +/- 0.10 on the eastern limb. The '
     'asymmetry tracks Mg2SiO4 / MgSiO3 silicate clouds that condense on the cooler western '
     'hemisphere; equatorial jet redistributes heat eastward.'),

    ('WASP-127 b', 'metallicity', 1.59, 0.30, 0.30, 'dex',
     'IGRINS high-resolution emission, free retrieval',
     '2024AJ....168..201K',
     'Kanumalla et al. 2024: [M/H] = 1.59 +/- 0.30 dex (~39x solar). Driven by the 8.67-sigma H2O '
     'and 4.34-sigma CO detections. NB Nortmann et al. 2025 (CRIRES+ transmission retrieval) prefers '
     'solar metallicity instead -> instrument/methodology tension worth flagging; we record IGRINS '
     'as the higher-S/N constraint and note the disagreement here.'),

    ('WASP-127 b', 'C/O', 0.68, 0.0, 0.68, 'ratio',
     'IGRINS high-resolution emission retrieval, upper limit',
     '2024AJ....168..201K',
     'Kanumalla et al. 2024: C/O < 0.68 (upper limit). Value 0.68 stored with unc_hi = 0 and unc_lo '
     'spanning the allowed range to encode "<= 0.68" honestly; the constraint is an upper bound, not '
     'a measurement.'),

    ('WASP-127 b', 'equatorial_jet_velocity', 7.7, 0.2, 0.2, 'km_s',
     'CRIRES+ high-resolution transmission, 3D cross-correlation',
     '2025A&A...693A.213N',
     'Nortmann et al. 2025: resolved a SUPERSONIC equatorial jet at 7.7 +/- 0.2 km/s from the double-'
     'peaked H2O/CO cross-correlation signature, the first such resolved jet in a hot exoplanet. '
     'New quantity (similar pattern to existing terminator_wind_velocity).'),

    ('WASP-127 b', 'morning_evening_temperature_diff', -175, 133, 117, 'K',
     'CRIRES+ high-resolution transmission, terminator-resolved retrieval',
     '2025A&A...693A.213N',
     'Nortmann et al. 2025: morning-evening terminator temperature difference -175 +133/-117 K, with '
     'the morning terminator cooler. Direct evidence of the 3D thermal structure. New quantity.'),

    ('WASP-69 b', 'metallicity', 10, 4, 4, 'x_solar',
     'JWST NIRCam + MIRI panchromatic emission retrieval',
     '2024AJ....168..104S',
     'Schlawin et al. 2024: atmospheric metallicity 6-14x solar (1-sigma range; value 10x is the '
     'midpoint, uncertainties span the range). Super-solar but moderate, consistent with a moderately '
     'enriched warm-Saturn atmosphere.'),

    ('WASP-69 b', 'C/O', 0.80, 0.14, 0.15, 'ratio',
     'JWST NIRCam + MIRI panchromatic emission retrieval',
     '2024AJ....168..104S',
     'Schlawin et al. 2024: C/O 0.65-0.94 1-sigma range (value 0.80 is the midpoint). High but not '
     'extreme; consistent with formation outside the H2O snowline.'),

    ('WASP-69 b', 'geometric_albedo', 0.64, NULL, NULL, 'dimensionless',
     'JWST NIRCam + MIRI panchromatic emission, scattering-model retrieval',
     '2024AJ....168..104S',
     'Schlawin et al. 2024: unexpectedly high geometric albedo of 0.64 if the strong-scattering model '
     'is correct (one of several aerosol models tested). Recorded with NULL uncertainties because the '
     'value is model-dependent; see curator_note. Aerosols (likely silicates) are required to fit '
     'the spectrum in any case.'),

    ('WASP-69 b', 'dayside_temperature', 1000, 50, 50, 'K',
     'JWST NIRCam + MIRI dayside brightness temperature',
     '2024AJ....168..104S',
     'Schlawin et al. 2024: dayside brightness temperature spans ~1050 K (2.1-4 um) to ~950 K '
     '(>5 um) -> dayside T gradient; value 1000 K is the midpoint, +/- 50 K spans the range. '
     'Catalog Teq is 963 K (zero-albedo) for reference.'),

    ('WASP-69 b', 'mass_loss_rate', 1, NULL, NULL, 'M_earth_per_Gyr',
     'Keck/NIRSPEC He I 10830 transit, EVE outflow model',
     '2024ApJ...960..123T',
     'Tyler et al. 2024: mass loss rate ~1 Mearth / Gyr (~2e5 t/s) inferred from the helium escape '
     'signal. Value recorded without explicit uncertainty (paper quotes an order-of-magnitude '
     'estimate). Same units as Kepler-1520 b for cross-comparison.'),

    ('WASP-69 b', 'helium_tail_length', 7.5, NULL, NULL, 'planet_radii',
     'Keck/NIRSPEC He I 10830 spatially-resolved absorption',
     '2024ApJ...960..123T',
     'Tyler et al. 2024: the escaping helium envelope is confined to a comet-like TAIL extending '
     '>= 7.5 planet radii (5.8e5 km, 350 000 miles) behind the planet, blue-shifted -23 km/s in the '
     'planet rest frame. New quantity; value is a LOWER LIMIT (>= 7.5 R_p), so unc fields NULL and '
     'the note records the bound.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
