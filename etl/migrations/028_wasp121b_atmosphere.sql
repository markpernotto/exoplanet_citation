-- WASP-121 b atmosphere deep dive (manual literature review, 2026-05-23). The
-- benchmark ultra-hot Jupiter (Teq ~2400 K) had no curated molecule/atom
-- detections despite a deep HST/Spitzer/JWST/high-resolution record. Values read
-- from the cited papers; bibcodes verified via ADS. Citations linked
-- role='characterization', contribution='atmosphere' in
-- etl/seed_followup_citations.py.
--
--   Evans et al. 2017 (HST/WFC3 emission)  -- H2O + a dayside thermal inversion
--     ("an ultrahot gas-giant with a stratosphere").
--   Evans et al. 2018 (HST/STIS optical)   -- VO; TiO ruled out (Ti cold-trapped);
--     10-30x solar metal enrichment.
--   Sing et al. 2019 (HST/STIS NUV)        -- escaping ionised Fe II and Mg II
--     (the planet is losing mass).
--   Hoeijmakers et al. 2020 (HARPS hi-res) -- neutral Na, Mg, Ca, Cr, Fe, Ni, V.
--   Gapp et al. 2025 (JWST/NIRSpec G395H)  -- SiO at 5.2 sigma + thermal
--     dissociation of H2O and H2 on the dayside.
--
-- Apply after 008_atmospheres.sql. Idempotent.

INSERT INTO planet_atmospheres
    (pl_name, molecule, detection, instrument, bibcode, confidence_sigma, curator_note)
VALUES
    ('WASP-121 b', 'H2O', 'detected', 'HST/WFC3', '2017Natur.548...58E', NULL,
     'Evans et al. 2017. H2O in emission revealing a dayside thermal inversion / stratosphere.'),
    ('WASP-121 b', 'VO', 'detected', 'HST/STIS', '2018AJ....156..283E', NULL,
     'Evans et al. 2018. VO spectral bands in the optical transmission spectrum (abundance ~ -6.6 dex); 10-30x solar metal enrichment.'),
    ('WASP-121 b', 'Na', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Na via high-resolution cross-correlation; lines significantly broadened, possibly outflowing.'),
    ('WASP-121 b', 'Mg', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Mg; part of the metal inventory (Na, Mg, Ca, Cr, Fe, Ni, V).'),
    ('WASP-121 b', 'Ca', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Ca via high-resolution cross-correlation.'),
    ('WASP-121 b', 'Cr', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Cr via high-resolution cross-correlation.'),
    ('WASP-121 b', 'Fe', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Fe via high-resolution cross-correlation; atomic lines under-predicted by hydrostatic models, indicating an extended atmosphere.'),
    ('WASP-121 b', 'Ni', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral Ni via high-resolution cross-correlation.'),
    ('WASP-121 b', 'V', 'detected', 'ESO 3.6m/HARPS', '2020A&A...641A.123H', NULL,
     'Hoeijmakers et al. 2020 (HEARTS IV). Neutral V, predicted in equilibrium with the VO seen by HST.'),
    ('WASP-121 b', 'Fe II', 'detected', 'HST/STIS', '2019AJ....158...91S', NULL,
     'Sing et al. 2019 (HST NUV transmission, PanCET). Ionised iron in the escaping exosphere.'),
    ('WASP-121 b', 'Mg II', 'detected', 'HST/STIS', '2019AJ....158...91S', NULL,
     'Sing et al. 2019 (HST NUV transmission, PanCET). Ionised magnesium in the escaping exosphere; the planet is losing mass.'),
    ('WASP-121 b', 'SiO', 'detected', 'JWST/NIRSpec', '2025AJ....169..341G', 5.2,
     'Gapp et al. 2025 (JWST/NIRSpec G395H). SiO at 5.2 sigma, consistent with chemical equilibrium; data also show thermal dissociation of H2O and H2 on the dayside.'),
    ('WASP-121 b', 'TiO', 'ruled_out', 'HST/STIS', '2018AJ....156..283E', NULL,
     'Evans et al. 2018 / Hoeijmakers et al. 2020. TiO NOT detected (3 sigma upper limit ~ -7.9 dex) and Ti is depleted, consistent with a cold-trap removing titanium from the gas phase.')
ON CONFLICT (pl_name, molecule) DO UPDATE SET
    detection        = EXCLUDED.detection,
    instrument       = EXCLUDED.instrument,
    bibcode          = EXCLUDED.bibcode,
    confidence_sigma = EXCLUDED.confidence_sigma,
    curator_note     = EXCLUDED.curator_note;
