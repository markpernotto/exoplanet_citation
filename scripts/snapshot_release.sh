#!/usr/bin/env bash
#
# snapshot_release.sh -- Build a frozen, version-tagged database snapshot
# suitable for archiving alongside a tagged release. The output is a
# single gzipped plain-SQL file that can be replayed into a fresh
# Postgres to reconstruct the production database state at the moment
# of the release.
#
# What goes IN the snapshot:
#   - Full schema for every table (CREATE TABLE, indexes, constraints,
#     sequences, etc.)
#   - All row data from every table EXCEPT planets_snapshots
#   - From planets_snapshots, only the rows belonging to the most
#     recent snapshot_date (i.e. the NASA EA mirror state that the
#     released version of the site was actually rendering against)
#
# Why we keep only the latest snapshot_date from planets_snapshots:
#   - planets_snapshots accumulates older NASA EA mirror states over
#     time; only the latest is what the site is currently serving
#   - Older mirror states can be re-pulled from NASA EA at any time if
#     someone needs historical comparison
#   - This keeps the release archive small enough to live in git (and
#     thus to be auto-archived by Zenodo on tag) without compromising
#     the "anyone can rebuild the site from this dump" reproducibility
#     promise.
#
# Why plain SQL gzipped (not pg_dump custom format):
#   - Single-command restore: gunzip -c file.sql.gz | psql DBNAME
#   - Human-inspectable: anyone can browse the dump
#   - Schema-portable: works across any Postgres major version that
#     supports the SQL syntax (custom format requires matching
#     pg_restore versions)
#
# Usage:
#   ./scripts/snapshot_release.sh v0.2.0
#
# Output:
#   data/snapshots/v0.2.0.sql.gz
#
# Restore (from a fresh Postgres):
#   createdb exoplanet_atlas
#   gunzip -c data/snapshots/v0.2.0.sql.gz | psql exoplanet_atlas

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-tag>" >&2
  echo "Example: $0 v0.2.0" >&2
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set. Source your .env first:" >&2
  echo "  set -a; source .env; set +a" >&2
  exit 1
fi

OUTPUT_DIR="data/snapshots"
OUTPUT="${OUTPUT_DIR}/${VERSION}.sql.gz"
mkdir -p "$OUTPUT_DIR"

if [[ -f "$OUTPUT" ]]; then
  echo "Output file already exists: $OUTPUT" >&2
  echo "Remove it first if you want to regenerate." >&2
  exit 1
fi

# Determine which snapshot_date is the "current" one we are freezing.
LATEST_SNAPSHOT=$(psql "$DATABASE_URL" -tAc \
  "SELECT MAX(snapshot_date) FROM planets_snapshots" | tr -d '[:space:]')

if [[ -z "$LATEST_SNAPSHOT" ]]; then
  echo "Could not determine MAX(snapshot_date) from planets_snapshots." >&2
  echo "Is the database populated?" >&2
  exit 1
fi

# Determine planets_snapshots column list in declared order. We need
# this for the manual COPY ... FROM stdin statement we will append
# to the dump for the filtered planets_snapshots data.
PLANETS_SNAPSHOTS_COLS=$(psql "$DATABASE_URL" -tAc "
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = 'planets_snapshots'
" | tr -d '[:space:]')

if [[ -z "$PLANETS_SNAPSHOTS_COLS" ]]; then
  echo "Could not introspect planets_snapshots columns." >&2
  exit 1
fi

echo "Building snapshot ${VERSION}"
echo "  Freezing planets_snapshots at snapshot_date = ${LATEST_SNAPSHOT}"
echo "  Output: ${OUTPUT}"

# Build the snapshot in a single pipeline.
#
# Pieces, in order of appearance in the resulting .sql:
#   1. pg_dump with --exclude-table-data=planets_snapshots
#      Produces: full schema (CREATE TABLE for every table including
#      planets_snapshots) + data for every table EXCEPT
#      planets_snapshots. The exclusion is data-only, so the
#      planets_snapshots schema (table definition, indexes,
#      constraints) IS still in the dump.
#   2. A manual COPY public.planets_snapshots (cols...) FROM stdin;
#      block, followed by the filtered subset of planets_snapshots
#      rows in COPY text format, terminated with \. as psql expects.

{
  pg_dump "$DATABASE_URL" \
    --no-owner \
    --no-privileges \
    --exclude-table-data=public.planets_snapshots

  echo ""
  echo "--"
  echo "-- planets_snapshots data: filtered to snapshot_date = ${LATEST_SNAPSHOT}"
  echo "-- (older snapshots are intentionally omitted; can be re-pulled from NASA EA)"
  echo "--"
  echo ""
  echo "COPY public.planets_snapshots (${PLANETS_SNAPSHOTS_COLS}) FROM stdin;"
  psql "$DATABASE_URL" -c "COPY (SELECT ${PLANETS_SNAPSHOTS_COLS} FROM planets_snapshots WHERE snapshot_date = '${LATEST_SNAPSHOT}') TO STDOUT"
  echo "\\."
  echo ""
} | gzip -9 > "$OUTPUT"

SIZE=$(du -h "$OUTPUT" | cut -f1)
ROWS=$(psql "$DATABASE_URL" -tAc \
  "SELECT COUNT(*) FROM planets_snapshots WHERE snapshot_date = '${LATEST_SNAPSHOT}'" | tr -d '[:space:]')

echo ""
echo "Wrote ${OUTPUT} (${SIZE})"
echo "  planets_snapshots rows frozen: ${ROWS}"
echo ""
echo "To restore into a fresh Postgres database:"
echo "  createdb exoplanet_atlas"
echo "  gunzip -c ${OUTPUT} | psql exoplanet_atlas"
