-- Curated dust temperatures for the system-level debris-disk belts that
-- migration 090 already stores radii + inclination for. Drives the
-- renderer's per-belt dust color: cold dust (~45-55 K, far-IR sub-mm
-- regime) reads as cool blue-gray, warm dust (>=150 K, mid-IR regime)
-- reads as orange-brown, matching what mid-IR pseudocolor imagery
-- conveys for real ALMA / Spitzer / Herschel observations.
--
-- 5 of 6 currently-rendered belts covered. The eps Eri b cold sub-mm
-- ring (Backman et al. 2009) abstract does NOT quote a dust temperature;
-- that row is intentionally deferred until a paper with an abstract- or
-- table-quoted temperature for the eps Eri outer ring is identified.
--
-- Citation rigor: every temperature value below is quoted directly in
-- the source paper's abstract OR a published table in the paper. For
-- HR 8799 and HD 95086, the temperature paper differs from the
-- geometry paper that migration 090 cites — both are valid primary
-- sources. The renderer associates temperature rows with the geometric
-- belt either by matching bibcode (when geometry + temperature share
-- a paper, e.g. beta Pic, 51 Eri belts) or by single-belt fallback
-- (when a planet has only one belt and the temperature row has a
-- different bibcode, e.g. HR 8799 + HD 95086).
--
-- Provenance is 'curated'. Idempotent via ON CONFLICT DO NOTHING on
-- the (pl_name, quantity, bibcode) primary key.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
VALUES

-- beta Pic b -- Dent et al. 2014, Science 343, 1490. Same primary paper
-- as the disk geometry row in migration 090. The 85 K dust temperature
-- is quoted in the main text of Dent 2014.
('bet Pic b', 'debris_disk_dust_temperature_k', 85, NULL, NULL, 'K',
 'ALMA + sub-mm equilibrium temperature, used in dust mass derivation', '2014Sci...343.1490D',
 'Dust temperature 85 K from Dent et al. 2014 (Science 343, 1490) main '
 'text: "...if we assume a standard dust mass opacity (0.15 m^2 kg^-1 '
 'at 850 um) and temperature of 85K." Equilibrium dust temperature for '
 'the mm-grain belt, used in the paper to derive a dust mass of 4.7e23 '
 'kg (6.4 Moon masses) from the 60 +/- 6 mJy total ALMA flux. Same '
 'paper that gives the belt''s 50-160 AU radii in migration 090.',
 'curated'),

-- HR 8799 b -- Su et al. 2009, ApJ 705, 314. Identifies three dust
-- components in the HR 8799 debris system; we cite the COLD belt
-- temperature (~45 K) since that is what migration 090 stores as the
-- HR 8799 b debris disk radii (Booth 2016 cold-belt ALMA fit). The
-- warm belt at ~150 K sits inside the planets and is not currently
-- rendered as a separate geometry row.
('HR 8799 b', 'debris_disk_dust_temperature_k', 45, NULL, NULL, 'K',
 'Spitzer SED of cold belt (sharp inner edge outside outermost planet)', '2009ApJ...705..314S',
 'Cold-belt dust temperature 45 K from Su et al. 2009 (ApJ 705, 314) '
 'abstract: "...a broad zone of cold dust (T ~ 45 K) with a sharp inner '
 'edge orbiting just outside the outermost planet and presumably '
 'sculpted by it." This is the dust component our debris-disk geometry '
 'row corresponds to (Booth 2016 ALMA, cited in migration 090). Warm '
 'belt at ~150 K sits inside the planets and is not currently rendered. '
 'Temperature paper differs from the geometry paper -- both are '
 'primary sources for their respective measurements.',
 'curated'),

-- HD 95086 b -- Su et al. 2015, ApJ 799, 146. The cold belt temperature
-- (~55 K) is quoted in the abstract alongside warm belt (~175 K) and
-- halo. Migration 090 uses Su 2017 (later ALMA refinement) for the
-- cold belt radii.
('HD 95086 b', 'debris_disk_dust_temperature_k', 55, NULL, NULL, 'K',
 'Spitzer/MIPS-SED + Herschel SED fit, cold disk component', '2015ApJ...799..146S',
 'Cold-belt dust temperature 55 K from Su et al. 2015 (ApJ 799, 146) '
 'abstract: "...the debris structure around HD 95086 consists of a warm '
 '(~175 K) belt, a cold (~55 K) disk, and an extended disk halo (up to '
 '~800 AU), and is very similar to that of HR 8799." Corresponds to '
 'the cold belt geometry (106-320 AU, Su 2017 ALMA) in migration 090. '
 'Warm belt at ~175 K is not currently rendered -- its radii are not '
 'quoted in any abstract/table we verified. Temperature paper differs '
 'from the geometry paper -- both are primary sources.',
 'curated'),

-- 51 Eridani b -- warm belt -- Patel et al. 2014, ApJS 212, 10. Same
-- primary paper as the warm-belt geometry in migration 090. The 180 K
-- temperature is in Table 7 alongside the 5.5 AU blackbody radius.
('51 Eri b', 'debris_disk_dust_temperature_k', 180, NULL, NULL, 'K',
 'WISE 12+22 um single-blackbody warm belt (SED fit)', '2014ApJS..212...10P',
 'Warm-belt dust temperature TBB = 180 K from Patel et al. 2014 (ApJS '
 '212, 10) Table 7 for HIP 21547. Same paper and table that give the '
 'warm-belt radius RBB = 5.5 AU (migration 090). TBB_lim < 344 K is '
 'the 3-sigma upper bound derived from the W4 (22 um) excess upper '
 'limit. Stored as point estimate without uncertainty because the '
 'table gives only the upper bound, not symmetric errors.',
 'curated'),

-- 51 Eridani b -- cold belt -- Riviere-Marichalar et al. 2014, A&A 565,
-- A68. Same primary paper as the cold-belt geometry in migration 090.
-- The 55 +/- 21 K temperature is in Table 5 with symmetric uncertainty.
('51 Eri b', 'debris_disk_dust_temperature_k', 55, 21, 21, 'K',
 'Herschel-PACS modified-blackbody cold belt (SED fit, 3 data points)', '2014A&A...565A..68R',
 'Cold-belt dust temperature 55 +/- 21 K from Riviere-Marichalar et al. '
 '2014 (A&A 565, A68) Table 5 for HD 29391. Same paper and table that '
 'give the cold-belt radius Rdust = 82 +677/-75 AU (migration 090). '
 'Symmetric uncertainty +/- 21 K reflects the limited constraints of '
 'fitting a 3-parameter modified blackbody to only 3 photometric '
 'points with excess at lambda >= 70 um.',
 'curated')

ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
