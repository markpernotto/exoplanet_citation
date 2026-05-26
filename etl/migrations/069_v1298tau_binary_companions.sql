-- V1298 Tau stellar architecture enrichment (manual literature review,
-- 2026-05-26). The catalog carries sy_snum = 3 for V1298 Tau, but our
-- binary_companions table was empty for this host, so the 3D renderer
-- showed it as a single star. This migration closes that gap, adding the
-- three known additional components: the two unresolved spectroscopic
-- components of the wide G0 companion HD 284154, and a SPHERE direct-imaging
-- candidate substellar companion at ~300 AU (not yet confirmed bound).
--
-- Bibcodes (verified via arXiv + Nature Astronomy):
--   2022NatAs...6..232S -- Suárez Mascareño et al. 2022 Nature Astronomy, "Rapid
--     contraction of giant planets orbiting the 20-million-years-old star V1298
--     Tau" (arXiv 2111.09193). Source for HD 284154 separation, spectral type,
--     spectroscopic-binary nature.
--   2023A&A...679A.111S -- Suárez Mascareño et al. 2023, GAPS programme at TNG
--     XLVII, "The unusual formation history of V1298 Tau" (arXiv 2307.08653).
--     Source for the SPHERE direct-imaging candidate substellar companion.
--
-- Architecture summary:
--   - V1298 Tau A (primary, host of 4 transiting planets b/c/d/e). K1, ~1.17 Msun.
--   - HD 284154 A and B: a WIDE G0 visual binary at 97.7 arcsec (~10,600 AU
--     projected) co-moving with V1298 Tau (Gaia DR2). HD 284154 is ITSELF a
--     double-lined spectroscopic binary, decomposed assuming equal-mass /
--     equal-luminosity components in the FIES analysis of Suárez Mascareño 2022.
--     The pair is unresolved spatially at the 97.7" wide separation, so both
--     components are co-located on the sky from V1298 Tau A's perspective.
--   - SPHERE candidate: a faint (∆mag H/K ~ 11.5-11.7) point source detected
--     by Suárez Mascareño 2023 at three SPHERE epochs (2019-11, 2021-10, 2021-12),
--     at ρ = 2.77-2.80 arcsec (~301 AU), PA ~ 344°. Astrometry consistent across
--     epochs but bound-vs-background not yet confirmed; absolute K magnitude
--     ~14.8 at the system distance + 10-30 Myr age implies substellar mass
--     (roughly planetary-mass to low-end brown dwarf, but paper does not quote
--     a retrieved mass). Recorded as TENTATIVE; does NOT increment sy_snum
--     (substellar, unconfirmed).
--
-- Honest provenance gaps: the Suárez Mascareño 2022 paper assumed HD 284154 A
-- and B share mass / metallicity / luminosity in the spectroscopic
-- decomposition but does not quote a numerical mass for either component;
-- a G0 spectral type implies ~1 Msun each but I have not fabricated that
-- value. component_mass_msun and component_teff_k left NULL with notes.
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('V1298 Tau', 'B', 'A', 'G0', 97.7,
     10600, NULL, false, NULL, false,
     'wide G0 visual binary (component A of HD 284154, itself a DLB)', 'manual', '2022NatAs...6..232S',
     'HD 284154 A: warmer (G0) wide visual companion to V1298 Tau A. Projected separation 97.7 arcsec '
     '(~10,600 AU at the 108.5 pc system distance), confirmed as a proper-motion companion via Gaia DR2 '
     '(Suárez Mascareño et al. 2022 Nature Astronomy). HD 284154 is itself a double-lined spectroscopic '
     'binary (HD 284154 A + HD 284154 B); FIES decomposition assumed equal-mass / equal-luminosity '
     'components but did not quote individual mass values, so component_mass_msun is NULL (G0 spectral '
     'type implies ~1 Msun, not recorded). Same age as V1298 Tau (~20 Myr, Group 29 association). '
     'Together, V1298 Tau A + HD 284154 A + HD 284154 B account for the catalog sy_snum = 3.'),

    ('V1298 Tau', 'C', 'A', 'G0', 97.7,
     10600, NULL, false, NULL, false,
     'inner spectroscopic-binary component of HD 284154', 'manual', '2022NatAs...6..232S',
     'HD 284154 B: the second component of the unresolved double-lined spectroscopic binary HD 284154. '
     'Co-located with HD 284154 A at the 97.7" / ~10,600 AU wide separation from V1298 Tau A (the two '
     'are not spatially resolved at that wide separation). Assumed equal-mass / equal-luminosity to A '
     'per the Suárez Mascareño 2022 FIES decomposition; the paper does not quote a spec-binary period or '
     'individual component masses. inner_binary = false because we use that flag for the planet host '
     'system (V1298 Tau A), not for tight binaries within wide companions.'),

    ('V1298 Tau', 'D', 'A', NULL, 2.77,
     301, NULL, false, NULL, false,
     'SPHERE direct-imaging candidate substellar companion (bound not confirmed)', 'manual', '2023A&A...679A.111S',
     'SPHERE point source detected at three epochs (2019-11-18, 2021-10-28, 2021-12-02) by Suárez Mascareño '
     'et al. 2023 (GAPS XLVII). Astrometry across epochs: ρ = 2.77-2.80 arcsec (~301 AU at the system '
     'distance), PA = 344.2-344.5°. Photometry: ∆mag H2 ~11.74, H3 ~11.71, K1 ~11.5-11.6, K2 ~11.2-11.7. '
     'Apparent K ≈ 20 -> absolute M_K ≈ 14.8 at 108.5 pc, implying substellar mass at the 10-30 Myr age '
     '(roughly planetary-mass to low-end brown dwarf, but the paper does not quote a retrieved mass; '
     'component_mass_msun NULL). The 3-epoch consistent astrometry is suggestive of common proper motion '
     'but bound-vs-background is not yet confirmed; recorded as a TENTATIVE substellar candidate. Does '
     'NOT contribute to sy_snum = 3 (substellar, unconfirmed).')
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
