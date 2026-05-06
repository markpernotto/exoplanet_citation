"""Unit tests for etl/enrich_gaia.py.

Pure helpers (filter_hosts, _record_params) hit directly. enrich() is exercised
with a mock Postgres connection and an injected fake fetcher so we can cover
the full incremental + resume + miss-handling logic without touching real
Postgres or the Gaia TAP service.
"""

from __future__ import annotations

from datetime import date
from typing import Any

import pytest

from etl.enrich_gaia import (
    UPSERT_BATCH_STATE_SQL,
    UPSERT_HOST_STAR_SQL,
    _record_params,
    enrich,
    filter_hosts,
)
from etl.sources.gaia import GaiaRecord


def _record(source_id: int, **overrides) -> GaiaRecord:
    """Build a GaiaRecord with sensible defaults for tests."""
    defaults: dict[str, Any] = {
        "source_id": source_id,
        "ra": 10.0,
        "dec": 20.0,
        "parallax_mas": 12.5,
        "parallax_error": 0.05,
        "pmra_mas_yr": 3.2,
        "pmdec_mas_yr": -1.4,
        "radial_velocity_km_s": 0.7,
        "phot_g_mean_mag": 11.2,
        "phot_bp_mean_mag": 11.6,
        "phot_rp_mean_mag": 10.7,
        "bp_rp": 0.9,
        "teff_gspphot": 5650.0,
        "logg_gspphot": 4.42,
        "mh_gspphot": -0.05,
        "distance_gspphot_pc": 80.1,
        "raw": {"source_id": source_id, "extra": "preserved"},
    }
    defaults.update(overrides)
    return GaiaRecord(**defaults)


# ─── filter_hosts ─────────────────────────────────────────────────────────


def test_filter_hosts_drops_unparseable():
    rows = [
        ("StarA", "Gaia DR3 100"),
        ("StarB", None),
        ("StarC", ""),
        ("StarD", "Gaia DR2 200"),  # wrong release
        ("StarE", "not a number"),
        ("StarF", "300"),
    ]
    hosts, skipped_unparseable, skipped_done = filter_hosts(rows, set())
    assert hosts == [("StarA", 100), ("StarF", 300)]
    assert skipped_unparseable == 4
    assert skipped_done == 0


def test_filter_hosts_skips_already_done_in_incremental_mode():
    rows = [
        ("StarA", "Gaia DR3 100"),
        ("StarB", "Gaia DR3 200"),
        ("StarC", "Gaia DR3 300"),
    ]
    already = {"100", "300"}
    hosts, skipped_unparseable, skipped_done = filter_hosts(rows, already)
    assert hosts == [("StarB", 200)]
    assert skipped_done == 2
    assert skipped_unparseable == 0


def test_filter_hosts_refresh_all_ignores_already_done():
    rows = [
        ("StarA", "Gaia DR3 100"),
        ("StarB", "Gaia DR3 200"),
    ]
    already = {"100", "200"}
    hosts, _, skipped_done = filter_hosts(rows, already, refresh_all=True)
    assert hosts == [("StarA", 100), ("StarB", 200)]
    assert skipped_done == 0


# ─── _record_params ───────────────────────────────────────────────────────


def test_record_params_maps_all_fields():
    rec = _record(42)
    params = _record_params(rec, "Kepler-22")
    assert params["gaia_dr3_id"] == "42"  # stored as TEXT
    assert params["hostname"] == "Kepler-22"
    assert params["parallax_mas"] == 12.5
    assert params["bp_rp"] == 0.9
    assert params["teff_gspphot"] == 5650.0
    # JSONB-wrapped raw is opaque — just verify it's the same wrapper type.
    assert params["source_record"] is not None
    assert params["source_record"].obj == {"source_id": 42, "extra": "preserved"}


def test_record_params_passes_nones_through():
    rec = _record(99, parallax_mas=None, bp_rp=None, teff_gspphot=None)
    params = _record_params(rec, "AnyHost")
    assert params["parallax_mas"] is None
    assert params["bp_rp"] is None
    assert params["teff_gspphot"] is None


# ─── enrich() — mock conn + injected fetcher ───────────────────────────────


class FakeCursor:
    """Minimal psycopg-cursor stand-in. Records every execute() call and lets
    tests pre-seed fetchall results in order."""

    def __init__(self, fetchall_queue: list[list[tuple]]):
        self._fetchall_queue = fetchall_queue
        self.executions: list[tuple[str, dict | tuple | None]] = []

    def execute(self, sql: str, params: Any = None):
        self.executions.append((sql, params))

    def fetchall(self):
        return self._fetchall_queue.pop(0)

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class FakeConn:
    """Hands out a fresh FakeCursor for each `with conn.cursor()` block, but
    all cursors share the same execution log + fetchall queue, so tests can
    assert on the full sequence of statements regardless of cursor scope."""

    def __init__(self, fetchall_queue: list[list[tuple]]):
        self._fetchall_queue = fetchall_queue
        self.executions: list[tuple[str, Any]] = []
        self.commits = 0

    def cursor(self):
        cursor = FakeCursor(self._fetchall_queue)
        # Forward execute calls into the shared log
        original_execute = cursor.execute

        def execute(sql, params=None):
            self.executions.append((sql, params))
            original_execute(sql, params)

        cursor.execute = execute
        return cursor

    def commit(self):
        self.commits += 1


def _statements_of_kind(executions, marker: str) -> list:
    """Helper: return params of every execute() whose SQL contains marker."""
    return [params for sql, params in executions if marker in sql]


def test_enrich_happy_path_writes_records_and_marks_completed():
    fetched = {1: _record(1), 2: _record(2), 3: _record(3)}

    def fake_fetcher(ids, *, user_agent):
        assert user_agent == "test-agent"
        return {i: fetched[i] for i in ids if i in fetched}

    conn = FakeConn(fetchall_queue=[
        # First fetchall: SELECT_HOSTS_SQL → (hostname, gaia_dr3_id) rows
        [("StarA", "Gaia DR3 1"), ("StarB", "Gaia DR3 2"), ("StarC", "Gaia DR3 3")],
        # Second fetchall: existing host_stars_gaia IDs (incremental anti-join)
        [],
    ])

    summary = enrich(
        conn,
        refresh_all=False,
        batch_size=2,
        max_batches=None,
        user_agent="test-agent",
        dry_run=False,
        fetcher=fake_fetcher,
        today_fn=lambda: date(2026, 5, 6),
    )

    assert summary == {"hosts": 3, "hits": 3, "misses": 0, "batches": 2}

    # Three host_stars_gaia UPSERTs (one per record), in the right shape.
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert len(upserts) == 3
    assert {p["gaia_dr3_id"] for p in upserts} == {"1", "2", "3"}
    assert {p["hostname"] for p in upserts} == {"StarA", "StarB", "StarC"}

    # backfill_state should be touched: initial create + per-batch update + final.
    state_writes = _statements_of_kind(conn.executions, "INTO backfill_state")
    assert len(state_writes) >= 3
    assert state_writes[0]["status"] == "in_progress"
    assert state_writes[0]["batch_id"] == "gaia-enrich-2026-05-06"
    assert state_writes[-1]["status"] == "completed"
    assert state_writes[-1]["processed_count"] == 3


def test_enrich_handles_misses_without_failing():
    """Gaia legitimately omits IDs sometimes (stale cross-references). They
    should be counted as misses, not crash, and not produce a host_stars_gaia row."""
    def fake_fetcher(ids, *, user_agent):
        # Return only id 1 — id 2 is a "miss"
        return {1: _record(1)}

    conn = FakeConn(fetchall_queue=[
        [("StarA", "Gaia DR3 1"), ("StarB", "Gaia DR3 2")],
        [],
    ])

    summary = enrich(
        conn, refresh_all=False, batch_size=10, max_batches=None,
        user_agent="ua", dry_run=False,
        fetcher=fake_fetcher, today_fn=lambda: date(2026, 5, 6),
    )

    assert summary["hits"] == 1
    assert summary["misses"] == 1
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert len(upserts) == 1
    assert upserts[0]["gaia_dr3_id"] == "1"
    # Final batch_state should report the miss in its notes.
    final_state = _statements_of_kind(conn.executions, "INTO backfill_state")[-1]
    assert final_state["status"] == "completed"
    assert final_state["notes"].obj["misses"] == 1


def test_enrich_skips_already_done_in_incremental_mode():
    def fake_fetcher(ids, *, user_agent):
        return {i: _record(i) for i in ids}

    conn = FakeConn(fetchall_queue=[
        [("StarA", "Gaia DR3 1"), ("StarB", "Gaia DR3 2")],
        [("1",)],  # gaia_dr3_id 1 already enriched
    ])

    summary = enrich(
        conn, refresh_all=False, batch_size=10, max_batches=None,
        user_agent="ua", dry_run=False,
        fetcher=fake_fetcher, today_fn=lambda: date(2026, 5, 6),
    )

    assert summary["hosts"] == 1
    assert summary["hits"] == 1
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert len(upserts) == 1
    assert upserts[0]["gaia_dr3_id"] == "2"


def test_enrich_dry_run_makes_no_writes():
    fetcher_calls = 0

    def fake_fetcher(ids, *, user_agent):
        nonlocal fetcher_calls
        fetcher_calls += 1
        return {}

    conn = FakeConn(fetchall_queue=[
        [("StarA", "Gaia DR3 1"), ("StarB", "Gaia DR3 2")],
        [],
    ])

    summary = enrich(
        conn, refresh_all=False, batch_size=10, max_batches=None,
        user_agent="ua", dry_run=True,
        fetcher=fake_fetcher, today_fn=lambda: date(2026, 5, 6),
    )

    assert summary["dry_run"] is True
    assert fetcher_calls == 0
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert upserts == []
    state_writes = _statements_of_kind(conn.executions, "INTO backfill_state")
    assert state_writes == []


def test_enrich_max_batches_stops_early():
    def fake_fetcher(ids, *, user_agent):
        return {i: _record(i) for i in ids}

    conn = FakeConn(fetchall_queue=[
        [("Star" + chr(64 + i), f"Gaia DR3 {i}") for i in range(1, 11)],  # 10 hosts
        [],
    ])

    summary = enrich(
        conn, refresh_all=False, batch_size=2, max_batches=2,
        user_agent="ua", dry_run=False,
        fetcher=fake_fetcher, today_fn=lambda: date(2026, 5, 6),
    )

    # 2 batches × 2 IDs = 4 records enriched
    assert summary["batches"] == 2
    assert summary["hits"] == 4
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert len(upserts) == 4


def test_enrich_persists_failure_state_on_exception():
    call_count = 0

    def flaky_fetcher(ids, *, user_agent):
        nonlocal call_count
        call_count += 1
        if call_count == 2:
            raise RuntimeError("Gaia TAP unreachable")
        return {i: _record(i) for i in ids}

    conn = FakeConn(fetchall_queue=[
        [("StarA", "Gaia DR3 1"), ("StarB", "Gaia DR3 2"),
         ("StarC", "Gaia DR3 3"), ("StarD", "Gaia DR3 4")],
        [],
    ])

    with pytest.raises(RuntimeError, match="Gaia TAP unreachable"):
        enrich(
            conn, refresh_all=False, batch_size=2, max_batches=None,
            user_agent="ua", dry_run=False,
            fetcher=flaky_fetcher, today_fn=lambda: date(2026, 5, 6),
        )

    # First batch's two records should have committed before the second batch
    # blew up — that's the resumability promise.
    upserts = _statements_of_kind(conn.executions, "INTO host_stars_gaia")
    assert len(upserts) == 2

    # The final batch_state write should mark the batch failed and record the
    # cursor so the next run can pick up where this one stopped.
    final_state = _statements_of_kind(conn.executions, "INTO backfill_state")[-1]
    assert final_state["status"] == "failed"
    assert final_state["error_count"] == 1
    assert "Gaia TAP unreachable" in final_state["notes"].obj["error"]


def test_enrich_idempotent_on_empty_input():
    """No hosts to enrich = no-op, no batch row, no writes."""
    conn = FakeConn(fetchall_queue=[
        [],   # SELECT_HOSTS_SQL returns nothing
        [],   # already-done query returns nothing
    ])
    summary = enrich(
        conn, refresh_all=False, batch_size=10, max_batches=None,
        user_agent="ua", dry_run=False,
        fetcher=lambda ids, *, user_agent: {},
        today_fn=lambda: date(2026, 5, 6),
    )
    assert summary == {"hosts": 0, "hits": 0, "misses": 0, "batches": 0}
    state_writes = _statements_of_kind(conn.executions, "INTO backfill_state")
    assert state_writes == []  # no batch row written when there's nothing to do


# ─── SQL constants — schema-stability smoke tests ──────────────────────────


def test_upsert_host_star_sql_covers_all_columns():
    # Sanity: every named parameter we pass in _record_params is referenced
    # in the SQL. Catches typos when someone adds/removes a column.
    sample = _record_params(_record(1), "X")
    for key in sample:
        assert f"%({key})s" in UPSERT_HOST_STAR_SQL, f"missing param {key} in UPSERT_HOST_STAR_SQL"


def test_upsert_batch_state_sql_covers_all_columns():
    expected = ["batch_id", "last_processed_key", "total_targets", "processed_count",
                "error_count", "status", "notes"]
    for key in expected:
        assert f"%({key})s" in UPSERT_BATCH_STATE_SQL, f"missing param {key} in UPSERT_BATCH_STATE_SQL"
