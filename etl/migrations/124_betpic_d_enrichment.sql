-- 124_betpic_d_enrichment.sql
-- Enrichment for bet Pic d (β Pictoris d): the third planet in the β Pic
-- system and the faintest planet yet directly imaged from Earth. First
-- ingested from NASA EA in the 2026-07-10 snapshot.
--
-- Primary source: Sutlieff, Bonse, et al. 2026, ApJL, 1006, L10
--   "Direct Imaging Discovery of Giant Exoplanet β Pictoris d:
--    A Decade-long Game of Hide-and-Seek"
--   bibcode 2026ApJ..1006L..10S · DOI 10.3847/2041-8213/ae80a0 · arXiv 2606.23801
--   VLT/ERIS discovery + archival JWST/NIRCam + VLT/SPHERE; orbits from orvara.
--
-- Adds three things (each cited to the paper above):
--   1. Discovery publication + planet_publications link. The paper published
--      2026-07-16, AFTER the 2026-07-10 snapshot that first ingested bet Pic d,
--      so its NASA EA disc_refname bibcode has likely not resolved yet — seed
--      it manually, same pattern as migration 122 (NGTS-38 b).
--   2. system_orbital_geometry: bet Pic d is coplanar with b and c. Extends the
--      existing Nowak 2020 (2020A&A...642L...2N) rows, which use bet Pic c as
--      the reference plane.
--   3. planet_derived_measurements: the MODEL-DEPENDENT physical estimates
--      (mass, Teff, radius from ATMO 2020 hot-start models at age 23±8 Myr) and
--      the orvara orbital inclination — values the flat NASA EA catalog row
--      cannot carry with model/provenance tagging.
--
-- Left to the NASA EA catalog row on purpose: the bulk orbital elements
-- (a = 26.0 au, P = 91 yr, e < 0.44). The coplanarity note records the
-- orvara non-crossing solution those come from.
--
-- Naming: NASA EA uses 'bet Pic' / 'bet Pic d' (confirmed against existing
-- bet Pic b/c rows). Apply after 123; idempotent on re-run.

BEGIN;

-- 1. Discovery publication ---------------------------------------------------
WITH pub AS (
    INSERT INTO publications (
        bibcode, doi, arxiv_id, title, authors, journal,
        resolved_via, confidence, updated_at
    ) VALUES (
        '2026ApJ..1006L..10S',
        '10.3847/2041-8213/ae80a0',
        '2606.23801',
        'Direct Imaging Discovery of Giant Exoplanet β Pictoris d: A Decade-long Game of Hide-and-Seek',
        '[
            "Sutlieff, Ben J.", "Bonse, Markus J.", "Christiaens, Valentin",
            "Fontanive, Clémence", "Matthews, Elisabeth C.", "Parker, Luke T.",
            "Pearce, Tim D.", "Birkby, Jayne L.", "Biller, Beth A.",
            "Dupuy, Trent J.", "Garvin, Emily O.", "Iskandarli, Leyla",
            "Kammerer, Jens", "Zhou, Yifan", "De Rosa, Robert J.",
            "Carter, Aarynn L.", "Hinkley, Sasha", "Kenworthy, Matthew A.",
            "Balmer, William O.", "Hammond, Iain", "Mang, James",
            "Morley, Caroline V.", "Neeser, Mark J.", "Absil, Olivier",
            "Boccaletti, Anthony", "Bonavita, Mariangela", "Bowler, Brendan P.",
            "Chen, Xueqing", "Dannert, Felix A.", "Girard, Julien H.",
            "Kasper, Markus", "Lagrange, Anne-Marie", "Liu, Pengyu",
            "Orban de Xivry, Gilles", "Poon, Michael", "Quanz, Sascha P.",
            "Serra, Benoît", "Vos, Johanna M.", "Wagner, Kevin", "Wang, Jason",
            "Schölkopf, Bernhard", "Agapito, Guido", "Agudo Berbel, Alex",
            "Apai, Dániel", "Baruffolo, Andrea", "Black, Martin",
            "Bonaglia, Marco", "Briguglio, Runa", "Cao, Yixian",
            "Carbonaro, Luca", "Chapman, Lee", "Cresci, Giovanni",
            "Dallilar, Yigit", "Davies, Richard", "Deysenroth, Matthias",
            "Di Antonio, Ivan", "Di Cianno, Amico", "Di Rico, Gianluca",
            "Doelman, David", "Dolci, Mauro", "Eisenhauer, Frank",
            "Esposito, Simone", "Ferruzzi, Debora", "Feuchtgruber, Helmut",
            "Förster-Schreiber, Natascha", "Franson, Kyle", "Genzel, Reinhard",
            "Gillessen, Stefan", "Gonzales, Eileen C.", "Hartl, Michael",
            "Hayoz, Jean", "Huber, Heinrich", "Keller, Christoph",
            "Kravchenko, Kateryna", "Leisenring, Jarron", "Lightfoot, John",
            "Lunney, David", "Lutz, Dieter", "Macintosh, Mike",
            "Mannucci, Filippo", "Metchev, Stanimir", "Ott, Thomas",
            "Pearson, David", "Puglisi, Alfio", "Rabien, Sebastian",
            "Rau, Christian", "Riccardi, Armando", "Salasnich, Bernardo",
            "Shimizu, Taro", "Snik, Frans", "Sturm, Eckhard",
            "Suárez, Genaro", "Tacconi, Linda", "Tan, Xianyu",
            "Taylor, William", "Waring, Christopher", "Xompero, Marco"
        ]'::jsonb,
        'The Astrophysical Journal Letters',
        'manual', 'high', now()
    )
    ON CONFLICT (bibcode) WHERE bibcode IS NOT NULL DO UPDATE SET
        doi          = EXCLUDED.doi,
        arxiv_id     = EXCLUDED.arxiv_id,
        title        = EXCLUDED.title,
        authors      = EXCLUDED.authors,
        journal      = EXCLUDED.journal,
        resolved_via = EXCLUDED.resolved_via,
        confidence   = EXCLUDED.confidence,
        updated_at   = now()
    RETURNING pub_id
)
INSERT INTO planet_publications (pl_name, pub_id, role)
SELECT 'bet Pic d', pub_id, 'discovery' FROM pub
ON CONFLICT DO NOTHING;

-- If the resolver had parked bet Pic d in the manual queue, clear it.
DELETE FROM citation_manual_queue WHERE pl_name = 'bet Pic d';

-- 2. Coplanarity -------------------------------------------------------------
-- Table 2 / Table 5 (orvara, non-crossing subsample):
--   i_d = 89.0 (+0.7/-0.6) deg,  Omega_d = 210.8 (+0.6/-0.4) deg
-- vs the reference plane bet Pic c (i_c = 88.9, Omega_c = 211.1): d is
-- near-coplanar with both inner planets. mutual_inclination_deg left NULL:
-- the paper reports coplanarity qualitatively and does not state a d-vs-c
-- mutual inclination. A computed d-vs-c value could be populated later if
-- wanted.
INSERT INTO system_orbital_geometry
    (hostname, pl_name, reference_pl_name, mutual_inclination_deg,
     inclination_uncertainty_deg, method, bibcode, note)
VALUES
    ('bet Pic', 'bet Pic d', 'bet Pic c', NULL, NULL, 'direct_imaging',
     '2026ApJ..1006L..10S',
     'Coplanar with b and c per Sutlieff 2026: i_d=89.0 (+0.7/-0.6) deg, Omega_d=210.8 (+0.6/-0.4) deg vs c (i=88.9, Omega=211.1). orvara non-crossing subsample; a_d=26.0 au, P_d=91 yr, e_d<0.44.')
ON CONFLICT (hostname, pl_name) DO NOTHING;

-- 3. Model-dependent physical estimates + orbital inclination ----------------
-- Table 2 mass/Teff/radius are ATMO 2020 evolutionary estimates (age 23±8 Myr),
-- so they belong in the derived table with an explicit model tag rather than
-- the flat catalog. orbital_inclination follows the existing vocabulary.
INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('bet Pic d', 'mass', 2.4, 0.6, 0.6, 'M_jup',
     'ATMO 2020 hot-start (chem-eq + strong non-eq), age 23+/-8 Myr',
     '2026ApJ..1006L..10S', 'Sutlieff 2026 Table 2; photometric evolutionary-model estimate.'),
    ('bet Pic d', 'effective_temperature', 600, 45, 60, 'K',
     'ATMO 2020 hot-start (chem-eq + strong non-eq), age 23+/-8 Myr',
     '2026ApJ..1006L..10S', 'Sutlieff 2026 Table 2.'),
    ('bet Pic d', 'radius', 1.26, 0.03, 0.03, 'R_jup',
     'ATMO 2020 hot-start (chem-eq + strong non-eq), age 23+/-8 Myr',
     '2026ApJ..1006L..10S', 'Sutlieff 2026 Table 2.'),
    ('bet Pic d', 'orbital_inclination', 89.0, 0.7, 0.6, 'deg',
     'direct imaging astrometry (orvara, non-crossing subsample)',
     '2026ApJ..1006L..10S', 'Sutlieff 2026 Table 5; near-coplanar with b and c.')
ON CONFLICT (pl_name, quantity, bibcode) DO NOTHING;

COMMIT;
