-- search_planet_name(input text, max_results int DEFAULT 20)
--
-- Companion to resolve_planet_name(). Where resolve_planet_name answers
-- "user pressed enter, what page do we send them to," THIS function
-- powers the search-as-you-type dropdown: substring + prefix matching
-- with rough quality ranking.
--
-- Returns planet rows only (never bare hosts), because hosts have no
-- destination of their own. When a hostname or host-alias matches, the
-- function expands to every planet at that host. Each result row
-- includes a `display_label` the UI can render directly.
--
-- Match sources:
--   pl_name      planet name itself matched
--   hostname     the planet's host matched (so this planet surfaces via
--                the system)
--   alias_planet a curated planet alias matched
--   alias_host   a curated host alias matched (this planet surfaces via
--                its aliased host)
--
-- Match quality (lower = better, drives ORDER BY):
--   1   normalized prefix match  ("Kepler 9" → "Kepler-90")
--   2   normalized substring match ("Peg" → "51 Peg b")
--
-- Performance: ~5800 planets and a small aliases table, so brute-force
-- substring scans are fine for now. Prefix matches are accelerated by
-- the expression indexes added at the bottom of this migration.
-- Minimum input length of 2 (after normalization) prevents single-char
-- inputs from returning the entire catalog.
--
-- Idempotent (CREATE OR REPLACE + CREATE INDEX IF NOT EXISTS).

CREATE OR REPLACE FUNCTION search_planet_name(
  input       text,
  max_results int DEFAULT 20
)
RETURNS TABLE (
  pl_name       text,
  hostname      text,
  display_label text,
  match_source  text,  -- pl_name | hostname | alias_planet | alias_host
  match_quality int    -- 1 = normalized prefix, 2 = normalized substring
)
LANGUAGE sql STABLE AS $$
  WITH
    norm AS (
      SELECT
        normalize_alias(input) AS n,
        length(normalize_alias(input)) AS n_len
    ),
    -- planet-name matches
    pl_matches AS (
      SELECT
        p.pl_name,
        p.hostname,
        p.pl_name                       AS display_label,
        'pl_name'::text                 AS match_source,
        CASE
          WHEN normalize_alias(p.pl_name) LIKE norm.n || '%'       THEN 1
          ELSE 2
        END                             AS match_quality
      FROM planets_current p, norm
      WHERE norm.n_len >= 2
        AND normalize_alias(p.pl_name) LIKE '%' || norm.n || '%'
    ),
    -- hostname matches expanded to every planet at the host
    host_matches AS (
      SELECT
        p.pl_name,
        p.hostname,
        p.pl_name || '  ·  ' || p.hostname AS display_label,
        'hostname'::text                AS match_source,
        CASE
          WHEN normalize_alias(p.hostname) LIKE norm.n || '%'      THEN 1
          ELSE 2
        END                             AS match_quality
      FROM planets_current p, norm
      WHERE norm.n_len >= 2
        AND normalize_alias(p.hostname) LIKE '%' || norm.n || '%'
    ),
    -- curated alias matches, expanded to planets
    alias_matches AS (
      SELECT
        p.pl_name,
        p.hostname,
        p.pl_name || '  ·  via "' || a.alias || '"' AS display_label,
        ('alias_' || a.alias_kind)::text AS match_source,
        CASE
          WHEN a.normalized_alias LIKE norm.n || '%'  THEN 1
          ELSE 2
        END                              AS match_quality
      FROM planet_aliases a
      JOIN planets_current p ON
        (a.alias_kind = 'planet' AND p.pl_name  = a.canonical_name)
        OR
        (a.alias_kind = 'host'   AND p.hostname = a.canonical_name)
      , norm
      WHERE norm.n_len >= 2
        AND a.normalized_alias LIKE '%' || norm.n || '%'
    ),
    all_matches AS (
      SELECT * FROM pl_matches
      UNION ALL
      SELECT * FROM host_matches
      UNION ALL
      SELECT * FROM alias_matches
    ),
    -- one row per planet, keeping the best (lowest) quality. Ties broken
    -- by match_source preference: a direct planet hit beats a hostname
    -- hit beats an alias hit, since "I typed the planet name" is the
    -- strongest signal of intent.
    ranked AS (
      SELECT
        pl_name, hostname, display_label, match_source, match_quality,
        ROW_NUMBER() OVER (
          PARTITION BY pl_name
          ORDER BY
            match_quality,
            CASE match_source
              WHEN 'pl_name'      THEN 1
              WHEN 'hostname'     THEN 2
              WHEN 'alias_planet' THEN 3
              WHEN 'alias_host'   THEN 4
              ELSE 5
            END
        ) AS rn
      FROM all_matches
    )
  SELECT pl_name, hostname, display_label, match_source, match_quality
  FROM ranked
  WHERE rn = 1
  ORDER BY match_quality, pl_name
  LIMIT max_results
$$;

-- Expression indexes for prefix-match acceleration. Substring matches
-- still fall back to a sequential scan (cheap at ~5800 rows; revisit
-- with pg_trgm if the catalog grows or autocomplete latency rises).
CREATE INDEX IF NOT EXISTS idx_planets_snapshots_normalized_pl_name
  ON planets_snapshots (normalize_alias(pl_name));

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_normalized_hostname
  ON planets_snapshots (normalize_alias(hostname));

-- ─────────────────────────────────────────────────────────────────────
-- Sanity-test queries
-- ─────────────────────────────────────────────────────────────────────
--
--   -- prefix-match on hostname
--   SELECT * FROM search_planet_name('Kepler 9');
--     -- expect: Kepler-9 b, Kepler-9 c, Kepler-9 d, then Kepler-90 b..h
--
--   -- substring-match (constellation suffix, the case 093 couldn't handle)
--   SELECT * FROM search_planet_name('Peg');
--     -- expect: 51 Peg b, BD+14 4559 b, HD 209458 b? (check actual hosts)
--
--   -- Greek-letter normalization
--   SELECT * FROM search_planet_name('β Pic');
--     -- expect: bet Pic b, bet Pic c
--
--   -- alias hit
--   SELECT * FROM search_planet_name('Helvetios');
--     -- expect: 51 Peg b  ·  via "Helvetios"
--
--   -- single char returns nothing (guard against catalog dump)
--   SELECT * FROM search_planet_name('K');
--
--   -- max_results respected
--   SELECT * FROM search_planet_name('Kepler', 5);
