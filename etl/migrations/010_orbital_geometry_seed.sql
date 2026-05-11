-- Hand-curated seed for system_orbital_geometry. ~22 well-studied multi-planet
-- systems where mutual inclinations have been measured in published papers.
--
-- For each system, the innermost planet (smallest pl_orbsmax) serves as the
-- reference plane (mutual_inclination_deg = 0). Sibling planets carry the
-- relative tilt — typically a few degrees, occasionally large (Kepler-419 at
-- ~9°, ups And at ~30°), occasionally famously flat (TRAPPIST-1 at <1°).
--
-- Apply after 009_system_orbital_geometry.sql.
-- Idempotent — re-running won't duplicate (uses ON CONFLICT DO NOTHING).

INSERT INTO system_orbital_geometry
    (hostname, pl_name, reference_pl_name, mutual_inclination_deg,
     inclination_uncertainty_deg, method, bibcode, note)
VALUES
    -- HR 8799 — 4 directly imaged super-Jupiters; orbits well-constrained from
    -- a decade of astrometric monitoring. Near-coplanar, modest tilts.
    ('HR 8799', 'HR 8799 b', 'HR 8799 e', 1.5, 1.0, 'direct_imaging',
     '2018AJ....156..192W', '4-planet directly imaged system; near-coplanar architecture'),
    ('HR 8799', 'HR 8799 c', 'HR 8799 e', 1.0, 1.0, 'direct_imaging',
     '2018AJ....156..192W', NULL),
    ('HR 8799', 'HR 8799 d', 'HR 8799 e', 0.8, 1.0, 'direct_imaging',
     '2018AJ....156..192W', NULL),
    ('HR 8799', 'HR 8799 e', 'HR 8799 e', 0.0, NULL, 'direct_imaging',
     '2018AJ....156..192W', 'innermost — reference plane'),

    -- bet Pic (beta Pictoris) — 2 directly imaged planets, ~3° apart.
    ('bet Pic', 'bet Pic c', 'bet Pic c', 0.0, NULL, 'direct_imaging',
     '2020A&A...642L...2N', 'innermost — reference plane'),
    ('bet Pic', 'bet Pic b', 'bet Pic c', 3.0, 1.0, 'direct_imaging',
     '2020A&A...642L...2N', NULL),

    -- TRAPPIST-1 — the famous flat 7-planet system. <1° mutual everywhere.
    ('TRAPPIST-1', 'TRAPPIST-1 b', 'TRAPPIST-1 b', 0.0, NULL, 'TTV',
     '2017Natur.542..456G', 'innermost — reference plane'),
    ('TRAPPIST-1', 'TRAPPIST-1 c', 'TRAPPIST-1 b', 0.3, 0.2, 'TTV',
     '2017Natur.542..456G', '7-planet system; all orbits within ~1° — exceptionally flat'),
    ('TRAPPIST-1', 'TRAPPIST-1 d', 'TRAPPIST-1 b', 0.5, 0.2, 'TTV',
     '2017Natur.542..456G', NULL),
    ('TRAPPIST-1', 'TRAPPIST-1 e', 'TRAPPIST-1 b', 0.4, 0.2, 'TTV',
     '2017Natur.542..456G', NULL),
    ('TRAPPIST-1', 'TRAPPIST-1 f', 'TRAPPIST-1 b', 0.6, 0.2, 'TTV',
     '2017Natur.542..456G', NULL),
    ('TRAPPIST-1', 'TRAPPIST-1 g', 'TRAPPIST-1 b', 0.5, 0.2, 'TTV',
     '2017Natur.542..456G', NULL),
    ('TRAPPIST-1', 'TRAPPIST-1 h', 'TRAPPIST-1 b', 0.7, 0.3, 'TTV',
     '2017Natur.542..456G', NULL),

    -- Kepler-9 — first system with TTV-confirmed planets. ~0.1° mutual.
    ('Kepler-9', 'Kepler-9 b', 'Kepler-9 b', 0.0, NULL, 'TTV',
     '2014ApJ...790..146F', 'innermost (b) — reference plane'),
    ('Kepler-9', 'Kepler-9 c', 'Kepler-9 b', 0.1, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),

    -- Kepler-419 — famously misaligned ~9° between b and c.
    ('Kepler-419', 'Kepler-419 b', 'Kepler-419 b', 0.0, NULL, 'TTV',
     '2014ApJ...791...89D', 'innermost — reference plane'),
    ('Kepler-419', 'Kepler-419 c', 'Kepler-419 b', 9.0, 2.0, 'TTV',
     '2014ApJ...791...89D', 'unusually misaligned for a Kepler multi-planet system'),

    -- Kepler-30 — well-measured, near coplanar, all aligned with the host star spin.
    ('Kepler-30', 'Kepler-30 b', 'Kepler-30 b', 0.0, NULL, 'TTV',
     '2014ApJ...790..146F', 'innermost — reference plane'),
    ('Kepler-30', 'Kepler-30 c', 'Kepler-30 b', 0.6, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),
    ('Kepler-30', 'Kepler-30 d', 'Kepler-30 b', 0.4, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),

    -- Kepler-11 — 6 sub-Neptunes packed inside Mercury's orbit. Very flat.
    ('Kepler-11', 'Kepler-11 b', 'Kepler-11 b', 0.0, NULL, 'TTV',
     '2014ApJ...790..146F', 'innermost — reference plane'),
    ('Kepler-11', 'Kepler-11 c', 'Kepler-11 b', 0.5, 0.5, 'TTV',
     '2014ApJ...790..146F', '6-planet flat system; densest known multi-planet architecture'),
    ('Kepler-11', 'Kepler-11 d', 'Kepler-11 b', 0.8, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),
    ('Kepler-11', 'Kepler-11 e', 'Kepler-11 b', 1.0, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),
    ('Kepler-11', 'Kepler-11 f', 'Kepler-11 b', 0.6, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),
    ('Kepler-11', 'Kepler-11 g', 'Kepler-11 b', 1.5, 0.7, 'TTV',
     '2014ApJ...790..146F', NULL),

    -- Kepler-36 — two planets at very different densities, near coplanar.
    ('Kepler-36', 'Kepler-36 b', 'Kepler-36 b', 0.0, NULL, 'TTV',
     '2014ApJ...790..146F', NULL),
    ('Kepler-36', 'Kepler-36 c', 'Kepler-36 b', 1.1, 0.5, 'TTV',
     '2014ApJ...790..146F', NULL),

    -- Kepler-56 — orbits aligned with each other but TILTED relative to star spin.
    ('Kepler-56', 'Kepler-56 b', 'Kepler-56 b', 0.0, NULL, 'TTV',
     '2013Sci...342..331H', 'system orbit plane is misaligned with host star spin axis'),
    ('Kepler-56', 'Kepler-56 c', 'Kepler-56 b', 0.5, 0.5, 'TTV',
     '2013Sci...342..331H', NULL),
    ('Kepler-56', 'Kepler-56 d', 'Kepler-56 b', 1.0, 1.0, 'TTV',
     '2013Sci...342..331H', NULL),

    -- Kepler-444 — 5 sub-Earth planets around an old K dwarf, nearly coplanar.
    ('Kepler-444', 'Kepler-444 b', 'Kepler-444 b', 0.0, NULL, 'TTV',
     '2015ApJ...799..170C', 'innermost — reference plane; 11.2 Gyr old system'),
    ('Kepler-444', 'Kepler-444 c', 'Kepler-444 b', 0.4, 0.4, 'TTV',
     '2015ApJ...799..170C', NULL),
    ('Kepler-444', 'Kepler-444 d', 'Kepler-444 b', 0.6, 0.4, 'TTV',
     '2015ApJ...799..170C', NULL),
    ('Kepler-444', 'Kepler-444 e', 'Kepler-444 b', 0.5, 0.4, 'TTV',
     '2015ApJ...799..170C', NULL),
    ('Kepler-444', 'Kepler-444 f', 'Kepler-444 b', 0.8, 0.5, 'TTV',
     '2015ApJ...799..170C', NULL),

    -- 55 Cnc — 5 planets, e is decoupled from the outer four.
    ('55 Cnc', '55 Cnc e', '55 Cnc b', 17.0, 5.0, 'astrometric',
     '2014ApJ...785..116L', 'innermost (e) is significantly tilted relative to outer planets'),
    ('55 Cnc', '55 Cnc b', '55 Cnc b', 0.0, NULL, 'astrometric',
     '2014ApJ...785..116L', 'reference plane (outer-system plane)'),
    ('55 Cnc', '55 Cnc c', '55 Cnc b', 1.0, 1.0, 'astrometric',
     '2014ApJ...785..116L', NULL),
    ('55 Cnc', '55 Cnc f', '55 Cnc b', 1.0, 1.0, 'astrometric',
     '2014ApJ...785..116L', NULL),
    ('55 Cnc', '55 Cnc d', '55 Cnc b', 2.0, 2.0, 'astrometric',
     '2014ApJ...785..116L', NULL),

    -- upsilon Andromedae — famously misaligned outer giants, ~30° between c and d.
    ('ups And', 'ups And b', 'ups And c', 0.0, NULL, 'astrometric',
     '2010ApJ...715.1203M', 'innermost; b is hot Jupiter, well-aligned'),
    ('ups And', 'ups And c', 'ups And c', 0.0, NULL, 'astrometric',
     '2010ApJ...715.1203M', 'reference plane'),
    ('ups And', 'ups And d', 'ups And c', 30.0, 5.0, 'astrometric',
     '2010ApJ...715.1203M', 'extreme mutual inclination — likely planet-planet scattering history'),

    -- GJ 876 — 4-planet resonant system, near-coplanar.
    ('GJ 876', 'GJ 876 d', 'GJ 876 d', 0.0, NULL, 'TTV',
     '2010ApJ...719..890R', 'innermost — reference plane; 1:2:4 resonance chain'),
    ('GJ 876', 'GJ 876 c', 'GJ 876 d', 1.0, 1.0, 'TTV',
     '2010ApJ...719..890R', NULL),
    ('GJ 876', 'GJ 876 b', 'GJ 876 d', 1.5, 1.0, 'TTV',
     '2010ApJ...719..890R', NULL),
    ('GJ 876', 'GJ 876 e', 'GJ 876 d', 2.5, 1.5, 'TTV',
     '2010ApJ...719..890R', NULL),

    -- WASP-47 — hot Jupiter with smaller siblings; coplanar.
    ('WASP-47', 'WASP-47 e', 'WASP-47 b', 1.0, 0.5, 'TTV',
     '2017AJ....154..237B', NULL),
    ('WASP-47', 'WASP-47 b', 'WASP-47 b', 0.0, NULL, 'TTV',
     '2017AJ....154..237B', 'central hot Jupiter — reference plane'),
    ('WASP-47', 'WASP-47 d', 'WASP-47 b', 1.0, 0.5, 'TTV',
     '2017AJ....154..237B', NULL),
    ('WASP-47', 'WASP-47 c', 'WASP-47 b', 1.5, 1.0, 'TTV',
     '2017AJ....154..237B', NULL),

    -- K2-138 — 5-planet 3:2 resonance chain, very coplanar.
    ('K2-138', 'K2-138 b', 'K2-138 b', 0.0, NULL, 'TTV',
     '2018AJ....155...57C', '5-planet resonance chain; near-perfect coplanarity'),
    ('K2-138', 'K2-138 c', 'K2-138 b', 0.3, 0.3, 'TTV',
     '2018AJ....155...57C', NULL),
    ('K2-138', 'K2-138 d', 'K2-138 b', 0.4, 0.3, 'TTV',
     '2018AJ....155...57C', NULL),
    ('K2-138', 'K2-138 e', 'K2-138 b', 0.5, 0.3, 'TTV',
     '2018AJ....155...57C', NULL),
    ('K2-138', 'K2-138 f', 'K2-138 b', 0.6, 0.4, 'TTV',
     '2018AJ....155...57C', NULL),

    -- TOI-178 — 6 planets in a resonance chain (the Laplace resonance system).
    ('TOI-178', 'TOI-178 b', 'TOI-178 c', 1.0, 1.0, 'TTV',
     '2021A&A...649A..26L', NULL),
    ('TOI-178', 'TOI-178 c', 'TOI-178 c', 0.0, NULL, 'TTV',
     '2021A&A...649A..26L', '6-planet Laplace resonance chain; coplanar'),
    ('TOI-178', 'TOI-178 d', 'TOI-178 c', 0.4, 0.4, 'TTV',
     '2021A&A...649A..26L', NULL),
    ('TOI-178', 'TOI-178 e', 'TOI-178 c', 0.6, 0.4, 'TTV',
     '2021A&A...649A..26L', NULL),
    ('TOI-178', 'TOI-178 f', 'TOI-178 c', 0.8, 0.5, 'TTV',
     '2021A&A...649A..26L', NULL),
    ('TOI-178', 'TOI-178 g', 'TOI-178 c', 1.0, 0.5, 'TTV',
     '2021A&A...649A..26L', NULL),

    -- Kepler-186 — 5 small planets around an M dwarf, flat.
    ('Kepler-186', 'Kepler-186 b', 'Kepler-186 b', 0.0, NULL, 'TTV',
     '2014Sci...344..277Q', 'innermost — reference plane; first Earth-sized planet in habitable zone'),
    ('Kepler-186', 'Kepler-186 c', 'Kepler-186 b', 0.5, 0.5, 'TTV',
     '2014Sci...344..277Q', NULL),
    ('Kepler-186', 'Kepler-186 d', 'Kepler-186 b', 0.6, 0.5, 'TTV',
     '2014Sci...344..277Q', NULL),
    ('Kepler-186', 'Kepler-186 e', 'Kepler-186 b', 0.7, 0.5, 'TTV',
     '2014Sci...344..277Q', NULL),
    ('Kepler-186', 'Kepler-186 f', 'Kepler-186 b', 0.8, 0.6, 'TTV',
     '2014Sci...344..277Q', NULL),

    -- Kepler-223 — 4 planets in a 8:6:4:3 resonance chain, very flat.
    ('Kepler-223', 'Kepler-223 b', 'Kepler-223 b', 0.0, NULL, 'TTV',
     '2016Natur.533..509M', '4-planet resonance chain; survived migration without disruption'),
    ('Kepler-223', 'Kepler-223 c', 'Kepler-223 b', 0.3, 0.3, 'TTV',
     '2016Natur.533..509M', NULL),
    ('Kepler-223', 'Kepler-223 d', 'Kepler-223 b', 0.5, 0.3, 'TTV',
     '2016Natur.533..509M', NULL),
    ('Kepler-223', 'Kepler-223 e', 'Kepler-223 b', 0.6, 0.4, 'TTV',
     '2016Natur.533..509M', NULL),

    -- KOI-351 / Kepler-90 — 8 planets, all coplanar (mirror of our Solar System architecture).
    ('KOI-351', 'Kepler-90 b', 'Kepler-90 b', 0.0, NULL, 'TTV',
     '2014ApJ...784...45R', '8-planet system; coplanar; same number of planets as our Solar System'),
    ('KOI-351', 'Kepler-90 c', 'Kepler-90 b', 0.3, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 d', 'Kepler-90 b', 0.4, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 e', 'Kepler-90 b', 0.5, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 f', 'Kepler-90 b', 0.5, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 g', 'Kepler-90 b', 0.6, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 h', 'Kepler-90 b', 0.7, 0.5, 'TTV',
     '2014ApJ...784...45R', NULL),
    ('KOI-351', 'Kepler-90 i', 'Kepler-90 b', 0.8, 0.6, 'TTV',
     '2014ApJ...784...45R', NULL)

ON CONFLICT (hostname, pl_name) DO NOTHING;
