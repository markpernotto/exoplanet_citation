-- sy_snum disagreements audit table (2026-06-22). Surfaces NASA EA
-- sy_snum values that primary literature does not support, with
-- bibcode-cited rationale. The Atlas's contradiction of an
-- authoritative catalog is only acceptable if it is itself cited;
-- this table is the visible-in-UI receipt.
--
-- The disagreements seeded here were surfaced during the WDS curation
-- pass (migrations 101, 103) when the gap audit query returned hosts
-- that NASA EA flags as multi-star but the primary literature
-- characterizes as fewer. Each row carries:
--   * what NASA EA claims (nasa_ea_sy_snum)
--   * what primary literature supports (supported_sy_snum)
--   * prose rationale explaining the disagreement
--   * an ADS bibcode array backing our position
--
-- The UI surfaces this as a footnote within the System Stars section
-- on the planet card: "NASA EA reports N components; primary literature
-- supports M. See: <bibcodes as ADS links>."
--
-- The intent here is curated provenance, NOT to "fix" NASA EA. Their
-- catalog is the upstream source; this table is the value-added
-- override visible to researchers.
--
-- Apply after 011_binary_companions.sql. Idempotent.

CREATE TABLE IF NOT EXISTS sy_snum_audit (
    hostname            TEXT PRIMARY KEY,
    nasa_ea_sy_snum     INTEGER NOT NULL,        -- value from NASA EA
    supported_sy_snum   INTEGER NOT NULL,        -- value supported by cited primary literature
    rationale           TEXT NOT NULL,           -- prose explanation, surfaced in UI
    source_bibcodes     TEXT[] NOT NULL,         -- ADS bibcodes backing our position
    curated_at          DATE NOT NULL DEFAULT CURRENT_DATE,
    curator_note        TEXT                     -- optional extra context for internal review
);

COMMENT ON TABLE sy_snum_audit IS
    'Hosts where NASA EA sy_snum is not supported by primary literature. Each row carries cited rationale and surfaces in the UI as a visible disagreement note. The Atlas only overrides an authoritative source when it can cite the override.';

COMMENT ON COLUMN sy_snum_audit.nasa_ea_sy_snum IS
    'sy_snum value as reported by NASA Exoplanet Archive pscomppars.';

COMMENT ON COLUMN sy_snum_audit.supported_sy_snum IS
    'Stellar-component count supported by the primary literature cited in source_bibcodes. Substellar companions (brown dwarfs in planets table) are NOT counted as stars here.';

COMMENT ON COLUMN sy_snum_audit.source_bibcodes IS
    'Array of ADS bibcodes backing the supported_sy_snum value. Each surfaces as a clickable ADS link in the UI footnote.';


-- =============================================================================
-- Seed disagreements from WDS curation batches 1-2 (migrations 101, 103)
-- =============================================================================

INSERT INTO sy_snum_audit (hostname, nasa_ea_sy_snum, supported_sy_snum, rationale, source_bibcodes, curator_note)
VALUES
    ('HD 113337', 3, 1,
     'Primary literature does not support any stellar companion to HD 113337. Borgniet 2019 (CHARA-VEGA interferometry + LBTI imaging + SOPHIE RV + MESS2 combined analysis) refines stellar/disk/planet parameters but characterizes no stellar companion. Ginski 2016 (AstraLux lucky imaging) observed HD 113337 and detected no companion down to ~0.08 Msun at 2.5 arcsec separation. SIMBAD also returns only planets. Three independent negative confirmations against NASA EA''s sy_snum = 3.',
     ARRAY['2019A&A...627A..44B', '2016MNRAS.457.2173G'],
     'Surfaced during WDS Batch 1 curation (migration 101). The agent-guess assertion that Borgniet 2019 characterizes a wide M-dwarf companion at ~120"/~4000 AU was incorrect; on direct reading the paper makes no such claim.'),

    ('16 Cyg B', 3, 2,
     '16 Cyg is a wide BINARY (A + B), not a triple. Hauser & Marcy 1999 characterizes the A-B wide orbit and discusses a tertiary CANDIDATE: a red point source 3.2 arcsec from 16 Cyg A (Trilling), assessed as either an M-dwarf at ~80 AU, a higher-mass ~0.5 Msun star at >150 AU, or a background star. Membership is unconfirmed; migration 098 deliberately did not add a row for it. NASA EA''s sy_snum = 3 likely counts the unconfirmed Trilling source.',
     ARRAY['1999PASP..111..321H'],
     'Captured by the 16 Cyg curation in migration 098. The Trilling tertiary remains a real-but-unconfirmed candidate; if future astrometry confirms binding, this audit row can be updated to supported_sy_snum = 3.'),

    ('HD 87646', 3, 2,
     'HD 87646 A hosts planet b (12.4 MJup hot Jupiter at 0.117 AU, P = 13.5 d) and a brown dwarf c (57 MJup at 1.58 AU, P = 674 d) and is itself in a close stellar binary with companion B at ~22 AU. Two STARS (A + B) plus one stellar-mass + one substellar planet-table companion. NASA EA''s sy_snum = 3 likely counts the 57 MJup brown dwarf as a star, but our catalog treats substellar objects as planets / brown dwarf companions, not as stars contributing to sy_snum.',
     ARRAY['2016AJ....152..112M'],
     'Conventions disagreement, not a literature disagreement. NASA EA''s star-count convention includes brown dwarfs at the deuterium-burning-mass boundary; ours does not. Worth flagging.'),

    ('BD-14 3065 A', 3, 2,
     'Šubjak 2024 fits two-component (A + B at 0.92"/520 AU) and three-component (A + B + close unresolved c) SED models for BD-14 3065. The B companion is speckle-resolved with SOAR HRCam and confidently characterized. The third component c is suggested only by a long-term non-linear RV trend (period unconstrained) and Gaia RUWE = 3.5; Šubjak treats it as plausible but unconstrained. We curate B confidently in binary_companions and document c in B''s notes pending characterization. NASA EA''s sy_snum = 3 likely anticipates Šubjak''s triple framing; we hold supported_sy_snum = 2 until c is characterized.',
     ARRAY['2024A&A...688A.120S'],
     'Promote to supported_sy_snum = 3 if a follow-up paper constrains c''s period and mass.'),

    ('HD 2638', 3, 2,
     'Three independent imaging detections (Wittrock 2016 Gemini-North DSSI speckle; Roberts 2015 Palomar Robo-AO + PALM-3000; Ginski 2016 AstraLux at Calar Alto) confirm exactly ONE stellar companion B at ~26 AU. No third stellar component is identified in primary literature. NASA EA''s sy_snum = 3 has no support from these independent detections.',
     ARRAY['2016AJ....152..149W', '2015AJ....149..118R', '2016MNRAS.457.2173G'],
     'Strong case for overcount; possibly a SIMBAD bulk-resolver artifact in the NASA EA pipeline.'),

    ('HD 43691', 3, 2,
     'Ginski 2016 reports a single-epoch lucky-imaging candidate companion at 4.4 arcsec (CPM not yet confirmed). One candidate stellar companion, not two. NASA EA''s sy_snum = 3 has no support from primary literature; even Ginski''s single candidate is unresolved as bound vs background.',
     ARRAY['2016MNRAS.457.2173G'],
     'If Ginski 2016 candidate is confirmed background, supported_sy_snum drops to 1 in a future revision.')
ON CONFLICT (hostname) DO UPDATE SET
    nasa_ea_sy_snum    = EXCLUDED.nasa_ea_sy_snum,
    supported_sy_snum  = EXCLUDED.supported_sy_snum,
    rationale          = EXCLUDED.rationale,
    source_bibcodes    = EXCLUDED.source_bibcodes,
    curator_note       = EXCLUDED.curator_note;
