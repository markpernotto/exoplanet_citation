-- LTT 1445 A stellar architecture enrichment (manual literature review,
-- 2026-05-26). Second migration of the S-type stellar-multiplicity audit
-- campaign (after migration 070 WASP-12 + HAT-P-8). Catalog sy_snum = 3 for
-- LTT 1445 A but binary_companions was empty. The triple is well-characterized
-- at 6.87 pc -- the closest M-dwarf transiting multi-planet system known.
-- Already-relevant context: LTT 1445 A b's atmosphere was harvested in
-- migration 063 (rocky-JWST batch); we now add its stellar architecture.
--
-- Bibcode:
--   2019AJ....158..152W -- Winters et al. 2019 AJ 158, 152, "Three Red Suns
--     in the Sky: A Transiting, Terrestrial Planet in a Triple M Dwarf System
--     at 6.9 Parsecs" (arXiv 1906.10147). The discovery + characterization
--     paper. Component masses derived from photometric deblending of the BC
--     pair using HST/NICMOS + AO + Speckle astrometry (Tables 1 + 2); BC
--     orbital fit (preliminary, period 36.2 yr) in Table 3.
--
-- Architecture (Winters 2019 Table 1):
--   - LTT 1445 A: M3V (per abstract; the paper text classifies it as M3V),
--     0.257 ± 0.014 Msun, 0.268 ± 0.027 Rsun, transiting planet host (b, c).
--   - LTT 1445 B: 0.215 ± 0.014 Msun, 0.236 ± 0.027 Rsun (M4.5V approx;
--     spectype inferred from mass-radius, not explicitly assigned in the
--     paper's Table 1).
--   - LTT 1445 C: 0.161 ± 0.014 Msun, 0.197 ± 0.027 Rsun (M5V approx, same
--     caveat).
--
-- Geometry:
--   - BC pair on the sky: orbital semi-major axis = 1.159 ± 0.076 arcsec
--     (Table 3) -> ~8.1 AU at 6.87 pc; current angular separation has varied
--     from 0.07-1.34 arcsec across 2003-2014 (Table 2) as B and C orbit each
--     other. Period 36.2 ± 5.3 yr, eccentricity 0.50 ± 0.11, inclination
--     89.64° (nearly edge-on).
--   - BC pair offset from A: ~7.1 arcsec on the sky (computed from the RA/Dec
--     coordinates in Table 1: ΔRA ≈ 5.0", ΔDec = -5.0"), corresponding to
--     ~49 AU projected separation. Earlier search-summary "~34 AU" appears
--     to have been approximate; the Winters 2019 RA/Dec yield 7.1" / ~49 AU.
--     A-BC orbital period not constrained in Winters 2019 (the BC orbit is the
--     paper's headline; A-BC is a long-period outer orbit estimated at ~250 yr).
--   - System distance: 6.87 pc (parallax 145.55 mas for A; 142.57 mas for BC).
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('LTT 1445 A', 'B', 'A', 'M4.5V', 7.1,
     49, 0.215, false, NULL, false,
     'mid-M-dwarf in a tight BC pair, outer companion to LTT 1445 A', 'manual', '2019AJ....158..152W',
     'LTT 1445 B: 0.215 ± 0.014 Msun, 0.236 ± 0.027 Rsun (Winters et al. 2019 Table 1, deblended from '
     'joint BC photometry). Spectral type M4.5V is approximate (inferred from the mass-radius and '
     'photometric colors; not explicitly classified in Winters 2019 Table 1). Position derived from '
     'the BC pair coordinates relative to A (Table 1 RA/Dec): ~7.1 arcsec on the sky, ~49 AU '
     'projected at the 6.87 pc system distance. B and C themselves are a tight binary: orbital '
     'semi-major axis 1.159 ± 0.076 arcsec (~8.1 AU), period 36.2 ± 5.3 yr, eccentricity 0.50 ± '
     '0.11, inclination 89.64° (near-edge-on; Winters 2019 Table 3 preliminary orbit). The current '
     'angular separation of B and C varies from 0.07-1.34 arcsec across 2003-2014 observations as '
     'they orbit (Table 2). System at 6.87 pc is the closest known M-dwarf transiting multi-planet '
     'system.'),

    ('LTT 1445 A', 'C', 'A', 'M5V', 7.1,
     49, 0.161, false, NULL, false,
     'mid-to-late M-dwarf, BC pair partner with B, outer companion to LTT 1445 A', 'manual', '2019AJ....158..152W',
     'LTT 1445 C: 0.161 ± 0.014 Msun, 0.197 ± 0.027 Rsun (Winters et al. 2019 Table 1, deblended from '
     'joint BC photometry). Spectral type M5V approximate (same caveat as B). Co-located with B on '
     'the sky at ~7.1 arcsec from A (~49 AU projected). C is the lightest of the three components; '
     'masses run A (0.257) > B (0.215) > C (0.161) Msun.')
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
