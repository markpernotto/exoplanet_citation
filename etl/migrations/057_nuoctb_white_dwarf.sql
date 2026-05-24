-- nu Oct B white-dwarf companion (manual literature review, 2026-05-24; "Wild Orbits" theme).
-- nu Octantis is a tight (~2.6 AU mean separation) binary hosting nu Oct A b, a planet on a
-- RETROGRADE circum-primary (S-type) orbit midway between the two stars. Cheng et al. 2025
-- (Nature) confirmed the planet AND showed, via adaptive-optics imaging, that the companion
-- nu Oct B is a WHITE DWARF -- which reframes the planet as second-generation (formed from the
-- WD progenitor's shed material) or captured from a circumbinary orbit, since the tight binary
-- rules out coeval formation. nu Oct B was absent from binary_companions; this adds it with the
-- verified facts (spectral class D, mean orbital separation 2.6 AU), cited to Cheng 2025. The
-- AO-imaging projected separation (arcsec) + position angle and the WD mass/Teff are not in the
-- discovery abstract, so separation_arcsec / position_angle_deg / mass / Teff are left NULL --
-- the companion will not be sky-positioned in the 3D scene until those are filled. Bibcode
-- verified via ADS. (The planet->paper link nu Oct A b -> Cheng 2025 is in
-- etl/seed_followup_citations.py as role='follow_up'.)
--
--   Cheng et al. 2025 (Nature): companion nu Oct B is a white dwarf; binary mean sep ~2.6 AU.
--
-- Idempotent (ON CONFLICT on the (hostname, component_designation) primary key; the NULL
-- render fields are not in the SET list, so a later fill of arcsec/PA/mass/Teff is preserved).

INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, component_spectype, separation_au,
     inner_binary, binary_class, source_catalog, source_bibcode, notes)
VALUES
    ('nu Oct A', 'B', 'A', 'D', 2.6,
     false, 'K-giant + white dwarf', 'manual', '2025Natur.641..866C',
     'White-dwarf companion to nu Oct A, confirmed by adaptive-optics imaging (Cheng et al. 2025, '
     'Nature). Mean binary separation ~2.6 AU. The planet nu Oct A b orbits the K-giant primary on '
     'a retrograde S-type orbit between the stars; the WD nature implies a second-generation or '
     'captured origin. AO-imaging projected separation/PA and the WD mass/Teff not yet harvested.')
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation = EXCLUDED.primary_designation,
    component_spectype  = EXCLUDED.component_spectype,
    separation_au       = EXCLUDED.separation_au,
    inner_binary        = EXCLUDED.inner_binary,
    binary_class        = EXCLUDED.binary_class,
    source_catalog      = EXCLUDED.source_catalog,
    source_bibcode      = EXCLUDED.source_bibcode,
    notes               = EXCLUDED.notes;
