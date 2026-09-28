-- 126_planet_satellites.sql
-- New entity: satellites (candidate exomoons) of catalog planets, seeded with
-- the first radial-velocity satellite candidate around a directly imaged
-- substellar companion, CD-35 2722 B.
--
-- Primary source: Hoy, Zurlo, Peña R., et al. 2026, Nature, 655, 865
--   "Planetary-Mass Exosatellite Detected Around the Substellar Companion
--    of a Star"
--   bibcode 2026Natur.655..865H · DOI 10.1038/s41586-026-10751-w · arXiv 2607.05193
--   VLT/CRIRES+ (R ~ 100,000, 1469-1780 nm), 23 epochs Oct 2023 - Feb 2026,
--   RVs via viper, Keplerian fits via EMPEROR, stability via REBOUND.
--   ESO press release eso2610 (2026-07-22).
--
-- Why a new table rather than planet_derived_measurements rows: a satellite is
-- a distinct body with its own orbit, mass and status, not a scalar property
-- of the planet. Modelling it as an entity lets the page list it as a body,
-- lets later candidates (e.g. the transit-timing candidates around
-- Kepler-1625 b and Kepler-1708 b) join without another schema change, and
-- keeps the derived table's controlled vocabulary for planet properties only.
--
-- NASA EA context: the 37 MJup brown dwarf CD-35 2722 B is itself the catalog
-- planet `CD-35 2722 b` (imaging, Wahhaj et al. 2011, 2011ApJ...729..139W;
-- host: 0.4 Msun M dwarf, sy_snum = 1). The satellite therefore hangs off
-- that planet row: star -> catalog planet (brown dwarf) -> satellite.
--
-- Designation: the paper assigns no name and deliberately uses the neutral
-- term "satellite". We store 'satellite 1' (and 'satellite 2' for the
-- alternative model) rather than minting a hierarchical name such as
-- "CD-35 2722 B b" that no authority has issued. When one is assigned, add an
-- alias; do not rename the key.
--
-- Models: the RV data alone cannot separate two fits of nearly equal
-- evidence (logZ -144.3 vs -141.7), because a single eccentric orbit mimics a
-- 2:1 mean-motion-resonance pair. The authors favour the 1-satellite eccentric
-- model on N-body stability grounds only: the 2-satellite model is stable just
-- for coplanar (within ~20 deg), counter-rotating orbits, and the host star's
-- perturbation destabilises it further. Both models are stored, with
-- `preferred` true on the favoured one, so the page can show the favoured
-- solution and disclose the alternative instead of presenting a judgement
-- call as a fact.
--
-- Not stored on purpose: true mass (inclination unconstrained; the paper
-- notes only that a brown-dwarf-mass satellite would need i ~ 4 deg), phase
-- and RV offset/jitter (fit nuisance parameters), and the rejected 14-day,
-- 70-day and 115-day aliases of the inner signal.
--
-- Apply after 125; idempotent on re-run.

BEGIN;

-- 1. Table ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS planet_satellites (
    pl_name                 TEXT NOT NULL,      -- catalog planet the satellite orbits
    satellite_designation   TEXT NOT NULL,      -- 'satellite 1', ... (author naming; no minted IDs)
    model                   TEXT NOT NULL,      -- which published fit these values come from
    preferred               BOOLEAN NOT NULL DEFAULT true,  -- the authors' favoured model
    status                  TEXT NOT NULL
        CHECK (status IN ('candidate', 'confirmed', 'disputed', 'refuted')),
    detection_method        TEXT NOT NULL
        CHECK (detection_method IN ('radial_velocity', 'transit_timing', 'transit', 'imaging', 'microlensing', 'other')),
    instrument              TEXT,               -- e.g. 'VLT/CRIRES+'
    period_days             DOUBLE PRECISION,
    period_unc_hi           DOUBLE PRECISION,   -- +1 sigma
    period_unc_lo           DOUBLE PRECISION,   -- -1 sigma (stored positive)
    rv_semi_amplitude_ms    DOUBLE PRECISION,
    rv_semi_amplitude_unc_hi DOUBLE PRECISION,
    rv_semi_amplitude_unc_lo DOUBLE PRECISION,
    eccentricity            DOUBLE PRECISION,
    eccentricity_unc_hi     DOUBLE PRECISION,
    eccentricity_unc_lo     DOUBLE PRECISION,
    longitude_periastron_rad DOUBLE PRECISION,
    longitude_periastron_unc_hi DOUBLE PRECISION,
    longitude_periastron_unc_lo DOUBLE PRECISION,
    semi_major_axis_au      DOUBLE PRECISION,
    semi_major_axis_unc_hi  DOUBLE PRECISION,
    semi_major_axis_unc_lo  DOUBLE PRECISION,
    msini_mjup              DOUBLE PRECISION,   -- minimum mass (RV); NULL for non-RV methods
    msini_unc_hi            DOUBLE PRECISION,
    msini_unc_lo            DOUBLE PRECISION,
    mass_mjup               DOUBLE PRECISION,   -- true mass, when inclination is known
    mass_unc_hi             DOUBLE PRECISION,
    mass_unc_lo             DOUBLE PRECISION,
    bibcode                 TEXT NOT NULL,      -- ADS bibcode of the source paper
    curator_note            TEXT,
    curated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pl_name, satellite_designation, bibcode, model)
);

CREATE INDEX IF NOT EXISTS idx_planet_satellites_pl_name ON planet_satellites (pl_name);

-- 2. Publication + citation link ----------------------------------------------
WITH pub AS (
    INSERT INTO publications (
        bibcode, doi, arxiv_id, title, authors, journal, pub_date,
        resolved_via, confidence, updated_at
    ) VALUES (
        '2026Natur.655..865H',
        '10.1038/s41586-026-10751-w',
        '2607.05193',
        'Planetary-Mass Exosatellite Detected Around the Substellar Companion of a Star',
        '[
            "Hoy, Kevin", "Zurlo, Alice", "Peña R., Pablo A.", "Köhler, Jana",
            "Desidera, Silvano", "Gratton, Raffaele", "Lazzoni, Cecilia",
            "Petrus, Simon", "Rodler, Florian", "Smoker, Jonathan",
            "D''Orazi, Valentina", "Carleo, Ilaria", "Giovannini, Ilaria"
        ]'::jsonb,
        'Nature',
        DATE '2026-07-22',
        'manual', 'high', now()
    )
    ON CONFLICT (bibcode) WHERE bibcode IS NOT NULL DO UPDATE SET
        doi          = EXCLUDED.doi,
        arxiv_id     = EXCLUDED.arxiv_id,
        title        = EXCLUDED.title,
        authors      = EXCLUDED.authors,
        journal      = EXCLUDED.journal,
        pub_date     = EXCLUDED.pub_date,
        resolved_via = EXCLUDED.resolved_via,
        confidence   = EXCLUDED.confidence,
        updated_at   = now()
    RETURNING pub_id
)
INSERT INTO planet_publications (pl_name, pub_id, role, contribution)
SELECT 'CD-35 2722 b', pub_id, 'characterization', 'satellite' FROM pub
ON CONFLICT DO NOTHING;

-- 3. Satellite rows (Table 1) -------------------------------------------------
-- Uncertainties are the paper's asymmetric 1-sigma intervals, stored as
-- positive magnitudes.
INSERT INTO planet_satellites
    (pl_name, satellite_designation, model, preferred, status, detection_method, instrument,
     period_days, period_unc_hi, period_unc_lo,
     rv_semi_amplitude_ms, rv_semi_amplitude_unc_hi, rv_semi_amplitude_unc_lo,
     eccentricity, eccentricity_unc_hi, eccentricity_unc_lo,
     longitude_periastron_rad, longitude_periastron_unc_hi, longitude_periastron_unc_lo,
     semi_major_axis_au, semi_major_axis_unc_hi, semi_major_axis_unc_lo,
     msini_mjup, msini_unc_hi, msini_unc_lo,
     bibcode, curator_note)
VALUES
    -- Favoured: single eccentric satellite.
    ('CD-35 2722 b', 'satellite 1',
     '1-satellite eccentric Keplerian (EMPEROR); favoured on REBOUND N-body stability',
     true, 'candidate', 'radial_velocity', 'VLT/CRIRES+',
     171.112, 0.525, 0.363,
     318.479, 5.022, 12.718,
     0.269, 0.013, 0.037,
     3.459, 0.071, 0.084,
     0.200, 0.001, 0.004,
     0.918, 0.011, 0.045,
     '2026Natur.655..865H',
     'Hoy 2026 Table 1, 1-satellite fit. GLS peak near 170 d above the 0.1% FAP threshold; '
     'residual RMS 53.4 m/s; logZ = -144.3. Favoured over the 2-satellite model because it is '
     'stable in N-body integrations for nearly all arguments of periapsis (small unstable islands '
     'near +/-115 deg). True mass unknown: orbital inclination is unconstrained and the brown '
     'dwarf''s obliquity is unmeasured; a satellite of >= 13 MJup would need i ~ 4 deg. Periapse '
     'distance is far outside the conservative Roche limit (0.0064 au). The 171 d period is 11 '
     'sigma from the half-year alias and shows no correlation with barycentric correction, '
     'instrument profile or weather. The authors call the body a "satellite" and note no '
     'accepted definition of an exomoon exists; status stays candidate pending follow-up RVs.'),

    -- Alternative: two circular satellites near 2:1 mean-motion resonance.
    ('CD-35 2722 b', 'satellite 1',
     '2-satellite circular Keplerian near 2:1 MMR (EMPEROR); disfavoured on N-body stability',
     false, 'candidate', 'radial_velocity', 'VLT/CRIRES+',
     171.454, 0.191, 0.813,
     305.959, 17.532, 18.540,
     0.001, 0.013, 0.001,
     5.647, 0.636, 4.742,
     0.195, 0.005, 0.004,
     0.869, 0.033, 0.025,
     '2026Natur.655..865H',
     'Hoy 2026 Table 1, 2-satellite fit, outer body. Same ~171 d signal as the favoured model '
     'but on a circular orbit; residual RMS 51.0 m/s; logZ = -141.7. Disfavoured: REBOUND '
     'integrations eject one satellite within ~500 yr unless the pair is counter-rotating and '
     'within ~20 deg of coplanar, and the host star''s perturbation adds further unstable islands.'),

    ('CD-35 2722 b', 'satellite 2',
     '2-satellite circular Keplerian near 2:1 MMR (EMPEROR); disfavoured on N-body stability',
     false, 'candidate', 'radial_velocity', 'VLT/CRIRES+',
     87.349, 0.641, 0.451,
     94.970, 19.881, 18.887,
     0.008, 0.006, 0.008,
     0.352, 5.929, 0.352,
     0.125, 0.002, 0.000,
     0.219, 0.048, 0.046,
     '2026Natur.655..865H',
     'Hoy 2026 Table 1, 2-satellite fit, inner body. Period is degenerate: 88 d is ~4.5x more '
     'likely than 115 d and ~6x more likely than 70 d by Bayesian evidence, all yearly-sampling '
     'aliases of each other; a 14 d window was rejected as a sampling artifact. Exists only in '
     'the disfavoured model.')
ON CONFLICT (pl_name, satellite_designation, bibcode, model) DO UPDATE SET
    preferred                 = EXCLUDED.preferred,
    status                    = EXCLUDED.status,
    detection_method          = EXCLUDED.detection_method,
    instrument                = EXCLUDED.instrument,
    period_days               = EXCLUDED.period_days,
    period_unc_hi             = EXCLUDED.period_unc_hi,
    period_unc_lo             = EXCLUDED.period_unc_lo,
    rv_semi_amplitude_ms      = EXCLUDED.rv_semi_amplitude_ms,
    rv_semi_amplitude_unc_hi  = EXCLUDED.rv_semi_amplitude_unc_hi,
    rv_semi_amplitude_unc_lo  = EXCLUDED.rv_semi_amplitude_unc_lo,
    eccentricity              = EXCLUDED.eccentricity,
    eccentricity_unc_hi       = EXCLUDED.eccentricity_unc_hi,
    eccentricity_unc_lo       = EXCLUDED.eccentricity_unc_lo,
    longitude_periastron_rad  = EXCLUDED.longitude_periastron_rad,
    longitude_periastron_unc_hi = EXCLUDED.longitude_periastron_unc_hi,
    longitude_periastron_unc_lo = EXCLUDED.longitude_periastron_unc_lo,
    semi_major_axis_au        = EXCLUDED.semi_major_axis_au,
    semi_major_axis_unc_hi    = EXCLUDED.semi_major_axis_unc_hi,
    semi_major_axis_unc_lo    = EXCLUDED.semi_major_axis_unc_lo,
    msini_mjup                = EXCLUDED.msini_mjup,
    msini_unc_hi              = EXCLUDED.msini_unc_hi,
    msini_unc_lo              = EXCLUDED.msini_unc_lo,
    curator_note              = EXCLUDED.curator_note,
    curated_at                = now();

COMMIT;

-- Verify:
--   SELECT satellite_designation, preferred, period_days, msini_mjup, eccentricity, semi_major_axis_au
--     FROM planet_satellites WHERE pl_name = 'CD-35 2722 b' ORDER BY preferred DESC, satellite_designation;
--   -- expect 3 rows, exactly one preferred
--   SELECT pp.role, pp.contribution, p.bibcode FROM planet_publications pp
--     JOIN publications p USING (pub_id) WHERE pp.pl_name = 'CD-35 2722 b';
--   -- expect discovery 2011ApJ...729..139W + characterization/satellite 2026Natur.655..865H
