-- Trigram GIN indexes on normalize_alias(pl_name) and
-- normalize_alias(hostname) so that the /api/planets search path
-- (and search_planet_name) can substring-match in sub-100ms instead
-- of doing a sequential scan that calls normalize_alias() on every
-- row of the current snapshot.
--
-- The btree expression indexes added in 094 cover EQUALITY lookups
-- (used by resolve_planet_name's exact-normalized branch). The GIN
-- trgm indexes added here cover '%foo%' / 'foo%' LIKE patterns
-- (used by search_planet_name and the /api/planets q= filter). Both
-- are kept; they serve different operators.
--
-- pg_trgm needs at least 3 chars of static pattern to use the index;
-- shorter inputs fall back to seq scan. In practice every Greek-folded
-- input is already >=3 chars (β -> bet, ε -> eps, etc.) so this is a
-- non-issue for normal use.
--
-- Idempotent (extension and indexes are guarded).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_norm_pl_name_trgm
  ON planets_snapshots
  USING gin (normalize_alias(pl_name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_planets_snapshots_norm_hostname_trgm
  ON planets_snapshots
  USING gin (normalize_alias(hostname) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_planet_aliases_normalized_trgm
  ON planet_aliases
  USING gin (normalized_alias gin_trgm_ops);
