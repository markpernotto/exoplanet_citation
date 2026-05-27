-- WASP-76 + HAT-P-57 + WASP-2 stellar architecture enrichment (manual
-- literature review, 2026-05-26). Sixth migration of the S-type stellar-
-- multiplicity audit campaign. WASP-76 is item #6 in the 13-system priority
-- list (its B companion); HAT-P-57 (missing-2) and WASP-2 (missing-1) are
-- "free wins" covered by the same Bohn 2020 SPHERE high-contrast imaging
-- survey paper. All three companions have status C (confirmed by proper-
-- motion analysis at >=5σ) in Bohn 2020 Table 3.
--
-- Bibcode:
--   2020A&A...635A..73B -- Bohn et al. 2020 A&A 635, A73, "A multiplicity
--     study of transiting exoplanet host stars. I. High-contrast imaging
--     with VLT/SPHERE" (arXiv 2001.08224). SPHERE/IRDIS K-band imaging of
--     45 TEP hosts. Status flag in Table 3 distinguishes confirmed
--     companions (C, via 5σ proper-motion test), ambiguous (A, PM test
--     inconclusive), and background (B, confirmed unbound). Only C-status
--     companions are recorded here.
--
-- Architecture (from Bohn 2020 Table 3):
--   - WASP-76 B: K dwarf at 0.436 ± 0.003 arcsec (PA 215.9°) from WASP-76 A;
--     mass 0.79 ± 0.03 Msun, Teff 4824 +128/-132 K (K3-K4V approx), ∆K = 2.30
--     ± 0.05 mag. Projected separation ~85 AU at 194.5 pc. Discovered by
--     Wöllert & Brandner 2015, confirmed by Ngo et al. 2016, characterized by
--     Bohn 2020. The atmospheric "iron rain" hot Jupiter WASP-76 b
--     (migration 032) orbits A; the K-dwarf companion at ~85 AU is close
--     enough to dynamically influence the planet over Gyr timescales.
--   - HAT-P-57 B + C: TWO confirmed M-dwarf companions, both at ~2.7-2.8
--     arcsec from A (PA 226-232°). Bohn 2020 Table 3: CC1 0.59 ± 0.01 Msun,
--     Teff 3942 +50/-37 K, sep 2.688" (~752 AU at 279.9 pc); CC2 0.50 ± 0.01
--     Msun, Teff 3684 +40/-23 K, sep 2.807" (~786 AU). HAT-P-57 was already
--     classified sy_snum = 3 in NASA EA but binary_companions was empty;
--     this migration closes the gap entirely (missing-2 → missing-0).
--   - WASP-2 B: confirmed M-dwarf at 0.710 ± 0.003 arcsec (PA 104.9°) from
--     WASP-2 A; mass 0.40 ± 0.02 Msun, Teff 3523 +28/-19 K (M3V approx), ∆K
--     = 2.55 ± 0.07. Projected separation ~109 AU at 153.2 pc.
--
-- Skipped (ambiguous "A" status in Bohn 2020 Table 3, won't manufacture):
--   - WASP-130 CC1 (0.30 Msun candidate at 0.60") -- p_B = 0.22% but PM
--     test inconclusive at 5σ. Will revisit when proper-motion baseline
--     improves.
--   - WASP-20 CC1 (0.88 Msun candidate at 0.26") -- p_B = 0.004% (very
--     unlikely background) but still officially "A". Strong candidate;
--     could be promoted with a later proper-motion confirmation paper.
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('WASP-76', 'B', 'A', 'K3V', 0.436,
     85, 0.79, false, 4824, false,
     'K-dwarf wide visual companion to hot-Jupiter host WASP-76 A', 'manual', '2020A&A...635A..73B',
     'WASP-76 B: K3V approximate (Teff 4824 +128/-132 K), mass 0.79 ± 0.03 Msun, ∆K = 2.30 ± 0.05 mag '
     '(Bohn et al. 2020 Table 3). Confirmed companion (Status C via SPHERE/IRDIS proper-motion analysis '
     'at >=5σ; epoch 2016-11-07). Position: separation 0.436 ± 0.003 arcsec, PA = 215.9 ± 0.4° -> ~85 AU '
     'projected at the 194.5 pc system distance. Original lucky-imaging detection: Wöllert & Brandner '
     '2015; bound-status confirmation: Ngo et al. 2016. Hot-Jupiter host WASP-76 A has the iron-rain '
     'atmosphere recorded in migration 032; the K-dwarf at ~85 AU is dynamically relevant on Gyr '
     'timescales for the inner planet''s orbit.'),

    ('HAT-P-57', 'B', 'A', 'M0V', 2.688,
     752, 0.59, false, 3942, false,
     'M-dwarf wide visual companion to hot-Jupiter host HAT-P-57 A, tight pair with C', 'manual', '2020A&A...635A..73B',
     'HAT-P-57 B: M0V approximate (Teff 3942 +50/-37 K, mass 0.59 ± 0.01 Msun, ∆K = 2.91 ± 0.05; Bohn '
     'et al. 2020 Table 3). Confirmed companion (Status C). Position: separation 2.688 ± 0.004 arcsec, '
     'PA = 231.8 ± 0.1° -> ~752 AU projected at 279.9 pc system distance. Two epochs (2016-10-09 + '
     '2017-05-15) agree to <1 mas. B and C are a tight near-coplanar pair: angular separation between '
     'B and C is only ~0.12 arcsec (B sep 2.688, C sep 2.807, PA diff ~5°), corresponding to ~33 AU '
     'projected. Together HAT-P-57 A + B + C close the catalog sy_snum = 3 (which was previously '
     'rendering as a single star, binary_companions empty).'),

    ('HAT-P-57', 'C', 'A', 'M1V', 2.807,
     786, 0.50, false, 3684, false,
     'M-dwarf wide visual companion to hot-Jupiter host HAT-P-57 A, tight pair with B', 'manual', '2020A&A...635A..73B',
     'HAT-P-57 C: M1V approximate (Teff 3684 +40/-23 K, mass 0.50 ± 0.01 Msun, ∆K = 3.47 ± 0.05; Bohn '
     'et al. 2020 Table 3). Confirmed companion (Status C). Position: separation 2.807 ± 0.004 arcsec, '
     'PA = 226.9 ± 0.1° -> ~786 AU projected at 279.9 pc. Tight pair with B at ~33 AU projected '
     'between them; mass ratio C/B = 0.85 (near-equal-mass).'),

    ('WASP-2', 'B', 'A', 'M3V', 0.710,
     109, 0.40, false, 3523, false,
     'M-dwarf wide visual companion to hot-Jupiter host WASP-2 A', 'manual', '2020A&A...635A..73B',
     'WASP-2 B: M3V approximate (Teff 3523 +28/-19 K, mass 0.40 ± 0.02 Msun, ∆K = 2.55 ± 0.07; Bohn '
     'et al. 2020 Table 3). Confirmed companion (Status C). Position: separation 0.710 ± 0.003 arcsec, '
     'PA = 104.9 ± 0.2° -> ~109 AU projected at the 153.2 pc system distance.')
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
