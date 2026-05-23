-- TRAPPIST-1 orbital-geometry refinement from Agol et al. 2021 (manual deep
-- dive, 2026-05-22; bibcode 2021PSJ.....2....1A, verified via ADS). Migration 010
-- seeded hand-curated mutual inclinations (0.3-0.7 deg) sourced to the Gillon
-- et al. 2017 discovery paper. Agol et al. 2021 Table 5 reports MEASURED
-- sky-plane orbital inclinations from the photodynamic fit:
--   b 89.728+/-0.165, c 89.778+/-0.118, d 89.896+/-0.077, e 89.793+/-0.048,
--   f 89.740+/-0.019, g 89.742+/-0.012, h 89.805+/-0.013 (degrees).
--
-- IMPORTANT: that table gives sky-plane inclinations only, NOT the ascending
-- nodes (Omega), so a true 3-D mutual inclination cannot be derived. We replace
-- the unsourced guesses with the measured inclination DIFFERENCE from the
-- innermost planet b (|i_p - i_b|), which equals the mutual inclination only if
-- the nodes are aligned and is otherwise a lower bound. Uncertainties are the
-- quadrature sum of the two inclination errors. Every value is consistent with
-- zero (sigma >= |di| for all planets): the system is consistent with coplanar.
-- The note records this caveat so the number is not over-interpreted.
--
-- The matching citation (Agol 2021) is added as role='characterization',
-- contribution='mutual_inclination' in etl/seed_followup_citations.py; the
-- Gillon 2017 citation is kept (it established the flat architecture).
--
-- Apply after 010_orbital_geometry_seed.sql. Idempotent (sets fixed values).

UPDATE system_orbital_geometry AS g SET
    mutual_inclination_deg      = v.mi,
    inclination_uncertainty_deg = v.unc,
    method                      = 'photodynamic',
    bibcode                     = '2021PSJ.....2....1A',
    note                        = v.note
FROM (VALUES
    ('TRAPPIST-1 b', 0.000, NULL::double precision,
     'innermost -- reference plane; Agol et al. 2021 sky-plane inclination 89.73 +/- 0.17 deg.'),
    ('TRAPPIST-1 c', 0.050, 0.20,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.'),
    ('TRAPPIST-1 d', 0.168, 0.18,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.'),
    ('TRAPPIST-1 e', 0.065, 0.17,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.'),
    ('TRAPPIST-1 f', 0.012, 0.17,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.'),
    ('TRAPPIST-1 g', 0.014, 0.17,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.'),
    ('TRAPPIST-1 h', 0.077, 0.17,
     'Difference in sky-plane orbital inclination from b (Agol et al. 2021, Table 5, photodynamic fit). Ascending nodes unconstrained, so this is a coplanar-node lower bound; consistent with coplanar.')
) AS v(pl_name, mi, unc, note)
WHERE g.hostname = 'TRAPPIST-1' AND g.pl_name = v.pl_name;
