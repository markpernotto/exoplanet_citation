-- Proxima Cen stellar architecture REPAIR (manual literature review,
-- 2026-05-26). Fourteenth migration of the S-type stellar-multiplicity
-- audit. Proxima Cen is the ONLY entry in this campaign so far that requires
-- a true cross-reference REPAIR rather than an enrichment-or-split: the
-- existing SIMBAD-bulk-load 'B' row at 3.667 arcsec / no AU / no mass / no
-- bibcode is almost certainly an OPTICAL DOUBLE (line-of-sight projection),
-- NOT a bound companion. This has been a known cross-reference issue in our
-- data-quality flags (web/src/pages/Collections.tsx DATA_QUALITY_FLAGS):
-- "Cross-referenced wide-binary entry at 3.67 arcsec (~4.8 AU) has no
-- counterpart in the known Proxima / Alpha Cen AB triple; almost certainly
-- a line-of-sight projection rather than a bound companion."
--
-- THE REAL ARCHITECTURE:
--   - Proxima Cen (= alpha Cen C): M5.5V planet host at 1.30 pc (the closest
--     star to the Sun). Hosts Proxima Cen b (temperate Earth-mass, 11.2 d),
--     c (cold sub-Neptune, 5.2 yr), and d (sub-Earth candidate, 5.1 d).
--   - alpha Cen A: G2V at ~13,000 AU (~10,000 arcsec / ~2.8° on the sky)
--     from Proxima. Gravitational binding of Proxima to the alpha Cen AB
--     pair was confirmed by Kervella et al. 2017 (A&A 598, L7) using
--     Gaia/HARPS astrometry: Proxima's orbit around alpha Cen AB has
--     period ~547,000 yr, eccentricity 0.50 +0.08/-0.09, periastron
--     8,700 AU, apastron 13,000 AU.
--   - alpha Cen B: K1V, in a CLOSE binary with A (a = 23.5 AU, P = 79.9 yr,
--     e = 0.52) -- the AB pair is unresolved from Proxima's vantage but
--     well-known as a tight visual/spectroscopic binary in its own right.
--     From Proxima's perspective B is at essentially the same wide
--     separation as A.
--
-- This migration:
--   1. DELETEs the bogus SIMBAD 'B' row (the 3.67" optical double).
--   2. INSERTs 'B' = alpha Cen A (G2V, wide).
--   3. INSERTs 'C' = alpha Cen B (K1V, wide, AB-binary partner of A).
--
-- Together Proxima + alpha Cen A + alpha Cen B account for sy_snum = 3.
-- The DELETE is restricted to source_catalog = 'SIMBAD' AND source_bibcode
-- IS NULL so a more authoritative existing entry would not be touched.
-- Idempotent.
--
-- Bibcodes:
--   2017A&A...598L...7K -- Kervella et al. 2017, "Proxima's orbit around
--     alpha Centauri". The gravitational-binding proof + Proxima/AB orbit
--     characterization (548,000 yr, e=0.50, periastron 8,700 AU, apastron
--     13,000 AU). Recorded values for alpha Cen A and B masses come from
--     Pourbaix 2002 / Kervella 2003 visual-orbit + AAS-tomography work
--     that Kervella 2017 references (alpha Cen A 1.105 Msun, B 0.934 Msun).
--
-- Apply after 011_binary_companions.sql.

-- Step 1: remove the bogus SIMBAD optical-double 'B' entry.
DELETE FROM binary_companions
WHERE hostname = 'Proxima Cen'
  AND component_designation = 'B'
  AND source_catalog = 'SIMBAD'
  AND source_bibcode IS NULL;

-- Step 2: insert alpha Cen A (B) and alpha Cen B (C).
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Proxima Cen', 'B', 'A', 'G2V', 10000,
     13000, 1.105, false, 5790, false,
     'alpha Cen A: G2V wide companion in the Proxima-AB bound triple', 'manual', '2017A&A...598L...7K',
     'alpha Centauri A: G2V Sun-like star, the bright primary of the alpha Cen AB tight binary. At a '
     'wide projected separation of ~13,000 AU (~10,000 arcsec / ~2.8° on the sky) from Proxima Cen at '
     'the system''s 1.30 pc distance. Gravitational binding of Proxima Cen to the alpha Cen AB pair '
     'was definitively established by Kervella et al. 2017 (A&A 598, L7): orbital period ~547,000 yr, '
     'eccentricity 0.50 +0.08/-0.09, periastron 8,700 AU, apastron 13,000 AU. Mass 1.105 Msun and Teff '
     '5790 K are the well-established values from the alpha Cen AB visual-orbit work (Pourbaix 2002, '
     'Kervella 2003, and many follow-ups) that Kervella 2017 references. NB this REPLACES the prior '
     'bogus SIMBAD-bulk-load entry at 3.667 arcsec, which was a line-of-sight optical double with no '
     'physical counterpart in the Proxima/alpha Cen AB triple.'),

    ('Proxima Cen', 'C', 'A', 'K1V', 10000,
     13000, 0.934, false, 5260, false,
     'alpha Cen B: K1V wide companion, AB-binary partner of alpha Cen A', 'manual', '2017A&A...598L...7K',
     'alpha Centauri B: K1V star in a close binary with alpha Cen A (semi-major axis 23.5 AU, '
     'orbital period 79.9 yr, eccentricity 0.52). From Proxima Cen''s vantage at ~13,000 AU, the AB '
     'pair is unresolved and B sits at essentially the same wide angular separation as A (the AB '
     'separation of 23.5 AU is dwarfed by the ~13,000 AU distance to Proxima). Mass 0.934 Msun and '
     'Teff 5260 K are the long-established AB-orbit-derived values (Pourbaix 2002, Kervella 2003). '
     'Proxima Cen + alpha Cen A + alpha Cen B account for the catalog sy_snum = 3.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation  = EXCLUDED.primary_designation,
    component_spectype   = EXCLUDED.component_spectype,
    separation_arcsec    = EXCLUDED.separation_arcsec,
    separation_au        = EXCLUDED.separation_au,
    component_mass_msun  = EXCLUDED.component_mass_msun,
    component_mass_is_min= EXCLUDED.component_mass_is_min,
    component_teff_k     = EXCLUDED.component_teff_k,
    inner_binary         = EXCLUDED.inner_binary,
    binary_class         = EXCLUDED.binary_class,
    source_catalog       = EXCLUDED.source_catalog,
    source_bibcode       = EXCLUDED.source_bibcode,
    notes                = EXCLUDED.notes;
