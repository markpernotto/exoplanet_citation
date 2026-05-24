-- GJ 86 B white-dwarf companion provenance (manual literature review, 2026-05-24).
-- GJ 86 b is a hot Jupiter (~4.4 Mjup, 15.8 d) orbiting GJ 86 A; the system's wide
-- companion GJ 86 B is a white dwarf -- the first white dwarf found orbiting an exoplanet
-- host star. GJ 86 B already exists in binary_companions from the general SIMBAD
-- cross-reference load (component_designation 'B', spectype DQ6, separation ~2.05") but
-- carried NO citation (source_bibcode was NULL) -- a "displayed but uncited" gap, since
-- the companion is rendered in the 3D scene. This sets its source_bibcode to the
-- white-dwarf confirmation paper. (GJ 86 is an S-type system, NOT a cb_flag circumbinary
-- host, so this row is outside the cb_flag inner-binary backfill -- ownership confirmed
-- with that workstream.) The companion's physical parameters (mass, Teff) remain to be
-- harvested from Mugrauer & Neuhauser 2005 / Lagrange et al. 2006 if those tables are
-- obtained. Bibcode verified via ADS. The planet->paper link is added in
-- etl/seed_followup_citations.py (role='characterization', contribution='binary_companion').
--
--   Mugrauer & Neuhauser 2005, "Gl86B: a white dwarf orbits an exoplanet host star"
--     (2005MNRAS.361L..15M) -- confirms GJ 86 B is a white dwarf.
--   Lagrange et al. 2006 (2006A&A...459..955L) -- further NIR coronagraphic constraints.
--
-- Idempotent (scoped UPDATE to fixed values).

UPDATE binary_companions
SET source_bibcode = '2005MNRAS.361L..15M',
    notes = 'White-dwarf companion confirmed by Mugrauer & Neuhauser 2005 '
            '(Gl86B: a white dwarf orbits an exoplanet host star); further NIR '
            'constraints in Lagrange et al. 2006. Physical parameters (mass, Teff) '
            'not yet harvested. First white dwarf found orbiting an exoplanet host star.'
WHERE hostname = 'GJ 86' AND component_designation = 'B';
