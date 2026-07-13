BEGIN;

-- Section 1: DELETE SIMBAD crowded-field / chance-alignment companion rows
-- from Kepler-432 and two OGLE microlensing hosts.
--
-- All 12 rows share the same defect: legacy SIMBAD bulk ingest pulled in
-- wide neighbors that appeared close on the sky but are not bound companions.
-- The rationale differs per host and is documented per subsection.
--
-- ---------------------------------------------------------------------------
-- Kepler-432 (K-giant field, Cygnus/Lyra Kepler field)
-- ---------------------------------------------------------------------------
-- Host has Gaia DR3 astrometry: parallax 1.171 +/- 0.010 mas, pmra +4.67,
-- pmdec +9.96 mas/yr. Distinctive positive-both PM signature.
--
-- Each SIMBAD row was matched to a Gaia DR3 source by (separation, PA).
-- All four failed the parallax + PM consistency test by >= 100 sigma in at
-- least one component; three failed by hundreds of sigma in both PM axes.
-- Every candidate drifts SW while Kepler-432 drifts NE, ruling out shared
-- galactic orbit and hence physical binding.
--
-- Row C carried a K1IV spectype in SIMBAD. The classification is a real
-- published characterization of that field star (Gaia G=10.83, brighter than
-- Kepler-432 itself). It is legitimate as a stellar identifier but is not
-- a bound companion to Kepler-432.

DELETE FROM binary_companions
 WHERE hostname = 'Kepler-432'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 4 rows deleted.

-- ---------------------------------------------------------------------------
-- OGLE-2006-BLG-284L A (galactic bulge microlensing host)
-- ---------------------------------------------------------------------------
-- Host has NO Gaia DR3 astrometry (gaia_dr3_id IS NULL). The lens is a bulge
-- L/M dwarf too faint for a Gaia parallax measurement. We therefore cannot
-- do the Gaia-verified PM-mismatch check that discriminated so cleanly for
-- Kepler-CBP and Kepler-432 rows.
--
-- Delete rationale is based on absence of positive evidence for binding
-- combined with the strongest possible field-artifact prior:
--
--   1. Gaia cone search around the host at 25" radius returned ~110 sources,
--      i.e. ~17x the source density of the (already crowded) Kepler field.
--   2. None of the four SIMBAD rows resolves cleanly to a Gaia source at the
--      expected (separation, position angle) combination, suggesting the
--      SIMBAD row coordinates derive from a lower-resolution photometric
--      bulge survey (DENIS or 2MASS-era) rather than a modern astrometric
--      catalog. Our own position anchors are therefore unstable.
--   3. Bennett et al. 2008 (2008ApJ...684..663B), the discovery paper for
--      OGLE-2006-BLG-284L, does not report any imaging characterization of
--      wide bound stellar companions to the lens.
--   4. Separations 12-19" in the galactic bulge are consistent with
--      seeing-limited photometric-survey neighbors in a field where every
--      source has 15+ neighbors within an arcsec.
--
-- This is a weaker verification than the PM-verified Kepler cases but still
-- librarian-defensible: no published characterization of these as bound
-- companions exists, and the field-artifact prior in the bulge is dominant.

DELETE FROM binary_companions
 WHERE hostname = 'OGLE-2006-BLG-284L A'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 4 rows deleted.

-- ---------------------------------------------------------------------------
-- OGLE-2008-BLG-092L (galactic bulge microlensing host)
-- ---------------------------------------------------------------------------
-- Host has NO Gaia DR3 astrometry. Same as above, no baseline for the
-- Gaia PM-mismatch check.
--
-- Poleski et al. 2014 (2014ApJ...795...42P), the discovery paper, DOES
-- report a bound stellar/brown-dwarf companion to the lens. Critically, that
-- companion has a projected separation of ~54 AU (= ~3x the planet's ~18 AU
-- projected separation), which at a bulge lens distance of 3-6 kpc
-- corresponds to ~10-20 milliarcsec on the sky. The Poleski companion is
-- essentially coincident with the primary in any resolved imaging; it is
-- detected only via a secondary microlensing subevent, not by direct imaging.
--
-- The four SIMBAD debt rows sit at 2.3", 3.6", 3.9", and 7.9" separations.
-- These are 100-800x wider than the real bound companion and therefore
-- CANNOT be the Poleski companion. Their Gaia DR3 astrometry confirms they
-- are four unrelated bulge field stars:
--   B (2.3"): plx=0.21+/-0.10, pmra=-3.64, pmdec=-4.78
--   C (3.6"): plx=0.06+/-0.13, pmra=-1.81, pmdec=-6.77
--   D (3.9"): plx=0.26+/-0.06, pmra=+2.48, pmdec=-5.54
--   E (7.9"): plx=0.56+/-0.32, pmra=-1.83, pmdec=-3.47
-- Parallaxes and PMs are scattered; they are not comoving with each other,
-- ruling out a hierarchical bound quadruple.
--
-- Delete all four; the real Poleski companion is added below in Section 2.

DELETE FROM binary_companions
 WHERE hostname = 'OGLE-2008-BLG-092L'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;

-- Expected: 4 rows deleted.
-- Section 1 total expected: 12 rows deleted.

-- ---------------------------------------------------------------------------
-- Section 2: INSERT the real Poleski 2014 stellar/brown-dwarf companion
-- for OGLE-2008-BLG-092L.
--
-- Reported in the discovery paper as a bound companion detected via a
-- secondary microlensing subevent ~653 days after the primary lens event
-- (Table 1 "secondary subevent"). The paper reports the projected separation
-- of the companion as ~3x the planet's projected separation of ~18 AU,
-- placing the companion at ~54 AU projected. The nature (low-mass star vs.
-- brown dwarf) is left ambiguous in the paper; component_mass_msun and
-- component_spectype are left NULL rather than guessed.

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
) VALUES (
    'OGLE-2008-BLG-092L',
    'B',
    'A',
    FALSE,
    NULL,          -- ~10-20 mas at bulge distance, not directly resolvable
    54.0,          -- projected separation, ~3x the planet's ~18 AU
    NULL,          -- lensing model does not constrain sky-plane PA
    NULL,          -- Poleski 2014 leaves stellar vs BD ambiguous
    NULL,
    'manual',
    '2014ApJ...795...42P',
    'Poleski et al. 2014: stellar or brown-dwarf companion detected via secondary microlensing subevent ~653 days after the primary lens event. Projected separation ~54 AU (roughly 3x the planet''s ~18 AU projected separation). Nature (low-mass star vs BD) not resolved by the paper. Companion is at ~10-20 milliarcsec on the sky at bulge lens distance; not directly resolvable by imaging.'
);

-- Expected: 1 row inserted.

-- ---------------------------------------------------------------------------
-- Section 3: INSERT the AO-imaged bound M-dwarf companion to Kepler-432,
-- from Quinn et al. 2015 (2015ApJ...803...49Q).
-- ---------------------------------------------------------------------------
-- Quinn et al. 2015 abstract explicitly reports: "adaptive optics imaging
-- revealed a nearby (0.87 arcsec), faint companion (Kepler-432B) that is a
-- physically bound M dwarf." The designation Kepler-432B is used in the
-- discovery paper itself.
--
-- Projected separation in AU derived from the paper's host distance
-- (Table 3: 870 +/- 20 pc): 0.87 arcsec * 870 pc = ~757 AU projected.
--
-- Component mass and position angle are not quoted in the abstract and not
-- surfaced in the tables provided at draft time; if the paper's AO imaging
-- section reports them, they can be added in a follow-up UPDATE. Spectype
-- is recorded as 'M' since the paper's wording ("M dwarf") does not commit
-- to a subclass.

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
) VALUES (
    'Kepler-432',
    'B',
    'A',
    FALSE,
    0.87,          -- Quinn 2015 abstract, AO imaging
    757.0,         -- derived: 0.87" * 870 pc host distance (paper Table 3)
    NULL,          -- not quoted in abstract; may be in paper's imaging section
    NULL,          -- M dwarf; no numeric mass quoted in abstract
    'M',           -- from the paper's wording "M dwarf"
    'manual',
    '2015ApJ...803...49Q',
    'Quinn et al. 2015: adaptive-optics imaging companion Kepler-432B at 0.87 arcsec, physically bound M dwarf. Projected separation ~757 AU (derived from host distance 870 +/- 20 pc, Table 3). Position angle and exact mass/subclass not quoted in abstract; add via UPDATE if surfaced later.'
);

-- Expected: 1 row inserted.
-- Migration 120 total expected: 12 rows deleted, 2 rows inserted.

COMMIT;
