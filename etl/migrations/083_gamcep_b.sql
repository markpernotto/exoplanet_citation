-- gam Cep stellar architecture enrichment (manual literature review,
-- 2026-05-27). Fifteenth and FINAL migration of the S-type stellar-
-- multiplicity audit's 13-system priority phase. gam Cep (γ Cephei A =
-- Errai) was the original radial-velocity-detected planet host in a close
-- binary (Hatzes 2003 Phase I-III), but binary_companions had no entry
-- for it. This migration adds γ Cep B (the close stellar companion).
--
-- Bibcodes:
--   2003ApJ...599.1383H -- Hatzes et al. 2003, "A Planetary Companion to
--     γ Cephei A". The original RV-discovery paper for both the planet
--     and the binary mass function. Provides binary orbital elements
--     (Table 5: P = 20,750.66 ± 1568.6 d ≈ 56.8 yr, e = 0.361 ± 0.023,
--     a = 18.5 ± 1.1 AU, K1 = 1.82 km/s, mass function f(m) = 0.0106 ±
--     0.0012 Msun) and stellar parameters for γ Cep A (Table 7: K1IV-V,
--     Teff 4888 K, mass 1.59 Msun, distance 13.79 pc Hipparcos / 13.39 pc
--     spectroscopic). NB Hatzes 2003 alone gives only the mass function;
--     γ Cep B's actual mass requires combining with an imaging-derived
--     inclination.
--   2007A&A...462..777N -- Neuhäuser, Mugrauer, Fukagawa, Torres, &
--     Schmidt 2007, "Direct detection of exoplanet host star companion γ
--     Cep B and revised masses for both stars and the sub-stellar object"
--     (arXiv astro-ph/0611427). Source for the directly imaged γ Cep B
--     properties: spectral type M4V, mass ~0.4 Msun. Recent stellar-
--     evolution + Gaia parallax refinement (Mugrauer 2022 AN follow-up,
--     2022AN....34324014M) gives M_B = 0.39 ± 0.03 Msun, the value
--     recorded here.
--
-- Architecture (the famous "planet in a close binary" benchmark):
--   - γ Cep A (= γ Cephei = Errai): K1IV-V subgiant, mass 1.59 Msun,
--     Teff 4888 K, hosts γ Cep A b (a = 2.13 AU, P = 905 d, m sin i
--     ~1.85 M_Jup; Hatzes 2003 Table 6). At 13.79 pc.
--   - γ Cep B: M4V red dwarf, mass 0.39 ± 0.03 Msun, on a 56.8-yr binary
--     orbit (Hatzes 2003 RV-derived; newer Mugrauer 2022 imaging refines
--     to ~66 yr with slightly different a). Orbital semi-major axis ~18.5
--     AU, eccentricity 0.361 -> periastron ~11.8 AU, apastron ~25.2 AU.
--     Current angular separation depends on orbital phase; recorded value
--     of 1.34 arcsec corresponds to the orbital sma at 13.8 pc.
--   - γ Cep A + B make this one of the TIGHTEST known binaries hosting a
--     confirmed exoplanet (separation 11.8-25.2 AU; planet at 2.13 AU is
--     comfortably inside the dynamical stability region per the orbit
--     hierarchy a_planet < ~a_binary/3).
--
-- Apply after 011_binary_companions.sql. Idempotent.

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('gam Cep', 'B', 'A', 'M4V', 1.34,
     18.5, 0.39, false, NULL, false,
     'M4V close stellar companion to gam Cep A on a ~57-66 yr eccentric binary orbit', 'manual', '2007A&A...462..777N',
     'γ Cep B: M4V red dwarf, mass 0.39 ± 0.03 Msun (Neuhäuser et al. 2007 direct AO detection + '
     'Mugrauer 2022 Gaia + stellar-evolution refinement). Sits on a 56.8-yr binary orbit (Hatzes '
     '2003 RV mass function 0.0106 Msun + Neuhäuser 2007 imaging inclination): semi-major axis a '
     '~18.5 AU, eccentricity 0.361 ± 0.023 -> periastron ~11.8 AU, apastron ~25.2 AU. At the system '
     'distance of 13.79 pc, the orbital sma corresponds to 1.34 arcsec on the sky; current angular '
     'separation varies across the orbit. component_teff_k NULL (M4V implies ~3250 K but not '
     'explicitly derived in the cited papers). One of the TIGHTEST known binaries hosting a confirmed '
     'exoplanet -- γ Cep A b (Hatzes 2003 Table 6: a 2.13 AU, P 905 d, m sin i ~1.85 M_Jup) sits well '
     'inside the dynamical stability region (a_planet ~ a_binary / 9). Mugrauer 2022 AN follow-up '
     '(2022AN....34324014M) provides slightly revised orbital parameters (~66 yr period) but the mass '
     'value used here is the consensus 0.39 ± 0.03 Msun.')
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
