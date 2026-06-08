-- Curated geometric / Bond albedos for famous exoplanets where the
-- measurement value is quoted directly in the source paper's abstract.
-- 9 planets, spanning the dynamic range from "darkest known" (TrES-2 b,
-- A_g ~ 0.025) to lava-world reflective (Kepler-10 b, Bond ~ 0.50).
-- Renderer reads these to modulate the planet body's reflected-light
-- brightness; HD 189733 b additionally tints reflected starlight blue
-- based on its wavelength-dependent albedo (high in the blue, suppressed
-- beyond ~450 nm by sodium absorption).
--
-- Unit: dimensionless (albedo is a 0-1 fraction). `model` records the
-- measurement methodology (instrument + bandpass). Upper-limit rows
-- (WASP-12 b) say "UPPER LIMIT" in the model field so consumers can tell
-- a non-detection from a measurement at a glance.
--
-- Coverage gaps (intentionally NOT included to keep every row properly
-- cited): HAT-P-7 b (Welsh 2010 doesn't quantify A_g; Esteves 2013/2015
-- only give a generic "< 0.3" bound, no per-planet number), 55 Cnc e
-- (Demory 2011 is the Spitzer transit detection, Demory 2016 is the
-- thermal map -- neither quantifies albedo in the abstract), WASP-18 b
-- (Nymeyer 2011 says "near-zero" qualitatively but quotes no number).
-- These can be added later if a paper with an abstract-quoted value is
-- identified.
--
-- Bibcodes verified against ADS abstracts before landing; every value
-- here is the number the paper's abstract reports. Provenance is
-- 'curated'. Idempotent via ON CONFLICT DO NOTHING on the
-- (pl_name, quantity, bibcode) primary key.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
VALUES

-- HD 189733 b -- Evans et al. 2013, ApJL 772, L16. HST/STIS visible
-- reflection spectroscopy. Wavelength-dependent: high in the blue, low
-- in the red. The famous "deep cobalt blue" visual color comes from
-- this asymmetry.
('HD 189733 b', 'geometric_albedo', 0.40, 0.12, 0.12, 'dimensionless',
 'HST/STIS visible reflection (290-450 nm)', '2013ApJ...772L..16E',
 'Evans et al. 2013 (ApJL 772, L16). Geometric albedo A_g = 0.40 +/- 0.12 '
 'across 290-450 nm; A_g < 0.12 across 450-570 nm at 1-sigma. The asymmetry '
 '(high blue, suppressed red) is attributed to optically thick reflective '
 'clouds plus sodium absorption beyond ~450 nm. Stored value is the blue '
 'band that drives the deep-blue visual color; the renderer tints reflected '
 'starlight blue for this planet specifically.',
 'curated'),

-- Kepler-7 b -- Demory et al. 2011, ApJL 735, L12. Highest-precision
-- exoplanet albedo at time of publication. Reflective clouds / haze.
('Kepler-7 b', 'geometric_albedo', 0.32, 0.03, 0.03, 'dimensionless',
 'Kepler bandpass occultation', '2011ApJ...735L..12D',
 'Demory et al. 2011 (ApJL 735, L12). Occultation depth 44 +/- 5 ppm in the '
 'Kepler bandpass yields geometric albedo A_g = 0.32 +/- 0.03 -- the most '
 'precise exoplanet albedo measurement at time of publication. High value '
 'attributed to reflective clouds / haze layer; alternative explanation is '
 'pure Rayleigh scattering with Na and K depleted 10-100x below solar.',
 'curated'),

-- HD 209458 b -- Rowe et al. 2008, ApJ 689, 1345. MOST satellite optical
-- photometry; consistent with zero. Rules out bright reflective clouds.
('HD 209458 b', 'geometric_albedo', 0.038, 0.045, 0.045, 'dimensionless',
 'MOST optical photometry (400-700 nm)', '2008ApJ...689.1345R',
 'Rowe et al. 2008 (ApJ 689, 1345). MOST satellite optical photometry '
 'spanning 14 + 44 days in 2004 + 2005. Flux ratio 7 +/- 9 ppm yields '
 'geometric albedo A_g = 0.038 +/- 0.045 in the MOST bandpass (400-700 nm); '
 '1-sigma upper limit 0.08, 3-sigma upper 0.17. Consistent with zero -- '
 'significantly less reflective than Jupiter (which would give A_g ~ 0.5); '
 'rules out bright reflective clouds.',
 'curated'),

-- TrES-2 b -- Kipping & Spiegel 2011, MNRAS 417, L88. The "darkest
-- exoplanet known" at time of publication. Even the scattering-only A_g
-- is tiny, and the true emission-corrected value is < 1%.
('TrES-2 b', 'geometric_albedo', 0.0253, 0.0072, 0.0072, 'dimensionless',
 'Kepler 0.4-0.9 um phase curve', '2011MNRAS.417L..88K',
 'Kipping & Spiegel 2011 (MNRAS 417, L88). Day-night contrast amplitude '
 '6.5 +/- 1.9 ppm in Kepler 0.4-0.9 um -- the lowest amplitude orbital '
 'phase variation discovered. Geometric albedo A_g = 0.0253 +/- 0.0072 in '
 'the scattering-only interpretation. Abstract notes a significant emission '
 'component to the dayside brightness; the true scattering albedo is even '
 'lower (<1%). The darkest exoplanet known at time of publication.',
 'curated'),

-- Kepler-10 b -- Rouan et al. 2011, ApJL 741, L30. Lava-ocean terrestrial
-- planet, first detection of a rocky exoplanet via its phase curve. Reports
-- Bond albedo (not geometric); the value is qualitative (~50%) so NULL unc.
('Kepler-10 b', 'bond_albedo', 0.50, NULL, NULL, 'dimensionless',
 'Lambertian lava-ocean model (Kepler phase curve)', '2011ApJ...741L..30R',
 'Rouan et al. 2011 (ApJL 741, L30). First detection of a terrestrial '
 'exoplanet via its phase curve. Lava-ocean model: no atmosphere, surface '
 'partially molten rock, isotropic Lambertian reflection. Abstract reports '
 'Bond albedo ~50% (qualitative tilde, no formal uncertainty quoted). '
 'Important caveat: there is a significant thermal-emission component in '
 'the Kepler band on top of the reflection. Reflected and emitted spectra '
 'are predicted to be distinguishable with JWST.',
 'curated'),

-- Kepler-13Ab -- Shporer et al. 2014, ApJ 788, 92. Hot Jupiter around an
-- A-type host (one of the hottest planets known). Relatively high optical
-- albedo for a hot Jupiter.
('Kepler-13Ab', 'geometric_albedo', 0.33, 0.04, 0.06, 'dimensionless',
 'Kepler bandpass occultation', '2014ApJ...788...92S',
 'Shporer et al. 2014 (ApJ 788, 92). Day-side hemisphere temperature '
 '2750 +/- 160 K. Geometric albedo A_g = 0.33 +0.04/-0.06 in the Kepler '
 'bandpass -- relatively high for a hot Jupiter. One-dimensional atmosphere '
 'models underestimate the optical occultation depth, independently '
 'supporting the high A_g. Stellar binary companion 1.15 arcsec away '
 'dilutes the photometric signal; revised planet mass M_p = 4.94-8.09 M_jup, '
 'radius R_p = 1.406 +/- 0.038 R_jup.',
 'curated'),

-- WASP-12 b -- Bell et al. 2017, ApJL 847, L2. HST/STIS optical eclipse;
-- stringent NONDETECTION. Rules out Mie-scattering aluminum-oxide haze
-- AND cloud-free Rayleigh scattering; consistent with thermal emission
-- plus weak Rayleigh scattering from atomic H/He. Famous comparison
-- case for HD 189733 b -- the only other hot Jupiter with optical
-- albedo spectra at the time -- showing the diversity of hot Jupiters.
('WASP-12 b', 'geometric_albedo', 0.064, NULL, NULL, 'dimensionless',
 'HST/STIS visible (290-570 nm) -- 97.5% UPPER LIMIT', '2017ApJ...847L...2B',
 'Bell et al. 2017 (ApJL 847, L2). HST/STIS optical eclipse. UPPER LIMIT: '
 'A_g < 0.064 (97.5% confidence) across 290-570 nm white-light bandpass. '
 'NOT a detection -- stored value is the 97.5% upper bound and the model '
 'column makes this explicit. Stringent nondetection rules out previously '
 'proposed Mie-scattering aluminum-oxide haze AND cloud-free Rayleigh '
 'scattering models; consistent with thermal emission plus weak Rayleigh '
 'scattering from atomic H/He. Uncertainties null because this is a bound, '
 'not a measurement.',
 'curated'),

-- WASP-43 b -- Stevenson et al. 2014, Science 346, 838. HST spectroscopic
-- thermal emission phase curve. Bond albedo with asymmetric uncertainty.
('WASP-43 b', 'bond_albedo', 0.18, 0.07, 0.12, 'dimensionless',
 'HST WFC3 thermal emission phase curve', '2014Sci...346..838S',
 'Stevenson et al. 2014 (Science 346, 838). HST spectroscopic thermal '
 'emission phase curve spanning three full planet rotations -- yielded a '
 'global atmospheric thermal-structure map showing large day-night '
 'temperature variations at all altitudes. Bond albedo A_B = 0.18 '
 '+0.07/-0.12. Also reports an altitude-dependent hot-spot offset relative '
 'to the substellar point.',
 'curated'),

-- WASP-19 b -- Wong et al. 2020, AJ 159, 104. TESS Sector 9 phase curve;
-- the first atmospheric retrieval of the planet's optical secondary
-- eclipse spectrum. Indicates significant reflected-light contribution.
('WASP-19 b', 'geometric_albedo', 0.16, 0.04, 0.04, 'dimensionless',
 'TESS bandpass phase curve + SCARLET retrieval', '2020AJ....159..104W',
 'Wong et al. 2020 (AJ 159, 104). TESS Sector 9 phase curve of WASP-19. '
 'Secondary eclipse depth 470 +130/-110 ppm with no significant offset '
 'between the substellar point and dayside peak. SCARLET-code atmospheric '
 'retrieval yields a dayside isothermal T = 2240 +/- 40 K AND visible '
 'geometric albedo A_g = 0.16 +/- 0.04 in the TESS bandpass -- significant '
 'reflected-starlight contribution. Moderately efficient day-night heat '
 'transport.',
 'curated')

ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
