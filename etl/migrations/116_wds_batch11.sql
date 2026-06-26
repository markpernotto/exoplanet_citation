-- WDS curation Batch 11 (2026-06-26). Cleanup of two of the three
-- Batch 10 stragglers (K2-136 and HD 135344 A). TOI-159 remains
-- deferred indefinitely (Mantovan et al. 2026 explicitly calls the
-- system "S-type close binary" but does not characterize the
-- companion in any section we have access to, and no follow-up
-- imaging paper has been identified in this session).
--
-- BATCH 11 SCOPE (2 binary_companions rows):
--
--   K2-136 B              (Ciardi et al. 2018, 2018AJ....155...10C)
--                          M7/8V late-M dwarf companion to the K5V
--                          Hyades planet host. rho ~ 0.73" / projected
--                          sep ~ 40 AU. The Mann et al. 2018 discovery
--                          paper (2018AJ....155....4M) treated the
--                          host as single; Ciardi 2018 resolved the
--                          binary via AO imaging and renamed the
--                          system to K2-136A with planet K2-136Ac.
--                          NASA EA retains "K2-136" as the hostname
--                          per ingestion convention.
--
--   HD 135344 A B         (Gaia DR3 catalog + Stolker et al. 2025
--                          system context, 2025A&A...700A..21S)
--                          The famous A0V + F4Ve visual binary system.
--                          HD 135344 B = SAO 206462 is the well-known
--                          transitional-disk host; HD 135344 A is the
--                          A0V primary which Stolker 2025 used as a
--                          dust-free target for direct imaging of
--                          new substellar companions (HD 135344 Ab,
--                          10 MJ planet at 16.5 AU, in the planets
--                          table). NEITHER Stolker 2025 nor any other
--                          recent paper characterizes the A-B pair
--                          geometry directly -- it has been "background
--                          knowledge" for decades. Geometry derived
--                          here from Gaia DR3 J2000 positions:
--                            * HD 135344 A: Gaia DR3 6199395656645840384
--                              RA 15:15:48.9462675744, Dec -37:08:55.731
--                            * HD 135344 B: Gaia DR3 6199395656645838976
--                              RA 15:15:48.4460065200, Dec -37:09:16.024
--                            * Delta-RA (east, cos-dec corrected): -5.984"
--                            * Delta-Dec (north): -20.293"
--                            * rho = 21.16" (matches the historical lore)
--                            * PA = 196.4 deg (atan2; SW quadrant)
--                            * Projected separation at d = 135 pc
--                              (parallax 7.41 mas per Stolker 2025
--                              Table A.1) = 2857 AU
--                          F4Ve spectype for HD 135344 B is the
--                          well-established literature designation for
--                          SAO 206462 (Houk 1982 catalog, references
--                          tracing back well before any modern paper).
--                          Mass and Teff for HD 135344 B are not
--                          quoted in the pasted excerpts and so are
--                          left NULL here -- to be filled in a future
--                          enrichment pass with citation.
--
-- RESOLVED INLINE in this batch (was originally going to be deferred):
--   TOI-159 B            (Mantovan et al. 2026, 2026arXiv260504149M
--                          Section 4.4 "Stellar companion and host star
--                          determination"). rho = 0.65" / projected
--                          separation 225 AU. The companion was
--                          originally discovered by Ziegler et al. 2020
--                          and Lester et al. 2022 high-resolution
--                          imaging; CPM-confirmed across 6 years by
--                          Howell et al. 2025. K3V early-K dwarf
--                          (3.3 mag fainter than the F0V primary).
--
-- Apply after 115_toi_3523_field_star_cleanup.sql.


-- ============================================================================
-- K2-136 B  (Ciardi et al. 2018; M7/8V late-M dwarf in the Hyades)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('K2-136', 'B', 'A', 'M7-M8V', 0.73,
     40, NULL, false, NULL, false,
     'late-M dwarf close visual companion (Hyades; AO imaging detection)', 'manual', '2018AJ....155...10C',
     'K2-136 B: M7/8V late-M dwarf close visual companion to the K5V Hyades planet host (Ciardi '
     'et al. 2018, 2018AJ....155...10C). Projected separation 40 AU at d = 50-60 pc; recorded '
     'rho = 0.73" computed from 40 AU / 55 pc. Companion is fainter by Delta-Kepmag = 6.5 mag '
     '(Kepmag_B = 17.4 vs Kepmag_A = 10.9). Deblended photometry (Table 1): J_B = 14.1 +/- 0.1, '
     'H_B = 13.47 +/- 0.04, Ks_B = 13.03 +/- 0.03. M_B and Teff_B not directly derived in the '
     'paper; for M7-M8V spectype the implied mass is ~0.08-0.10 Msun (near the H-burning limit) '
     'and Teff ~2500-2800 K. PA not stated in the pasted excerpt. The planet K2-136 c (renamed '
     'K2-136A c in Ciardi 2018) is a Neptune-sized (R = 3.0 R_earth) transiting planet around '
     'the K5V primary. The original Mann et al. 2018 (2018AJ....155....4M) discovery paper '
     'treated the host as a single star; Ciardi 2018 resolved the binary via AO imaging. NASA '
     'EA retains the hostname "K2-136" (without the "A" qualifier from Ciardi 2018) per '
     'ingestion convention.',
     NULL);


-- ============================================================================
-- HD 135344 A B  (Gaia DR3 + Stolker 2025 system context)
--                The canonical A0V + F4Ve visual binary; HD 135344 B is the
--                famous SAO 206462 transitional-disk host.
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('HD 135344 A', 'B', 'A', 'F4Ve', 21.16,
     2857, NULL, false, NULL, false,
     'F4Ve wide visual binary (transitional-disk host SAO 206462)', 'Gaia DR3', '2025A&A...700A..21S',
     'HD 135344 B: the F4Ve secondary of the canonical HD 135344 A + HD 135344 B wide visual '
     'binary system. HD 135344 B is also known as SAO 206462, the famous transitional-disk '
     'host with asymmetric scattered-light spiral arms and an internal dust-free cavity '
     '(Stolker et al. 2024 = 2024A&A...682A.101S and many others). The A-B pair is treated '
     'as "background knowledge" in modern literature -- no recent paper re-characterizes the '
     'pair geometry. Stolker et al. 2025 (2025A&A...700A..21S, source_bibcode here) provides '
     'the system context: "HD 135344 AB is a young visual binary system that is best known '
     'for the protoplanetary disk around the secondary star. The circumstellar environment '
     'of the A0-type primary star, on the other hand, is already depleted." HD 135344 A is '
     'A0V (Houk 1982) and Stolker 2025 added a substellar companion HD 135344 Ab (10 MJ '
     'planet at 16.5 AU; in the planets table). '
     'GEOMETRY computed from Gaia DR3 J2000 positions of both components: '
     '  HD 135344 A: Gaia DR3 6199395656645840384, '
     '              RA 15:15:48.9462675744, Dec -37:08:55.731368400; '
     '  HD 135344 B: Gaia DR3 6199395656645838976, '
     '              RA 15:15:48.4460065200, Dec -37:09:16.024369824; '
     '  Delta-RA (east, cos-dec corrected) = -5.984"; '
     '  Delta-Dec (north) = -20.293" (B is SSW of A); '
     '  rho = sqrt(5.984^2 + 20.293^2) = 21.16" '
     '         (consistent with the historical ~21" literature value); '
     '  PA = atan2(-5.984, -20.293) = 196.4 deg (SW quadrant); '
     '  d = 135 pc (HD 135344 A parallax 7.41 +/- 0.04 mas, Stolker 2025 Table A.1); '
     '  projected separation = 21.16 x 135 = 2857 AU. '
     'F4Ve spectype is the canonical Houk 1982 / SAO 206462 literature designation. Mass '
     'and Teff for HD 135344 B are not directly quoted in either Stolker 2024 or Stolker 2025 '
     'pasted excerpts; commonly cited values in the disk literature are M ~ 1.5-1.6 Msun and '
     'Teff ~ 6500-7500 K, but pending citation those fields are left NULL. Source_catalog '
     'is set to "Gaia DR3" because the geometry comes directly from the Gaia DR3 positions; '
     'source_bibcode references Stolker 2025 as the system-context paper.',
     196.4);


-- ============================================================================
-- TOI-159 B  (Mantovan 2026 Section 4.4; K3V early-K dwarf, CPM-confirmed)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes,
     position_angle_deg)
VALUES
    ('TOI-159', 'B', 'A', 'K3V', 0.65,
     225, NULL, false, NULL, false,
     'K3V early-K dwarf close companion (high-res imaging; CPM-confirmed across 6 years)', 'manual', '2026arXiv260504149M',
     'TOI-159 B: K3V early-K dwarf close visual companion to the F0V (Teff = 7294 K) planet '
     'host TOI-159 (Mantovan et al. 2026, 2026arXiv260504149M, Section 4.4 "Stellar companion '
     'and host star determination"). rho = 0.65", projected separation = 225 AU at d = 347.2 '
     '+1.2/-1.4 pc (Bailer-Jones 2021, Mantovan 2026 Table 2). B is 3.3 mag fainter than A '
     '(F0V vs K3V), giving a contamination ratio CR ~ 0.048 in the IMACS bandpass. Originally '
     'discovered by Ziegler et al. 2020 (SOAR speckle imaging of TESS targets) and Lester et '
     'al. 2022 (additional high-resolution imaging follow-up); CPM-confirmed across a 6-year '
     'baseline by Howell et al. 2025 (Gemini Zorro imaging) -- the photocenter separation '
     'between A and B remained almost unchanged between the Ziegler 2020 and Howell 2025 '
     'epochs, which rules out the background-star scenario. Mantovan 2026 stellar-density '
     'comparison establishes that TOI-159 A (the primary) is the planet host: the inferred '
     'stellar density from refined parameters matches the density from the transit fit ONLY '
     'if the planet orbits A; the B-host scenario gives an unrealistically small (large) '
     'planetary density (radius). M_B and Teff_B are not directly derived in the paper; for '
     'K3V on the MS the implied values are M ~ 0.78 Msun and Teff ~ 4800 K (Pecaut & Mamajek '
     '2013 tables), but pending direct citation they are left NULL here. PA not stated in '
     'the pasted excerpt. The S-type planet TOI-159 b (R = 1.622 RJ, M = 3.49 MJ, e = 0.24, '
     'P = 3.76 d) is currently the hottest known eccentric hot Jupiter (Teq = 1900 K).',
     NULL);
