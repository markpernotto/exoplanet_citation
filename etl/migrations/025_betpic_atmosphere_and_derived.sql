-- beta Pictoris b deep dive (manual literature review, 2026-05-23). The
-- directly-imaged giant bet Pic b had no curated atmosphere or derived-property
-- data. This adds both, demonstrating the split: molecule detections go to
-- planet_atmospheres, derived scalars (spin, C/O) go to the general
-- planet_derived_measurements table. Values read from the cited papers; bibcodes
-- verified via ADS. Citations linked role='characterization',
-- contribution='atmosphere' in etl/seed_followup_citations.py.
--
--   Snellen et al. 2014 (VLT/CRIRES, R=100,000) -- CO in the thermal spectrum;
--     the rotationally-broadened, blueshifted CO lines gave the orbit and the
--     planet's fast spin (~25 km/s equatorial velocity), the fastest then known.
--   GRAVITY Collaboration 2020 (VLTI, K-band R=500) -- H2O constrained in the
--     spectrum used to derive C/O = 0.43 +/- 0.05; that low C/O with a high mass
--     (12.7 Mjup) points to core accretion with planetesimal enrichment.
--
-- JWST imaging/dust papers (Kammerer 2024 NIRCam, Worthen 2024 MIRI MRS) are in
-- planet_atmospheric_observations and are not molecule-detection sources.
--
-- Apply after 023_hr8799_atmospheres.sql and 024_planet_derived_measurements.sql.
-- Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('bet Pic b', 'CO', 'detected', 'VLT/CRIRES', '2014Natur.509...63S', NULL,
     'Snellen et al. 2014. CO in the thermal spectrum (VLT/CRIRES, R = 100,000); '
     'the blueshifted, rotationally-broadened CO lines also gave the orbit and the '
     'planet spin.'),
    ('bet Pic b', 'H2O', 'detected', 'VLTI/GRAVITY', '2020A&A...633A.110G', NULL,
     'GRAVITY Collaboration 2020. H2O constrained in the R = 500 K-band spectrum '
     'used to derive the C/O ratio (ExoREM forward model and petitRADTRANS retrieval).')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('bet Pic b', 'rotation_velocity', 25, NULL, NULL, 'km_s', 'CO line broadening',
     '2014Natur.509...63S',
     'Snellen et al. 2014. Equatorial rotation velocity ~25 km/s from CO line '
     'broadening (VLT/CRIRES) - faster than any Solar System planet and the fastest '
     'exoplanet spin then measured.'),
    ('bet Pic b', 'C/O', 0.43, 0.05, 0.05, 'ratio', 'forward model + free retrieval',
     '2020A&A...633A.110G',
     'GRAVITY Collaboration 2020. C/O = 0.43 +/- 0.05 (ExoREM and petitRADTRANS '
     'agree). Low C/O with a high mass (12.7 Mjup) points to core accretion with '
     'planetesimal enrichment.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
