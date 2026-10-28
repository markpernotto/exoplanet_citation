"""Unit tests for the value check in etl/backfill_change_reflinks.py.

The backfill only attaches a reference when the archived snapshots reproduce
the change's recorded values. Rows are raw CSV cells as pandas yields them.
"""

from __future__ import annotations

import math

from etl.backfill_change_reflinks import resolve_reflinks, values_match


def change(field="pl_bmasse", prev=9.0, new=12.0):
    return {"change_id": 1, "pl_name": "X b", "field_name": field, "prev_value": prev, "new_value": new}


def test_matching_values_return_both_reflinks():
    prev_row = {"pl_bmasse": 9.0, "pl_bmasse_reflink": "<a>Old</a>"}
    curr_row = {"pl_bmasse": 12.0, "pl_bmasse_reflink": "<a>New</a>"}
    assert resolve_reflinks(change(), prev_row, curr_row) == ("<a>Old</a>", "<a>New</a>")


def test_new_value_mismatch_is_rejected():
    prev_row = {"pl_bmasse": 9.0, "pl_bmasse_reflink": "<a>Old</a>"}
    curr_row = {"pl_bmasse": 13.0, "pl_bmasse_reflink": "<a>New</a>"}
    assert isinstance(resolve_reflinks(change(), prev_row, curr_row), str)


def test_prev_value_mismatch_is_rejected():
    prev_row = {"pl_bmasse": 8.0, "pl_bmasse_reflink": "<a>Old</a>"}
    curr_row = {"pl_bmasse": 12.0, "pl_bmasse_reflink": "<a>New</a>"}
    assert isinstance(resolve_reflinks(change(), prev_row, curr_row), str)


def test_null_transition_and_nan_cells():
    prev_row = {"pl_bmasse": math.nan, "pl_bmasse_reflink": math.nan}
    curr_row = {"pl_bmasse": 12.0, "pl_bmasse_reflink": "<a>New</a>"}
    assert resolve_reflinks(change(prev=None), prev_row, curr_row) == (None, "<a>New</a>")


def test_int_field_from_float_cell():
    prev_row = {"disc_year": 2019.0, "disc_refname": "<a>D</a>"}
    curr_row = {"disc_year": 2020.0, "disc_refname": "<a>D</a>"}
    assert resolve_reflinks(change("disc_year", 2019, 2020), prev_row, curr_row) == ("<a>D</a>", "<a>D</a>")


def test_missing_planet_or_ref_col():
    row = {"pl_bmasse": 12.0}
    assert isinstance(resolve_reflinks(change(), None, row), str)
    assert isinstance(resolve_reflinks(change(), row, None), str)
    assert resolve_reflinks(change("sy_pnum", 1, 2), {"sy_pnum": 1}, {"sy_pnum": 2}) == "no_ref_col"


def test_values_match_tolerates_float_repr_only():
    assert values_match(0.1 + 0.2, 0.3)
    assert not values_match(9.0, 9.01)
    assert values_match("Transit", "Transit")
    assert not values_match(None, 0.0)
