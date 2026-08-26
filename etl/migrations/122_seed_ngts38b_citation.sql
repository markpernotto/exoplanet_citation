-- 122_seed_ngts38b_citation.sql
-- Manual discovery-citation seed for NGTS-38 b (= TIC-65910228 b).
--
-- Why manual: the NASA EA disc_refname points at a *temporary* MNRAS bibcode
-- (2026MNRAS.tmp..998R) assigned before the paper received its final
-- volume/page. ADS's bibcode + title lookups both return sparse/empty on the
-- temp record, so all automated resolve_citations tiers failed and the planet
-- was parked in citation_manual_queue (queued 2026-07-10). We resolve it here
-- from the verified primary source instead of waiting on the final bibcode.
--
-- Primary source: Rodel et al. 2026, MNRAS,
--   "TIC-65910228 b / NGTS-38 b, a 180 day transiting warm super-Jupiter"
--   DOI 10.1093/mnras/stag1061 · arXiv 2602.12977 · temp bibcode 2026MNRAS.tmp..998R
--
-- Mirrors the shape resolve_citations writes (publications + planet_publications),
-- with resolved_via='manual'. pub_date/citation_count left NULL: a future nightly
-- will backfill them once ADS finalizes the bibcode (this row won't be re-resolved
-- because the planet is already linked in planet_publications).

BEGIN;

WITH pub AS (
    INSERT INTO publications (
        bibcode, doi, arxiv_id, title, authors, journal,
        resolved_via, confidence, updated_at
    ) VALUES (
        '2026MNRAS.tmp..998R',
        '10.1093/mnras/stag1061',
        '2602.12977',
        'TIC-65910228 b / NGTS-38 b, a 180 day transiting warm super-Jupiter',
        '[
            "Rodel, Toby", "Ulmer-Moll, Solène", "Gill, Samuel",
            "Watson, Christopher A.", "Eschen, Yoshi Nike Emilia",
            "Freckelton, Alix V.", "Mortier, Annelies", "Collins, Karen A.",
            "Dragomir, Diana", "Essack, Zahra", "Skinner, Brett",
            "Mallaghan, Niamh", "Wheatley, Peter J.", "Anderson, David R.",
            "Apergis, Ioannis", "Barkaoui, Khalid", "Battley, Matthew P.",
            "Bayliss, Daniel", "Bouchy, François", "Bryant, Edward M.",
            "Burleigh, Matthew R.", "Cadell, Benjamin M. J.",
            "Carlier, Samuel J.", "Carteret, Yann", "Casewell, Sarah L.",
            "Claringbold, Alastair B.", "Costes, Jean C.",
            "Davies, Benjamin D. R.", "Doyle, Lauren", "Evans, Phil",
            "Fernández Fernández, Jorge", "Fontanet, Emile", "Gillen, Edward",
            "Goad, Michael R.", "Harvey, George", "Hawthorn, Faith",
            "Hobbs, Katlyn L.", "Hobson, Melissa", "Isopi, Giovanni",
            "Jenkins, James S.", "Kendall, Alicia", "Kipping, David",
            "Lendl, Monika", "Mallia, Franco", "Mann, Christopher",
            "McCormac, James", "de Mooij, Ernst J.W.", "Moyano, Maximiliano",
            "Nigioni, Arianna", "Odeh, Mohammad", "Passegger, Vera Maria",
            "Saha, Suman", "Schwarz, Richard P.", "Sedgley, Amber",
            "Shporer, Avi", "Soubkiou, Abderahmane", "Udry, Stéphane",
            "Veras, Dimitri", "Vignes, Jean P.", "Villanueva, Steven, Jr.",
            "Vinés, José I.", "West, Richard", "Wilson, Thomas G.",
            "Worters, Hannah L.", "Young, Mitchell E.", "Zapparata, Aldo"
        ]'::jsonb,
        'Monthly Notices of the Royal Astronomical Society',
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
SELECT 'NGTS-38 b', pub_id, 'discovery' FROM pub
ON CONFLICT DO NOTHING;

-- Clear it out of the manual queue now that it's resolved.
DELETE FROM citation_manual_queue WHERE pl_name = 'NGTS-38 b';

COMMIT;
