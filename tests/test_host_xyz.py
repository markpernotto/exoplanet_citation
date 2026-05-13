"""Unit tests for api/host_xyz.py.

Pin the coordinate-transform math. Wrong rotations here mean every
per-vantage sky is rotated incorrectly — a hard bug to spot visually.
"""

from __future__ import annotations

import math

import pytest

from api.host_xyz import (
    equatorial_to_xyz_pc,
    galactic_to_icrs,
    galactic_to_xyz_pc,
    icrs_to_galactic,
    resolve_host_xyz,
)

# ── equatorial → ICRS Cartesian ────────────────────────────────────────────

def test_equatorial_origin():
    """RA=0, Dec=0 → pure +X direction in heliocentric ICRS."""
    x, y, z = equatorial_to_xyz_pc(0, 0, 100)
    assert (x, y, z) == pytest.approx((100, 0, 0), abs=1e-9)


def test_equatorial_ra_90():
    x, y, z = equatorial_to_xyz_pc(90, 0, 100)
    assert (x, y, z) == pytest.approx((0, 100, 0), abs=1e-9)


def test_equatorial_north_pole():
    x, y, z = equatorial_to_xyz_pc(123, 90, 50)
    assert (x, y, z) == pytest.approx((0, 0, 50), abs=1e-9)


# ── galactic → ICRS rotation ───────────────────────────────────────────────

def test_galactic_to_icrs_round_trip():
    """Round-tripping through both rotations must return the input."""
    for original in [(1.0, 2.0, 3.0), (-5.0, 0.0, 10.0), (0.5, -7.3, 2.1)]:
        xg, yg, zg = original
        xi, yi, zi = galactic_to_icrs(xg, yg, zg)
        xg2, yg2, zg2 = icrs_to_galactic(xi, yi, zi)
        assert (xg2, yg2, zg2) == pytest.approx(original, abs=1e-9)


def test_galactic_center_direction_in_icrs():
    """The galactic center (l=0, b=0) in galactic coords is at ICRS
    RA ≈ 266.4°, Dec ≈ -28.94° (Sgr A*). A unit vector from Sol toward
    (l=0, b=0) should rotate to a unit vector in that ICRS direction.
    """
    # Galactic (l=0, b=0) at 1 pc → galactic Cartesian (1, 0, 0).
    xi, yi, zi = galactic_to_icrs(1.0, 0.0, 0.0)
    # Convert to RA/Dec for an easy sanity check.
    ra = math.degrees(math.atan2(yi, xi)) % 360.0
    dec = math.degrees(math.asin(zi / math.sqrt(xi * xi + yi * yi + zi * zi)))
    assert ra == pytest.approx(266.4, abs=0.5)
    assert dec == pytest.approx(-28.94, abs=0.5)


def test_north_galactic_pole_in_icrs():
    """North galactic pole (l=any, b=+90°) at ICRS RA≈192.86°, Dec≈+27.13°."""
    xi, yi, zi = galactic_to_icrs(0.0, 0.0, 1.0)
    ra = math.degrees(math.atan2(yi, xi)) % 360.0
    dec = math.degrees(math.asin(zi / math.sqrt(xi * xi + yi * yi + zi * zi)))
    assert ra == pytest.approx(192.86, abs=0.5)
    assert dec == pytest.approx(27.13, abs=0.5)


def test_galactic_distance_preserved():
    """Rotation preserves length — the resolved point should be at the
    same distance from origin as the input distance."""
    x, y, z = galactic_to_xyz_pc(45, 10, 500)
    assert math.sqrt(x * x + y * y + z * z) == pytest.approx(500.0, abs=1e-6)


# ── resolver: which path is taken ──────────────────────────────────────────

def test_resolve_prefers_gaia_distance_when_available():
    """When both `sy_dist` and `distance_gspphot_pc` are present, prefer Gaia."""
    # Same ra/dec, different distances → different XYZ → assertable.
    result_gaia = resolve_host_xyz({
        "ra": 0, "dec": 0, "sy_dist": 100, "distance_gspphot_pc": 50,
    })
    result_sydist_only = resolve_host_xyz({
        "ra": 0, "dec": 0, "sy_dist": 100,
    })
    assert result_gaia is not None
    assert result_sydist_only is not None
    assert result_gaia[0] == pytest.approx(50.0)
    assert result_sydist_only[0] == pytest.approx(100.0)


def test_resolve_falls_back_to_sy_dist():
    result = resolve_host_xyz({"ra": 0, "dec": 0, "sy_dist": 42})
    assert result is not None
    assert result == pytest.approx((42, 0, 0), abs=1e-9)


def test_resolve_falls_back_to_galactic_bulge_path():
    """No ra/dec/distance → use galactic l/b/distance fallback."""
    result = resolve_host_xyz({
        "galactic_l_deg": 0, "galactic_b_deg": 0, "discovery_distance_kpc": 1.0,
    })
    assert result is not None
    # 1 kpc at (l=0, b=0) = 1000 pc toward galactic center.
    # ICRS XYZ of that is just the rotation matrix's first row × 1000.
    assert math.sqrt(sum(c * c for c in result)) == pytest.approx(1000.0, abs=1e-6)


def test_resolve_accepts_distance_in_pc_for_bulge_fallback():
    """The bulge fallback should accept either `discovery_distance_pc` or `discovery_distance_kpc`."""
    pc_result = resolve_host_xyz({
        "galactic_l_deg": 90, "galactic_b_deg": 0, "discovery_distance_pc": 500,
    })
    kpc_result = resolve_host_xyz({
        "galactic_l_deg": 90, "galactic_b_deg": 0, "discovery_distance_kpc": 0.5,
    })
    assert pc_result is not None and kpc_result is not None
    assert pc_result == pytest.approx(kpc_result, abs=1e-6)


# ── resolver: None paths ───────────────────────────────────────────────────

def test_resolve_returns_none_when_missing_inputs():
    """All inputs missing → None."""
    assert resolve_host_xyz({}) is None
    assert resolve_host_xyz({"ra": 0, "dec": 0}) is None       # no distance
    assert resolve_host_xyz({"sy_dist": 100}) is None          # no ra/dec
    assert resolve_host_xyz({"galactic_l_deg": 0}) is None     # incomplete galactic


def test_resolve_returns_none_for_non_positive_distance():
    """Zero or negative distances are physically meaningless."""
    assert resolve_host_xyz({"ra": 0, "dec": 0, "sy_dist": 0}) is None
    assert resolve_host_xyz({"ra": 0, "dec": 0, "sy_dist": -5}) is None


def test_resolve_handles_string_values():
    """Postgres/JSON often delivers values as strings; coerce gracefully."""
    result = resolve_host_xyz({
        "ra": "0", "dec": "0", "sy_dist": "100",
    })
    assert result is not None
    assert result == pytest.approx((100, 0, 0), abs=1e-9)


def test_resolve_handles_nan_and_invalid():
    """NaN and unparseable strings should be treated as missing, not crash."""
    assert resolve_host_xyz({"ra": float("nan"), "dec": 0, "sy_dist": 100}) is None
    assert resolve_host_xyz({"ra": "garbage", "dec": 0, "sy_dist": 100}) is None
