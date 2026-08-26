BEGIN;

-- Migration 121: SIMBAD citation-debt pass, 3-row-tier cleanup for
-- HD 18599, Kepler-1063, Kepler-108, and Kepler-477. Deletes 12 SIMBAD
-- rows across the four hosts, plus inserts two rows for the newly
-- verified HD 18599 wide bound-binary tertiary pair.
--
-- All four hosts were audited via Gaia DR3 astrometric consistency in
-- the same manner as migrations 119 (Kepler CBP cluster) and 120
-- (Kepler-432 + OGLE hosts). Per-host rationale documented below.
--
-- ===========================================================================
-- Section 1: DELETE crowded-field / duplicate SIMBAD rows.
-- ===========================================================================
--
-- ---------------------------------------------------------------------------
-- HD 18599 (nearby K2V, ~38.6 pc, distinctive PM signature)
-- ---------------------------------------------------------------------------
-- HD 18599 (Gaia DR3 4728513943538448512) has parallax 25.885 +/- 0.013 mas,
-- pmra -36.66, pmdec +50.56 mas/yr. The three SIMBAD debt rows for this host
-- all sat at ~87-88 arcsec, PA ~182°, essentially the same position on the
-- sky. That single position is real, but SIMBAD had it recorded three times
-- under different aliases (e.g. Tycho, 2MASS, Gaia DR1 all catalogued the
-- same star). Our ingest picked up each SIMBAD record as a separate row.
--
-- Gaia DR3 resolves what SIMBAD had as one blob into TWO real sources at
-- that position:
--   Ba = Gaia DR3 4728513630006428800 at 87.37", PA 181.85°, G=9.75
--   Bb = Gaia DR3 4728513634300803968 at 88.24", PA 181.95°, G=10.30
-- Both share HD 18599's parallax within ~1-6 sigma, and their PMs are
-- consistent with a tight visual binary orbiting each other around a
-- shared center of mass that itself matches HD 18599's PM. They are only
-- ~1 arcsec apart from each other on the sky, and their bound-pair
-- relationship is confirmed independently in El-Badry, Rix & Heintz 2021
-- (2021MNRAS.506.2269E) with R_chance_align = 1.13e-11, binary_type MSMS,
-- sep_AU 34.4. Deleting the three SIMBAD placeholders and inserting Ba +
-- Bb via Section 2 below.
--
-- Note: El-Badry 2021 does NOT include HD 18599 A itself in their catalog
-- (likely rejected by their brightness/RUWE quality cuts at G=8.74). The
-- wider linkage of the (Ba+Bb) pair to HD 18599 A as a tertiary is an
-- atlas-side finding derived from Gaia DR3 astrometric consistency during
-- this audit.

DELETE FROM binary_companions
 WHERE hostname = 'HD 18599'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 3 rows deleted.

-- ---------------------------------------------------------------------------
-- Kepler-1063 (Kepler field, ~518 pc)
-- ---------------------------------------------------------------------------
-- Kepler-1063 (Gaia DR3 2052800269327720832) has parallax 1.931 +/- 0.084
-- mas, pmra -8.54, pmdec -14.90 mas/yr. Its close AO companion at 1.112"
-- (Mugrauer et al. 2019, 2019MNRAS.490.5088M) is already properly cited
-- in binary_companions and not touched by this migration.
--
-- The three SIMBAD debt rows are wide (114-187 arcsec) and were matched
-- by (separation, PA) to Gaia DR3 sources. All three fail the parallax
-- or PM consistency check:
--   C (114.5", PA 21.4°)  = Gaia 2052806179202719360, pmra Δ 87σ, pmdec Δ 128σ
--   D (165.2", PA 300.3°) = Gaia 2052801270059972352, plx Δ 4.2σ, pmdec Δ 87σ
--   E (187.3", PA 10.8°)  = Gaia 2052807042496056064, pmra Δ 134σ, pmdec Δ 186σ
-- Row D carries a K3V spectype in SIMBAD and row E carries G5. Those are
-- legitimate photometric classifications of real characterized field
-- stars, but neither is bound to Kepler-1063.

DELETE FROM binary_companions
 WHERE hostname = 'Kepler-1063'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 3 rows deleted.

-- ---------------------------------------------------------------------------
-- Kepler-108 (Kepler field, ~530 pc, TTV multi-planet system)
-- ---------------------------------------------------------------------------
-- Kepler-108 (Gaia DR3 2080062630081883264) has degraded Gaia astrometry:
-- parallax 1.893 +/- 0.254 mas, pmra 0.088 +/- 0.329, pmdec 1.084 +/- 0.410.
-- The large uncertainties reflect blending with a Gaia source at 1.04"
-- (Gaia DR3 2080062630080517376, G=13.36). AO/speckle-era work would
-- have listed that 1.04" source as a bound stellar companion, but Gaia
-- refutes it: the source has clean astrometry with parallax 0.99 +/- 0.017
-- mas (~1000 pc), placing it at nearly 2x Kepler-108's distance. The
-- "companion" is a chance-alignment background star, not physically
-- bound. This finding is documented here for the future record; the
-- 1.04" source is NOT currently in binary_companions and is not being
-- added.
--
-- The three SIMBAD debt rows at 104-193" all fail the parallax or PM
-- check. Kepler-108's inflated PM uncertainties make the sigma numbers
-- look softer than for other hosts (5-10σ instead of 100+σ), but the
-- discrimination is still decisive:
--   B (104", PA 311.1°) = Gaia 2128101117723777152 (best-fit, +2" +3° off),
--                        Δplx 6.8σ, Δpmra 5.1σ, Δpmdec 6.5σ
--   C (160", PA 98.7°)  = Gaia 2080063832671380352, Δpmra 28σ
--   D (193", PA 137.4°) = Gaia 2080062286483138944, Δpmra 10.6σ

DELETE FROM binary_companions
 WHERE hostname = 'Kepler-108'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 3 rows deleted.

-- ---------------------------------------------------------------------------
-- Kepler-477 (Kepler field, ~471 pc, planet host is fainter component B
--             of a resolved AO binary per Mugrauer et al. 2019)
-- ---------------------------------------------------------------------------
-- Kepler-477 is a resolved AO binary (Mugrauer et al. 2019,
-- 2019MNRAS.490.5088M). Both stars are in Gaia DR3 with clean and
-- essentially identical astrometry (parallax ~2.13 mas, pmra ~-29,
-- pmdec ~-12), confirming they are bound to each other. Naming per
-- Mugrauer: planet host = Kepler-477 B (fainter, Gaia G ~14.55);
-- companion = Kepler-477 A (brighter, G ~14.11, spectype G5V,
-- mass 0.859 Msun). Our binary_companions row for the Mugrauer
-- companion is already properly cited and not touched by this migration.
--
-- The three SIMBAD debt rows for Kepler-477:
--   B (1.22", PA 32.75°) is the SAME PHYSICAL PAIR as the already-cited
--     Mugrauer 2019 companion, catalogued by SIMBAD with the opposite
--     naming convention (SIMBAD: "B is companion of A"; Mugrauer:
--     "A is companion of B"). The 180° PA flip (212.7° in Mugrauer vs
--     32.75° in SIMBAD) is exactly what you get from measuring from
--     the other star. Delete as duplicate ingest.
--   C (167.3", PA 344.1°) = Gaia 2102506445539585920, Δpmra 38σ,
--     with anomalously large astrometric errors on the source itself
--     that make parallax uninformative. Field star.
--   D (193.1", PA 154.4°) = Gaia 2102504452674731136, Δpmra 632σ,
--     Δpmdec 335σ. Decisive field star.

DELETE FROM binary_companions
 WHERE hostname = 'Kepler-477'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 3 rows deleted.
-- Section 1 total expected: 12 rows deleted (3 per host, 4 hosts).

-- ===========================================================================
-- Section 2: INSERT the two components of HD 18599's bound wide-binary
-- tertiary pair (Ba and Bb).
-- ===========================================================================
-- Ba + Bb is a bound MS+MS binary per El-Badry, Rix & Heintz 2021
-- (2021MNRAS.506.2269E), catalog binary_type MSMS, R_chance_align 1.13e-11,
-- sep_AU 34.4. Verified directly by loading the El-Badry catalog FITS from
-- Zenodo (10.5281/zenodo.4435257) and grepping for both Gaia DR3 source_ids
-- as source_id1 / source_id2.
--
-- The wider linkage to HD 18599 A as a tertiary is derived from Gaia DR3
-- astrometric consistency in this audit (shared parallax within a few
-- sigma; PMs consistent after accounting for Ba+Bb orbital motion around
-- their common center of mass matching HD 18599 A's PM). HD 18599 A itself
-- is not in the El-Badry catalog (likely excluded by their quality cuts
-- at G=8.74); the tertiary linkage is therefore an atlas-side finding.
-- The notes field spells this out so future readers can distinguish what
-- El-Badry documents (the Ba+Bb pair) from what the atlas contributed
-- (the wider linkage to A).
--
-- Projected separation in AU derived from HD 18599's parallax (25.885 mas,
-- distance ~38.63 pc):
--   Ba: 87.37" x 38.63 pc = 3375 AU
--   Bb: 88.24" x 38.63 pc = 3409 AU

INSERT INTO binary_companions (
    hostname,
    component_designation,
    primary_designation,
    inner_binary,
    separation_arcsec,
    separation_au,
    position_angle_deg,
    component_mass_msun,
    component_spectype,
    source_catalog,
    source_bibcode,
    notes
) VALUES
(
    'HD 18599',
    'Ba',
    'A',
    FALSE,
    87.37,
    3375.0,
    181.85,
    NULL,       -- G=9.75; MS type per El-Badry binary_type MSMS
    NULL,
    'manual',
    '2021MNRAS.506.2269E',
    'One component of a bound MS+MS visual binary. El-Badry, Rix & Heintz 2021 catalog the tight (Ba+Bb) pair itself as bound with R_chance_align 1.13e-11, sep_AU 34.4, binary_type MSMS. Gaia DR3 source_id 4728513630006428800; verified directly against the catalog file. The wider linkage of the (Ba+Bb) pair to HD 18599 A as a tertiary is derived from Gaia DR3 astrometric consistency in the atlas SIMBAD citation-debt audit (shared parallax, PM consistent with tight visual binary motion around a common center of mass matching HD 18599 A). HD 18599 A itself is not in the El-Badry catalog, so this tertiary linkage is not attributable to that paper. Projected separation 3375 AU from HD 18599 A distance 38.63 pc.'
),
(
    'HD 18599',
    'Bb',
    'A',
    FALSE,
    88.24,
    3409.0,
    181.95,
    NULL,       -- G=10.30; MS type per El-Badry binary_type MSMS
    NULL,
    'manual',
    '2021MNRAS.506.2269E',
    'Companion of Ba (Gaia DR3 4728513630006428800) in a bound MS+MS visual binary per El-Badry, Rix & Heintz 2021 catalog (R_chance_align 1.13e-11, sep_AU 34.4, binary_type MSMS). Gaia DR3 source_id 4728513634300803968; verified directly against the catalog file. The wider linkage of the (Ba+Bb) pair to HD 18599 A as a tertiary is derived from Gaia DR3 astrometric consistency in the atlas SIMBAD citation-debt audit; see Ba notes for the full attribution split. Projected separation 3409 AU from HD 18599 A distance 38.63 pc.'
);

-- Expected: 2 rows inserted.
-- Migration 121 total expected: 12 rows deleted, 2 rows inserted.

COMMIT;
