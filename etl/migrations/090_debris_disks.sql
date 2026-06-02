-- Curated system-level debris-disk geometries for famous resolved disks
-- where the inner/outer radii are quoted directly in the source paper's
-- abstract or main-text-table. 4 systems, all with confirmed planets in
-- our catalog. The disk is a SYSTEM-level feature (all planets in the
-- system share it), but planet_derived_measurements is keyed on pl_name;
-- we associate each disk row with the canonical / first-imaged planet
-- in the system (β Pic b, HR 8799 b, HD 95086 b, eps Eri b).
--
-- Quantities used (extending the controlled-vocab to debris disks):
--   debris_disk_inner_au         -- inner edge of the dust/gas belt (AU)
--   debris_disk_outer_au         -- outer edge of the dust/gas belt (AU)
--   debris_disk_inclination_deg  -- inclination from face-on (degrees)
--
-- For multi-belt systems (HD 95086, eps Eri), only the COLD outer belt's
-- radii are quantified in the abstracts/tables we verified. Warm inner
-- belts (eps Eri ~3 AU per Backman 2009, HD 95086 ~175 K warm belt per
-- Su 2015) are qualitative position only -- deferred to a follow-up
-- migration when papers with abstract-quoted inner-belt radii are found.
--
-- 51 Eri uses SINGLE-RADIUS BLACKBODY fits (Patel 2014 WISE for warm
-- belt at 5.5 AU, Riviere-Marichalar 2014 Herschel for cold belt at
-- 82 AU) rather than resolved imaging like the other four systems.
-- This means: (a) no separate inner/outer edges -- one characteristic
-- radius per belt, (b) no inclination -- not measurable from SED fits,
-- (c) cold belt has huge -75/+677 AU uncertainty. Stored as
-- debris_disk_inner_au only (no outer rows); renderer should treat
-- these as narrow rings rather than broad belts.
--
-- Coverage gaps (intentionally NOT included to keep every row properly
-- cited): Fomalhaut (Kalas 2005 has clean geometry but Fomalhaut b was
-- demoted to a dispersing dust cloud per Gáspár & Rieke 2020; system
-- has no confirmed planet in the catalog).
--
-- Bibcodes verified against ADS abstracts (or main text where the value
-- is text-quoted but not in abstract) before landing. Provenance is
-- 'curated'. Idempotent via ON CONFLICT DO NOTHING on the
-- (pl_name, quantity, bibcode) primary key.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note, provenance)
VALUES

-- β Pictoris b -- Dent et al. 2014, Science 343, 1490. ALMA CO 3-2 PV
-- diagram of the archetypal edge-on debris disk. The disk extends from
-- 50 to 160 AU with a peak at 85 AU. Disk plane is "closely aligned
-- with the orbit of β Pic b" (abstract), so we inherit the inclination
-- from β Pic b's astrometric orbital fit: 88.88 ± 0.09° per Nielsen et
-- al. 2020 (reported in Shiohira et al. 2024 Table 1).
('bet Pic b', 'debris_disk_inner_au', 50, NULL, NULL, 'AU',
 'ALMA CO 3-2 PV diagram', '2014Sci...343.1490D',
 'Inner edge of broad gas+dust belt from Dent et al. 2014 (Science 343, '
 '1490) ALMA CO J=3-2 observations. Main text: "broad belt of orbiting '
 'gas, with inner and outer radii of 50 and 160AU, and a peak around '
 '85AU. No gas emission is seen inside 50AU." Co-located with mm-dust '
 'continuum belt. Disk plane is coplanar with the orbit of bet Pic b '
 '(per abstract); inclination stored separately.',
 'curated'),

('bet Pic b', 'debris_disk_outer_au', 160, NULL, NULL, 'AU',
 'ALMA CO 3-2 PV diagram', '2014Sci...343.1490D',
 'Outer edge of broad gas+dust belt from Dent et al. 2014. Same source '
 'as inner edge. The mm-dust continuum shows an "abrupt drop in density '
 'around 130AU radius" -- this is the planetesimal belt outer edge -- '
 'while the gas component extends to 160 AU. Stored value is the gas '
 'outer radius for consistency with inner=50.',
 'curated'),

('bet Pic b', 'debris_disk_inclination_deg', 88.88, 0.09, 0.09, 'deg',
 'inherited from coplanar planet orbit', '2014Sci...343.1490D',
 'Disk inclination derived via Dent et al. 2014 statement that the gas '
 'plane is "closely aligned with the orbit of the inner planet, beta Pic '
 'b" + bet Pic b orbital inclination 88.88 ± 0.09° from Nielsen et al. '
 '2020 (cited in Shiohira et al. 2024 Table 1). Combined chain: disk '
 'coplanar with planet orbit, planet orbit at 88.88° -> disk at 88.88°. '
 'Consistent with Dent 2014 main text qualitative "edge-on" descriptor.',
 'curated'),

-- HR 8799 b -- Booth et al. 2016, MNRAS 460, L10. ALMA band 6 (1.34 mm)
-- of the broad debris disk. The disk surrounds the four imaged giants
-- (HR 8799 b/c/d/e); we anchor on b (the outermost, discovered first).
-- Pre-existing Su et al. 2009 Spitzer paper identifies three components
-- (warm, cold, halo) but only Booth 2016 quotes the cold-belt radii in
-- its abstract.
('HR 8799 b', 'debris_disk_inner_au', 145, 12, 12, 'AU',
 'ALMA band 6 (1.34 mm) MCMC fit', '2016MNRAS.460L..10B',
 'Inner edge of the cold planetesimal belt from Booth et al. 2016 '
 '(MNRAS 460, L10) ALMA 1.34 mm observations. Abstract: "broad ring '
 'between 145+12/-12 au and 429+37/-32 au at an inclination of 40+5/-6° '
 'and a position angle of 51+8/-8°." Note: this inner edge sits well '
 'outside the orbit of planet b (~68 AU), implying either a more '
 'complicated dynamical history or an additional planet beyond b.',
 'curated'),

('HR 8799 b', 'debris_disk_outer_au', 429, 37, 32, 'AU',
 'ALMA band 6 (1.34 mm) MCMC fit', '2016MNRAS.460L..10B',
 'Outer edge of the cold planetesimal belt from Booth et al. 2016. Same '
 'source as inner edge. Su et al. 2009 Spitzer paper noted an additional '
 '"halo of small grains" extending beyond the planetesimal belt (driven '
 'by radiation pressure on collisional debris), not quantified here.',
 'curated'),

('HR 8799 b', 'debris_disk_inclination_deg', 40, 5, 6, 'deg',
 'ALMA band 6 (1.34 mm) MCMC fit', '2016MNRAS.460L..10B',
 'Disk inclination 40 +5/-6° from Booth et al. 2016 (MNRAS 460, L10) '
 'ALMA fit. Position angle 51 ± 8° additionally reported. Inclination '
 'is from face-on (0° = face-on, 90° = edge-on).',
 'curated'),

-- HD 95086 b -- Su et al. 2017, AJ 154, 225. ALMA 1.3 mm imaging of the
-- Kuiper-Belt analog (cold outer belt). The system also hosts a warm
-- inner belt (~175 K per Su et al. 2015) and an extended halo (~800 AU
-- per Su 2015), but only the cold belt's radii are quoted explicitly.
('HD 95086 b', 'debris_disk_inner_au', 106, 6, 6, 'AU',
 'ALMA 1.3 mm continuum imaging', '2017AJ....154..225S',
 'Inner edge of the cold (Kuiper-belt analog) debris belt from Su et al. '
 '2017 (AJ 154, 225) ALMA 1.3 mm observations. Abstract: "broad disk '
 'with sharp boundaries from 106 ± 6 to 320 ± 20 au with a surface '
 'density distribution described by a power law with an index of -0.5 '
 '± 0.2. Millimeter emission peaks at 200 ± 6 au." Warm inner belt at '
 '~175 K (Su 2015) not quantified in radii; deferred.',
 'curated'),

('HD 95086 b', 'debris_disk_outer_au', 320, 20, 20, 'AU',
 'ALMA 1.3 mm continuum imaging', '2017AJ....154..225S',
 'Outer edge of cold belt from Su et al. 2017. Same source as inner '
 'edge. Surface density power-law index -0.5 ± 0.2 across the belt.',
 'curated'),

('HD 95086 b', 'debris_disk_inclination_deg', 30, 3, 3, 'deg',
 'ALMA 1.3 mm continuum imaging', '2017AJ....154..225S',
 'Disk inclination 30 ± 3° from Su et al. 2017 ALMA fit. Inclination '
 'is from face-on. The system is described as "a young analog of HR 8799" '
 '(Su 2015) in terms of architecture (warm + cold + halo). HD 95086 b '
 '(directly imaged at projected ~56 AU) is interior to the cold belt.',
 'curated'),

-- eps Eridani b -- Backman et al. 2009, ApJ 690, 1522. Spitzer + Caltech
-- Submillimeter Observatory imaging. Note: no explicit inclination quoted
-- in the abstract for the outer (sub-mm) ring -- omitted. Inner belts at
-- ~3 AU and ~20 AU exist (per the abstract) but no quantified outer radii.
('eps Eri b', 'debris_disk_inner_au', 35, NULL, NULL, 'AU',
 'Spitzer MIPS + CSO 350 um SED + imaging', '2009ApJ...690.1522B',
 'Inner edge of the outer (Kuiper-belt-analog) sub-mm ring from Backman '
 'et al. 2009 (ApJ 690, 1522). Abstract: "r = 11''-28'' (35-90 AU)" at '
 'eps Eri''s 3.22 pc distance. The system also hosts inner belts: '
 '"innermost belt at r ~ 3 AU is composed of silicate dust" + an '
 'intermediate component, both interior to the sub-mm ring''s central '
 'void. Inner belts not quantified in radii (qualitative position only) '
 'and deferred. No system inclination is quoted in this abstract.',
 'curated'),

('eps Eri b', 'debris_disk_outer_au', 90, NULL, NULL, 'AU',
 'Spitzer MIPS + CSO 350 um SED + imaging', '2009ApJ...690.1522B',
 'Outer edge of the sub-mm ring from Backman et al. 2009. Same source '
 'as inner edge. Later ALMA observations (Booth et al. 2017, MNRAS 469, '
 '3200) refined the parent-body ring to be very narrow (11-13 AU wide '
 'centered near 48 AU), while the broader 35-90 AU Spitzer/sub-mm extent '
 'traces smaller grains spread by radiation pressure -- the stored value '
 'is the broader-grain extent, more representative for visualization.',
 'curated'),

-- 51 Eridani b -- warm belt -- Patel et al. 2014, ApJS 212, 10. WISE
-- 12+22 um photometric excess for HIP 21547 (= 51 Eri = HD 29391); Table 7
-- single-temperature blackbody fit gives a characteristic dust radius and
-- temperature. NOT a resolved-imaging measurement -- the "5.5 AU" is the
-- blackbody-equivalent radius from the W3 excess, with the 1.5 AU as the
-- 3-sigma lower limit derived from the W4 excess upper limit. The warm
-- belt sits INTERIOR to 51 Eri b's orbit (~12 AU per Maire 2019),
-- matching the "warm belt + planet + cold belt" architecture seen in
-- HR 8799 and HD 95086.
('51 Eri b', 'debris_disk_inner_au', 5.5, NULL, 4.0, 'AU',
 'WISE 12+22 um single-blackbody warm belt (SED fit)', '2014ApJS..212...10P',
 'Single-radius blackbody fit (NOT resolved imaging). Patel et al. 2014 '
 '(ApJS 212, 10) Table 7 for HIP 21547: TBB = 180 K, RBB = 5.5 AU from the '
 'W3 (12 um) excess fit; TBB_lim < 344 K and RBB_lim > 1.5 AU are 3-sigma '
 'bounds from the W4 (22 um) excess upper limit. Stored unc_lo = 4 (= 5.5 '
 '- 1.5) to capture the 3-sigma lower bound. Fractional dust luminosity '
 'fd = 2.4e-5. WISE excess significance 3.76 sigma at W3-W4 (Table 6). '
 'Maire et al. 2019 (A&A 624, A118) re-quoted these values when reviewing '
 '51 Eri''s system architecture. Warm belt sits inside 51 Eri b''s ~12 AU '
 'orbit. No outer_au row because this is a single-blackbody-radius fit; '
 'the renderer should treat this as a narrow ring at 5.5 AU.',
 'curated'),

-- 51 Eridani b -- cold belt -- Riviere-Marichalar et al. 2014, A&A 565,
-- A68. Herschel-PACS far-IR photometry of beta Pictoris moving group
-- members; first detection of an IR excess at HD 29391 = 51 Eri = HIP 21547.
-- Table 5 modified-blackbody fit gives the cold-dust temperature, radius,
-- and upper-limit mass. The RADIUS UNCERTAINTY IS HUGE (-75/+677 AU,
-- spanning 7-759 AU at 1-sigma) because the fit uses only 3 data points
-- with excess at lambda >= 70 um. Still useful as a system-level "there is
-- a cold belt around this star at large separation" measurement.
('51 Eri b', 'debris_disk_inner_au', 82, 677, 75, 'AU',
 'Herschel-PACS modified-blackbody cold belt (SED fit, 3 data points)', '2014A&A...565A..68R',
 'Single-radius modified-blackbody fit (NOT resolved imaging). '
 'Riviere-Marichalar et al. 2014 (A&A 565, A68) Table 5 for HD 29391: '
 'T = 55 +/- 21 K, Rdust = 82 +677/-75 AU, beta = 0.0 +2.0, LIR/L_star = '
 '2.3e-6, Mdust < 1.6e-3 M_earth. The +677/-75 AU uncertainty span (7 to '
 '759 AU at 1-sigma) is intrinsic to the 3-parameter modified-blackbody '
 'fit against only 3 photometric points with excess at lambda >= 70 um. '
 'Stored as inner_au with no outer because this is a single-radius fit; '
 'renderer should treat as a narrow ring at 82 AU. Cold belt sits well '
 'outside 51 Eri b''s ~12 AU orbit, matching the architecture seen in '
 'HR 8799 (cold belt outer to imaged planets) and HD 95086 (planet b '
 'imaged inside cold belt).',
 'curated')

ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;
