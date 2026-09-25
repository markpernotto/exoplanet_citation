-- 125_binary_companion_exclusions.sql
-- Make SIMBAD citation-debt cleanups durable against the nightly re-ingest.
--
-- Problem found 2026-09-11. etl/enrich_binaries.py runs nightly in
-- incremental mode and decides which hosts to (re)resolve from SIMBAD by
-- checking whether the host has ANY row in binary_companions. A host whose
-- rows a cleanup migration deleted in full therefore looks "never fetched"
-- and is re-resolved the next morning, restoring the exact artifacts the
-- migration removed. Two hosts regressed this way:
--
--   Kepler-108            121 deleted 3 rows (applied 2026-07-12);
--                         nightly re-inserted 3 rows at 2026-07-13 07:00 UTC.
--   OGLE-2006-BLG-284L A  120 deleted 4 rows (applied 2026-07-11);
--                         nightly re-inserted 4 rows at 2026-07-12 06:50 UTC.
--
-- Every other host touched by 119-123 kept at least one row (an inner
-- binary, a cited companion, or a fresh insert) and was never re-fetched.
--
-- Fix, in three parts:
--   1. binary_companion_exclusions: a curated, cited record of hosts whose
--      SIMBAD neighbors have been reviewed and rejected. The enricher skips
--      any hostname listed here (code change in etl/enrich_binaries.py,
--      same commit). To deliberately re-resolve an excluded host, delete its
--      exclusion row first.
--   2. Re-apply the 120 and 121 deletes for the two regressed hosts.
--   3. Seed exclusion rows for both, citing the migration that carries the
--      per-host rationale.
--
-- Going forward: any cleanup migration that deletes a host's LAST
-- binary_companions row must also insert an exclusion row here, or the
-- delete will not survive the next nightly run.
--
-- Note on OGLE-2006-BLG-284L A: the re-ingested rows are not identical to
-- the set 120 deleted. 120 described neighbors at 12-19"; the current rows
-- sit at 5.3", 12.6", 14.6" and 15.3" (SIMBAD's spatial query returns a
-- slightly different neighbor set each time the crowded bulge field is
-- resolved, which is itself evidence these are not stable companion
-- identifications). The 120 rationale is separation-independent: no Gaia
-- astrometry for the lens, ~110 Gaia sources within 25" of the host, and
-- no published characterization of any bound stellar companion in the
-- discovery paper (Bennett et al. 2008, 2008ApJ...684..663B). At that
-- source density the expected number of chance neighbors inside 5.3" is
-- already ~5, so the closer row does not change the verdict.
--
-- Apply after 124; idempotent on re-run.

BEGIN;

-- 1. Exclusion table ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS binary_companion_exclusions (
    hostname        TEXT        PRIMARY KEY,   -- matches planets_current.hostname
    reason          TEXT        NOT NULL,      -- one-paragraph verdict, librarian-readable
    source_bibcode  TEXT,                      -- primary literature the verdict leans on, if any
    migration       TEXT        NOT NULL,      -- migration file carrying the full per-host rationale
    curated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE binary_companion_exclusions IS
    'Hosts whose SIMBAD spatial neighbors were reviewed and rejected as unbound '
    'field artifacts. etl/enrich_binaries.py skips these hostnames so a curated '
    'DELETE is not undone by the nightly incremental re-ingest.';

-- 2. Re-apply the regressed deletes -----------------------------------------
DELETE FROM binary_companions
 WHERE hostname = 'Kepler-108'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;
-- Expected: 3 rows deleted (B 104", C 160", D 193"; same set 121 removed).

DELETE FROM binary_companions
 WHERE hostname = 'OGLE-2006-BLG-284L A'
   AND source_catalog = 'SIMBAD'
   AND source_bibcode IS NULL
   AND inner_binary IS NOT TRUE;
-- Expected: 4 rows deleted (B 5.3", C 12.6", D 14.6", E 15.3").

-- 3. Seed exclusions ---------------------------------------------------------
INSERT INTO binary_companion_exclusions (hostname, reason, source_bibcode, migration)
VALUES
    ('Kepler-108',
     'All three SIMBAD neighbors (104-193") fail Gaia DR3 parallax or proper-motion consistency with the host (Gaia DR3 2080062630081883264): 5-28 sigma discrepancies despite the host''s inflated astrometric uncertainties. The 1.04" blended source is a background star at ~2x the host distance and is not a companion either. Crowded Kepler-field chance alignments.',
     NULL,
     '121_3row_tier_simbad_cleanup_and_hd18599_wide_binary.sql'),
    ('OGLE-2006-BLG-284L A',
     'Galactic-bulge microlensing lens with no Gaia DR3 astrometry; ~110 Gaia sources within 25" of the host. SIMBAD neighbors at 5-19" do not resolve to stable Gaia counterparts and the discovery paper reports no imaging characterization of wide bound stellar companions. Field artifacts by prior; no positive evidence of binding.',
     '2008ApJ...684..663B',
     '120_kepler432_ogle_simbad_cleanup_and_poleski_companion.sql')
ON CONFLICT (hostname) DO NOTHING;

COMMIT;
