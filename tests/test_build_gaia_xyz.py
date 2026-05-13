"""Unit tests for etl/build_gaia_xyz.py.

Each test pins a specific astrophysical claim. Wrong math here means every
per-vantage sky downstream is wrong.
"""

from __future__ import annotations

import math

import pytest

from etl.build_gaia_xyz import (
    SOL_ABS_G_MAG,
    SOL_BP_RP,
    apparent_to_absolute_g,
    build_xyz_dataframe,
    equatorial_to_xyz,
)

# ── equatorial → cartesian ─────────────────────────────────────────────────

def test_xyz_origin_direction():
    """RA=0, Dec=0 → pure +X direction."""
    x, y, z = equatorial_to_xyz(0, 0, 1.0)   # parallax 1 mas → 1 kpc = 1000 pc
    assert x == pytest.approx(1000.0)
    assert y == pytest.approx(0.0, abs=1e-9)
    assert z == pytest.approx(0.0, abs=1e-9)


def test_xyz_ra_90_direction():
    """RA=90°, Dec=0 → pure +Y direction."""
    x, y, z = equatorial_to_xyz(90, 0, 1.0)
    assert x == pytest.approx(0.0, abs=1e-9)
    assert y == pytest.approx(1000.0)
    assert z == pytest.approx(0.0, abs=1e-9)


def test_xyz_north_pole():
    """Dec=+90° → pure +Z direction (north celestial pole)."""
    x, y, z = equatorial_to_xyz(0, 90, 1.0)
    assert x == pytest.approx(0.0, abs=1e-9)
    assert y == pytest.approx(0.0, abs=1e-9)
    assert z == pytest.approx(1000.0)


def test_xyz_south_pole():
    """Dec=-90° → pure -Z direction."""
    x, y, z = equatorial_to_xyz(123, -90, 2.0)   # 0.5 kpc
    assert x == pytest.approx(0.0, abs=1e-9)
    assert y == pytest.approx(0.0, abs=1e-9)
    assert z == pytest.approx(-500.0)


def test_xyz_distance_from_parallax():
    """Parallax 100 mas = 10 pc. Distance from origin should equal 10 pc."""
    x, y, z = equatorial_to_xyz(42, 17, 100.0)
    dist = math.sqrt(x * x + y * y + z * z)
    assert dist == pytest.approx(10.0)


def test_xyz_milliparsec_parallax():
    """Tiny parallax → kpc-scale distance, but still valid."""
    x, y, z = equatorial_to_xyz(0, 0, 0.5)   # parallax 0.5 mas → 2 kpc
    assert math.sqrt(x * x + y * y + z * z) == pytest.approx(2000.0)


# ── absolute magnitude ─────────────────────────────────────────────────────

def test_absolute_mag_at_10pc():
    """The 10-pc distance modulus is the definition: at 10 pc, M = m."""
    # parallax 100 mas = 10 pc
    assert apparent_to_absolute_g(5.0, 100.0) == pytest.approx(5.0)


def test_absolute_mag_at_100pc():
    """At 100 pc, abs mag = apparent - 5 (distance modulus = 5)."""
    assert apparent_to_absolute_g(10.0, 10.0) == pytest.approx(5.0)


def test_absolute_mag_at_1pc():
    """At 1 pc, abs mag = apparent + 5 (closer than reference, abs > app)."""
    assert apparent_to_absolute_g(0.0, 1000.0) == pytest.approx(5.0)


def test_sol_abs_mag_consistent():
    """Sol's apparent G ≈ -26.5; from 1 AU.

    1 AU in pc = 1 / 206_264.8 ≈ 4.848e-6 pc, so parallax in MAS is
    1000 / d_pc = 1000 / 4.848e-6 ≈ 2.063e8 mas. This is huge, but the
    distance-modulus math should still produce something close to Sol's
    well-known absolute G magnitude (4.67).
    """
    apparent_g_at_1au = -26.5
    parallax_at_1au_mas = 1000.0 / (1.0 / 206264.8)   # ≈ 2.063e8 mas
    abs_g = apparent_to_absolute_g(apparent_g_at_1au, parallax_at_1au_mas)
    assert abs_g == pytest.approx(4.67, abs=0.5)


# ── dataframe assembly ─────────────────────────────────────────────────────

def test_sol_is_row_zero():
    """Empty input still produces a 1-row DataFrame with Sol at origin."""
    df = build_xyz_dataframe([])
    assert len(df) == 1
    assert df.iloc[0]["x_pc"] == pytest.approx(0.0)
    assert df.iloc[0]["y_pc"] == pytest.approx(0.0)
    assert df.iloc[0]["z_pc"] == pytest.approx(0.0)
    assert df.iloc[0]["abs_g_mag"] == pytest.approx(SOL_ABS_G_MAG)
    assert df.iloc[0]["bp_rp"] == pytest.approx(SOL_BP_RP)


def test_one_star_appended_after_sol():
    """Sol stays row 0; the one input star lands at row 1."""
    df = build_xyz_dataframe([
        {"ra": 0, "dec": 0, "parallax": 1.0, "phot_g_mean_mag": 5.0, "bp_rp": 0.8},
    ])
    assert len(df) == 2
    assert df.iloc[1]["x_pc"] == pytest.approx(1000.0)


def test_negative_parallax_skipped():
    """Gaia occasionally reports negative parallax from noisy fits; we drop them."""
    df = build_xyz_dataframe([
        {"ra": 0, "dec": 0, "parallax": -0.5, "phot_g_mean_mag": 5.0, "bp_rp": 0.8},
    ])
    assert len(df) == 1   # Sol only; the bad star was dropped


def test_missing_fields_skipped():
    """Rows missing any required field are dropped (no crash)."""
    df = build_xyz_dataframe([
        {"ra": 0, "dec": 0, "parallax": 1.0, "phot_g_mean_mag": 5.0},   # no bp_rp
        {"ra": 0, "dec": 0, "parallax": 1.0, "bp_rp": 0.8},              # no g_mag
        {"ra": 0, "dec": 0, "phot_g_mean_mag": 5.0, "bp_rp": 0.8},       # no parallax
    ])
    assert len(df) == 1


def test_dtypes_are_float32():
    """All output columns must be float32 to keep the parquet compact."""
    df = build_xyz_dataframe([
        {"ra": 10, "dec": 20, "parallax": 5.0, "phot_g_mean_mag": 6.0, "bp_rp": 1.2},
    ])
    for col in ("x_pc", "y_pc", "z_pc", "abs_g_mag", "bp_rp"):
        assert df[col].dtype == "float32", f"{col} should be float32"


def test_none_input_doesnt_crash():
    """Defensive: a None for any field shouldn't raise, just gets skipped."""
    df = build_xyz_dataframe([
        {"ra": None, "dec": 0, "parallax": 1.0, "phot_g_mean_mag": 5.0, "bp_rp": 0.8},
    ])
    assert len(df) == 1


# ── round-trip ─────────────────────────────────────────────────────────────

def test_round_trip_position_and_mag():
    """Compose XYZ from RA/Dec/parallax, then verify distance and abs-mag math."""
    ra, dec, parallax_mas, g_mag = 45.0, 30.0, 2.5, 7.5
    x, y, z = equatorial_to_xyz(ra, dec, parallax_mas)
    dist_pc = math.sqrt(x * x + y * y + z * z)
    assert dist_pc == pytest.approx(1000.0 / parallax_mas)

    abs_mag = apparent_to_absolute_g(g_mag, parallax_mas)
    expected = g_mag - 5.0 * math.log10(dist_pc / 10.0)
    assert abs_mag == pytest.approx(expected)


def test_dataframe_columns_order():
    """Column order matters because the server may read by position."""
    df = build_xyz_dataframe([])
    assert list(df.columns) == ["x_pc", "y_pc", "z_pc", "abs_g_mag", "bp_rp"]
