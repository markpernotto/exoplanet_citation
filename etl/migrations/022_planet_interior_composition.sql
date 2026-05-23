-- New feature: curated planet interior-composition layer (manual deep dive,
-- 2026-05-22). The catalog had no home for interior-structure results (core mass
-- fraction, bulk Fe/Mg, inferred water content) even though they are a major
-- value-added product of mass-radius modelling. This creates the table and seeds
-- it from Agol et al. 2021 (2021PSJ.....2....1A, Table 9; bibcode verified via
-- ADS) for the seven TRAPPIST-1 planets, the best-characterised rocky system.
--
-- Provenance note: the interior values come from Agol 2021, recorded in the
-- bibcode column below. Agol 2021 is already linked to these planets in the
-- citation graph (as a characterization source for the geometry), so the paper
-- is credited. The graph's (pl_name, pub_id, role) uniqueness means a single
-- paper carries one contribution tag per planet+role, so a distinct
-- 'interior_composition' contribution is not added there; see the follow-up note
-- in the deep-dive ledger about widening the citation key if finer tagging is
-- wanted.
--
-- Modelling caveat (recorded per row): CMF is from a fully-differentiated, dry
-- interior model. Core mass fraction and water content are DEGENERATE against a
-- measured density (a planet's density fits either more iron and no water, or
-- less iron plus water), so the water content is reported qualitatively in the
-- note rather than as a single structured value.
--
-- Idempotent: CREATE TABLE IF NOT EXISTS + INSERT ... ON CONFLICT DO UPDATE.

CREATE TABLE IF NOT EXISTS planet_interior_composition (
    pl_name               TEXT NOT NULL,
    core_mass_fraction_wt DOUBLE PRECISION,   -- CMF, weight percent
    cmf_unc_hi            DOUBLE PRECISION,    -- +1 sigma (weight percent)
    cmf_unc_lo            DOUBLE PRECISION,    -- -1 sigma (weight percent)
    fe_mg_molar           DOUBLE PRECISION,    -- bulk Fe/Mg molar ratio
    fe_mg_unc_hi          DOUBLE PRECISION,
    fe_mg_unc_lo          DOUBLE PRECISION,
    model                 TEXT,                -- interior model assumption
    bibcode               TEXT,                -- ADS source for the values
    curator_note          TEXT,
    curated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name)
);

CREATE INDEX IF NOT EXISTS idx_interior_pl_name
    ON planet_interior_composition (pl_name);

INSERT INTO planet_interior_composition
    (pl_name, core_mass_fraction_wt, cmf_unc_hi, cmf_unc_lo,
     fe_mg_molar, fe_mg_unc_hi, fe_mg_unc_lo, model, bibcode, curator_note)
VALUES
    ('TRAPPIST-1 b', 25.2, 5.3, 6.0, 0.60, 0.18, 0.18, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. Iron-poor vs Earth (Earth CMF about 33 wt-pct, Fe/Mg about '
     '0.83). Dry: inferred water below 0.001 wt-pct across all modelled core '
     'fractions. CMF and water are degenerate against the measured density.'),
    ('TRAPPIST-1 c', 26.6, 4.6, 5.1, 0.64, 0.16, 0.16, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. Iron-poor vs Earth. Dry: inferred water below 0.001 wt-pct '
     'across all modelled core fractions. CMF and water are degenerate against density.'),
    ('TRAPPIST-1 d', 19.7, 4.7, 5.1, 0.44, 0.14, 0.13, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. Iron-poor vs Earth. Dry: inferred water below 0.001 wt-pct '
     'across all modelled core fractions. CMF and water are degenerate against density.'),
    ('TRAPPIST-1 e', 24.6, 4.3, 4.9, 0.58, 0.14, 0.14, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. At an assumed core mass fraction of 25 wt-pct the density '
     'allows about 0.3 wt-pct water (rising to about 9 wt-pct for an Earth-like CMF). '
     'CMF and water are degenerate against density.'),
    ('TRAPPIST-1 f', 20.1, 3.5, 4.2, 0.45, 0.10, 0.11, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. At an assumed core mass fraction of 25 wt-pct the density '
     'allows about 1.9 wt-pct water (up to about 12 wt-pct for an Earth-like CMF). '
     'CMF and water are degenerate against density.'),
    ('TRAPPIST-1 g', 16.1, 3.5, 4.2, 0.34, 0.09, 0.10, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. At an assumed core mass fraction of 25 wt-pct the density '
     'allows about 3.5 wt-pct water (up to about 14 wt-pct for an Earth-like CMF). '
     'CMF and water are degenerate against density.'),
    ('TRAPPIST-1 h', 16.5, 9.3, 10.0, 0.35, 0.27, 0.23, 'fully-differentiated',
     '2021PSJ.....2....1A',
     'Agol et al. 2021. At an assumed core mass fraction of 25 wt-pct the density '
     'allows about 3.0 wt-pct water (up to about 12 wt-pct for an Earth-like CMF). '
     'CMF and water are degenerate against density.')
ON CONFLICT (pl_name) DO UPDATE SET
    core_mass_fraction_wt = EXCLUDED.core_mass_fraction_wt,
    cmf_unc_hi            = EXCLUDED.cmf_unc_hi,
    cmf_unc_lo            = EXCLUDED.cmf_unc_lo,
    fe_mg_molar           = EXCLUDED.fe_mg_molar,
    fe_mg_unc_hi          = EXCLUDED.fe_mg_unc_hi,
    fe_mg_unc_lo          = EXCLUDED.fe_mg_unc_lo,
    model                 = EXCLUDED.model,
    bibcode               = EXCLUDED.bibcode,
    curator_note          = EXCLUDED.curator_note;
