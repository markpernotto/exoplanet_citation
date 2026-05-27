-- HAT-P-7 stellar architecture enrichment (manual literature review,
-- 2026-05-26). Eleventh migration of the S-type stellar-multiplicity audit.
-- HAT-P-7 was previously deep-dived for spin-orbit obliquity in migration
-- 054 (Tilted & Tumbling theme) and for atmosphere in migration 061
-- (fast-follows batch 2). This migration adds the two stellar companions
-- that make the system a hierarchical triple, closing the sy_snum = 3 gap.
--
-- Bibcodes:
--   2012PASJ...64L...7N -- Narita et al. 2012 PASJ 64, L7, "A Common Proper
--     Motion Stellar Companion to HAT-P-7" (arXiv 1209.4422). Discovery of
--     HAT-P-7 B as a comoving M5.5V wide companion at 3.9 arcsec.
--   2009ApJ...703L..99W -- Winn et al. 2009 ApJL 703, L99, "HAT-P-7: A
--     Retrograde or Polar Orbit, and a Third Body" (already cited in migration
--     054 for the projected_obliquity 86.3° detection). Original RV-trend
--     detection of HAT-P-7 C as an inner third body; orbital parameters
--     constrained from the RV trend and Keplerian fit.
--
-- Architecture:
--   - HAT-P-7 A: F6V planet host (T_eff 6389 K). Hosts the polar hot Jupiter
--     HAT-P-7 b (a=0.038 AU, true obliquity 86.3° per Winn 2009 in migration
--     054). Atmosphere recorded in migration 061 (Changeat 2022 H2O/CO2/FeH).
--   - HAT-P-7 B: M5.5V wide common-proper-motion companion at 3.9 arcsec
--     east of A (Narita 2012), projected separation ~1286 AU at the catalog
--     distance. Spectype inferred from colors; explicit mass not quoted in
--     the paper (M5.5V implies ~0.18 Msun on main-sequence, recorded as
--     estimate with NULL uncertainty).
--   - HAT-P-7 C: RV-trend-only inner third body, NOT directly imaged.
--     Orbital fit (Winn 2009 + Knutson 2014 trend extension): semi-major
--     axis a = 32 +16/-11 AU, eccentricity e = 0.76 +0.12/-0.26, minimum
--     mass m sin i = 0.19 +0.11/-0.06 Msun. The system geometry (B + C +
--     planet b's polar orbit) is the basis for Narita 2012's proposed
--     sequential Kozai-Lidov migration scenario that explains the planet's
--     misalignment. component_mass_is_min = true; separation_arcsec NULL
--     because C is not directly imaged; separation_au populated with the
--     orbital semi-major axis (the closest defensible single value).
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-7', 'B', 'A', 'M5.5V', 3.9,
     1286, 0.18, false, NULL, false,
     'wide late M-dwarf visual companion (Narita 2012 common-proper-motion confirmation)', 'manual', '2012PASJ...64L...7N',
     'HAT-P-7 B: M5.5V wide companion at 3.9 arcsec east of HAT-P-7 A; projected separation ~1286 AU. '
     'Narita et al. 2012 PASJ 64, L7: spectral type inferred from JHK colors; common proper motion '
     'with the planet host confirmed. Mass 0.18 Msun is a main-sequence estimate from the M5.5V '
     'spectype (Narita does not quote an explicit mass; recorded with NULL uncertainty for that '
     'reason). component_teff_k NULL by the same reasoning (M5.5V implies ~3100 K but not derived). '
     'Together with HAT-P-7 C (recorded below), HAT-P-7 B drives the sequential Kozai-Lidov migration '
     'scenario in Narita 2012 that explains the host''s polar / retrograde hot-Jupiter (HAT-P-7 b '
     'true obliquity 86.3°, migration 054).'),

    ('HAT-P-7', 'C', 'A', NULL, NULL,
     32, 0.19, true, NULL, false,
     'RV-trend-only inner third body, not directly imaged (Winn 2009)', 'manual', '2009ApJ...703L..99W',
     'HAT-P-7 C: inner third body detected via radial-velocity trend by Winn et al. 2009 ApJL 703, L99 '
     '(same paper that measured the planet''s polar orbit). NOT directly imaged. Orbital fit: '
     'semi-major axis a = 32 +16/-11 AU, eccentricity e = 0.76 +0.12/-0.26, minimum mass '
     'm sin i = 0.19 +0.11/-0.06 Msun (component_mass_is_min = true; true mass is at least this '
     'value and could be larger if the orbit is more face-on). At m sin i = 0.19 Msun the object is '
     'an M5-ish dwarf if seen edge-on. separation_arcsec NULL because no direct astrometric detection; '
     'separation_au populated with the orbital semi-major axis. component_teff_k NULL. '
     'Together HAT-P-7 A + B + C account for the catalog sy_snum = 3.')
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
