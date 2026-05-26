-- Kepler-444 stellar architecture enrichment (manual literature review,
-- 2026-05-26). Fourth migration of the S-type stellar-multiplicity audit
-- campaign (after 070 WASP-12+HAT-P-8, 071 LTT 1445 A, 072 HD 110067).
-- Kepler-444 is the 11.2 ± 1.0 Gyr-old K0 V planet host featured in our
-- multi-planet collection (5 sub-Earth-sized planets in a tight inner system,
-- Campante et al. 2015). Catalog sy_snum = 3 but binary_companions empty.
-- Dupuy et al. 2016 fully solves the architecture: an M-dwarf pair (BC) on
-- a HIGHLY ECCENTRIC outer orbit that periodically passes within ~5 AU of A
-- (the "truncated disk" framing for why the planets are so tightly packed).
--
-- Bibcode:
--   2016ApJ...817...80D -- Dupuy et al. 2016 ApJ 817, 80,
--     "Orbital Architectures of Planet-Hosting Binaries. I. Forming Five
--     Small Planets in the Truncated Disk of Kepler-444A" (arXiv 1512.04559).
--     5 epochs of Keck NIRC2 AO astrometry + HIRES RVs that resolve the BC
--     pair spectroscopically (Table 3), driving an MCMC orbit fit (Table 4).
--
-- Architecture (Dupuy 2016 Table 4 + notes):
--   - Kepler-444 A: K0 V, 0.76 ± 0.04 Msun (Campante 2015 asteroseismic), the
--     planet host (5 planets: b, c, d, e, f).
--   - Kepler-444 B: ~0.29 ± 0.03 Msun M-dwarf (Delfosse 2000 mass-magnitude;
--     approximate spectype M3.5V from mass).
--   - Kepler-444 C: ~0.25 ± 0.03 Msun M-dwarf (Delfosse 2000; ~M4V approx).
--   - BC pair: too tight for AO resolution (orbital semi-major axis ~0.3 AU
--     per Dupuy/follow-ups); RV-resolved in Table 3.
--   - A-BC outer orbit: orbital semi-major axis a = 36.7 +0.7/-0.9 AU,
--     period 198 +8/-9 yr, eccentricity e = 0.864 ± 0.023, inclination
--     90.4° (near edge-on). Periastron approach a(1-e) = 5.0 +0.9/-1.0 AU
--     -- the BC pair sweeps within ~5 AU of A every ~200 years, which
--     dynamically truncates the protoplanetary disk and explains why all 5
--     planets are inside ~0.1 AU.
--   - Distance: 35.7 pc (Hipparcos, fixed in the orbit fit).
--
-- Current astrometry (Dupuy 2016 Table 1): ρ = 1843 mas, PA = 253.258°
-- (averaged over 2013-2015 epochs). Current PROJECTED separation = 1.843" *
-- 35.7 pc = 66 AU, which is near the orbit's apastron a(1+e) = 68 AU (the
-- BC pair is near maximum distance from A at the observation epochs).
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Kepler-444', 'B', 'A', 'M3.5V', 1.843,
     66, 0.29, false, NULL, false,
     'tight M-dwarf pair partner, outer companion to K0 V host Kepler-444 A on a highly eccentric orbit', 'manual', '2016ApJ...817...80D',
     'Kepler-444 B: 0.29 ± 0.03 Msun M-dwarf (Dupuy et al. 2016 Table 4 notes, derived from Delfosse 2000 '
     'mass-magnitude relation; spectype M3.5V inferred from mass, not explicitly classified). Co-located '
     'with C on the sky (BC pair too tight for AO resolution; spectroscopically resolved via Table 3 RVs, '
     'orbital semi-major axis ~0.3 AU). The recorded values are the CURRENT projected separation: 1843 ± '
     '0.4 mas at PA = 253.258° (averaged over 5 Keck NIRC2 epochs 2013-2015) -> ~66 AU at 35.7 pc. '
     'OUTER A-BC ORBITAL parameters (Table 4 MCMC): semi-major axis a = 36.7 +0.7/-0.9 AU, period 198 '
     '+8/-9 yr, eccentricity 0.864 ± 0.023 (HIGHLY ECCENTRIC), inclination 90.4° (near edge-on). '
     'Periastron approach a(1-e) = 5.0 +0.9/-1.0 AU -> the BC pair sweeps within ~5 AU of A every ~200 '
     'yr, dynamically truncating the disk and explaining the tightly-packed 5-planet inner system. '
     'Current separation (~66 AU) is near apastron a(1+e) = 68 AU. System age 11.2 ± 1.0 Gyr (Campante '
     '2015 asteroseismic).'),

    ('Kepler-444', 'C', 'A', 'M4V', 1.843,
     66, 0.25, false, NULL, false,
     'tight M-dwarf pair partner (paired with B), outer companion to K0 V host Kepler-444 A', 'manual', '2016ApJ...817...80D',
     'Kepler-444 C: 0.25 ± 0.03 Msun M-dwarf (Dupuy 2016 Table 4 notes, Delfosse 2000 mass-magnitude; '
     '~M4V approx). Co-located with B on the sky at the AB position (1843 mas, PA 253.258°), ~66 AU '
     'current projected from A. BC pair too tight for AO resolution (orbital sma ~0.3 AU); RV-resolved '
     'in Dupuy 2016 Table 3. Same A-BC outer orbit caveat as B (a = 36.7 AU, P = 198 yr, e = 0.864, '
     'periastron 5 AU). C is the lighter of the M-dwarf pair (0.25 vs 0.29 Msun).')
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
