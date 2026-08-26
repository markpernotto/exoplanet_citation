BEGIN;

-- Delete SIMBAD crowded-field companion artifacts from 6 Kepler CBP hosts.
--
-- Rationale: legacy SIMBAD bulk ingest for these 6 hosts pulled in wide-field
-- visual neighbors that appeared close on the sky but are not bound companions.
-- Same class of artifact as the four M4 rows previously deleted from
-- PSR B1620-26 during the cb_flag audit.
--
-- Verification method: for each host, cone-searched Gaia DR3 within a radius
-- covering all four SIMBAD rows, matched each row to its Gaia counterpart by
-- (separation, position angle), and compared parallax + proper motion vs the
-- host's own Gaia DR3 astrometry.
--
-- Result: every row failed by >= 100 sigma in at least one PM component;
-- most failed in both. Parallax matched coincidentally in several cases
-- (Kepler-field distances cluster near 1-2 kpc), but proper motion
-- discriminated cleanly. No row is a bound companion to its listed host.
--
-- Inner-binary rows (source_bibcode IS NOT NULL) are preserved:
--   Kepler-34   -> 2012Natur.481..475W (Welsh 2012)
--   Kepler-35   -> 2012Natur.481..475W (Welsh 2012)
--   Kepler-38   -> 2012ApJ...758...87O (Orosz 2012)
--   Kepler-47   -> 2012Sci...337.1511O (Orosz 2012)
--   Kepler-413  -> 2014ApJ...784...14K (Kostov 2014)
--   Kepler-1647 -> 2016ApJ...827...86K (Kostov 2016)

DELETE FROM binary_companions
 WHERE source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE
   AND hostname IN (
       'Kepler-34', 'Kepler-35', 'Kepler-38',
       'Kepler-47', 'Kepler-413', 'Kepler-1647'
   );

-- Expected: 24 rows deleted (4 per host).

COMMIT;
