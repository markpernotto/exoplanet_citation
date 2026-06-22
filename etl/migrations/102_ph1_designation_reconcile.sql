-- PH1 (= Kepler-64) component-designation reconciliation (2026-06-17).
-- Migration 101 added the wide visual pair Ba+Bb plus the inner Ab using
-- the simple A/B/C/D convention from sibling migrations 070-079 and 098.
-- That overlooked an earlier seed row that already used the LITERAL
-- literature designations (Ab with primary Aa), so 101 produced two
-- rows for the same star:
--   (PH1, 'Ab', 'Aa')  -- earlier seed, F+M eclipsing binary class
--   (PH1, 'B',  'A')   -- migration 101's new row, same star (Ab)
-- This migration takes the cleaner option A (per user direction):
--   1. Drop the 101 duplicate (PH1, 'B').
--   2. Augment the surviving (PH1, 'Ab') row with the separation_au from
--      Schwamb 2013 photometric-dynamical model (Aa-Ab a ~0.18 AU, P =
--      20.0002468 d); other fields on the seed row are left intact.
--   3. Rename the 101 wide-pair rows (PH1, 'C') -> (PH1, 'Ba') and
--      (PH1, 'D') -> (PH1, 'Bb') and switch primary_designation from
--      'A' to 'Aa' to match the literature convention used on the
--      existing Ab row. Notes are rewritten to drop the "designation C
--      used vs literature's Ba" parenthetical which is no longer true.
--
-- Why option A: the literature designations (Aa/Ab/Ba/Bb) preserve the
-- hierarchical structure of the 2+2 quadruple in the component names
-- themselves and are what subsequent followup papers will reference.
-- The earlier seed row predates the A/B/C/D convention adopted by
-- migrations 070-079 for triples; reconciling toward Aa/Ab/Ba/Bb keeps
-- PH1 internally consistent without touching the unrelated triples.
--
-- Apply after 101_wds_batch1.sql. Idempotent.


-- 1. Drop the duplicate of the inner eclipsing partner.
DELETE FROM binary_companions
WHERE hostname = 'PH1'
  AND component_designation = 'B';

-- 2. Augment the surviving Ab row with the Aa-Ab orbital separation.
-- The seed row's notes are good; we only fill the previously-NULL
-- separation_au with the Schwamb 2013 model value.
UPDATE binary_companions
SET separation_au = 0.18
WHERE hostname = 'PH1'
  AND component_designation = 'Ab'
  AND separation_au IS NULL;

-- 3a. Drop the 101 wide-pair rows (we will re-INSERT under literature
-- designations). This is cleaner than UPDATE-ing the PK columns and
-- lets us rewrite the notes in one shot.
DELETE FROM binary_companions
WHERE hostname = 'PH1'
  AND component_designation IN ('C', 'D');

-- 3b. Re-INSERT under the literature naming, primary = 'Aa'.
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_arcsec,
     separation_au, component_mass_msun, component_mass_is_min, component_teff_k, inner_binary,
     binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('PH1', 'Ba', 'Aa', 'G2', NULL,
     1000, 0.99, false, NULL, false,
     'wide visual pair (Ba, G2 dwarf at ~1000 AU from the Aa+Ab eclipsing binary)', 'manual', '2013ApJ...768..127S',
     'PH1 Ba: G2 dwarf in the wide visual pair Ba+Bb at ~1000 AU projected from the Aa+Ab eclipsing binary. '
     'Properties from Schwamb 2013 Section 9.3 photometric-deconvolution fit to SDSS griz + 2MASS JHKs + KIC '
     'D51 photometry using a 2 Gyr Dartmouth isochrone (after iteration with the photometric-dynamical model). '
     'Mass ~ 0.99 Msun -> G2 spectral type. Bound to Aa+Ab via RV (Ba and Bb both have the systemic velocity '
     'of Aa, Schwamb Section 9.3 narrative). Combined AO photometry (Ba + Bb relative to Aa + Ab): delta J = '
     '1.89 +/- 0.04, delta Ks = 1.67 +/- 0.03. System distance ~1500 pc from the photometric fit -> the ~0.68" '
     'angular separation translates to ~1000 AU. Ba and Bb are themselves separated by ~60 AU (Bb row). '
     'inner_binary = false (the eclipsing inner pair is Aa+Ab on the Ab row).'),

    ('PH1', 'Bb', 'Aa', 'M2', NULL,
     1000, 0.51, false, NULL, false,
     'wide visual pair (Bb, M2 dwarf, tight pair with Ba at ~60 AU)', 'manual', '2013ApJ...768..127S',
     'PH1 Bb: M2 dwarf in the wide visual pair Ba+Bb, the smaller component. Mass ~0.51 Msun per Schwamb 2013 '
     'Section 9.3 photometric-deconvolution fit (caveat: 0.51 Msun is more typical of K7-M0 than M2 at solar '
     'metallicity; the paper''s photometric classification favors M2). Co-located with Ba at the ~1000 AU '
     'projected distance from the Aa+Ab eclipsing binary. Ba-Bb internal separation ~60 AU (Schwamb 2013 Section '
     '9.3). Both Ba and Bb bound to the Aa+Ab pair gravitationally (RV-confirmed shared systemic velocity). The '
     'wide-pair semi-major axis around Aa+Ab is poorly constrained; Schwamb 2013 Section 9.3 uses 1000 AU as a '
     'representative value for MERCURY orbital integrations, finding negligible perturbation on PH1b''s orbit. '
     'inner_binary = false.')
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
