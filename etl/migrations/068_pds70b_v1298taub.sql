-- Atmosphere backlog batch 8: two single-planet young-system deep dives
-- (manual literature review, 2026-05-26). PDS 70 b completes the molecule
-- layer for a planet we already covered for accretion in migration 033;
-- V1298 Tau b is a young (10-20 Myr) sub-Neptune progenitor with the richest
-- single-planet spectrum we have harvested in any recent batch.
--
-- PDS 70 c was on the shortlist but skipped silently per user decision: no
-- dedicated atmosphere paper exists yet (JWST/NIRISS AMI re-detected c at 4.83
-- um but the flux is ambiguous between dust enshrouding, heated CO emission,
-- and Paschen-alpha accretion; not a clean molecule detection).
--
-- Bibcodes:
--   PDS 70 b -- Hsu et al. 2024, "PDS 70b Shows Stellar-like Carbon-to-oxygen
--     Ratio", ApJL 977, L47 -> 2024ApJ...977L..47H. Verified via arXiv +
--     IOPscience.
--   V1298 Tau b -- Barat et al. 2025, "A metal-poor atmosphere with a hot
--     interior for a young sub-Neptune progenitor: JWST/NIRSpec transmission
--     spectrum of V1298 Tau b", accepted AJ via DOI 10.3847/1538-3881/adec89.
--     Formal AJ bibcode not yet issued; cite arXiv eprint 2025arXiv250708837B
--     for now (update post-publication).
--
-- Results in brief:
--   PDS 70 b -- Keck/KPIC high-resolution cross-correlation (Hsu 2024 Figure 1
--     + Summary): CO detected at 3.8 sigma, H2O at 3.5 sigma, combined CO+H2O
--     template at 4.2 sigma. Star-only-fit rejected by Delta chi^2 = 772 and
--     log10 Bayes factor 344.9 (planet+star vs star-only). PetitRADTRANS
--     atmospheric retrieval (Table 2): C/O = 0.28 +0.20/-0.12 (95% upper limit
--     <= 0.63), [C/H] = -0.2 +0.8/-0.5 dex, BT-Settl Teff = 1103 +134/-75 K,
--     v sin i < 29 km/s at 95% (consistent with non-detection of spin given
--     ongoing accretion and the 2.7 R_Jup radius from Wang 2020). Barycentric-
--     corrected planet RV = -1.7 +3.4/-5.2 km/s, 2.5 sigma different from the
--     host star RV +6.65 km/s. The headline interpretation: PDS 70 b's C/O is
--     consistent with the HOST STAR (C/O ~0.44, [Fe/H] = -0.11 +/- 0.19),
--     much lower than the outer-disk gas-phase C/O ≳ 1, suggesting the planet
--     accreted bulk C+O from solids (dust+ice) rather than gas-phase volatiles,
--     OR formed before the disk gas was C-enriched.
--   V1298 Tau b -- Barat et al. 2025 (HST/WFC3 + JWST/NIRSpec G395H, combined
--     1.0-5.2 um transmission, free-chemistry PICASO retrieval): the richest
--     atmosphere spectrum in this entire backlog, six molecules detected. CO2
--     at 35 sigma, H2O at 30 sigma, CO at 10 sigma, CH4 at 6 sigma (Figure 3
--     caption + abstract), SO2 at 4 sigma, OCS at 3.5 sigma (abstract; SO2/OCS
--     also shown in Figure 3 legend). Mostly clear atmosphere, large scale
--     height ~1500 km, H/He dominated. Retrieval (Table 1): log Z = 0.6
--     +0.4/-0.6 (~4x solar; PICASO grid prefers ~11x), C/O = 0.22 +0.06/-0.05
--     (sub-solar), mass 12+/-1 M_earth (free; grid 15+/-1.7), log cloud opacity
--     -2.77 +/- 0.23. SELF-CONSISTENT GRID prefers a HOT INTERIOR Tint =
--     500+/-50 K (paper's headline) with vertical mixing log Kzz = 7 +/- 0.9
--     cm^2/s; this internal T is inconsistent with the ~100-200 K expected from
--     evolutionary models at this age (10-20 Myr) and is what's required to
--     suppress methane to its observed ~7-sigma-below-equilibrium abundance.
--     [CH4] log VMR = -6.2 +0.3/-0.5 (abstract value, not in pasted Table 1).
--
-- Apply after 008_atmospheres.sql and 024_planet_derived_measurements.sql.
-- Idempotent (ON CONFLICT DO UPDATE).

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('PDS 70 b', 'CO', 'detected', 'Keck/KPIC', '2024ApJ...977L..47H', 3.8,
     'Hsu et al. 2024 Figure 1 + Summary: CCF S/N = 3.8 sigma for CO molecular template (Sonora-Bobcat) '
     'against KPIC R~35,000 K-band spectra. Star-only-fit validation: Delta chi^2 = 772 and log10 Bayes '
     'factor 344.9 favour planet+star over star-only -> the CCF peak is genuinely planetary. Combined '
     'CO+H2O template peaks at 4.2 sigma. PDS 70 b is one of only two confirmed FORMING planets so '
     'molecule detections at planetary mass are rare; this is the first KPIC atmospheric measurement '
     'of either PDS 70 planet.'),

    ('PDS 70 b', 'H2O', 'detected', 'Keck/KPIC', '2024ApJ...977L..47H', 3.5,
     'Hsu et al. 2024 Figure 1 + Summary: CCF S/N = 3.5 sigma for H2O molecular template. Combined '
     'with the CO 3.8-sigma detection (above), drives the petitRADTRANS atmospheric retrieval that '
     'constrains C/O and [C/H] (see derived rows). Combined CO+H2O template at 4.2 sigma.'),

    ('V1298 Tau b', 'CO2', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 35.0,
     'Barat et al. 2025 Figure 3 caption + abstract: CO2 detected at 35 sigma via PICASO free-chemistry '
     'retrieval on combined HST/WFC3 + JWST/NIRSpec G395H transmission spectrum (1.0-5.2 um). The 4.3 '
     'um CO2 fundamental dominates the spectrum. Highest-significance molecule in the system; the '
     'CO2 + H2O + CO inventory anchors the ~solar metallicity retrieval.'),

    ('V1298 Tau b', 'H2O', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 30.0,
     'Barat et al. 2025 Figure 3 caption + abstract: H2O detected at 30 sigma via PICASO free retrieval. '
     'Multiple H2O features in the HST/WFC3 (1.1-1.7 um) + JWST NIRSpec G395H ranges. Mostly clear '
     'atmosphere with ~1500 km scale height.'),

    ('V1298 Tau b', 'CO', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 10.0,
     'Barat et al. 2025 Figure 3 caption + abstract: CO detected at 10 sigma via PICASO free retrieval. '
     'CO feature visible in NIRSpec G395H near 4.7-5.0 um.'),

    ('V1298 Tau b', 'CH4', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 6.0,
     'Barat et al. 2025 Figure 3 caption + abstract: CH4 detected at 6 sigma via PICASO free retrieval, '
     'log VMR [CH4] = -6.2 +0.3/-0.5. HEADLINE DISEQUILIBRIUM RESULT: this is ~7 sigma LOWER than the '
     'equilibrium-chemistry prediction for the planet''s 670 K equilibrium temperature, which is what '
     'drives the inferred ~500 K internal temperature + log Kzz ~7 vertical mixing (see derived rows).'),

    ('V1298 Tau b', 'SO2', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 4.0,
     'Barat et al. 2025 abstract: SO2 detected at 4 sigma. Photochemical product of H2O and H2S (or '
     'SO) under high-UV irradiation, similar to WASP-39 b. SO2 contribution shown in Figure 3 legend.'),

    ('V1298 Tau b', 'OCS', 'detected', 'JWST/NIRSpec G395H + HST/WFC3', '2025arXiv250708837B', 3.5,
     'Barat et al. 2025 abstract: carbonyl sulfide (OCS) detected at 3.5 sigma. Another sulfur-bearing '
     'photochemical product. OCS contribution shown in Figure 3 legend. OCS in particular is a strong '
     'tracer of sulfur cycling in irradiated atmospheres.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('PDS 70 b', 'C/O', 0.28, 0.20, 0.12, 'ratio',
     'Keck/KPIC petitRADTRANS atmospheric retrieval, chemically self-consistent',
     '2024ApJ...977L..47H',
     'Hsu et al. 2024 Table 2 retrieval: C/O = 0.28 +0.20/-0.12 (95% upper limit <= 0.63). STELLAR-LIKE '
     '(host star PDS 70 A C/O ~0.44; Cridland 2023), much LOWER than the outer-disk gas-phase C/O >= 1. '
     'Two interpretations: (1) the planet accreted bulk C+O from SOLIDS (dust+ice) instead of gas-phase '
     'volatiles, or (2) the planet formed BEFORE the disk gas was C-enriched. The two scenarios cannot '
     'be distinguished without dust C/O and time-dependent dust-to-gas ratio data.'),

    ('PDS 70 b', 'metallicity', -0.2, 0.8, 0.5, 'dex',
     'Keck/KPIC petitRADTRANS atmospheric retrieval (free chemistry)',
     '2024ApJ...977L..47H',
     'Hsu et al. 2024 Table 2 retrieval: [C/H] = -0.2 +0.8/-0.5 dex. Consistent within 1 sigma with '
     'the host star [Fe/H] = -0.11 +/- 0.19 dex (Steinmetz 2020), the same stellar-similarity story '
     'as the C/O ratio above. Stored as `metallicity` with unit `dex` (the established convention).'),

    ('PDS 70 b', 'rotation_velocity', 29, 0, 29, 'km_s',
     'Keck/KPIC line-broadening fit (BT-Settl forward model), upper limit',
     '2024ApJ...977L..47H',
     'Hsu et al. 2024 Table 1: v sin i < 29 km/s at 95% confidence (UPPER LIMIT). BT-Settl forward-'
     'model fit (Table 2) returns v sin i = 9 +9/-7 km/s, "consistent with non-detection of spin." '
     'Expected for a still-accreting young planet with a large inflated radius (2.7 +0.4/-0.3 R_Jup; '
     'Wang 2020) - rotation has not had time to spin up. Recorded as UPPER LIMIT: value 29 with '
     'unc_hi = 0 and unc_lo = 29 encodes "<= 29 km/s" (same convention as WASP-127 b C/O upper limit '
     'in migration 066).'),

    ('PDS 70 b', 'effective_temperature', 1103, 134, 75, 'K',
     'Keck/KPIC BT-Settl forward-model fit (Hsu 2024 Table 2)',
     '2024ApJ...977L..47H',
     'Hsu et al. 2024 Table 2 BT-Settl: Teff = 1103 +134/-75 K. Earlier Wang et al. 2020 SED fit gave '
     '1204 +52/-53 K - the two agree within 1 sigma but the Hsu KPIC value has larger uncertainty. '
     'Recorded as the more recent "this work" value; Wang 2020 noted in the curator note.'),

    ('PDS 70 b', 'radial_velocity', -1.7, 3.4, 5.2, 'km_s',
     'Keck/KPIC retrieval RV (barycentric-corrected, MJD 60453.27578)',
     '2024ApJ...977L..47H',
     'Hsu et al. 2024 Table 1 + Table 2 retrieval: planetary radial velocity RV = -1.7 +3.4/-5.2 km/s, '
     'barycentric-corrected. 2.5 sigma different from the host star RV during the same epoch '
     '(+6.65 +0.14/-0.22 km/s; Hsu 2024 Table 1). The first direct planetary-RV measurement for any '
     'still-forming planet via high-res cross-correlation. New quantity: radial_velocity '
     '(km_s) - distinct from stellar RV (which lives in the host-star tables); this is the planet''s '
     'own line-shifted RV.'),

    ('V1298 Tau b', 'internal_temperature', 500, 50, 50, 'K',
     'JWST + HST PICASO 1D self-consistent grid retrieval',
     '2025arXiv250708837B',
     'Barat et al. 2025 Table 1 (PICASO self-consistent grid): T_int > 500 +/- 50 K (the paper''s '
     'HEADLINE "hot interior" result; ATMO grid prefers 600 K). New quantity: internal_temperature '
     '(K) - distinct from effective / dayside / nightside temperatures, this is the interior '
     'temperature driving vertical mixing. INCONSISTENT with the ~100-200 K expected from evolutionary '
     'models at the system''s 10-20 Myr age, and required to explain the observed ~7-sigma-below-'
     'equilibrium CH4 abundance.'),

    ('V1298 Tau b', 'metallicity', 0.6, 0.4, 0.6, 'dex',
     'JWST + HST PICASO free-chemistry retrieval (log Z relative to solar)',
     '2025arXiv250708837B',
     'Barat et al. 2025 Table 1 (PICASO free): log Z = 0.6 +0.4/-0.6 (~4x solar). PICASO self-'
     'consistent grid prefers higher: log Z = 1.05 +/- 0.2 (~11x solar); ATMO grid 1.0 (~10x). The '
     'paper''s framing is "metal-poor" relative to the sub-Neptune population expectation, hence the '
     'title. With the H/He-dominated atmosphere + 1500 km scale height + 12 M_earth mass, this is '
     'consistent with the gas-dwarf formation scenario for sub-Neptunes.'),

    ('V1298 Tau b', 'C/O', 0.22, 0.06, 0.05, 'ratio',
     'JWST + HST PICASO free-chemistry retrieval',
     '2025arXiv250708837B',
     'Barat et al. 2025 Table 1 (PICASO free): C/O = 0.22 +0.06/-0.05 (sub-solar). PICASO grid '
     'agrees (0.23 +/- 0.08); ATMO grid slightly higher (0.35). The sub-solar C/O is consistent '
     'with formation interior to the H2O snowline.'),

    ('V1298 Tau b', 'vertical_mixing_kzz', 7, 0.9, 0.9, 'log_cm2_s',
     'JWST + HST PICASO 1D self-consistent grid retrieval',
     '2025arXiv250708837B',
     'Barat et al. 2025 Table 1 (PICASO self-consistent grid): log Kzz = 7 +/- 0.9 cm^2/s (ATMO grid '
     'gives log Kzz < 8 as upper limit). Required alongside the ~500 K internal T to suppress the '
     'observed CH4 abundance ~7 sigma below equilibrium chemistry. New quantity: vertical_mixing_kzz '
     '(log_cm2_s, i.e. log10 of the eddy diffusion coefficient in cm^2/s, the standard literature '
     'convention).'),

    ('V1298 Tau b', 'mass', 12, 1, 1, 'M_earth',
     'JWST + HST PICASO free-chemistry retrieval (transmission-spectrum-inferred)',
     '2025arXiv250708837B',
     'Barat et al. 2025 Table 1 (PICASO free): mass = 12 +/- 1 M_earth. PICASO grid: 15 +/- 1.7. ATMO '
     'grid: 15. Inferred from the planetary radius + atmospheric scale height + retrieval; distinct '
     'from prior RV-mass measurements (e.g. Suarez Mascareno 2022, Sikora 2023 reported masses in the '
     '17-20 M_earth range). Recorded as "this work" transmission-spectrum mass; the RV measurements '
     'remain authoritative for orbit-derived dynamical masses.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
