-- Mugrauer 2019 Gaia DR2 bulk enrichment, 5 hosts (manual literature review,
-- 2026-05-26). Seventh migration of the S-type stellar-multiplicity audit
-- campaign. Bonus opportunity from the user's Mugrauer 2019 paste while
-- looking for WASP-127 (which is in the online supplement, not the article's
-- sample tables): Tables 3 + 4 give full astrometry + mass + Teff for 5
-- hosts that match our audit list. WASP-127 deferred to a follow-on migration
-- once the supplementary table entry is in hand.
--
-- Bibcode:
--   2019MNRAS.490.5088M -- Mugrauer 2019 MNRAS 490, 5088, "Search for stellar
--     companions of exoplanet host stars by exploring the second ESA-Gaia
--     data release". 176 binaries + 27 hierarchical triples + 1 quadruple
--     detected via Gaia DR2 parallax + proper-motion analysis among 1300+
--     known exoplanet hosts. Companion masses derived from Gaia DR2 absolute
--     G-band magnitudes assuming main-sequence isochrones.
--
-- Architecture (from Mugrauer 2019 Tables 3 + 4):
--   - HD 142 B: M-dwarf at 3.895 arcsec / 102 AU from HD 142 A. mass 0.579
--     +0.016/-0.022 Msun, Teff 3922 +49/-66 K (M0V approx). Closes HD 142
--     (sy_snum = 2, missing 1).
--   - WASP-1 B: M-dwarf at 4.580 arcsec / 1820 AU from WASP-1 A. mass 0.405
--     +0.032/-0.068 Msun, Teff 3529 +52/-74 K (M3V approx). Closes WASP-1
--     (sy_snum = 2, missing 1).
--   - WASP-45 B: late M-dwarf at 4.372 arcsec / 929 AU from WASP-45 A. mass
--     0.157 +0.005/-0.009 Msun, Teff 3154 +16/-28 K (M5V approx). Closes
--     WASP-45 (sy_snum = 2, missing 1).
--   - HAT-P-16 C: K-dwarf at 23.347 arcsec / 5323 AU from HAT-P-16 A. mass
--     0.730 +0.011/-0.017 Msun, Teff 4571 +50/-81 K (K3V approx). The C
--     designation reflects that HAT-P-16 already has a known closer B
--     companion (sy_snum = 3, missing 1 in our audit; this row closes the
--     remaining gap, taking HAT-P-16 to missing-0).
--   - HD 4113 B: M-dwarf at 49.009 arcsec / 2055 AU from HD 4113 A. mass
--     0.588 +0.048/-0.023 Msun, Teff 3947 +198/-71 K (M0V approx). HD 4113
--     was not in the audit list because the C T9 brown dwarf at 22 AU
--     (migration 058) already provided one binary_companions row that
--     satisfied the COUNT(distinct component) check; this row adds the
--     genuine wide stellar B that the architecture has been missing.
--
-- All five entries: Gaia DR2 parallax + proper-motion confirmation, status
-- "comoving" (tangential motion exceeds escape velocity per Mugrauer's
-- Table 1 cpm-index test).
--
-- Apply after 011_binary_companions.sql (and migration 058 for HD 4113 C
-- ordering, though not strictly required since on-conflict is per-key).
-- Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 142', 'B', 'A', 'M0V', 3.895,
     102, 0.579, false, 3922, false,
     'M-dwarf wide visual companion to HD 142 A', 'manual', '2019MNRAS.490.5088M',
     'HD 142 B: Mugrauer 2019 Gaia DR2 detection. Tables 3+4: angular separation 3.89463 ± 0.00017 '
     'arcsec, PA = 185.824°, projected separation 102 AU. Mass 0.579 +0.016/-0.022 Msun, Teff 3922 '
     '+49/-66 K (M0V approx), MG 8.195 +0.202/-0.149 mag. Flags: PRI 2MA BPRP (primary catalog '
     'detection, 2MASS counterpart, Gaia DR2 BP/RP photometry). Closes HD 142 (catalog sy_snum = 2; '
     'binary_companions was empty before this entry).'),

    ('WASP-1', 'B', 'A', 'M3V', 4.580,
     1820, 0.405, false, 3529, false,
     'M-dwarf wide visual companion to hot-Jupiter host WASP-1 A', 'manual', '2019MNRAS.490.5088M',
     'WASP-1 B: Mugrauer 2019 Gaia DR2 detection. Tables 3+4: angular separation 4.57992 ± 0.00020 '
     'arcsec, PA = 1.884° (essentially due north), projected separation 1820 AU. Mass 0.405 '
     '+0.032/-0.068 Msun, Teff 3529 +52/-74 K (M3V approx), MG 9.671 +0.492/-0.251 mag. Flag: BPRP '
     'only (no 2MASS counterpart, faint). cpm-index 3.1 (just above the 3.0 confirmation threshold).'),

    ('WASP-45', 'B', 'A', 'M5V', 4.372,
     929, 0.157, false, 3154, false,
     'late M-dwarf wide visual companion to hot-Jupiter host WASP-45 A', 'manual', '2019MNRAS.490.5088M',
     'WASP-45 B: Mugrauer 2019 Gaia DR2 detection. Tables 3+4: angular separation 4.37224 ± 0.00024 '
     'arcsec, PA = 317.798°, projected separation 929 AU. Mass 0.157 +0.005/-0.009 Msun (one of the '
     'lower-mass companions in the Mugrauer 2019 sample), Teff 3154 +16/-28 K (M5V approx), MG 12.111 '
     '+0.168/-0.099 mag. Flags: 2MA BPRP. cpm-index 48 (clear common-proper-motion pair).'),

    ('HAT-P-16', 'C', 'A', 'K3V', 23.347,
     5323, 0.730, false, 4571, false,
     'K-dwarf wide visual companion to hot-Jupiter host HAT-P-16 A (third star; B is closer)', 'manual', '2019MNRAS.490.5088M',
     'HAT-P-16 C: Mugrauer 2019 Gaia DR2 detection. Tables 3+4: angular separation 23.34672 ± 0.00007 '
     'arcsec, PA = 315.481°, projected separation 5323 AU. Mass 0.730 +0.011/-0.017 Msun, Teff 4571 '
     '+50/-81 K (K3V approx), MG 6.774 +0.158/-0.097 mag. Flags: PRI 2MA BPRP. cpm-index 64. '
     'HAT-P-16 was previously sy_snum = 3 missing 1; B was already in binary_companions from earlier '
     'work, this C row closes the gap.'),

    ('HD 4113', 'B', 'A', 'M0V', 49.009,
     2055, 0.588, false, 3947, false,
     'M-dwarf wide visual companion to HD 4113 A (separate from the T9 brown dwarf HD 4113 C)', 'manual', '2019MNRAS.490.5088M',
     'HD 4113 B: Mugrauer 2019 Gaia DR2 detection. Tables 3+4: angular separation 49.00907 ± 0.00011 '
     'arcsec, PA = 350.337°, projected separation 2055 AU. Mass 0.588 +0.048/-0.023 Msun, Teff 3947 '
     '+198/-71 K (M0V approx), MG 8.117 +0.216/-0.457 mag. Flags: PRI 2MA BPRP. cpm-index 37. The '
     'HD 4113 system already has the T9 brown dwarf HD 4113 C at 22 AU (recorded in migration 058 '
     'from Cheetham et al. 2018); this B row adds the wide M-dwarf stellar companion that completes '
     'the hierarchical triple: HD 4113 A (host of eccentric e=0.90 planet b) + HD 4113 B (wide M0V '
     'at 2055 AU) + HD 4113 C (T9 BD at 22 AU).')
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
