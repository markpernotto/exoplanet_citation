-- HD 4113 C cold brown-dwarf companion (manual literature review, 2026-05-24; "Wild Orbits"
-- theme, closes the set). HD 4113 is a complex hierarchical system: the host HD 4113 A, an
-- eccentric giant planet HD 4113 A b (e=0.90; Tamuz et al. 2008), a wide M-dwarf companion
-- (HD 4113 B, already in binary_companions), and -- imaged by Cheetham et al. 2018 with VLT/
-- SPHERE -- an ULTRACOOL brown dwarf, HD 4113 C: a late-T (T9) dwarf with strong methane, Teff
-- 500-600 K (one of the coldest imaged companions), at a projected separation of 22 AU. Its
-- dynamical mass (66 +5/-4 Mjup, from 27 yr of RVs + the imaging astrometry) notably exceeds its
-- isochronal/temperature mass (~36 Mjup), hinting it may itself be an unresolved brown-dwarf
-- binary. HD 4113 C was absent from binary_companions; this adds it with Cheetham 2018's
-- parameters (separation, T9 type, Teff, dynamical mass). Position angle is not in the abstract,
-- so position_angle_deg is left NULL. Bibcode verified via ADS. The planet->paper link
-- HD 4113 b -> Cheetham 2018 (role='characterization', contribution='binary_companion') is in
-- etl/seed_followup_citations.py.
--
--   Cheetham et al. 2018 (VLT/SPHERE): HD 4113 C, sep 535 mas (22 AU), T9, Teff 500-600 K,
--     dynamical mass 66 +5/-4 Mjup (~0.063 Msun).
--
-- Idempotent (ON CONFLICT on the (hostname, component_designation) primary key).

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 4113', 'C', 'A', 'T9', 0.535,
     22, 0.063, false, 550, false,
     'T9 brown dwarf', 'manual', '2018A&A...614A..16C',
     'Ultracool late-T (T9) brown dwarf imaged by Cheetham et al. 2018 (VLT/SPHERE); Teff 500-600 K '
     '(one of the coldest imaged companions), strong methane. Projected separation 22 AU (535 mas). '
     'Dynamical mass 66 +5/-4 Mjup (~0.063 Msun) exceeds the isochronal ~36 Mjup, hinting HD 4113 C '
     'may itself be an unresolved brown-dwarf binary. Part of a system with the eccentric planet '
     'HD 4113 A b and the wide M-dwarf HD 4113 B. Position angle not yet harvested.')
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
