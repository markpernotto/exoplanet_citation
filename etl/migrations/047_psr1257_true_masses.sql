-- PSR B1257+12 deep dive (manual literature review, 2026-05-24). THE first confirmed
-- planetary system around any star other than the Sun (Wolszczan & Frail 1992; the
-- moon-mass inner planet and the definitive confirmation came in Wolszczan 1994). Three
-- planets orbit a 6.2 ms millisecond pulsar: b (~0.02 M_earth, moon-mass, 0.19 au),
-- c and d (~4 M_earth each, 0.36 / 0.46 au, locked near a 3:2 mean-motion resonance).
-- The value-add here is provenance + the orbital geometry: Konacki & Wolszczan 2003
-- measured the TRUE masses and orbital inclinations of c and d from their mutual
-- gravitational perturbations (microsecond pulse-arrival variations). The catalog
-- already carries those true masses (4.3 / 3.9 M_earth) but does NOT cite the paper
-- they come from, and the inclinations are not recorded anywhere -- so we add the
-- inclinations to planet_derived_measurements and credit Konacki & Wolszczan 2003 +
-- Wolszczan 1994 in etl/seed_followup_citations.py. The near-coplanar (~6 deg), near
-- 3:2-resonant configuration is the key evidence that these planets formed in a
-- post-supernova fallback/debris disk.
--
--   Wolszczan & Frail 1992 (Arecibo; discovery of c & d) -- >=2.8 and 3.4 M_earth at
--     0.36 / 0.47 au, near-circular, ~3:2 period ratio.
--   Wolszczan 1994 (Arecibo) -- confirmed c & d via the predicted resonance
--     perturbations and discovered the moon-mass inner planet b.
--   Konacki & Wolszczan 2003 -- true masses m_c = 4.3 +/- 0.2, m_d = 3.9 +/- 0.2
--     M_earth; inclinations i_c = 53 +/- 4 deg, i_d = 47 +/- 3 deg (or 127/133);
--     orbits almost coplanar -> disk origin; Earth-like masses guarantee stability.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('PSR B1257+12 c', 'orbital_inclination', 53, 4, 4, 'deg', 'pulsar-timing perturbations',
     '2003ApJ...591L.147K',
     'Konacki & Wolszczan 2003: i = 53 +/- 4 deg (or 127), from the mutual gravitational '
     'perturbations between c and d. Gives a true mass of 4.3 +/- 0.2 M_earth (the value the '
     'catalog already uses). Near-coplanar with d -- combined with the near 3:2 resonance, '
     'strong evidence for a disk origin.'),
    ('PSR B1257+12 d', 'orbital_inclination', 47, 3, 3, 'deg', 'pulsar-timing perturbations',
     '2003ApJ...591L.147K',
     'Konacki & Wolszczan 2003: i = 47 +/- 3 deg (or 133), from the same perturbation analysis. '
     'Gives a true mass of 3.9 +/- 0.2 M_earth. The ~6 deg mutual inclination with c makes the '
     'two Earth-mass planets almost coplanar.')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
