"""Unit tests for etl/sources/gaia.py.

Network-hitting code (_fetch_batch, fetch_gaia_dr3_records) is exercised
indirectly via etl/enrich_gaia.py integration tests once that lands. Here
we cover the pure-Python helpers.
"""

from __future__ import annotations

import pytest

from etl.sources.gaia import GAIA_COLUMNS, _build_query, parse_source_id


@pytest.mark.parametrize(
    "raw,expected",
    [
        (None, None),
        ("", None),
        ("   ", None),
        (123456789, 123456789),
        ("123456789", 123456789),
        ("Gaia DR3 123456789", 123456789),
        ("gaia dr3 123456789", 123456789),  # case-insensitive
        ("Gaia DR3   123456789", 123456789),  # extra whitespace
        ("  Gaia DR3 123456789  ", 123456789),  # leading/trailing whitespace
        ("not a number", None),
        ("Gaia DR2 123456789", None),  # wrong release prefix → unparseable
    ],
)
def test_parse_source_id(raw, expected):
    assert parse_source_id(raw) == expected


def test_build_query_includes_all_columns():
    q = _build_query([1, 2, 3])
    for col in GAIA_COLUMNS:
        assert col in q


def test_build_query_in_clause():
    q = _build_query([100, 200, 300])
    assert "WHERE source_id IN (100, 200, 300)" in q


def test_build_query_single_id():
    q = _build_query([42])
    assert "WHERE source_id IN (42)" in q
