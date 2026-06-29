-- Migration 118 (2026-06-27). Evans, Southworth, et al. 2018
-- (2018A&A...610A..20E, HITEP II) provides full Keplerian orbital
-- solutions for WASP-77AB and WASP-85AB based on joint fits to
-- historical micrometer astrometry (back to the 1920s for WASP-85,
-- 1944 for WASP-77) combined with the modern Lucky Imaging data from
-- the Two Colour Instrument on the Danish 1.54m. This is enrichment
-- of two existing rows that capture only the geometric snapshot;
-- the Keplerian orbital architecture (a, e, i, Omega, omega) is
-- appended in notes and Evans 2018 is added as the orbital-fit
-- citation.
--
-- TWO OPERATIONS:
--
--   1. WASP-77 A B (UPDATE)
--      Existing row is cited (Mugrauer 2019, rho=3.276", PA=153.81°,
--      sep=345 AU, M_B=0.742, Teff=4625 K). Mugrauer 2019 stays as
--      the primary geometric source. Evans 2018 orbital fit appended
--      to notes; bibcode mentioned inline. NB: WASP-77 B has DEC
--      coord around -7 degrees, accessible to both Southern micrometer
--      and Lucky Imaging surveys -- Evans 2018 Table A.1 lists
--      astrometry back to 1944.
--
--   2. WASP-85 A B (DELETE + INSERT, SIMBAD-debt cleanup)
--      Existing row is a citation-less SIMBAD-seed stub (source_bibcode
--      IS NULL, separation_au IS NULL, component_mass_msun IS NULL,
--      notes IS NULL). Replace with cited Evans 2018 row that
--      includes both the most recent epoch geometry (rho=1.4548", PA=
--      99.6 deg from Table A.2 entry at MJD 57499 = ~2016.5) and the
--      full Keplerian fit (Table 8). Evans 2018 Table 6 also gives
--      Teff_B = 5200 +/- 300 K and projected separation 175 +/- 17 AU
--      at the system distance; no direct mass derivation in this
--      paper, but the spectype G7-8V is implied from Teff.
--
-- NB on WASP-85 A C (the wide 141" entry): NOT in Evans 2018 scope --
-- that paper Table A.2 only covers the close ~1.5" pair AB. The C
-- entry stays in the SIMBAD-debt list for the upcoming citation-debt
-- pass.
--
-- Apply after 117_sy_snum_audit_hgca_refresh.sql.


-- ============================================================================
-- (1) WASP-77 A B  -- Mugrauer 2019 stays primary; append Evans 2018 orbit fit
-- ============================================================================
-- Guarded so re-running won't duplicate the appended text.
UPDATE binary_companions
   SET notes = notes ||
       E'\n\nORBITAL ARCHITECTURE from Evans, Southworth, et al. 2018 '
       '(2018A&A...610A..20E, HITEP II Table 7): joint Keplerian fit using '
       'historical micrometer astrometry back to MJD 16411 (1944.965 epoch) '
       'plus the Maxted 2013 + Paper I (Evans et al. 2016a) + Wollert et al. '
       '2015 lucky imaging epochs (Table A.1, 10 astrometric data points '
       'spanning 70 years). Best-fit posterior parameters (median +/- '
       'asymmetric 1-sigma): semi-major axis a = 420 (+250, -130) AU; '
       'eccentricity e = 0.60 (+0.28, -0.26) -- NB: the eccentricity '
       'distribution is BIMODAL between a moderate-e solution (e ~ 0.5) and '
       'a high-e solution (e ~ 0.95) with the latter having higher posterior '
       'mode; inclination i = 75 (+6, -15) deg; longitude of ascending node '
       'Omega = 339 (+7, -40) deg; argument of periapsis omega = 226 '
       '(+51, -30) deg. The Mugrauer 2019 snapshot geometry (rho, PA, sep_AU '
       'recorded in the typed columns above) is the projected separation at '
       'the Mugrauer 2019 epoch; the Keplerian semi-major axis from Evans '
       '2018 is the true orbital quantity. WASP-77 B is K3V (M = 0.742 Msun, '
       'Teff = 4625 K per Mugrauer 2019).'
 WHERE hostname = 'WASP-77 A'
   AND component_designation = 'B'
   AND notes NOT LIKE '%Evans, Southworth, et al. 2018%';


-- ============================================================================
-- (2) WASP-85 A B  -- DELETE SIMBAD-debt stub + INSERT cited Evans 2018 row
-- ============================================================================
-- Delete the citation-less SIMBAD-seed stub. Guarded so we do not
-- accidentally clobber a cited row.
DELETE FROM binary_companions
 WHERE hostname = 'WASP-85 A'
   AND component_designation = 'B'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL;

-- Insert the cited Evans 2018 row.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('WASP-85 A', 'B', 'A', 'G7-G8V', 1.4548,
     175, NULL, false, 5200, false,
     'G7-G8V close visual binary (near-twin, full Keplerian orbit fit)', 'manual', '2018A&A...610A..20E',
     'WASP-85 A B: G7-G8V close visual binary companion (Teff_B = 5200 +/- 300 K per Evans et al. '
     '2018 Table 6, 2018A&A...610A..20E "HITEP II"). Delta-K = 0.99 +/- 0.08 mag -- this is a '
     'near-twin pair. Most recent epoch astrometry (Evans 2018 Table A.2, MJD 57499 ~ 2016.5): '
     'rho = 1.4548 +/- 0.0038", PA = 99.606 +/- 0.083 deg. Projected separation 175 +/- 17 AU at '
     'the system distance per Evans 2018 Table 6. CPM-confirmed and physically associated. Mass '
     'M_B not directly derived in Evans 2018; implied ~0.95 Msun for a G7-G8 dwarf on the main '
     'sequence (Pecaut & Mamajek 2013). '
     'ORBITAL ARCHITECTURE from Evans 2018 Table 8: joint Keplerian fit using historical '
     'micrometer astrometry back to MJD 8197 (1922.32 epoch) plus modern lucky imaging '
     '(Brown 2015, Gaia DR1, Wollert & Brandner 2015, Tokovinin et al. 2016, Schmitt et al. '
     '2016, Evans 2018) -- Table A.2 lists 24 astrometric data points spanning ~94 years. '
     'Best-fit posterior parameters (median +/- asymmetric 1-sigma): semi-major axis a = 148 '
     '(+52, -23) AU; eccentricity e = 0.43 (+0.13, -0.25); inclination i = 140 (+16, -12) deg '
     '(retrograde); longitude of ascending node Omega = 112 (+177, -49) deg (multimodal); '
     'argument of periapsis omega = 209 (+110, -156) deg (highly multimodal). The orbital '
     'period is implied to be ~1500-2000 years. The planet WASP-85 A b (hot Jupiter, P = 2.66 '
     'd, R = 1.25 R_J) orbits the brighter primary star; WASP-85 was originally cited as a '
     'single-star discovery by Brown 2015 with the binary nature established by subsequent '
     'imaging follow-up. This row replaces a citation-less SIMBAD-seed stub at 1.483".',
     99.6);
