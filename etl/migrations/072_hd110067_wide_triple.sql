-- HD 110067 stellar architecture enrichment (manual literature review,
-- 2026-05-26). Third migration of the S-type stellar-multiplicity audit
-- campaign (after migrations 070 WASP-12 + HAT-P-8, 071 LTT 1445 A). HD 110067
-- is our showcase 6-planet 1:2:3 resonance system; the catalog sy_snum = 3
-- but binary_companions was empty. Apps & Luque 2023 RNAAS demonstrated that
-- the K0 V planet host has a wide companion HD 110106 that is itself a near-
-- equal-mass spectroscopic binary, making the system a wide hierarchical
-- triple. Same architecture pattern as V1298 Tau + HD 284154 (migration 069).
--
-- Bibcode:
--   2023RNAAS...7..264A -- Apps & Luque 2023, RNAAS 7, 264, "HD 110067 is a
--     wide hierarchical triple system" (arXiv 2312.04599). Short Research
--     Note that corrects the original discovery paper's "single star" claim.
--
-- Architecture (Apps & Luque 2023):
--   - HD 110067 A: K0 V planet host (sextuplet of sub-Neptunes in 1:2:3
--     mean-motion resonance chain). V = 8.4 mag, distance 32.22 pc (Gaia DR3
--     parallax). Gaia DR3 RUWE = 0.943 (well-behaved single).
--   - HD 110106 A and B: a wide co-moving K3 V companion at 415.701 ± 0.001
--     arcsec (PA = 148.1°) from HD 110067, epoch 2016.0; projected separation
--     13,394 ± 10 AU. HD 110106 is ITSELF a double-lined spectroscopic
--     binary with period P = 2899.2 ± 20.5 d (~7.94 years), RV semi-amplitude
--     ratio K1/K2 = 0.843 ± 0.056 -> "nearly equal binary" per the paper.
--     HD 110106 Gaia RUWE = 14.878 (>> 1.4 threshold) confirms the unseen
--     spec-binary companion. Individual component masses not given; K3 V
--     typical is ~0.74 Msun, so each is roughly that.
--
-- Wide-pair orbital period not determined; future Gaia epoch astrometry would
-- enable a joint spec+astrom fit.
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 110067', 'B', 'A', 'K3V', 415.701,
     13394, NULL, false, NULL, false,
     'wide K3 V visual binary (component A of HD 110106, itself a near-equal SB)', 'manual', '2023RNAAS...7..264A',
     'HD 110106 A: K3 V primary of the wide visual companion HD 110106. Apps & Luque 2023 RNAAS: '
     'angular separation 415.701 ± 0.001 arcsec at PA = 148.1° (epoch 2016.0), projected separation '
     '13,394 ± 10 AU at the 32.22 pc system distance. V = 8.8 mag. HD 110106 is a double-lined '
     'spectroscopic binary itself (RV K1/K2 = 0.843 ± 0.056, period 2899.2 ± 20.5 d ≈ 7.94 yr; '
     'paper concludes "it seems likely that HD 110106 is a nearly equal binary"). Gaia DR3 RUWE = '
     '14.878 for HD 110106 confirms an unseen companion (the SB secondary); RUWE = 0.943 for '
     'HD 110067 itself is well-behaved single. Individual masses not quoted; K3 V typical is '
     '~0.74 Msun, so both A and B are roughly that, but I have not recorded numerical values. '
     'Together HD 110067 A + HD 110106 A + HD 110106 B account for the catalog sy_snum = 3.'),

    ('HD 110067', 'C', 'A', 'K3V', 415.701,
     13394, NULL, false, NULL, false,
     'spectroscopic-binary partner of HD 110106 A (unresolved on the sky at the wide separation)', 'manual', '2023RNAAS...7..264A',
     'HD 110106 B: the second component of the HD 110106 spectroscopic binary. Co-located with '
     'HD 110106 A at the 415.7 arcsec / 13,394 AU wide separation from HD 110067 (the two SB '
     'components are not spatially resolved at that separation; the binary nature comes from '
     'RV decomposition and the Gaia astrometric noise). Near-equal mass to A (K1/K2 = 0.843 ± '
     '0.056), so K3 V approximate, ~0.74 Msun. inner_binary = false because that flag is for the '
     'planet host system (HD 110067 A), not for tight binaries within wide companions.')
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
