-- Drop unused functions and their supporting btree expression indexes
-- from migrations 093 and 094.
--
-- Why: 093 (resolve_planet_name) was built for a "deep-link to a
-- planet via any alias" route (/planets/Helvetios -> 51 Peg b);
-- 094 (search_planet_name) was built for a search-as-you-type
-- autocomplete dropdown. Both UX paths were rejected during the
-- alias-feature design pass, so the SQL never wired up to anything.
-- The live /api/planets?q= search uses a UNION-based query directly
-- against planet_aliases + the GIN trigram indexes added in 095; it
-- never touches these two functions or the btree indexes they were
-- paired with.
--
-- What stays: normalize_alias() (still required by planet_aliases'
-- generated column AND by the live search query), planet_aliases
-- table + its trigram index, and the trigram indexes on
-- planets_snapshots from 095.
--
-- Drop order matters: indexes first, functions last. Function drops
-- use IF EXISTS so the migration is safely re-runnable.

DROP INDEX IF EXISTS idx_planets_snapshots_normalized_pl_name;
DROP INDEX IF EXISTS idx_planets_snapshots_normalized_hostname;

DROP FUNCTION IF EXISTS resolve_planet_name(text);
DROP FUNCTION IF EXISTS search_planet_name(text, int);
