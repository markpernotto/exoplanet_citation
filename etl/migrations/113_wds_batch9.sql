-- WDS curation Batch 9 (2026-06-24). Final pass against the WDS gap
-- list. Nine binary_companions rows, one sy_snum_audit row, and one
-- UPDATE to the existing psi1 Dra A row to acknowledge the newly
-- curated inner C subsystem.
--
-- Systems and citations:
--
--   HR 5183 B    -- Mugrauer & Ginski 2019 (2019MNRAS.490.5088M)
--                  Gaia DR2 wide CPM detection; BD+07 2692 secondary
--                  at large angular separation. Mass refined by Mustill
--                  et al. 2022 (2022MNRAS.509.3616M) Table 1, citing
--                  the joint orbit fit of Blunt et al. 2019
--                  (2019AJ....158..181B): M_B = 0.67 +/- 0.05 Msun ->
--                  late-K dwarf (~K7V). Projected separation ~15000 AU
--                  at d ~ 31.6 pc, drawn from Mugrauer 2019 supplement
--                  (the supplement was not text-accessible during
--                  curation, so the AU and arcsec values carry larger
--                  uncertainty than other Batch 9 rows). The discovery-
--                  paper context is Blunt 2019 RV finding of the
--                  eccentric jovian HR 5183 b.
--
--   KELT-19 A B  -- Siverd et al. 2018 (2018AJ....155...35S). G9V-K1V
--                  visual companion at rho ~ 0.63", projected separation
--                  ~160 AU at d ~ 255 pc. Mass ~0.87 Msun. CPM-confirmed
--                  via systemic RV match; flux ratios F_B/F_A reported
--                  in their Table 4. The primary is an Am star, and
--                  the discovery paper notes the secondary as a
--                  possible Kozai-Lidov agent for the close-in planet.
--
--   HATS-37 A B  -- Jordan et al. 2020 (2020AJ....160..222J) Table 5
--                  "Binary Star Companion HATS-37B" block. UNRESOLVED
--                  stellar companion inferred from the joint
--                  photometric+RV blend modelling; supported by RV
--                  linear trend gamma-dot = 0.4539 m/s/d. Mass 0.654
--                  +/- 0.033 Msun, Teff 4210 +/- 170 K -> K7V. No
--                  resolved imaging exists; Gaia DR2 sees the system
--                  as a single source. separation_arcsec and
--                  separation_au are NULL (unresolved). Distance
--                  211.1 +/- 2.5 pc.
--
--   HATS-55 B    -- Espinoza et al. 2019 (2019AJ....158...63E)
--                  Discussion section. Gaia DR2 wide CPM detection at
--                  rho = 3.80336" +/- 0.00038. Projected separation
--                  2361 +/- 23 AU at d = 623.6 +/- 6.2 pc. The paper
--                  does not derive a mass for the secondary (no SED
--                  fit reported). NASA EA carries sy_snum=1 for
--                  HATS-55; this row is value-added enrichment from
--                  primary literature.
--
--   HATS-56 B    -- Espinoza et al. 2019 (2019AJ....158...63E) Section
--                  3.3 + Discussion. Gaia DR2 detection at rho =
--                  1.59879" +/- 0.00029. Mass 0.8058 +/- 0.0076 Msun,
--                  implying late-K dwarf. Projected separation 922
--                  +/- 15 AU at d = 577.1 +/- 9.6 pc. NASA EA carries
--                  sy_snum=1 for HATS-56; this row is value-added
--                  enrichment.
--
--   HATS-58 A B  -- Espinoza et al. 2019 (2019AJ....158...63E) Section
--                  2.5 + 3.3. Gaia DR2 visual companion at Delta-RA =
--                  +0.29733" +/- 0.00051, Delta-Dec = -0.68025" +/-
--                  0.00028, giving combined rho = 0.74238" +/-
--                  0.00033 and computed PA = 156.4 deg (atan2 of
--                  Delta-RA, Delta-Dec; SE quadrant). Mass from blend
--                  analysis 1.216 +/- 0.034 Msun. Gaia DR2 Teff =
--                  5095 +1842/-811 K is internally inconsistent with
--                  the blend mass (which would imply F8V at ~6000 K
--                  on the MS); the paper itself flags the Gaia Teff
--                  as very uncertain. Projected separation 365 +/- 15
--                  AU at d = 492 +/- 21 pc. CPM-confirmed via Gaia
--                  proper-motion match.
--
--   HATS-74 A B  -- Jordan et al. 2022 (2022AJ....163..125J) Table 6
--                  footnote a + Section 2.4. Gaia DR2 visual
--                  companion at 0."844 (rendered "0.00844" in the
--                  paper text with the arcsec mark before the
--                  decimal). Mass 0.2284 +/- 0.0078 Msun -> M5V.
--                  Projected separation ~242 AU at d = 286.6 +/- 3.0
--                  pc. Gaia DR2 common-proper-motion + common-
--                  parallax. Magnitude contrasts used to deblend the
--                  primary photometry: Delta-J = 2.6418, Delta-H =
--                  2.7294, Delta-KS = 2.6473. Assumed coeval with the
--                  primary (age 11.0 Gyr, [Fe/H] +0.51).
--
--   TOI-2267 A B -- Zuniga-Fernandez et al. 2025 (2025A&A...702A..85Z).
--                  M5V + M6V pair, one of the most compact binaries
--                  known to host planets. SAI-2.5m speckle astrometry
--                  across three epochs (Table 4) shows orbital motion:
--                  408 mas (2020-10-25) -> 393 mas (2021-10-22) ->
--                  324 mas (2024-08-09); PA stable at 282-284 deg.
--                  Paper fiducial value (abstract): rho = 0.384",
--                  projected separation ~8 AU at d = 22.55 +/- 0.19
--                  pc. M_B = 0.0989 +/- 0.0130 Msun, Teff_B = 2930
--                  +/- 160 K. The paper cannot unambiguously
--                  determine which of A or B hosts the transiting
--                  planets b, c, and candidate .02 (TOI-2267 d).
--
--   psi1 Dra C   -- Gullikson, Kraus & Dodson-Robinson 2015
--                  (2015ApJ...815...62G). New inner companion to the
--                  planet host, detected via cross-correlation
--                  spectroscopy of long-baseline RV monitoring. Mass
--                  0.70 +/- 0.07 Msun, Teff 4400 +/- 300 K -> K-dwarf
--                  (~K4V). True (SB2) semimajor axis a = 9.1 +0.4/
--                  -0.3 AU; orbital period 6774 d (~18.5 yr);
--                  eccentricity 0.679; inclination 31 deg. Mass ratio
--                  q = 0.466.
--
--                  NAMING NOTE: Gullikson 2015 calls the SB2 primary
--                  "psi1 Dra A" and the wide ~680 AU companion
--                  "psi1 Dra B". Our atlas (and NASA EA) call the
--                  planet host "psi1 Dra B" and the wide companion
--                  "psi1 Dra A" (the opposite). Mass values confirm
--                  this is a naming swap, not different stars
--                  (Mugrauer 2019 ascribes M = 1.329 Msun and Teff
--                  6515 K to the WIDE companion = our 'A' = Gullikson's
--                  'B'; Gullikson Table 2 cites Endl 2015 for the SB2
--                  primary at M = 1.38 Msun, Teff 6544 K = our 'B' =
--                  Gullikson's 'A'). The new row keeps Gullikson's 'C'
--                  designation for the inner companion (recommended for
--                  reader cross-reference), but in our atlas it is an
--                  INNER companion to the planet host 'psi1 Dra B'.
--                  inner_binary = true. We also UPDATE the existing
--                  Mugrauer 2019 A row to acknowledge the new inner
--                  subsystem.
--
--   Gl 49        -- sy_snum_audit row (NASA EA reports sy_snum=2, our
--                  audit supports sy_snum=1). Three independent
--                  primary-literature sources converge:
--                  * Cortes-Contreras et al. 2017 (2017A&A...597A..47C)
--                    FastCam lucky imaging at 1.5m TCS, Karmn
--                    J01026+623, observed twice (2012-09-17,
--                    2013-01-13). Gl 49 does NOT appear in their
--                    detected-binaries tables (Table 4, 5, or 6).
--                    Sensitivity 0.2-5.0" for q > 0.3 on M0-M3.5V
--                    primaries; Gl 49 is M1.5V, well within range.
--                  * Perger et al. 2019 (2019A&A...624A.123P) 22 years
--                    of HIRES + HARPS-N + CARMENES RV monitoring
--                    with no companion-amplitude signal; the only RV
--                    trend (dv/dt = 12.3 cm/s/a) is consistent with
--                    activity, not a stellar companion.
--                  * Houdebine 2010 (2010A&A...509A..65H) chromo-
--                    spheric activity study treats Gl 49 as a single
--                    dM1 star alongside eight other field dwarfs.
--                  Combined evidence: active null detection (Cortes-
--                  Contreras), spectroscopic null (Perger), and
--                  treatment-as-single (Houdebine).
--
-- Apply after 112_wds_batch8.sql. NOT idempotent (plain INSERTs);
-- run the consolidated existing-rows check first to confirm zero
-- conflicts.


-- ============================================================================
-- HR 5183 B
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HR 5183', 'B', 'A', 'K7V', NULL,
     15000, 0.67, false, NULL, false,
     'late-K wide CPM companion (Gaia DR2; BD+07 2692)', 'manual', '2019MNRAS.490.5088M',
     'HR 5183 B = BD+07 2692. Wide CPM companion detected by Mugrauer & Ginski 2019 (2019MNRAS.490.5088M) '
     'via Gaia DR2 proper-motion + parallax matching. Mass M_B = 0.67 +/- 0.05 Msun is from Mustill et al. '
     '2022 (2022MNRAS.509.3616M) Table 1, which cites the joint Bayesian orbit fit of Blunt et al. 2019 '
     '(2019AJ....158..181B; the original RV discovery of the eccentric jovian HR 5183 b). The Mustill 2022 '
     'reference also gives the primary mass M_A = 1.07 +/- 0.04 Msun and the system age 7.7 Gyr / adopted '
     '8 Gyr. Projected separation ~15000 AU at d ~ 31.6 pc; the exact rho value sits in the Mugrauer 2019 '
     'online-only supplement which was not text-accessible during curation, so separation_au is recorded '
     'as an approximate value and separation_arcsec is NULL. Primary spectype A0V is implied by mass and '
     'Teff. The binary semimajor axis and eccentricity are drawn from a joint posterior in Blunt 2019 '
     '(see their Figure 2) rather than reported as point estimates.',
     NULL);


-- ============================================================================
-- KELT-19 A B
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('KELT-19 A', 'B', 'A', 'G9V-K1V', 0.63,
     160, 0.87, false, NULL, false,
     'G9V-K1V visual companion (CPM-confirmed via systemic RV match)', 'manual', '2018AJ....155...35S',
     'KELT-19 A B: G9V-K1V dwarf companion to the Am-type primary KELT-19 A. Siverd et al. 2018 '
     '(2018AJ....155...35S) report rho = 0.63" angular separation, projected separation ~160 AU at d ~ 255 '
     'pc. Mass ~0.87 Msun from photometric SED + stellar isochrone fit. CPM-confirmed via systemic RV '
     'match between the components. Flux ratios F_B/F_A across multiple bandpasses are reported in their '
     'Table 4. The discovery paper discusses the secondary as a plausible Kozai-Lidov perturber that may '
     'have emplaced the close-in transiting planet KELT-19 A b around the Am primary, since Am stars are '
     'typically slow rotators that tidally evolve circular orbits whereas the planet sits on a hot Jupiter '
     'orbit.',
     NULL);


-- ============================================================================
-- HATS-37 A B  (unresolved spectroscopic+photometric binary)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HATS-37 A', 'B', 'A', 'K7V', NULL,
     NULL, 0.654, false, 4210, false,
     'unresolved K7V companion (joint photometric+RV blend modelling)', 'manual', '2020AJ....160..222J',
     'HATS-37 A B: K7V dwarf companion (Teff = 4210 +/- 170 K, M = 0.654 +/- 0.033 Msun, R = 0.654 +/- '
     '0.032 R_sun, log g = 4.622 +/- 0.023, L = 0.120 +/- 0.023 L_sun per Jordan et al. 2020 Table 5 '
     '"Binary Star Companion HATS-37B" block). UNRESOLVED: Gaia DR2 sees HATS-37 as a single source; the '
     'companion is inferred entirely from the joint photometric + RV blend modelling, and supported by an '
     'RV linear trend gamma-dot = 0.4539 +/- 0.0015 m/s/d in their Table 6. No resolved imaging exists, '
     'and the separation is unconstrained (below Gaia DR2 0.4-0.5" floor implies < ~100 AU at d = 211.1 '
     'pc, but no explicit upper limit is given). separation_arcsec and separation_au left NULL. HATS-37 A '
     'is the planet host (HATS-37 A b, a Neptune-desert transiter); the primary is K-dwarf, M_A = 0.843 '
     'Msun, Teff_A = 5326 K, age 11.46 Gyr.',
     NULL);


-- ============================================================================
-- HATS-55 B  (bonus: NASA EA carries sy_snum=1)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HATS-55', 'B', 'A', NULL, 3.80336,
     2361, NULL, false, NULL, false,
     'wide Gaia DR2 CPM companion (mass not derived in discovery paper)', 'manual', '2019AJ....158...63E',
     'HATS-55 B: wide visual companion detected by Espinoza et al. 2019 (2019AJ....158...63E) Discussion '
     'section via Gaia DR2 astrometry. Angular separation rho = 3.80336" +/- 0.00038, projected separation '
     '2361 +/- 23 AU at d = 623.6 +/- 6.2 pc (assuming the pair is physically bound; the paper does not '
     'pursue a formal CPM test for this wider source). AstraLux Sur z-band lucky imaging (Figure 10) does '
     'not detect the companion because it lies outside the ~3" AstraLux field. The paper does not derive '
     'a mass for the secondary (no SED fit reported); component_mass_msun left NULL. '
     'NASA Exoplanet Archive reports sy_snum=1 for HATS-55; this row is value-added catalog enrichment '
     'from primary literature beyond what NASA EA ingests.',
     NULL);


-- ============================================================================
-- HATS-56 B  (bonus: NASA EA carries sy_snum=1)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HATS-56', 'B', 'A', 'late-K', 1.59879,
     922, 0.8058, false, NULL, false,
     'late-K Gaia DR2 companion (mass from Espinoza 2019 blend modelling)', 'manual', '2019AJ....158...63E',
     'HATS-56 B: late-K dwarf companion (M = 0.8058 +/- 0.0076 Msun per Espinoza et al. 2019 '
     '(2019AJ....158...63E) Section 3.3 blend analysis). Gaia DR2 angular separation rho = 1.59879" +/- '
     '0.00029; projected separation 922 +/- 15 AU at d = 577.1 +/- 9.6 pc (assuming physically bound). '
     'The paper notes this companion as Gaia-detected and folds it into the photometric blend modelling '
     'for the transit fits. The Espinoza 2019 paper additionally identifies a separate long-period RV '
     'trend in HATS-56 (gamma-dot, gamma-double-dot in their Table 5) that they interpret as a possible '
     'long-period planet candidate (HATS-56c, M sin i ~ 5.1 MJup, P ~ 815 d), inconsistent in distance '
     'with this 922 AU wide stellar companion. '
     'NASA Exoplanet Archive reports sy_snum=1 for HATS-56; this row is value-added catalog enrichment '
     'from primary literature beyond what NASA EA ingests.',
     NULL);


-- ============================================================================
-- HATS-58 A B  (DELETE existing stub + INSERT cited row)
-- ============================================================================
-- The existing HATS-58 A / B row carries separation_arcsec = 154.099"
-- (~76,000 AU at d = 492 pc, implausible for a bound companion),
-- separation_au = NULL, component_mass_msun = NULL, and
-- source_bibcode = NULL. It appears to be a citation-less stub. The
-- Espinoza et al. 2019 Gaia DR2 detection at rho = 0.74238" / 365 AU
-- is the correct primary-literature geometry. Replace the stub.
DELETE FROM binary_companions
 WHERE hostname = 'HATS-58 A'
   AND component_designation = 'B'
   AND source_bibcode IS NULL;

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HATS-58 A', 'B', 'A', 'F-G dwarf', 0.74238,
     365, 1.216, false, 5095, false,
     'F-G dwarf companion (Gaia DR2 CPM-confirmed; blend analysis mass)', 'manual', '2019AJ....158...63E',
     'HATS-58 A B: F-G dwarf companion to the Am-type planet host HATS-58 A. Espinoza et al. 2019 '
     '(2019AJ....158...63E) Section 2.5 reports Gaia DR2 detection at Delta-RA = +0.29733" +/- 0.00051 '
     '(east of A) and Delta-Dec = -0.68025" +/- 0.00028 (south of A), giving combined angular separation '
     'rho = 0.74238" +/- 0.00033 (matches the explicit value in their Section 4). Computed position angle '
     '156.4 deg (atan2 of Delta-RA, Delta-Dec; companion in SE quadrant of primary). Projected separation '
     '365 +/- 15 AU at d = 492 +/- 21 pc. CPM-confirmed: Gaia DR2 proper motion -12.96 +/- 0.92 mas/yr '
     'RA, -2.30 +/- 0.44 mas/yr Dec for B vs -12.70 +/- 0.30 / -3.23 +/- 0.16 for A. Mass M_B = 1.216 +/- '
     '0.034 Msun from blend-analysis joint fit (Section 3.3). Gaia DR2 Teff_B = 5095 +1842/-811 K is very '
     'uncertain (the paper itself flags it) and internally inconsistent with the blend mass (which on the '
     'main sequence would correspond to F8/G0V at ~6000 K). The blend mass is the more reliable value. '
     'CAVEAT: the paper cannot photometrically distinguish whether the planet orbits A or B; the orbital '
     'RV variation measured with HARPS, however, is consistent with the brighter A as host, and they '
     'adopt that scenario. Delta-G = 0.92 mag (B fainter than A).',
     156.4);


-- ============================================================================
-- HATS-74 A B
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HATS-74 A', 'B', 'A', 'M5V', 0.844,
     242, 0.2284, false, NULL, false,
     'M5V Gaia DR2 CPM companion (deblended primary photometry)', 'manual', '2022AJ....163..125J',
     'HATS-74 A B: M5V dwarf companion (M = 0.2284 +/- 0.0078 Msun per Jordan et al. 2022 '
     '(2022AJ....163..125J) Table 6 footnote a and Section 2.4). Gaia DR2 angular separation 0."844 '
     '(rendered in the paper text as "0.00844" with the arcsec mark before the decimal; matches their '
     'Section 2.4 discussion). Projected separation ~242 AU at d = 286.6 +/- 3.0 pc. Gaia DR2 common-'
     'proper-motion + common-parallax confirmation. Assumed coeval with the primary HATS-74 A (M1V planet '
     'host, age 11.0 Gyr, [Fe/H] +0.51). Magnitude contrasts used to deblend the primary photometry: '
     'Delta-J = 2.6418, Delta-H = 2.7294, Delta-KS = 2.6473, Delta-W1 = 2.5259, Delta-W2 = 2.3352 (see '
     'Jordan 2022 Table 4 footnote f). Sister paper notes: HATS-75, HATS-76, and HATS-77 are listed in '
     'the same paper Table 6 with only 95% upper limits on unresolved stellar companions (M_B < 0.38, '
     '0.24, 0.53 Msun respectively); none are detections, so they do not get binary_companions rows.',
     NULL);


-- ============================================================================
-- TOI-2267 A B  (compact M5V + M6V pair with orbital motion resolved)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-2267 A', 'B', 'A', 'M6V', 0.384,
     8, 0.0989, false, 2930, false,
     'M6V close companion (SAI-2.5m speckle; orbital motion resolved across 3 epochs)', 'manual', '2025A&A...702A..85Z',
     'TOI-2267 B: M6V dwarf companion (M = 0.0989 +/- 0.0130 Msun, R = 0.130 +/- 0.030 R_sun, Teff = 2930 '
     '+/- 160 K, L = 1.1 +/- 0.3 x 10^-3 L_sun, log g = 5.28 +/- 0.18, P_rot = 0.4936 d per Zuniga-'
     'Fernandez et al. 2025 (2025A&A...702A..85Z) Table 2). One of the most compact binaries known to '
     'host planets. Speckle interferometric astrometry at SAI-2.5m across three epochs (Table 4) resolves '
     'ORBITAL MOTION: 2020-10-25 rho = 408 +/- 5 mas, PA = 283.8 +/- 0.4 deg; 2021-10-22 rho = 393 +/- 2 '
     'mas, PA = 283.4 +/- 0.5 deg; 2024-08-09 rho = 324 +/- 3 mas, PA = 282.3 +/- 0.5 deg. The paper '
     'fiducial value (abstract) is rho = 0.384", projected separation ~8 AU at d = 22.55 +/- 0.19 pc; '
     'recorded separation_arcsec uses that fiducial value, and position_angle_deg uses the mean of the '
     'three epochs (~283 deg). [Fe/H] of the pair = 0.164 +/- 0.11 (Dittmann 2016); system age >= 1 Gyr. '
     'The TESS data reveal three planet candidates (TOI-2267 b at P = 2.28 d, c at 3.49 d, and a third '
     'candidate .02 / d at 2.03 d) but the paper EXPLICITLY CANNOT determine which of A or B hosts each '
     'planet (Table H.1 gives parameters under both A-host and B-host assumptions). Dynamical analyses '
     'in the paper suggest b and c likely orbit the same component (near a 3:2 mean motion resonance) '
     'with .02 orbiting the other, making TOI-2267 the most compact binary system known with both '
     'components harbouring transiting worlds (if all three candidates confirm). Primary HATS-2267 A is '
     'M5V at M = 0.1710 +/- 0.0079 Msun, Teff = 3030 +/- 100 K.',
     283.2);


-- ============================================================================
-- psi1 Dra C  (inner SB2 companion to the planet host)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('psi1 Dra B', 'C', 'B', 'K4V', NULL,
     9.1, 0.70, false, 4400, true,
     'inner SB2 K-dwarf companion (cross-correlation spectroscopic detection)', 'manual', '2015ApJ...815...62G',
     'psi1 Dra C: inner SB2 companion to the planet host (our psi1 Dra B), detected by Gullikson, Kraus & '
     'Dodson-Robinson 2015 (2015ApJ...815...62G) via cross-correlation analysis of long-baseline RV '
     'monitoring. Mass M_C = 0.70 +/- 0.07 Msun (full SB2 mass, not M sin i), Teff_C = 4400 +/- 300 K -> '
     'K-dwarf (~K4V). True semimajor axis a = 9.1 +0.4/-0.3 AU (SB2, not projected); orbital period 6774 '
     '+271/-167 d (~18.5 yr); eccentricity 0.679 +0.006/-0.004; inclination 31 +/- 1 deg; mass ratio q = '
     '0.466 +/- 0.008. Spectroscopic detection only -- no rho / PA from imaging. inner_binary = true. '
     'NAMING CONVENTION: Gullikson 2015 labels the SB2 primary "psi1 Dra A" and the new inner companion '
     '"psi1 Dra C", with the known wide ~680 AU companion as their "psi1 Dra B". OUR atlas (and NASA EA) '
     'use the opposite labels: planet host = psi1 Dra B; wide ~684 AU companion = psi1 Dra A. The mass '
     'and Teff values confirm this is a naming swap, not different stars (the wide companion at 1.329 '
     'Msun and Teff 6515 K from Mugrauer 2019 maps to Gullikson''s "B"; the SB2 primary from Gullikson '
     'Table 2 citing Endl 2015 at 1.38 Msun and Teff 6544 K is the planet host = our "B" = Gullikson''s '
     '"A"). We keep the literature designation "C" for the inner companion (Option A reader cross-'
     'reference), but in our atlas it is recorded as an inner companion to the planet host psi1 Dra B '
     '(primary_designation = ''B''). The existing psi1 Dra A wide-companion row (Mugrauer 2019, '
     'separation 30.081", 684 AU) is unaffected.',
     NULL);


-- ============================================================================
-- UPDATE existing psi1 Dra A row to acknowledge the new inner C subsystem
-- ============================================================================
UPDATE binary_companions
   SET notes = notes ||
       ' --- INNER C SUBSYSTEM: Gullikson et al. 2015 (2015ApJ...815...62G) ' ||
       'subsequently discovered an inner SB2 companion (psi1 Dra C, M = 0.70 ' ||
       'Msun K-dwarf, a = 9.1 AU, P ~ 18.5 yr) to the planet host psi1 Dra B ' ||
       'via cross-correlation spectroscopy. See the dedicated C row in ' ||
       'binary_companions for that subsystem. NB: Gullikson 2015 uses opposite ' ||
       'naming convention (their "psi1 Dra A" = our "psi1 Dra B" planet host, ' ||
       'their "psi1 Dra B" = our "psi1 Dra A" wide companion, their "psi1 Dra ' ||
       'C" = the new inner SB2 partner to our "psi1 Dra B").'
 WHERE hostname = 'psi1 Dra B'
   AND component_designation = 'A'
   AND source_bibcode = '2019MNRAS.490.5088M'
   AND notes NOT LIKE '%INNER C SUBSYSTEM%';


-- ============================================================================
-- Gl 49  --  sy_snum_audit
-- ============================================================================
-- NASA EA reports sy_snum=2. Audit supports sy_snum=1 based on three
-- independent primary-literature sources converging on no companion
-- detection / treatment-as-single.
INSERT INTO sy_snum_audit
    (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes,
     curated_at, curator_note)
VALUES
    ('Gl 49', 2, 1,
     'NASA EA reports sy_snum=2 for Gl 49 (BD+61 195, Karmn J01026+623, HIP 4872), '
     'but three independent primary-literature sources converge on a single-star '
     'interpretation. (1) Cortes-Contreras et al. 2017 (2017A&A...597A..47C) high-'
     'resolution FastCam lucky imaging at the 1.5m TCS observed Gl 49 across two '
     'epochs (2012-09-17 and 2013-01-13) as part of the CARMENES M-dwarf input '
     'catalogue survey of 490 mid- to late-M dwarfs; Gl 49 does NOT appear in any '
     'of their detected-companion tables (their Tables 4, 5, or 6). Sensitivity '
     'was rho = 0.2-5.0" for q > 0.3 on M0-M3.5V primaries, well-matched to Gl 49 '
     '(M1.5V). (2) Perger et al. 2019 (2019A&A...624A.123P) 22 years of high-'
     'precision RV monitoring with HIRES + HARPS-N + CARMENES (~22-year baseline, '
     'rms ~5 m/s) shows only the planetary signal (Gl 49 b super-Earth at 13.85 d) '
     'plus stellar-activity contributions; no companion-amplitude trend. The Gaia '
     'DR2 RV trend dv/dt = 12.3 cm/s/a is consistent with activity, not a stellar '
     'companion. (3) Houdebine 2010 (2010A&A...509A..65H) treats Gl 49 as a single '
     'dM1 star in a chromospheric-activity sample alongside eight other field '
     'dwarfs. Combined evidence: active null detection (Cortes-Contreras 2017), '
     'spectroscopic null (Perger 2019), and treatment-as-single (Houdebine 2010). '
     'Caveat: high-resolution imaging is blind below rho ~ 0.2" (~2 AU at d = 9.86 '
     'pc); a very close unresolved companion below RV sensitivity threshold cannot '
     'be formally ruled out, but the WDS catalog claim driving NASA EA sy_snum=2 '
     'is for a wider companion that Cortes-Contreras 2017 would have caught.',
     ARRAY['2017A&A...597A..47C', '2019A&A...624A.123P', '2010A&A...509A..65H'],
     DATE '2026-06-24',
     'Curated during WDS Batch 9 final pass; converging three-paper null detection.');
