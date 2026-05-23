-- Consolidate derived scalar properties into one general, provenance-carrying
-- table (manual deep dive, 2026-05-23). Replaces the one-off
-- planet_interior_composition (migration 022) with a long-form measurements table
-- that holds ANY derived scalar quantity (interior composition, elemental
-- abundances, metal budget, ...) without a new table per result type. Molecule
-- detections stay in planet_atmospheres (a categorical shape, not scalar).
--
-- `quantity` is a controlled vocabulary; `unit` carries the meaning of `value`:
--   core_mass_fraction (wt_pct), fe_mg_molar (ratio),
--   C/H, O/H, S/H, N/H (x_solar), metal_mass_fraction (fraction),
--   total_metal_mass, metals_from_solids, metals_from_gas (M_earth).
-- PRIMARY KEY (pl_name, quantity, bibcode) allows multiple sources per quantity.
--
-- Seeded here: TRAPPIST-1 interior composition (migrated from migration 022, Agol
-- et al. 2021) and HR 8799 elemental abundances + metal budget (Xuan et al. 2026,
-- Tables 4 and 5; bibcode verified via ADS). Provenance is the bibcode column;
-- both papers are already in the citation graph for these planets.
--
-- Apply after 022_planet_interior_composition.sql. Idempotent.

CREATE TABLE IF NOT EXISTS planet_derived_measurements (
    pl_name      TEXT NOT NULL,
    quantity     TEXT NOT NULL,         -- controlled vocabulary (see header)
    value        DOUBLE PRECISION,
    unc_hi       DOUBLE PRECISION,      -- +1 sigma
    unc_lo       DOUBLE PRECISION,      -- -1 sigma
    unit         TEXT,                  -- 'wt_pct','ratio','x_solar','fraction','M_earth'
    model        TEXT,                  -- modelling assumption / context
    bibcode      TEXT,
    curator_note TEXT,
    curated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, quantity, bibcode)
);

CREATE INDEX IF NOT EXISTS idx_derived_pl_name  ON planet_derived_measurements (pl_name);
CREATE INDEX IF NOT EXISTS idx_derived_quantity ON planet_derived_measurements (quantity);

-- Migrate planet_interior_composition into the general table, then retire it.
-- Guarded so a re-run (after the table is gone) is a no-op.
DO $$
BEGIN
  IF to_regclass('planet_interior_composition') IS NOT NULL THEN
    INSERT INTO planet_derived_measurements
        (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
    SELECT pl_name, 'core_mass_fraction', core_mass_fraction_wt, cmf_unc_hi, cmf_unc_lo,
           'wt_pct', model, bibcode, curator_note
    FROM planet_interior_composition
    ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

    INSERT INTO planet_derived_measurements
        (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
    SELECT pl_name, 'fe_mg_molar', fe_mg_molar, fe_mg_unc_hi, fe_mg_unc_lo,
           'ratio', model, bibcode, curator_note
    FROM planet_interior_composition
    ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

    DROP TABLE planet_interior_composition;
  END IF;
END $$;

-- HR 8799 elemental abundances (Xuan et al. 2026, Table 4; relative to solar,
-- Asplund et al. 2009). N/H reported only for b (NH3 detected only there).
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('HR 8799 b', 'C/H', 4.2, 0.9, 0.8, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 b', 'O/H', 4.9, 1.0, 0.8, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 b', 'S/H', 5.2, 0.8, 0.7, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 b', 'N/H', 21.2, 16.2, 8.8, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. N/H reported only for b (NH3 detected only there); large and uncertain.'),
    ('HR 8799 c', 'C/H', 4.4, 0.8, 0.7, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 c', 'O/H', 3.8, 0.9, 0.8, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 c', 'S/H', 2.6, 0.4, 0.4, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 d', 'C/H', 5.3, 1.2, 1.1, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 d', 'O/H', 4.1, 1.1, 0.9, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 d', 'S/H', 2.0, 0.4, 0.3, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 e', 'C/H', 3.3, 1.2, 0.9, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 e', 'O/H', 2.8, 1.0, 0.7, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
    ('HR 8799 e', 'S/H', 1.4, 1.7, 1.1, 'x_solar', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 4. Elemental abundance relative to solar.'),
-- HR 8799 metal budget (Xuan et al. 2026, Table 5). Total system metals ~412
-- M_earth split into solids (~239) and metal-enriched gas (~170): core accretion.
    ('HR 8799 b', 'metal_mass_fraction', 0.067, 0.012, 0.010, 'fraction', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Bulk metal mass fraction.'),
    ('HR 8799 b', 'total_metal_mass', 123, 24, 19, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Total heavy-element mass.'),
    ('HR 8799 b', 'metals_from_solids', 98, 16, 14, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted solids.'),
    ('HR 8799 b', 'metals_from_gas', 22, 18, 10, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted metal-enriched gas.'),
    ('HR 8799 c', 'metal_mass_fraction', 0.040, 0.007, 0.006, 'fraction', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Bulk metal mass fraction.'),
    ('HR 8799 c', 'total_metal_mass', 96, 19, 16, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Total heavy-element mass.'),
    ('HR 8799 c', 'metals_from_solids', 55, 10, 9, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted solids.'),
    ('HR 8799 c', 'metals_from_gas', 41, 15, 13, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted metal-enriched gas.'),
    ('HR 8799 d', 'metal_mass_fraction', 0.041, 0.009, 0.008, 'fraction', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Bulk metal mass fraction.'),
    ('HR 8799 d', 'total_metal_mass', 119, 28, 24, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Total heavy-element mass.'),
    ('HR 8799 d', 'metals_from_solids', 51, 11, 9, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted solids.'),
    ('HR 8799 d', 'metals_from_gas', 67, 23, 19, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted metal-enriched gas.'),
    ('HR 8799 e', 'metal_mass_fraction', 0.028, 0.010, 0.008, 'fraction', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Bulk metal mass fraction.'),
    ('HR 8799 e', 'total_metal_mass', 68, 26, 19, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Total heavy-element mass.'),
    ('HR 8799 e', 'metals_from_solids', 31, 34, 22, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted solids.'),
    ('HR 8799 e', 'metals_from_gas', 35, 22, 22, 'M_earth', 'free retrieval', '2026ApJ..1000...27X', 'Xuan et al. 2026, Table 5. Metals attributed to accreted metal-enriched gas.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
