-- 128_cd35_2722_reclassification.sql
-- Follow NASA EA's reclassification of the CD-35 2722 system and repair the
-- data that migration 126 attached to the old catalog row.
--
-- What changed upstream (nightly diff, 2026-09-04 06:02 UTC):
--   REMOVED  CD-35 2722 b    the 37 MJup brown dwarf, listed as a planet of
--                            the M dwarf CD-35 2722 (Wahhaj et al. 2011).
--   NEW      CD-35 2722 B b  the Hoy et al. 2026 satellite, now catalogued as
--                            a planet of host CD-35 2722 B (the brown dwarf;
--                            L4.5 V, 0.035 Msun), sy_snum = 2, discovery
--                            2026Natur.655..865H, P 171.11 d, a 0.2 au,
--                            e 0.27, m sin i 292.4 Mearth (the paper's
--                            favoured 1-body fit).
--
-- Migration 126 was written against the June 2026 snapshot and keyed its rows
-- to `CD-35 2722 b`, so they no longer attach to any catalog planet. Keeping
-- them would also count the object twice (NASA's planet row plus our
-- satellite row). Decision (2026-09-27): follow NASA EA's classification.
-- The Atlas audits the catalog rather than overriding it, and the paper
-- itself quotes the IAU definition under which a planetary-mass object
-- orbiting a brown dwarf is a planet. planet_satellites stays, empty, for
-- exomoon candidates around catalog planets.
--
-- The paper's disfavoured 2-body alternative (171 d + 87 d near 2:1) is not
-- given a structured home; the planet links the discovery paper, where it is
-- described.
--
-- Apply after 127; idempotent on re-run.

BEGIN;

-- 1. Remove only what 126 attached to the removed catalog row ----------------
--    The publications row for 2026Natur.655..865H stays: the citation
--    resolver has linked it as the discovery paper of CD-35 2722 B b.
DELETE FROM planet_satellites
 WHERE pl_name = 'CD-35 2722 b'
   AND bibcode = '2026Natur.655..865H';

DELETE FROM planet_publications
 WHERE pl_name = 'CD-35 2722 b'
   AND role = 'characterization'
   AND contribution = 'satellite'
   AND pub_id = (SELECT pub_id FROM publications WHERE bibcode = '2026Natur.655..865H');

-- 2. System distance for the new host -----------------------------------------
--    The brown dwarf has no Gaia DR3 source and NASA EA left sy_dist empty, so
--    the scene had no distance at all (the companion query crashed on it).
--    The system distance is the primary's: CD-35 2722 A = Gaia DR3
--    2885863400349980288, parallax 44.7203 +/- 0.0128 mas (already in
--    host_stars_gaia under hostname 'CD-35 2722'). Inverse parallax is exact
--    to well under 0.1% at this fractional error.
INSERT INTO host_distances_manual
    (hostname, distance_pc, distance_pc_err, source_bibcode, source_note)
VALUES
    ('CD-35 2722 B', 22.3612, 0.0064, '2023A&A...674A...1G',
     'Distance of the primary CD-35 2722 A (Gaia DR3 2885863400349980288, parallax '
     '44.7203 +/- 0.0128 mas, inverse parallax). The brown-dwarf host CD-35 2722 B has no '
     'Gaia DR3 source; it is a common-proper-motion companion of A (Wahhaj et al. 2011).')
ON CONFLICT (hostname) DO UPDATE SET
    distance_pc     = EXCLUDED.distance_pc,
    distance_pc_err = EXCLUDED.distance_pc_err,
    source_bibcode  = EXCLUDED.source_bibcode,
    source_note     = EXCLUDED.source_note,
    retrieved_at    = now();

-- 3. The M-dwarf primary as a cited companion of CD-35 2722 B ----------------
--    Without a row the nightly SIMBAD enricher would resolve this new
--    sy_snum = 2 host and could insert an uncited stub; a curated row makes
--    the host "already fetched", and the enricher's upsert never overwrites
--    a row with a source_bibcode (migration 125).
--
--    Source: Wahhaj et al. 2011 (2011ApJ...729..139W), Gemini/NICI.
--      Table 2 astrometry of B relative to A:
--        2009-01-06  3.172 +/- 0.005"  PA 244.13 +/- 0.25 deg
--        2010-01-10  3.137 +/- 0.005"  PA 243.10 +/- 0.25 deg  (adopted in Table 1)
--      Table 1 properties of A: M1Ve, 0.4 +/- 0.05 Msun, Teff 3680 +/- 100 K;
--      projected separation 67 +/- 4 AU at their 21.3 pc.
--
--    Position angle convention: rows record the companion as seen from the
--    planet's host (as for Kepler-477 in migration 121). The host here is B,
--    so A's PA from B is the paper's B-from-A PA flipped by 180 deg:
--    243.10 - 180 = 63.10 deg.
--    separation_au left NULL: the renderer derives it from arcsec x the
--    system distance (22.36 pc above), giving ~70 AU; the paper's 67 AU uses
--    the pre-Gaia 21.3 pc.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation,
     separation_arcsec, position_angle_deg,
     component_mass_msun, component_teff_k, component_mag_v, component_spectype,
     source_catalog, source_bibcode, inner_binary)
VALUES
    ('CD-35 2722 B', 'A', 'B',
     3.137, 63.10,
     0.4, 3680, NULL, 'M1Ve',
     'manual', '2011ApJ...729..139W', false)
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation = EXCLUDED.primary_designation,
    separation_arcsec   = EXCLUDED.separation_arcsec,
    position_angle_deg  = EXCLUDED.position_angle_deg,
    component_mass_msun = EXCLUDED.component_mass_msun,
    component_teff_k    = EXCLUDED.component_teff_k,
    component_spectype  = EXCLUDED.component_spectype,
    source_catalog      = EXCLUDED.source_catalog,
    source_bibcode      = EXCLUDED.source_bibcode,
    inner_binary        = EXCLUDED.inner_binary,
    retrieved_at        = now();

COMMIT;

-- Then run the citation seed so both new data sources are linked to the
-- planet (python -m etl.seed_followup_citations): Wahhaj 2011 as
-- binary_companion, Gaia DR3 as distance.
--
-- Verify:
--   SELECT component_designation, separation_arcsec, position_angle_deg, source_bibcode
--     FROM binary_companions WHERE hostname = 'CD-35 2722 B';                     -- expect A, 3.137, 63.10
--   SELECT count(*) FROM planet_satellites WHERE pl_name = 'CD-35 2722 b';        -- expect 0
--   SELECT * FROM host_distances_manual WHERE hostname = 'CD-35 2722 B';          -- expect 22.3612 pc
--   SELECT pp.role, p.bibcode FROM planet_publications pp JOIN publications p USING (pub_id)
--    WHERE pp.pl_name = 'CD-35 2722 B b';                                          -- discovery 2026Natur.655..865H
