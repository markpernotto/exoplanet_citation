-- PH1 (= Kepler-64, KIC 4862625) wide-companion cleanup (2026-06-08).
-- PH1 b's catalog had a 'B' row in binary_companions with
-- separation_arcsec = 162.5 and no bibcode — a SIMBAD bulk-ingest
-- artifact. Sanity check: 162.5" at PH1's ~430 pc distance is ~70,000
-- AU, well past the plausible-bound-companion limit and past our own
-- API's 25,000 AU sanity cap (so the row is silently filtered from the
-- /companions response anyway). The literature (Schwamb et al. 2013,
-- ApJ 768, 127) does discuss the wide contaminating source but does
-- not characterize it architecturally in the published tables — Table 7
-- only reports a flux-contamination fraction (FX/FAa ~ 7.5%), not a
-- separation or component breakdown.
--
-- This migration deletes the bogus row and intentionally does NOT add a
-- curated replacement: real wide-pair characterization (separation, PA,
-- spectype, mass) needs either a prose excerpt from Schwamb 2013's
-- observations section or a separate AO follow-up paper. Once that
-- data is in hand, a follow-up migration can INSERT the proper Ba / Bb
-- (or single 'B') row with a bibcode.
--
-- Net result after this applies: PH1 b's binary_companions table has
-- only the Aa+Ab inner-binary row from migration 073 (Schwamb 2013
-- cited). The 3D scene renders the inner binary correctly; the wide
-- pair remains an acknowledged data gap rather than a fabricated row.
--
-- Idempotent.

DELETE FROM binary_companions
WHERE hostname = 'PH1'
  AND component_designation = 'B'
  AND source_catalog = 'SIMBAD'
  AND source_bibcode IS NULL;
