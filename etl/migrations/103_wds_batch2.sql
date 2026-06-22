-- WDS curation Batch 2 (2026-06-19). Second of nine planned passes
-- against the 82-host WDS gap list. Six systems, all curated from
-- abstracts and tables already pasted during the Batch 1 prep work
-- (Wittrock et al. 2016 and Ginski et al. 2016 are both survey papers
-- spanning multiple hosts). No fresh paper lookups required.
--
-- Systems and citations:
--   HD 164509   -- Wittrock et al. 2016 (2016AJ....152..149W). Same
--                  Gemini-North DSSI speckle survey paper as HD 2638
--                  (Batch 1). HD 164509's companion is a NEW discovery
--                  in Wittrock 2016; rho = 0.697", projected separation
--                  36.5 AU, mass 0.416 Msun, Teff 3450 K -> late M dwarf.
--   Kepler-21   -- Ginski et al. 2016 (2016MNRAS.457.2173G). CONFIRMED
--                  co-moving at 4.0 sigma confidence across two AstraLux
--                  epochs (2013-07-02 and 2014-08-20). rho = 0.767",
--                  projected ~87 AU, mass 0.42 Msun.
--   Kepler-68   -- Ginski 2016. CONFIRMED co-moving at 2.1 sigma across
--                  two epochs (2013-07-02 and 2014-08-19). rho = 10.95",
--                  projected ~1479 AU, mass 0.175 Msun.
--   HD 116029   -- Ginski 2016. CANDIDATE (single epoch 2013-06-30,
--                  co-moving not yet determined). rho = 1.387",
--                  projected ~171 AU, mass 0.18 Msun.
--   HAT-P-18    -- Ginski 2016. CANDIDATE (single detection epoch
--                  2013-07-01; co-moving not yet determined despite
--                  multiple imaging epochs). rho = 2.643", projected
--                  ~439 AU, mass 0.099 Msun (M dwarf / BD boundary).
--   Kepler-42   -- Ginski 2016. CANDIDATE (single epoch 2013-07-01,
--                  co-moving not yet determined). rho = 5.206",
--                  projected ~201 AU, mass 0.082 Msun (very late M /
--                  hydrogen-burning boundary).
--
-- Candidate vs confirmed handling follows the V1298 Tau D precedent
-- (migration 069) and HD 43691 precedent (migration 101): we curate
-- candidates with TENTATIVE notes that explicitly flag CPM status,
-- so the data is durable but a future migration can remove rows that
-- turn out to be background sources.
--
-- Distances come from Ginski Table 5 (which cites the underlying
-- source per host, mostly van Leeuwen 2007 Hipparcos reductions or
-- the host's discovery paper for Kepler systems); see notes per row.
--
-- Citation surfacing caveat (per feedback-cite-every-surfaced-datum
-- memory, 2026-06-19): the BinaryCompanion API model and
-- /api/planets/{pl_name}/companions endpoint currently do NOT expose
-- source_bibcode to the UI. These rows land correctly in the DB with
-- citations but those citations don't reach the frontend until a
-- follow-up patch lifts source_bibcode through the model and endpoint
-- and the planet card UI renders it. That patch is queued and lands
-- before any further new-feature work.
--
-- Apply after 102_ph1_designation_reconcile.sql. Idempotent.


-- ============================================================================
-- HD 164509  (Wittrock 2016 NEW DISCOVERY, same paper as HD 2638)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 164509', 'B', 'A', 'M', 0.697,
     36.5, 0.416, false, 3450, false,
     'late M-dwarf companion (Gemini-North DSSI speckle, new discovery in Wittrock 2016)', 'manual', '2016AJ....152..149W',
     'HD 164509 B: late M-dwarf companion, NEW DISCOVERY in Wittrock et al. 2016 (the same Gemini-North DSSI '
     'speckle survey paper that refined HD 2638 B in migration 101). Geometry: rho = 0.697 +/- 0.002" at 692 + '
     '880 nm, projected separation 36.5 +/- 1.9 AU at the d = 52.4 pc host distance (derived from the rho-to-AU '
     'conversion in the Wittrock abstract). M = 0.416 +/- 0.007 Msun, Teff = 3450 +/- 7 K from stellar isochrone '
     'modeling. Late M dwarf classification. Unlike HD 2638 B (previously detected by Roberts 2015), HD 164509 B '
     'has no prior-detection literature; Wittrock 2016 is the discovery cite. Survey covered "almost a hundred" '
     'planet-host stars; only HD 2638 and HD 164509 yielded detections.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- Kepler-21  (Ginski 2016 CONFIRMED co-moving)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Kepler-21', 'B', 'A', 'M', 0.7671,
     87, 0.42, false, NULL, false,
     'M dwarf companion (AstraLux lucky imaging, CONFIRMED co-moving 4.0 sigma)', 'manual', '2016MNRAS.457.2173G',
     'Kepler-21 B: M-dwarf companion, CONFIRMED co-moving at 4.0 sigma confidence by Ginski et al. 2016 across two '
     'AstraLux epochs at Calar Alto 2.2 m (2013-07-02 and 2014-08-20). Astrometry: rho = 0.7671 +/- 0.0062" / PA = '
     '129.74 +/- 0.46 deg (2013); rho = 0.7739 +/- 0.0099" / PA = 129.53 +/- 0.63 deg (2014). Photometry: delta i = '
     '5.9 (+4.2, -1.0) mag (2013); upper limit < 8.1 mag (2014). Projected separation ~87 AU at d = 112.9 +/- 7.9 '
     'pc (Ginski Table 5, citing van Leeuwen 2007). Mass derived from photometric absolute SDSS-i magnitude: M = '
     '0.42 (+0.14, -0.32) Msun (Ginski Table 6). One of the 4 newly confirmed companions in Ginski 2016''s 60-host '
     'AstraLux survey (alongside HD 197037, HD 217786, Kepler-68). PA captured in notes pending position_angle_deg '
     'backfill.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- Kepler-68  (Ginski 2016 CONFIRMED co-moving)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Kepler-68', 'B', 'A', 'M', 10.953,
     1479, 0.175, false, NULL, false,
     'wide M-dwarf companion (AstraLux lucky imaging, CONFIRMED co-moving 2.1 sigma)', 'manual', '2016MNRAS.457.2173G',
     'Kepler-68 B: M-dwarf companion, CONFIRMED co-moving at 2.1 sigma confidence by Ginski et al. 2016 across two '
     'AstraLux epochs at Calar Alto 2.2 m (2013-07-02 and 2014-08-19). Astrometry: rho = 10.953 +/- 0.034" / PA = '
     '145.39 +/- 0.20 deg (2013); rho = 10.979 +/- 0.030" / PA = 145.43 +/- 0.18 deg (2014) -- excellent inter-epoch '
     'agreement on both rho and PA. Photometry: delta i = 6.569 +/- 0.073 mag (2013) and 6.641 +/- 0.075 mag (2014). '
     'Projected separation ~1479 AU at d = 135 +/- 10 pc (Ginski Table 5, citing Gilliland et al. 2013). Mass from '
     'photometric absolute SDSS-i magnitude: M = 0.175 (+0.013, -0.010) Msun (Ginski Table 6). System age 6.3 +/- '
     '1.7 Gyr (Gilliland 2013). One of the 4 newly confirmed companions in Ginski 2016''s 60-host AstraLux survey. '
     'PA captured in notes pending position_angle_deg backfill.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HD 116029  (Ginski 2016 CANDIDATE)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HD 116029', 'B', 'A', 'M', 1.3871,
     171, 0.18, false, NULL, false,
     'AstraLux lucky-imaging candidate companion (single-epoch, CPM not yet confirmed)', 'manual', '2016MNRAS.457.2173G',
     'HD 116029 B: TENTATIVE late-M-dwarf candidate companion. Single-epoch detection by Ginski et al. 2016 at '
     'Calar Alto 2.2 m AstraLux (2013-06-30, retried 2014-08-20 also). Astrometry: rho = 1.3871 +/- 0.0058", PA = '
     '209.11 +/- 0.28 deg. Photometry: delta i = 8.8 +/- 1.8 mag (large uncertainty -> mass error band is wide). '
     'Projected separation ~171 AU at d = 123.2 +/- 10.7 pc (Ginski Table 5, citing van Leeuwen 2007). Mass M = '
     '0.18 (+0.21, -0.07) Msun from photometric absolute SDSS-i magnitude (Ginski Table 6) ASSUMING physical '
     'association. co-moving status in Ginski Table 3 is "-" (not yet determined). Recorded TENTATIVE per the '
     'V1298 Tau D precedent (migration 069) and HD 43691 precedent (migration 101): geometry is honest, '
     'physical-pair confirmation pending. System age 3.5 +/- 0.5 Gyr (Bonfanti et al. 2015). PA captured in '
     'notes pending position_angle_deg backfill.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- HAT-P-18  (Ginski 2016 CANDIDATE)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('HAT-P-18', 'B', 'A', 'M', 2.643,
     439, 0.0994, false, NULL, false,
     'AstraLux lucky-imaging candidate companion (M-dwarf / BD boundary; CPM not yet confirmed)', 'manual', '2016MNRAS.457.2173G',
     'HAT-P-18 B: TENTATIVE candidate companion at the late-M / brown-dwarf boundary. Single detection epoch by '
     'Ginski et al. 2016 at Calar Alto 2.2 m AstraLux (2013-07-01, despite imaging follow-ups 2014-08-19 and '
     '2014-08-20 per Ginski Table 1). Astrometry: rho = 2.643 +/- 0.014", PA = 185.72 +/- 0.33 deg. Photometry: '
     'delta i = 7.19 +/- 0.12 mag. Projected separation ~439 AU at d = 166 +/- 9 pc (Ginski Table 5, citing '
     'Hartman et al. 2011a). Mass M = 0.0994 (+0.0022, -0.0016) Msun from photometric absolute SDSS-i magnitude '
     '(Ginski Table 6); this is RIGHT at the hydrogen-burning limit (~0.075 Msun), so HAT-P-18 B is a very late M '
     'dwarf or low-mass brown dwarf candidate depending on the true mass. co-moving status in Ginski Table 3 is '
     '"-" (not yet determined). Recorded TENTATIVE. System age 12.4 +/- 6.4 Gyr (Hartman et al. 2011a) -- wide age '
     'error makes mass-from-photometry less constraining. PA captured in notes.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;


-- ============================================================================
-- Kepler-42  (Ginski 2016 CANDIDATE)
-- ============================================================================
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('Kepler-42', 'B', 'A', NULL, 5.206,
     202, 0.0819, false, NULL, false,
     'AstraLux lucky-imaging candidate companion (very low mass, near hydrogen-burning limit; CPM not yet confirmed)', 'manual', '2016MNRAS.457.2173G',
     'Kepler-42 B: TENTATIVE candidate companion at or near the hydrogen-burning limit. Single-epoch detection '
     'by Ginski et al. 2016 at Calar Alto 2.2 m AstraLux (2013-07-01). Astrometry: rho = 5.206 +/- 0.017", PA = '
     '118.93 +/- 0.21 deg. Photometry: delta i = 4.157 +/- 0.082 mag. Projected separation ~202 AU at d = 38.7 '
     '+/- 6.3 pc (Ginski Table 5, citing Muirhead et al. 2012). Mass M = 0.0819 (+0.0035, -0.0029) Msun from '
     'photometric absolute SDSS-i magnitude (Ginski Table 6); this is within 5 percent of the canonical 0.075 Msun '
     'hydrogen-burning limit, so Kepler-42 B sits at the M-dwarf / brown-dwarf boundary. Spectral type left NULL '
     '(very late M / L). co-moving status in Ginski Table 3 is "-" (not yet determined). Recorded TENTATIVE. '
     'System age 5.0 +/- 1.0 Gyr (Muirhead et al. 2012). Note: Kepler-42 itself is a very low-mass M-dwarf host '
     '(M_star ~ 0.13 Msun per Muirhead), so a B companion at 0.082 Msun makes the system mass ratio close to '
     '1:0.6. PA captured in notes.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    component_spectype    = EXCLUDED.component_spectype,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    component_teff_k      = EXCLUDED.component_teff_k,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes;
