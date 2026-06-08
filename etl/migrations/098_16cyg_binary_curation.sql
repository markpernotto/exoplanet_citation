-- 16 Cygni stellar architecture curation (manual literature review,
-- 2026-06-08). 16 Cyg B b is in our atlas with three rows in
-- binary_companions for hostname '16 Cyg B', all from a SIMBAD bulk
-- ingest with no bibcode. Audit by querying the live table showed:
--
--   designation  primary  spectype   sep_arcsec               source
--   A            B        G1.5Vb     39.561733369065266       SIMBAD
--   B            A        NULL       38.571894116801026       SIMBAD
--   C            A        G1.5Vb     39.561733369065266       SIMBAD
--
-- Two rows are bogus:
--   - 'B' is a self-reference: the catalog stored both A→B and B→A
--     relations, and from the planet host's perspective the B→A row
--     ends up as "16 Cyg B has a companion designated B," which is a
--     star being its own companion.
--   - 'C' is a duplicate of A — identical separation_arcsec (12
--     decimal places) and spectype G1.5Vb. 16 Cyg has no widely-
--     accepted third stellar component (a possible unconfirmed
--     tertiary candidate is discussed in the notes below).
--
-- Architecture established by:
--   Bibcode: 1999PASP..111..321H -- Hauser & Marcy 1999, PASP 111, 321,
--     "The Orbit of the Wide Binary 16 Cygni"
--
-- Orbital parameters from the H&M 1999 abstract (one-velocity-vector
-- orbit derivation, ~1% of the orbit transpired since 1830 first
-- astrometry; the unknown line-of-sight separation component yields a
-- family of bound orbits, ranges given):
--   - Period P:                1.82e4 - 1.3e6 yr
--   - Semi-major axis a:       877 - 15,180 AU
--   - Eccentricity e:          0.54 - 0.96
--   - Periastron distance r_p: 68 - 1500 AU
--
-- Tertiary candidate (unconfirmed) discussed in H&M 1999, citing
-- Trilling et al.: a red point source 3.2" from 16 Cyg A. Membership
-- unknown. If bound, either an M-dwarf at ~80 AU from A, a ~0.5 Msun
-- star at >150 AU from A, or a background star. NOT added as a row
-- here pending confirmation.
--
-- Apply order: after 011_binary_companions.sql (table creation) and
-- after any bulk ingest that may have populated the three bogus rows.
-- Idempotent.

-- 1. Drop the two bogus rows ('B' self-reference, 'C' duplicate of A).
DELETE FROM binary_companions
WHERE hostname = '16 Cyg B' AND component_designation IN ('B', 'C');

-- 2. Upsert the canonical 'A' row with full citation.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype,
     separation_arcsec, separation_au, component_mass_msun, component_mass_is_min,
     component_teff_k, inner_binary, binary_class, source_catalog,
     source_bibcode, notes)
VALUES
    ('16 Cyg B', 'A', 'B', 'G1.5Vb',
     39.5, 835, NULL, false,
     NULL, false,
     'wide binary partner to G2V host 16 Cyg B; orbit characterized by '
     'Hauser & Marcy 1999 from one-velocity-vector inversion of RV + '
     'astrometric data plus Hipparcos parallax',
     'manual', '1999PASP..111..321H',
     '16 Cygni A: G1.5V wide binary partner of the G2V planet host 16 Cyg B. '
     'Current projected separation ~39.5 arcsec at 21.13 pc Hipparcos '
     'distance gives ~835 AU. Hauser & Marcy 1999 (PASP 111, 321) '
     'characterizes the A-B orbit by instantaneous-velocity-vector '
     'inversion (only ~1% of the orbit has transpired since the first '
     'astrometric measurements in 1830); the unknown line-of-sight '
     'separation component yields a family of bound-orbit solutions with '
     'period 1.82e4-1.3e6 yr, semi-major axis 877-15,180 AU, eccentricity '
     '0.54-0.96, and periastron distance 68-1500 AU. The high eccentricity '
     '(definitely e >= 0.54) is relevant to the perturbative-origin '
     'hypothesis for 16 Cyg B b''s own orbital eccentricity. 16 Cyg is a '
     'wide BINARY, not a triple; older catalog rows for "B" (self-reference '
     'from reversed A-B storage) and "C" (duplicate of A at identical '
     'separation 39.561733") were SIMBAD bulk-ingest artifacts and were '
     'deleted by this migration. Hauser & Marcy 1999 discusses an '
     'unconfirmed tertiary candidate -- a red point source detected 3.2" '
     'from 16 Cyg A by Trilling et al. -- assessed as either an M-dwarf at '
     '~80 AU from A, a higher-mass ~0.5 Msun star at >150 AU from A, or a '
     'background star; not added here pending membership confirmation. If '
     'the Trilling source is bound, A and B never approach closer than '
     '~500 AU, which weakens the perturbative-eccentricity hypothesis for '
     'the planet around 16 Cyg B.')
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
    notes                 = EXCLUDED.notes;
