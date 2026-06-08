-- resolve_planet_name(input text) -- single entry point for "user typed
-- something, what real catalog row(s) did they mean?"
--
-- Returns 0..N rows; each row is one canonical catalog name (either a
-- planets_current.pl_name or a planets_current.hostname) that the input
-- matches, plus implicit system-expansion rows.
--
-- Why system-expansion: the site does not (currently) have a host-only
-- route, so a bare host hit has no destination. If the input matches a
-- host, we also return every planet at that host. Symmetrically, if the
-- input matches a planet, we also return its host (so callers that DO
-- want to surface system context can). Expansion rows are tagged with
-- priority 4 so a `LIMIT 1` still gets the literal match.
--
-- Match priority (lower = better):
--   1. exact_pl_name        input = planets_current.pl_name
--   1. exact_hostname       input = planets_current.hostname
--   2. normalized_pl_name   normalize_alias(input) = normalize_alias(pl_name)
--   2. normalized_hostname  normalize_alias(input) = normalize_alias(hostname)
--   3. alias                planet_aliases.normalized_alias hit, verified
--                           that the canonical_name still exists in the
--                           current snapshot
--   4. host_expansion       a planet at a host that matched at pri 1-3
--   4. planet_expansion     the host of a planet that matched at pri 1-3
--
-- One row per (canonical_name, alias_kind), keeping the best priority.
-- Ordered priority-ascending so a `LIMIT 1` on the API side gets the
-- strongest match.
--
-- The function is STABLE rather than IMMUTABLE because planets_current
-- is a view over the current snapshot and the snapshot changes nightly.
-- normalize_alias() itself remains IMMUTABLE so it can still drive the
-- planet_aliases.normalized_alias generated column.
--
-- Idempotent (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION resolve_planet_name(input text)
RETURNS TABLE (
  canonical_name text,
  alias_kind     text,  -- 'planet' or 'host'
  match_type     text,  -- exact_pl_name | exact_hostname |
                        -- normalized_pl_name | normalized_hostname |
                        -- alias | host_expansion | planet_expansion
  alias_source   text,  -- NULL for catalog-direct hits;
                        -- planet_aliases.source for alias hits
  match_priority int    -- 1 = exact, 2 = normalized, 3 = curated alias,
                        -- 4 = system-expansion
)
LANGUAGE sql STABLE AS $$
  WITH
    norm AS (
      SELECT normalize_alias(input) AS n
    ),
    base AS (
      -- priority 1: exact pl_name
      SELECT DISTINCT
        pl_name                AS canonical_name,
        'planet'::text         AS alias_kind,
        'exact_pl_name'::text  AS match_type,
        NULL::text             AS alias_source,
        1                      AS match_priority
      FROM planets_current
      WHERE pl_name = input

      UNION ALL

      -- priority 1: exact hostname
      SELECT DISTINCT
        hostname,
        'host'::text,
        'exact_hostname'::text,
        NULL::text,
        1
      FROM planets_current
      WHERE hostname = input

      UNION ALL

      -- priority 2: normalized pl_name
      SELECT DISTINCT
        pl_name,
        'planet'::text,
        'normalized_pl_name'::text,
        NULL::text,
        2
      FROM planets_current, norm
      WHERE normalize_alias(pl_name) = norm.n

      UNION ALL

      -- priority 2: normalized hostname
      SELECT DISTINCT
        hostname,
        'host'::text,
        'normalized_hostname'::text,
        NULL::text,
        2
      FROM planets_current, norm
      WHERE normalize_alias(hostname) = norm.n

      UNION ALL

      -- priority 3: curated alias. Verify the canonical_name still
      -- exists in the current snapshot so stale aliases (e.g. a
      -- pre-migration-084 hostname that's no longer in the catalog
      -- under that spelling) don't surface as fake matches.
      SELECT
        a.canonical_name,
        a.alias_kind,
        'alias'::text,
        a.source,
        3
      FROM planet_aliases a, norm
      WHERE a.normalized_alias = norm.n
        AND (
          (a.alias_kind = 'planet'
            AND EXISTS (SELECT 1 FROM planets_current p WHERE p.pl_name  = a.canonical_name))
          OR
          (a.alias_kind = 'host'
            AND EXISTS (SELECT 1 FROM planets_current p WHERE p.hostname = a.canonical_name))
        )
    ),
    expanded AS (
      -- priority 4: for each host hit at pri 1-3, surface every planet
      -- at that host. The site has no host-only route today, so a bare
      -- host match has no destination on its own.
      SELECT DISTINCT
        p.pl_name,
        'planet'::text,
        'host_expansion'::text,
        NULL::text,
        4
      FROM base b
      JOIN planets_current p ON p.hostname = b.canonical_name
      WHERE b.alias_kind = 'host'

      UNION ALL

      -- priority 4: for each planet hit at pri 1-3, surface the host
      -- (so a UI can show system context alongside the planet match).
      SELECT DISTINCT
        p.hostname,
        'host'::text,
        'planet_expansion'::text,
        NULL::text,
        4
      FROM base b
      JOIN planets_current p ON p.pl_name = b.canonical_name
      WHERE b.alias_kind = 'planet'
    ),
    candidates AS (
      SELECT * FROM base
      UNION ALL
      SELECT * FROM expanded
    ),
    ranked AS (
      SELECT
        canonical_name, alias_kind, match_type, alias_source, match_priority,
        ROW_NUMBER() OVER (
          PARTITION BY canonical_name, alias_kind
          ORDER BY match_priority
        ) AS rn
      FROM candidates
    )
  SELECT canonical_name, alias_kind, match_type, alias_source, match_priority
  FROM ranked
  WHERE rn = 1
  ORDER BY match_priority, alias_kind, canonical_name
$$;

-- ─────────────────────────────────────────────────────────────────────
-- Sanity-test queries (paste at psql to spot-check after applying)
-- ─────────────────────────────────────────────────────────────────────
--
--   -- exact + expansion: typing the host returns host + all its planets
--   SELECT * FROM resolve_planet_name('bet Pic');
--     -- expect: (bet Pic, host, exact_hostname, NULL, 1)
--     --         (bet Pic b, planet, host_expansion, NULL, 4)
--     --         (bet Pic c, planet, host_expansion, NULL, 4)
--
--   -- exact planet returns planet + its host
--   SELECT * FROM resolve_planet_name('bet Pic b');
--
--   -- normalized: Greek + genitive variants
--   SELECT * FROM resolve_planet_name('β Pictoris');
--   SELECT * FROM resolve_planet_name('Beta Pictoris b');
--   SELECT * FROM resolve_planet_name('HD-39060');
--   SELECT * FROM resolve_planet_name('ε Eridani b');
--   SELECT * FROM resolve_planet_name('ϵ Eridani');     -- U+03F5 lunate
--   SELECT * FROM resolve_planet_name('Epsilon Eridani');
--
--   -- alias-table hits with system expansion: typing "Helvetios"
--   -- should land on 51 Peg b via the curated alias + host expansion
--   SELECT * FROM resolve_planet_name('Helvetios');
--   SELECT * FROM resolve_planet_name('Aldebaran');
--
--   -- multi-planet host expansion
--   SELECT * FROM resolve_planet_name('Kepler-90');
--
--   -- a miss returns 0 rows
--   SELECT * FROM resolve_planet_name('not a real name');
