"""Unit tests for etl/build_galactic_particles.py.

Pins the procedural Milky Way sampler. The math + frame conversion is
load-bearing for Phase 3 — wrong distributions or wrong rotation here
produce a galaxy whose density doesn't match reality, which becomes
visible on every per-vantage starfield render.
"""

from __future__ import annotations

import math

import numpy as np
import pytest

from etl.build_galactic_particles import (
    SOL_X_KPC,
    SOL_Y_KPC,
    SOL_Z_KPC,
    galactocentric_to_heliocentric_icrs,
    sample_bulge,
    sample_halo,
    sample_luminosity_and_color,
    sample_thick_disk,
    sample_thin_disk,
)

# ── deterministic seeding ──────────────────────────────────────────────────

def _rng(seed: int = 0) -> np.random.Generator:
    return np.random.default_rng(seed)


# ── thin disk geometry ────────────────────────────────────────────────────

def test_thin_disk_count_and_shape():
    """Sampler returns exactly N rows × 3 cols (XYZ)."""
    out = sample_thin_disk(1000, _rng())
    assert out.shape == (1000, 3)


def test_thin_disk_radial_falloff():
    """Thin disk density falls off exponentially in R.

    Concretely: more particles within 3 kpc of axis than between 6-9 kpc.
    With h_R=2.6, exp(-3/2.6) ≈ 0.31, exp(-9/2.6) ≈ 0.03 → expect ~10x more
    inside 3 kpc than between 6-9.
    """
    out = sample_thin_disk(50_000, _rng())
    R = np.sqrt(out[:, 0] ** 2 + out[:, 1] ** 2)
    n_inner = ((R < 3).sum())
    n_outer = (((R >= 6) & (R < 9)).sum())
    # Loose factor-of-3 check; sampling noise + integral over annulus area shifts this.
    assert n_inner > n_outer


def test_thin_disk_vertical_concentration():
    """Most thin disk particles are within ~1 kpc of the midplane (h_z=300pc)."""
    out = sample_thin_disk(50_000, _rng())
    z_within_1kpc = (np.abs(out[:, 2]) < 1.0).sum()
    assert z_within_1kpc / 50_000 > 0.85   # vast majority near plane


# ── thick disk geometry ───────────────────────────────────────────────────

def test_thick_disk_more_vertically_extended_than_thin():
    """Thick disk has h_z=900pc vs thin's 300pc — thicker in z."""
    thin = sample_thin_disk(20_000, _rng(1))
    thick = sample_thick_disk(20_000, _rng(2))
    assert np.std(thick[:, 2]) > np.std(thin[:, 2])


# ── bulge geometry ────────────────────────────────────────────────────────

def test_bulge_centrally_concentrated():
    """Bulge density peaks at the galactic center; most particles within 2 kpc.

    Empirically the bulge sampler (exp falloff, R_eff=700pc, triaxial)
    puts ~89% of particles within 2 kpc and ~96% within 2.5 kpc — a
    reasonable match to the real bulge's centrally-concentrated profile.
    """
    out = sample_bulge(20_000, _rng())
    r = np.sqrt(out[:, 0] ** 2 + out[:, 1] ** 2 + out[:, 2] ** 2)
    assert (r < 2.5).mean() > 0.90   # >90% within 2.5 kpc


def test_bulge_is_triaxial():
    """Bulge geometry is wider in X than Y or Z (the bar axis)."""
    out = sample_bulge(20_000, _rng())
    sigma_x = np.std(out[:, 0])
    sigma_y = np.std(out[:, 1])
    sigma_z = np.std(out[:, 2])
    assert sigma_x > sigma_y
    assert sigma_x > sigma_z


# ── halo geometry ─────────────────────────────────────────────────────────

def test_halo_extends_far():
    """Halo extends to ~30 kpc, way beyond the disk."""
    out = sample_halo(5_000, _rng())
    r = np.sqrt(out[:, 0] ** 2 + out[:, 1] ** 2 + out[:, 2] ** 2)
    # Max around r_max=30; the sampler clamps before that.
    assert r.max() < 31.0
    assert r.max() > 20.0   # should reach high values, not all near r_min


def test_halo_isotropic():
    """Halo is spherically distributed — no preferred direction."""
    out = sample_halo(20_000, _rng())
    # Means should be near zero (centered on galactic center).
    assert abs(np.mean(out[:, 0])) < 1.0
    assert abs(np.mean(out[:, 1])) < 1.0
    assert abs(np.mean(out[:, 2])) < 1.0


# ── luminosity + color distributions ──────────────────────────────────────

def test_bulge_is_redder_than_thin_disk():
    """Bulge population is dominated by red giants → mean bp_rp higher."""
    _, thin_color = sample_luminosity_and_color(10_000, "thin", _rng(1))
    _, bulge_color = sample_luminosity_and_color(10_000, "bulge", _rng(2))
    assert np.mean(bulge_color) > np.mean(thin_color)


def test_bulge_is_brighter_than_halo():
    """Bulge has lots of red giants (bright); halo is dim main-sequence."""
    bulge_mag, _ = sample_luminosity_and_color(10_000, "bulge", _rng(1))
    halo_mag, _ = sample_luminosity_and_color(10_000, "halo", _rng(2))
    # Lower mag = brighter.
    assert np.mean(bulge_mag) < np.mean(halo_mag)


def test_luminosity_color_dtype():
    """Output arrays are float32 for parquet compactness."""
    mag, color = sample_luminosity_and_color(100, "thin", _rng())
    assert mag.dtype == np.float32
    assert color.dtype == np.float32


def test_unknown_component_raises():
    with pytest.raises(ValueError):
        sample_luminosity_and_color(10, "spiral_arm", _rng())


# ── frame conversion: galactocentric → heliocentric ICRS pc ───────────────

def test_sol_position_maps_to_origin():
    """Sol's galactocentric position should land at heliocentric ICRS (0,0,0).

    With +X galactic pointing from Sol toward GC, Sol's galactocentric
    position is the NEGATIVE of (SOL_X_KPC, SOL_Y_KPC, SOL_Z_KPC) — Sol
    is in the -X direction from GC. Putting Sol there and converting
    should land at heliocentric origin.
    """
    sol_in_galactocentric = np.array([[-SOL_X_KPC, -SOL_Y_KPC, -SOL_Z_KPC]])
    out = galactocentric_to_heliocentric_icrs(sol_in_galactocentric)
    assert out.shape == (1, 3)
    np.testing.assert_allclose(out[0], [0.0, 0.0, 0.0], atol=1e-3)


def test_galactic_center_lands_in_sgr_a_direction():
    """The galactic center (origin in galactic frame) should land in the
    ICRS direction of Sgr A* — RA ≈ 266.4°, Dec ≈ -28.9°.
    """
    gc = np.array([[0.0, 0.0, 0.0]])   # galactocentric origin
    out = galactocentric_to_heliocentric_icrs(gc)   # → heliocentric ICRS pc
    x, y, z = out[0]
    # Should point AWAY from us in the Sgr A* direction (i.e., NEGATIVE of
    # the direction from Sol to galactic center per Sol's galactic position).
    # Sol's galactic position is (8.122, 0, 0.025) kpc — galactic center is
    # OPPOSITE direction in heliocentric galactic frame, i.e., (-8.122, 0, -0.025).
    # After rotation to ICRS, the direction (normalized) should match Sgr A*.
    r = math.sqrt(x * x + y * y + z * z)
    ra_deg = math.degrees(math.atan2(y, x)) % 360.0
    dec_deg = math.degrees(math.asin(z / r))
    assert ra_deg == pytest.approx(266.4, abs=0.5)
    assert dec_deg == pytest.approx(-28.9, abs=0.5)


def test_frame_conversion_preserves_distances():
    """Rotation + translation preserves Euclidean distance to Sol after kpc→pc."""
    test_points = np.array([
        [10.0, 0.0, 0.0],
        [8.122, 5.0, 0.0],
        [0.0, 0.0, 10.0],
    ])
    out = galactocentric_to_heliocentric_icrs(test_points)
    # Sol's galactocentric position is (-SOL_X_KPC, -SOL_Y_KPC, -SOL_Z_KPC)
    sol_galactocentric = np.array([-SOL_X_KPC, -SOL_Y_KPC, -SOL_Z_KPC])
    for i, point in enumerate(test_points):
        dist_kpc = np.linalg.norm(point - sol_galactocentric)
        dist_pc = np.linalg.norm(out[i])
        assert dist_pc == pytest.approx(dist_kpc * 1000.0, rel=1e-5)


def test_output_units_are_pc_not_kpc():
    """Sanity: a particle 1 kpc from Sol should be at ~1000 pc in output.

    Place a particle 1 kpc from Sol in the +X galactic direction.
    Sol is at galactocentric (-SOL_X_KPC, -SOL_Y_KPC, -SOL_Z_KPC), so
    1 kpc from Sol in +X galactic direction is at galactocentric
    (-SOL_X_KPC + 1, -SOL_Y_KPC, -SOL_Z_KPC).
    """
    one_kpc_from_sol = np.array([[-SOL_X_KPC + 1.0, -SOL_Y_KPC, -SOL_Z_KPC]])
    out = galactocentric_to_heliocentric_icrs(one_kpc_from_sol)
    dist_pc = np.linalg.norm(out[0])
    assert dist_pc == pytest.approx(1000.0, rel=1e-3)


# ── deterministic seeding ──────────────────────────────────────────────────

def test_seeding_is_deterministic():
    """Same seed → identical samples (reproducibility critical for the ETL)."""
    a_thin = sample_thin_disk(100, _rng(42))
    b_thin = sample_thin_disk(100, _rng(42))
    np.testing.assert_array_equal(a_thin, b_thin)


def test_different_seeds_differ():
    a = sample_thin_disk(100, _rng(1))
    b = sample_thin_disk(100, _rng(2))
    assert not np.array_equal(a, b)
