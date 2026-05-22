-- Deep-dive enrichment (manual literature review, 2026-05-21): landmark
-- atmosphere detections, an orbital-geometry refinement, and wide-companion
-- separations for foundational systems the catalog held at discovery-only depth.
-- All values are read from the cited papers (bibcodes verified via ADS); the
-- matching citations are linked as role='characterization' in
-- etl/seed_followup_citations.py.
--
-- planet_atmospheres was empty for every planet below (observation campaigns
-- existed, but no curated molecule detections):
--   HD 209458 b: first exoplanet atmosphere (Na), first escaping atmosphere (H),
--                plus CO and weak water from high-dispersion / WFC3 spectroscopy.
--   51 Peg b:    dayside water at high spectral resolution.
--   HD 189733 b: first ground-based exoplanet sodium detection, plus dayside
--                water and CO from high-dispersion spectroscopy.
--   55 Cnc e:    first secondary atmosphere on a rocky exoplanet (CO2 or CO;
--                composition not uniquely determined, so logged as tentative).
--
-- ups And d: system_orbital_geometry already carried McArthur et al. 2010 from
-- migration 010, rounded to 30.0 +/- 5.0 deg. Refine to the published
-- 29.9 +/- 1.0 deg.
--
-- Apply after 008_atmospheres.sql and 010_orbital_geometry_seed.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('HD 209458 b', 'Na', 'detected', 'HST/STIS', '2002ApJ...568..377C', 4.1,
     'Charbonneau et al. 2002. First detection of an exoplanet atmosphere. Neutral '
     'sodium (Na D, 589.3 nm) in transmission; (2.32 +/- 0.57)e-4 excess transit '
     'depth, about 4.1 sigma.'),
    ('HD 209458 b', 'H', 'detected', 'HST/STIS', '2003Natur.422..143V', 3.8,
     'Vidal-Madjar et al. 2003. Extended, escaping upper atmosphere. Atomic hydrogen '
     'Lyman-alpha absorption of 15 +/- 4% during transit, about 3.8 sigma; absorption '
     'beyond the Roche limit indicates hydrodynamic escape.'),
    ('HD 209458 b', 'CO', 'detected', 'VLT/CRIRES', '2010Natur.465.1049S', NULL,
     'Snellen et al. 2010. Carbon monoxide via high-dispersion transmission '
     'spectroscopy; the orbital radial-velocity shift also yielded the absolute mass '
     'and roughly 2 km/s high-altitude winds.'),
    ('51 Peg b', 'H2O', 'detected', 'VLT/CRIRES', '2017AJ....153..138B', 5.6,
     'Birkby et al. 2017. Dayside water absorption at high spectral resolution '
     '(R ~ 100,000), 5.6 sigma; confirmed 51 Peg as a double-lined spectroscopic '
     'binary (Kp gives the true mass).'),
    ('HD 189733 b', 'Na', 'detected', 'HET/HRS', '2008ApJ...673L..87R', 3.2,
     'Redfield et al. 2008. First ground-based detection of an exoplanet atmosphere. '
     'Na I doublet in transmission, (-67.2 +/- 20.7)e-5 relative depth, above 3 sigma.'),
    ('55 Cnc e', 'CO2', 'tentative', 'JWST/NIRCam+MIRI', '2024Natur.630..609H', NULL,
     'Hu et al. 2024. First secondary atmosphere on a rocky exoplanet, from JWST '
     'thermal emission (4-12 um); a bona fide volatile atmosphere probably rich in '
     'CO2 or CO, outgassed from a magma ocean. Composition (CO2 vs CO) not uniquely '
     'determined, hence tentative.'),
    ('HD 189733 b', 'H2O', 'detected', 'VLT/CRIRES', '2013MNRAS.436L..35B', 4.8,
     'Birkby et al. 2013. Dayside water absorption at high spectral resolution '
     '(R ~ 100,000, 3.2 um), 4.8 sigma.'),
    ('HD 189733 b', 'CO', 'detected', 'VLT/CRIRES', '2013A&A...554A..82D', 5.0,
     'de Kok et al. 2013. Carbon monoxide in the dayside spectrum, 5 sigma; the '
     'orbital RV shift also gave the true mass (1.16 Mjup). No H2O/CO2/CH4 detected '
     'in this dataset.'),
    ('HD 209458 b', 'H2O', 'detected', 'HST/WFC3', '2013ApJ...774...95D', NULL,
     'Deming et al. 2013. Weak water absorption (about 200 ppm at 1.38 um) via WFC3 '
     'spatial-scan transmission spectroscopy, superposed on a haze/dust-dominated '
     'continuum.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

UPDATE system_orbital_geometry
SET mutual_inclination_deg      = 29.9,
    inclination_uncertainty_deg = 1.0,
    note = 'McArthur et al. 2010: 29.9 +/- 1.0 deg between c and d, the first '
           'astrometric mutual-inclination measurement in an exoplanet system; '
           'likely a planet-planet scattering history.'
WHERE hostname = 'ups And' AND pl_name = 'ups And d';

-- Wide stellar companions: the existing SIMBAD rows lacked a projected
-- separation. Backfill from the companions' characterization papers
-- (abstract-stated values).
UPDATE binary_companions
SET separation_au  = 216,
    source_bibcode = '2006ApJ...641L..57B',
    notes = 'Bakos et al. 2006. Mid-M dwarf companion at projected separation '
            'about 216 AU; orbit lies nearly in the plane of the sky (roughly '
            'perpendicular to the transiting planet orbit).'
WHERE hostname = 'HD 189733' AND component_designation = 'B';

UPDATE binary_companions
SET separation_au  = 750,
    source_bibcode = '2002ApJ...572L..79L',
    notes = 'Lowrance et al. 2002. Common-proper-motion M4.5V companion at '
            'projected separation about 750 AU; the first multi-planet system '
            'known in a multiple-star system.'
WHERE hostname = 'ups And' AND component_designation = 'B';
