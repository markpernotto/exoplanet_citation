-- WDS curation Batch 8 (2026-06-23). Eighth pass against the WDS gap
-- list. Six Kepler/KOI hosts characterized in five primary papers:
--
--   KOI-13 (= Kepler-13)  -- Howell et al. 2011 (2011AJ....142...19H)
--                            DSSI speckle at WIYN: A+A visual pair at
--                            rho = 1.163" / PA = 279.7 deg, Dm_692 ~
--                            1.0 mag. Adams et al. 2012 (2012AJ....144
--                            ...42A) PHARO cross-check at rho = 1.12"
--                            / PA = 99.4 deg (the PA is 180 deg flipped
--                            from Howell, a reference-convention mis-
--                            match; we adopt Howell's PA convention).
--                            REPLACES an earlier SIMBAD-bulk-ingest B
--                            row that had source_bibcode = NULL.
--
--   Kepler-14 (= KOI-98)  -- Buchhave et al. 2011 (2011ApJS..197....3B,
--                            discovery paper) speckle + AO at WIYN +
--                            Palomar + MMT: F+F nearly-equal pair at
--                            rho = 0.286-0.289" / PA = 143.67 deg
--                            stable across V/R/I bands. DV = 0.52 mag.
--                            Cross-confirmed by Howell 2011 (DSSI) and
--                            Adams 2012 (PHARO).
--
--   Kepler-132 (= KOI-284) -- Adams et al. 2012 (2012AJ....144...42A)
--                            PHARO imaging: rho = 0.84" / PA = 96.7
--                            deg / DJ = DK = 0.3 mag. Lissauer et al.
--                            2014 (2014ApJ...784...44L) confirms
--                            twins are gravitationally bound via DRV
--                            = 0.94 +/- 0.10 km/s and validates the
--                            multi-planet system across both stellar
--                            components. Planets split between primary
--                            and secondary.
--
--   Kepler-296 (= KOI-1422) -- Cartier et al. 2015 (2015ApJ...804...97C)
--                            HST/WFC3 F555W + F775W resolving: M0V +
--                            M3V pair at rho = 0.217" (80 AU at d =
--                            358 pc), M = 0.626 + 0.453 Msun, Teff =
--                            3821 + 3434 K, coeval (5 Gyr, [Fe/H] =
--                            +0.3). All 5 planets orbit primary A. PA
--                            not measured in Cartier 2015.
--
--   Kepler-693 (= KOI-3680) -- Masuda 2017 (2017AJ....154...64M) TTV +
--                            TDV dynamical detection: m_c = 145
--                            (+58, -37) MJup (= 0.139 Msun, very late
--                            M / H-burning limit), a = 2.8 AU, e =
--                            0.47, P = 1800 d, mutual inclination 53
--                            or 134 deg (TTV degeneracy). Companion
--                            likely drives planet b''s eccentricity
--                            via Kozai-Lidov. NOT direct-imaged.
--
--   KOI-1257 (= Kepler-420) -- Santerne et al. 2014 (2014A&A...571A..37S)
--                            joint SOPHIE RV + HARPS-N + Kepler light
--                            curve + line bisector + FWHM + SED modeling
--                            via PASTIS Bayesian: G5V + K6V/K7V pair,
--                            M = 0.99 + 0.70 Msun, T_eff = 5520 + 4270
--                            K. Orbital fit (Scenario 1, P out = 3430
--                            d / a out = 5.3 AU / e_out = 0.31 / i_out
--                            = 18 deg). NOT direct-imaged. Future
--                            observations needed for confirmation per
--                            Santerne 2014 abstract.
--
-- Apply after 111_wds_batch7.sql. Idempotent.


-- ============================================================================
-- KOI-13 (= Kepler-13)  --  REPLACE earlier NULL-bibcode row with Howell 2011
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('KOI-13', 'B', 'A', 'A', 1.163,
     600, 1.5, false, NULL, false,
     'A-star close visual binary partner (DSSI speckle, multi-band stable)', 'manual', '2011AJ....142...19H',
     'KOI-13 B: A-type stellar companion to the A-type planet host KOI-13 A. Howell et al. 2011 ("Speckle '
     'Camera Observations for the Kepler Mission Follow-up Program") DSSI speckle at WIYN across two epochs '
     '(2010-06-19 and 2010-06-22) in 562 nm and 692 nm: rho = 1.163 +/- 0.002 arcsec (562 nm avg) and '
     '1.164 +/- 0.003 arcsec (692 nm avg), PA = 279.76 +/- 0.02 deg (562 nm) and 279.60 +/- 0.08 deg (692 '
     'nm), DM = 0.85 (562 nm) and 1.03 (692 nm) -- positionally and photometrically stable across both '
     'wavelengths confirming a real visual binary. Cross-confirmed by Adams et al. 2012 (2012AJ....144...42A) '
     'PHARO at Palomar 5m: rho = 1.12 arcsec / PA = 99.4 deg / DJ = -0.0 mag. The Adams PA is 180 deg from '
     'Howell''s -- a reference-orientation convention difference, NOT inconsistent astrometry; we adopt '
     'Howell''s 279.7 deg convention. Mass 1.5 Msun is an estimate for a late-A dwarf; spectype recorded as '
     'generic "A" since neither Howell nor Adams subclass the secondary. Projected separation ~600 AU at d '
     '~516 pc (Hipparcos for KOI-13 = Kepler-13). This row REPLACES an earlier SIMBAD-bulk-ingest B row that '
     'had source_bibcode = NULL.',
     279.7)
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes,
    position_angle_deg    = EXCLUDED.position_angle_deg;


-- ============================================================================
-- Kepler-14 B  (Buchhave 2011 discovery + Howell 2011 + Adams 2012)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('Kepler-14', 'B', 'A', 'F', 0.289,
     283, 0.95, false, NULL, false,
     'F-type nearly-equal-mag visual binary partner (discovery paper + 2 independent imaging cross-checks)', 'manual', '2011ApJSS.197....3B',
     'Kepler-14 B: F-type dwarf companion to the F-type planet host A. Buchhave et al. 2011 (the planet '
     'discovery paper, 2011ApJSS.197....3B) WIYN speckle + Palomar AO + MMT AO at three bands (V/R/I): rho '
     '= 0.286-0.289 +/- 0.01-0.04 arcsec, PA = 143.67-143.91 +/- 0.05-0.07 deg, DV = 0.52 +/- 0.05 mag, DR '
     '= 0.54 +/- 0.12 mag, DI = 0.45 +/- 0.04 mag against the F6V primary. Three-band agreement on rho and '
     'PA + nearly-equal-magnitude confirms a near-twin F+F pair, both ~F type. Companion mass ~0.9-1.0 Msun '
     'inferred from photometric similarity to the 1.512 Msun primary at coeval 5-7 Gyr age (Buchhave 2011 '
     'does not derive an explicit companion mass; recorded 0.95 Msun as a midpoint estimate). Independent '
     'cross-checks at consistent geometry: Howell et al. 2011 (2011AJ....142...19H) DSSI at WIYN across 6 '
     'epochs in 562/692/880 nm; Adams et al. 2012 (2012AJ....144...42A) PHARO at Palomar 5m. Furlan et al. '
     '2017 (2017AJ....153...71F) catalogs this system observed by 7 facilities including DCT, Gemini, '
     'Keck, MMT, Palomar 1.5m/5m, and WIYN. Projected separation 283 AU at d = 980 pc (Kepler Input '
     'Catalog). The dilution correction from this companion increased Buchhave 2011''s derived planet '
     'mass by 60 percent and planet radius by 10 percent.',
     143.67);


-- ============================================================================
-- Kepler-132 B  (Adams 2012 geometry + Lissauer 2014 bound + multi-planet)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('Kepler-132', 'B', 'A', 'G', 0.84,
     168, 1.0, false, NULL, false,
     'twin-mass visual binary partner (Adams 2012 imaging + Lissauer 2014 spectroscopic bound confirmation)', 'manual', '2012AJ....144...42A',
     'Kepler-132 B (KOI-284): nearly-equal-magnitude twin to the planet host A. Adams et al. 2012 PHARO '
     'imaging at Palomar 5m: rho = 0.84 +/- 0.04 arcsec, PA = 96.7-96.8 +/- 0.2 deg, DJ = 0.3 mag, DK = 0.3 '
     'mag -- a near-twin pair where the two components share spectral type and brightness within 0.3 mag in '
     'both J and K bands. Bound-binary confirmation from Lissauer et al. 2014 (2014ApJ...784...44L, "Validation '
     'of Kepler Multi-Transiting Planet Systems. II"): speckle resolves two near-equal stars at ~1 arcsec '
     'with nearly identical spectra and Delta-RV = 0.94 +/- 0.10 km/s, consistent with gravitational binding. '
     'Lissauer 2014 also validates the three transiting planets in this system (KOI-284.01 / .02 / .03) by '
     'splitting them between the two stellar components -- planets b and c cannot share a host (dynamical '
     'instability) so are inferred to orbit the two different stars. Mass ~1.0 Msun for B inferred from '
     'photometric similarity to the G-type primary; Adams 2012 / Lissauer 2014 do not derive an explicit '
     'companion mass. Projected separation ~168 AU at d ~200 pc (estimated from the host''s Kp = 11.82 mag '
     'and G-type SED; Lissauer 2014 does not quote a precise distance).',
     96.7);


-- ============================================================================
-- Kepler-296 B  (Cartier 2015 HST imaging)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Kepler-296', 'B', 'A', 'M3V', 0.217,
     80, 0.453, false, 3434, false,
     'M3V companion in M0V+M3V pair (HST/WFC3 F555W+F775W resolving)', 'manual', '2015ApJ...804...97C',
     'Kepler-296 B (KOI-1422): M3V dwarf in the bound M0V + M3V visual pair. Cartier et al. 2015 ("Revision '
     'of Earth-like Kepler Planets Orbiting M Dwarfs") HST WFC3 imaging in F555W and F775W bands resolves '
     'the system at rho = 0.217 arcsec (80 AU projected at d = 358 +/- 6 pc). Stellar parameters derived '
     'from Victoria-Regina stellar models fit to multi-band WFC3 photometry (Cartier Table 4): M = 0.453 '
     '+/- 0.082 Msun, T_eff = 3434 +/- 156 K, R = 0.429 +/- 0.072 Rsun. Primary HD parameters from same '
     'fit: A = M0V, M = 0.626 +/- 0.082 Msun, T_eff = 3821 +/- 160 K. Coeval at ~5 Gyr, [Fe/H] = +0.3, '
     'E(B-V) = 0.00 per Cartier''s isochrone fit (chi^2_min = 0.218). Photometric F775W differential '
     'across primary-secondary: DF775W = 1.356 mag (DKp ~ 1.57 mag for Kepler band). All 5 known planets '
     '(c, d, b, f, e) orbit the primary A; Cartier 2015 re-evaluates habitable-zone candidacy after '
     'accounting for dilution from B. PA NOT measured by Cartier 2015 (HST imaging gives rho but Table 2 '
     'does not tabulate angular orientation). Furlan et al. 2017 (2017AJ....153...71F) catalog confirms '
     'HST + Cartier as the primary characterization references.');


-- ============================================================================
-- Kepler-693 B  (Masuda 2017 dynamical TTV+TDV inference)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     orbital_period_d, eccentricity, inclination_deg)
VALUES
    ('Kepler-693', 'B', 'A', 'M', NULL,
     2.8, 0.139, false, NULL, false,
     'very-late M-dwarf (or stellar/BD-boundary object) from TTV + TDV dynamical inference, not direct-imaged', 'manual', '2017AJ....154...64M',
     'Kepler-693 B: very-late M-dwarf / H-burning-boundary object characterized DYNAMICALLY (not directly '
     'imaged) by Masuda 2017 from MCMC modeling of Kepler-693b''s transit timing and duration variations '
     '(TTVs + TDVs). Mass M_B = 145 (+58, -37) MJup combined-solution median (Masuda Table 6) = 0.139 '
     'Msun -- right at the canonical 0.075 Msun H-burning limit, but the high end of the uncertainty (0.20 '
     'Msun) puts it firmly in the stellar M-dwarf range. Orbit: a = 2.8 (+0.8, -0.4) AU, e = 0.47 (+0.11, '
     '-0.06), P = 1800 (+800, -300) d (~5 yr), periastron distance = 1.5 +/- 0.2 AU. MUTUAL INCLINATION '
     'between inner planet and outer B: i21 = 53 (+7, -9) deg OR 134 (+11, -10) deg (Masuda finds two '
     'statistically indistinguishable solutions with this degeneracy). At this large mutual inclination '
     'the companion likely drives secular eccentricity oscillations in the planet b''s orbit via Kozai-'
     'Lidov, possibly inducing tidal migration toward a hot Jupiter. NOT direct-imaged -- at d ~470 pc '
     'the 2.8 AU SMA gives rho ~0.006 arcsec, well below AO/speckle resolution; future astrometric '
     'detection via Gaia is possible. Mass is the TRUE dynamical mass from N-body fitting (not m sin i '
     'from RV).',
     1800, 0.47, 53);


-- ============================================================================
-- KOI-1257 B  (Santerne 2014 spectroscopic + SED Bayesian inference)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     orbital_period_d, eccentricity, inclination_deg)
VALUES
    ('KOI-1257', 'B', 'A', 'K6V/K7V', NULL,
     5.3, 0.70, false, 4270, false,
     'K6V/K7V spectroscopically + SED-inferred companion (NOT direct-imaged; awaits confirmation)', 'manual', '2014A&A...571A..37S',
     'KOI-1257 B (= Kepler-420 B): K6V/K7V dwarf spectroscopically + photometrically inferred (NOT directly '
     'imaged) by Santerne et al. 2014 via joint Bayesian modeling (PASTIS framework) of the Kepler transit '
     'light curve + SOPHIE RVs + HARPS-N spectra + line bisector + FWHM + spectral energy distribution. '
     'Scenario 1 (the most likely architecture per Santerne''s posterior odds ratio analysis, Table 5: '
     'P(S1) = 98.7%): M = 0.70 +/- 0.07 Msun, T_eff = 4270 +/- 290 K, R = 0.68 +/- 0.07 Rsun, log g = 4.62 '
     '+/- 0.05. Orbit (Santerne Table 6 / Scenario 1): semi-major axis a = 5.3 +/- 1.3 AU, eccentricity '
     'e = 0.31 (+0.37, -0.21), period P = 3430 +/- 1200 d (~9 yr), inclination i = 18.2 (+18, -5.4) deg '
     '(close to face-on), argument of periastron 180 +/- 110 deg. NOT direct-imaged -- at d = 900 +/- 110 '
     'pc the 5.3 AU SMA gives rho ~0.006 arcsec, well below any current AO/speckle resolution. The planet '
     'KOI-1257 b is a transiting warm Jupiter at 86.65 d period, e = 0.772, on the primary A (G5V, 0.99 '
     'Msun). Santerne 2014 explicitly notes: "future observations are needed to confirm" this binary '
     'architecture. Recorded as a spectroscopically inferred row; promote to imaging-confirmed when direct '
     'detection arrives.',
     3430, 0.31, 18.2);
