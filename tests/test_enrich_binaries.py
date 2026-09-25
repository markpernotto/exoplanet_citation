"""Unit tests for etl/enrich_binaries.py host selection.

Covers the curated-exclusion rule added with migration 125: a host listed in
binary_companion_exclusions is never re-resolved, in any mode, so a cleanup
migration that empties a host's binary_companions rows is not undone by the
nightly incremental run.
"""

from __future__ import annotations

from etl.enrich_binaries import UPSERT_SQL, select_hosts

HOSTS = [
    ("Kepler-108", 291.0, 47.0),          # cleaned + excluded (migration 125)
    ("OGLE-2006-BLG-284L A", 269.0, -29.0),  # cleaned + excluded (migration 125)
    ("WD 1856+534", 284.0, 53.0),         # has rows already
    ("TOI-9999", 10.0, 10.0),             # new arrival, never fetched
]
ALREADY = {"WD 1856+534"}
EXCLUDED = {"Kepler-108", "OGLE-2006-BLG-284L A"}


def _names(rows):
    return [r[0] for r in rows]


def test_incremental_skips_cached_and_excluded():
    todo = select_hosts(HOSTS, already=ALREADY, excluded=EXCLUDED)
    assert _names(todo) == ["TOI-9999"]


def test_incremental_without_exclusions_would_refetch_emptied_hosts():
    # The pre-125 behaviour, kept as documentation of the regression: an
    # emptied host looks "never fetched" and comes straight back.
    todo = select_hosts(HOSTS, already=ALREADY, excluded=set())
    assert "Kepler-108" in _names(todo)
    assert "OGLE-2006-BLG-284L A" in _names(todo)


def test_refresh_all_still_honours_exclusions():
    todo = select_hosts(HOSTS, already=ALREADY, excluded=EXCLUDED, refresh_all=True)
    assert _names(todo) == ["WD 1856+534", "TOI-9999"]


def test_target_host_ignores_cache_but_not_exclusions():
    cached = select_hosts(HOSTS, already=ALREADY, excluded=EXCLUDED,
                          target_host="WD 1856+534")
    assert _names(cached) == ["WD 1856+534"]
    excluded = select_hosts(HOSTS, already=ALREADY, excluded=EXCLUDED,
                            target_host="Kepler-108")
    assert excluded == []


def test_target_host_unknown_is_empty():
    assert select_hosts(HOSTS, already=set(), excluded=set(), target_host="nope") == []


def test_upsert_never_overwrites_curated_rows():
    # The ON CONFLICT branch must be gated on the existing row being an
    # uncited SIMBAD stub, so a re-resolve cannot clobber a migration's
    # cited replacement under the same (hostname, component_designation).
    tail = UPSERT_SQL.split("DO UPDATE SET", 1)[1]
    assert "WHERE binary_companions.source_bibcode IS NULL" in tail
    assert "binary_companions.source_catalog = 'SIMBAD'" in tail
