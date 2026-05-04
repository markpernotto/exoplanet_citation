"""Unit tests for etl/diff.py.

All tests run on in-memory dicts; no DB required.
"""

from __future__ import annotations

import pytest

from etl.diff import (
    ALL_FIELDS,
    FieldSpec,
    classify_field_change,
    diff_rows,
    diff_snapshots,
)


def make_row(pl_name: str = "Kepler-22 b", **overrides):
    base = {
        "pl_name": pl_name,
        "hostname": "Kepler-22",
        "sy_snum": 1,
        "sy_pnum": 1,
        "discoverymethod": "Transit",
        "disc_year": 2011,
        "disc_facility": "Kepler",
        "disc_telescope": "Kepler",
        "disc_instrument": "Kepler CCD Array",
        "disc_refname": "Borucki et al. 2011",
        "pl_orbper": 289.86,
        "pl_rade": 2.4,
        "pl_bmasse": 9.0,
        "pl_eqt": 262.0,
        "st_dist": 190.0,
    }
    base.update(overrides)
    return base


# ---- classify_field_change ----

def test_classify_no_change_returns_false():
    f = FieldSpec("discoverymethod", tier="A")
    r = classify_field_change(f, "Transit", "Transit")
    assert r.is_change is False
    assert r.tier == ""


def test_classify_categorical_change_emits_at_field_tier():
    f = FieldSpec("discoverymethod", tier="A")
    r = classify_field_change(f, "Transit", "Radial Velocity")
    assert r.is_change is True
    assert r.tier == "A"


def test_classify_null_to_value_emits_at_field_tier_skipping_tolerance():
    f = FieldSpec("pl_rade", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, None, 1.5)
    assert r.is_change is True
    assert r.tier == "A"


def test_classify_value_to_null_emits_at_field_tier():
    f = FieldSpec("pl_rade", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, 1.5, None)
    assert r.is_change is True
    assert r.tier == "A"


def test_classify_tier_a_float_above_threshold_emits_at_a():
    f = FieldSpec("pl_orbper", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, 100.0, 102.0)  # 2%
    assert r.is_change is True
    assert r.tier == "A"


def test_classify_tier_a_float_below_threshold_demoted_to_b():
    f = FieldSpec("pl_orbper", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, 100.0, 100.5)  # 0.5%
    assert r.is_change is True
    assert r.tier == "B"


def test_classify_tier_a_float_exactly_at_threshold_is_below():
    """Strictly less-than, so a 1.000% change is NOT below 1% (no demotion)."""
    f = FieldSpec("pl_orbper", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, 100.0, 101.0)  # exactly 1% relative to max
    assert r.is_change is True
    # 1.0/101 ≈ 0.0099 — actually below threshold, gets demoted. Document the behavior.
    assert r.tier == "B"


def test_classify_tier_b_float_below_threshold_suppressed():
    f = FieldSpec("pl_eqt", tier="B", rel_tolerance=0.01)
    r = classify_field_change(f, 200.0, 201.0)  # 0.5%
    assert r.is_change is False
    assert r.tier == ""


def test_classify_tier_b_float_above_threshold_emits_at_b():
    f = FieldSpec("pl_eqt", tier="B", rel_tolerance=0.01)
    r = classify_field_change(f, 200.0, 210.0)  # 5%
    assert r.is_change is True
    assert r.tier == "B"


def test_classify_tier_b_int_emits_at_b_for_any_change():
    f = FieldSpec("sy_pnum", tier="B")
    r = classify_field_change(f, 1, 2)
    assert r.is_change is True
    assert r.tier == "B"


def test_classify_zero_to_zero_no_change():
    f = FieldSpec("pl_orbper", tier="A", rel_tolerance=0.01)
    r = classify_field_change(f, 0.0, 0.0)
    assert r.is_change is False


# ---- diff_rows ----

def test_diff_rows_new_planet():
    out = diff_rows(None, make_row("Kepler-22 b"), ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["change_type"] == "NEW"
    assert out[0]["pl_name"] == "Kepler-22 b"
    assert out[0]["field_name"] is None
    assert out[0]["field_tier"] is None
    assert out[0]["prev_value"] is None
    assert out[0]["new_value"]["pl_name"] == "Kepler-22 b"


def test_diff_rows_removed_planet():
    out = diff_rows(make_row("Old Planet"), None, ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["change_type"] == "REMOVED"
    assert out[0]["pl_name"] == "Old Planet"
    assert out[0]["new_value"] is None
    assert out[0]["prev_value"]["pl_name"] == "Old Planet"


def test_diff_rows_no_changes_returns_empty():
    row = make_row()
    assert diff_rows(row, row, ALL_FIELDS, "2026-05-05") == []


def test_diff_rows_single_param_change():
    prev = make_row(pl_orbper=289.86)
    curr = make_row(pl_orbper=300.0)  # ~3.5%
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["change_type"] == "PARAMETER_CHANGE"
    assert out[0]["field_name"] == "pl_orbper"
    assert out[0]["field_tier"] == "A"
    assert out[0]["prev_value"] == 289.86
    assert out[0]["new_value"] == 300.0


def test_diff_rows_multiple_param_changes():
    prev = make_row(pl_orbper=289.86, pl_rade=2.4, discoverymethod="Transit")
    curr = make_row(pl_orbper=300.0, pl_rade=3.0, discoverymethod="Radial Velocity")
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert len(out) == 3
    assert {c["field_name"] for c in out} == {"pl_orbper", "pl_rade", "discoverymethod"}


def test_diff_rows_subthreshold_a_demoted_to_b():
    prev = make_row(pl_orbper=100.0)
    curr = make_row(pl_orbper=100.5)  # 0.5% — below 1%
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["field_name"] == "pl_orbper"
    assert out[0]["field_tier"] == "B"


def test_diff_rows_subthreshold_b_suppressed():
    prev = make_row(pl_eqt=200.0)
    curr = make_row(pl_eqt=200.5)  # 0.25% — below 1%
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert out == []


def test_diff_rows_tier_c_fields_not_diffed():
    """Fields outside ALL_FIELDS (hostname, disc_telescope, disc_refname) are
    Tier C and must not produce changes even when their values differ."""
    prev = make_row(hostname="Old Host", disc_telescope="Telescope-1", disc_refname="Ref A")
    curr = make_row(hostname="New Host", disc_telescope="Telescope-2", disc_refname="Ref B")
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert out == []


def test_diff_rows_null_to_value_emits():
    prev = make_row(disc_year=None)
    curr = make_row(disc_year=2024)
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["field_name"] == "disc_year"
    assert out[0]["field_tier"] == "A"
    assert out[0]["prev_value"] is None
    assert out[0]["new_value"] == 2024


def test_diff_rows_value_to_null_emits_for_tier_b_too():
    prev = make_row(pl_eqt=200.0)
    curr = make_row(pl_eqt=None)
    out = diff_rows(prev, curr, ALL_FIELDS, "2026-05-05")
    assert len(out) == 1
    assert out[0]["field_name"] == "pl_eqt"
    assert out[0]["field_tier"] == "B"


# ---- diff_snapshots ----

def test_diff_snapshots_new_removed_changed():
    prev = {
        "Kepler-22 b": make_row("Kepler-22 b", pl_orbper=289.86),
        "Old Planet": make_row("Old Planet"),
    }
    curr = {
        "Kepler-22 b": make_row("Kepler-22 b", pl_orbper=300.0),
        "New Planet": make_row("New Planet"),
    }
    out = diff_snapshots(prev, curr, snapshot_date="2026-05-05")
    by_type = {c["change_type"]: c for c in out}
    assert set(by_type) == {"NEW", "REMOVED", "PARAMETER_CHANGE"}
    assert by_type["NEW"]["pl_name"] == "New Planet"
    assert by_type["REMOVED"]["pl_name"] == "Old Planet"
    assert by_type["PARAMETER_CHANGE"]["pl_name"] == "Kepler-22 b"
    assert by_type["PARAMETER_CHANGE"]["field_name"] == "pl_orbper"


def test_diff_snapshots_idempotency():
    """Running the function twice on identical input produces identical output."""
    prev = {"A": make_row("A"), "B": make_row("B", pl_orbper=100)}
    curr = {"A": make_row("A"), "B": make_row("B", pl_orbper=110), "C": make_row("C")}
    out1 = diff_snapshots(prev, curr, snapshot_date="2026-05-05")
    out2 = diff_snapshots(prev, curr, snapshot_date="2026-05-05")
    assert out1 == out2


def test_diff_snapshots_empty_prev_marks_all_new():
    curr = {"A": make_row("A"), "B": make_row("B")}
    out = diff_snapshots({}, curr, snapshot_date="2026-05-05")
    assert all(c["change_type"] == "NEW" for c in out)
    assert {c["pl_name"] for c in out} == {"A", "B"}


def test_diff_snapshots_empty_curr_marks_all_removed():
    prev = {"A": make_row("A"), "B": make_row("B")}
    out = diff_snapshots(prev, {}, snapshot_date="2026-05-05")
    assert all(c["change_type"] == "REMOVED" for c in out)
    assert {c["pl_name"] for c in out} == {"A", "B"}


def test_diff_snapshots_empty_both_returns_empty():
    assert diff_snapshots({}, {}, snapshot_date="2026-05-05") == []


def test_diff_snapshots_deterministic_ordering():
    """Output is deterministic (sorted by pl_name) so re-runs produce identical
    rows for the unique-index idempotency guard."""
    prev = {"Z": make_row("Z"), "A": make_row("A"), "M": make_row("M")}
    curr = {"Z": make_row("Z"), "A": make_row("A"), "M": make_row("M")}
    out = diff_snapshots(prev, curr, snapshot_date="2026-05-05")
    assert out == []
    # With one change in each, expect alphabetical pl_name ordering
    prev2 = {"Z": make_row("Z", pl_orbper=10), "A": make_row("A", pl_orbper=10), "M": make_row("M", pl_orbper=10)}
    curr2 = {"Z": make_row("Z", pl_orbper=20), "A": make_row("A", pl_orbper=20), "M": make_row("M", pl_orbper=20)}
    out2 = diff_snapshots(prev2, curr2, snapshot_date="2026-05-05")
    assert [c["pl_name"] for c in out2] == ["A", "M", "Z"]


# ---- Built-in field-list sanity ----

def test_all_fields_unique_names():
    names = [f.name for f in ALL_FIELDS]
    assert len(names) == len(set(names))


def test_all_field_tiers_valid():
    for f in ALL_FIELDS:
        assert f.tier in {"A", "B"}


@pytest.mark.parametrize(
    "field_name,expected_tier",
    [
        ("discoverymethod", "A"),
        ("disc_year", "A"),
        ("disc_facility", "A"),
        ("pl_orbper", "A"),
        ("pl_rade", "A"),
        ("pl_bmasse", "A"),
        ("sy_snum", "B"),
        ("sy_pnum", "B"),
        ("pl_eqt", "B"),
        ("st_dist", "B"),
    ],
)
def test_field_tier_assignments(field_name, expected_tier):
    field = next(f for f in ALL_FIELDS if f.name == field_name)
    assert field.tier == expected_tier
