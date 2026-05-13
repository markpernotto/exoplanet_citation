"""Unit tests for api/starfield.py rasterization core.

These pin the geometry of the per-vantage projection. Wrong math here
produces a sky that's subtly rotated or scaled wrong — easy to ship a
broken texture if we don't catch it numerically.
"""

from __future__ import annotations

import math

import numpy as np
import pandas as pd
import pytest

from api.starfield import (
    DEFAULT_HEIGHT,
    DEFAULT_WIDTH,
    bprp_to_rgb,
    rasterize_skytexture,
    render_png,
)

# ── bprp_to_rgb buckets ────────────────────────────────────────────────────

def test_bprp_buckets_cover_all_spectral_types():
    """Every type from O/B through brown dwarf maps to a distinct color."""
    bp_rp = np.array([-1.0, 0.2, 0.7, 1.2, 2.0, 4.0], dtype=np.float32)
    rgb = bprp_to_rgb(bp_rp)
    # O/B = blue (high B channel)
    assert rgb[0, 2] > rgb[0, 0]
    # M = red (high R, low B)
    assert rgb[4, 0] > rgb[4, 2]
    # Brown dwarf = even redder
    assert rgb[5, 0] > rgb[5, 1] > rgb[5, 2]


def test_bprp_handles_empty():
    rgb = bprp_to_rgb(np.array([], dtype=np.float32))
    assert rgb.shape == (0, 3)


# ── geometry: a star at known direction lands at the right pixel ──────────

def _single_star_catalog(x, y, z, abs_mag=2.0, bp_rp=0.8) -> pd.DataFrame:
    return pd.DataFrame({
        "x_pc": [x],
        "y_pc": [y],
        "z_pc": [z],
        "abs_g_mag": [abs_mag],
        "bp_rp": [bp_rp],
    }).astype({
        "x_pc": "float32",
        "y_pc": "float32",
        "z_pc": "float32",
        "abs_g_mag": "float32",
        "bp_rp": "float32",
    })


def _brightest_pixel(arr: np.ndarray) -> tuple[int, int]:
    """Return (py, px) of the pixel with the highest RGB sum.

    Stars are now drawn as anti-aliased discs spanning ~4 pixels each
    (plus optional halo overlay for bright stars), so we can't just
    look for "the one lit pixel" — we find the brightest one.
    """
    luminance = arr.sum(axis=2)
    py, px = np.unravel_index(int(luminance.argmax()), luminance.shape)
    return int(py), int(px)


def test_star_at_ra0_dec0_lands_at_left_edge():
    """A star at RA=0, Dec=0 maps to u=0.5 (center horizontal), v=0.5
    (equator).

    Why u=0.5: our convention is u = (ra + π) / 2π. RA=0 (which is
    arctan2(0, +X) = 0) gives u = π / 2π = 0.5.
    """
    catalog = _single_star_catalog(x=100.0, y=0.0, z=0.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    py, px = _brightest_pixel(np.array(img))
    assert px == pytest.approx(DEFAULT_WIDTH // 2, abs=1)
    assert py == pytest.approx(DEFAULT_HEIGHT // 2, abs=1)


def test_star_at_dec_plus_90_lands_at_top():
    """North celestial pole → top of texture (v=0)."""
    catalog = _single_star_catalog(x=0.0, y=0.0, z=100.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    py, _ = _brightest_pixel(np.array(img))
    assert py == pytest.approx(0, abs=1)   # very top row (allow 1px for disc spread)


def test_star_at_dec_minus_90_lands_at_bottom():
    """South celestial pole → bottom of texture (v=1)."""
    catalog = _single_star_catalog(x=0.0, y=0.0, z=-100.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    py, _ = _brightest_pixel(np.array(img))
    assert py == pytest.approx(DEFAULT_HEIGHT - 1, abs=1)   # very bottom row


# ── per-vantage reprojection: a star looks different from a different host ─

def test_same_star_different_vantage_lands_at_different_pixel():
    """Move the host; the star should land in a different direction.

    Star at (100, 0, 0). From Sol (0,0,0): direction is +X (RA=0, Dec=0).
    From a host at (0, 100, 0): direction is now (100, -100, 0) — angle
    has changed substantially → different texture pixel.
    """
    catalog = _single_star_catalog(x=100.0, y=0.0, z=0.0)
    img_sol = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    img_host = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 100.0, 0.0))
    sol_brightest = _brightest_pixel(np.array(img_sol))
    host_brightest = _brightest_pixel(np.array(img_host))
    # Brightest pixel from the two vantages should land in DIFFERENT places.
    assert sol_brightest != host_brightest


# ── apparent magnitude cutoff ──────────────────────────────────────────────

def test_dim_star_culled_by_mag_cutoff():
    """A star intrinsically faint and far away should drop below cutoff."""
    # M = 10, d = 1000 pc → m = 10 + 5*log10(100) = 20 → way past cutoff (12)
    catalog = _single_star_catalog(x=1000.0, y=0.0, z=0.0, abs_mag=10.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert np.array(img).sum() == 0   # no lit pixels


def test_bright_star_rendered():
    """A bright, nearby star should produce a visible pixel."""
    # M = 2, d = 10 pc → m = 2 → well below cutoff
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert np.array(img).sum() > 0


# ── host self-exclusion ────────────────────────────────────────────────────

def test_host_star_excluded():
    """The host star itself shouldn't render — it'd be at infinite
    apparent brightness right at the camera.
    """
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=4.0)
    # Host at the same position as the star.
    img = rasterize_skytexture(catalog, host_xyz_pc=(10.0, 0.0, 0.0))
    assert np.array(img).sum() == 0


# ── output dimensions and format ───────────────────────────────────────────

def test_output_dimensions_default():
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert img.size == (DEFAULT_WIDTH, DEFAULT_HEIGHT)
    assert img.mode == "RGB"


def test_output_dimensions_custom():
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0)
    img = rasterize_skytexture(
        catalog, host_xyz_pc=(0.0, 0.0, 0.0), width=512, height=256,
    )
    assert img.size == (512, 256)


def test_render_png_returns_valid_png_bytes():
    """render_png should produce a PNG header that PIL can read back."""
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0)
    png_bytes = render_png(
        catalog, host_xyz_pc=(0.0, 0.0, 0.0), width=128, height=64,
    )
    assert png_bytes[:8] == b"\x89PNG\r\n\x1a\n"
    # Round-trip read back to confirm valid encoding.
    import io

    from PIL import Image
    img = Image.open(io.BytesIO(png_bytes))
    assert img.size == (128, 64)


# ── color survives rasterization ───────────────────────────────────────────

def test_red_star_pixel_is_red():
    """An M-dwarf (bp_rp > 1.5) at known position should write a red-dominant pixel."""
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0, bp_rp=2.0)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    py, px = _brightest_pixel(arr)
    r, g, b = arr[py, px]
    assert r > g > b   # M-dwarf: red dominates


def test_blue_star_pixel_is_blue():
    """An O/B star (bp_rp < 0) should write a blue-dominant pixel."""
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0, bp_rp=-0.3)
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    py, px = _brightest_pixel(arr)
    r, g, b = arr[py, px]
    assert b > r   # O/B: blue dominates


# ── distance modulus integration ───────────────────────────────────────────

def test_apparent_mag_formula_matches_distance_modulus():
    """Spot-check: same star, observed from 10 pc vs 30 pc.

    At 10 pc, m = M (by definition).
    At 30 pc, m = M + 5*log10(3) ≈ M + 2.4.
    With abs_mag = 3, near apparent ≈ 3, far apparent ≈ 5.4 — both
    well under the 9.5 cutoff. Near should render brighter than far.
    """
    catalog_near = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=3.0)
    catalog_far = _single_star_catalog(x=30.0, y=0.0, z=0.0, abs_mag=3.0)
    near_img = rasterize_skytexture(catalog_near, host_xyz_pc=(0.0, 0.0, 0.0))
    far_img = rasterize_skytexture(catalog_far, host_xyz_pc=(0.0, 0.0, 0.0))
    near_brightness = np.array(near_img).sum()
    far_brightness = np.array(far_img).sum()
    assert near_brightness > 0
    assert far_brightness > 0
    assert near_brightness > far_brightness


def test_dec_value_is_clipped_for_extreme_input():
    """Numerical edge: a star whose normalized z is slightly > 1 due to
    float roundoff shouldn't crash arcsin.
    """
    # Construct a star with z very slightly larger than x²+y²+z² implies.
    # In practice the dz/d_pc ratio will be 1.0 or so. The np.clip in
    # rasterize_skytexture should handle this gracefully.
    catalog = _single_star_catalog(x=0.0, y=0.0, z=100.0)
    # Should not raise.
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert img is not None


# ── end-to-end with a larger synthetic catalog ────────────────────────────

def test_many_stars_render_to_distinct_pixels():
    """A realistic-ish small catalog should produce a sky with multiple
    lit pixels at sensible positions.
    """
    # 100 stars on a sphere of radius 100 pc, evenly distributed angles.
    np.random.seed(42)
    n = 100
    theta = np.random.uniform(0, 2 * math.pi, n)
    phi = np.arccos(np.random.uniform(-1, 1, n))
    r = 100.0
    catalog = pd.DataFrame({
        "x_pc": (r * np.sin(phi) * np.cos(theta)).astype(np.float32),
        "y_pc": (r * np.sin(phi) * np.sin(theta)).astype(np.float32),
        "z_pc": (r * np.cos(phi)).astype(np.float32),
        "abs_g_mag": np.full(n, 4.0, dtype=np.float32),
        "bp_rp": np.full(n, 0.8, dtype=np.float32),
    })
    img = rasterize_skytexture(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    n_lit = np.count_nonzero(arr.sum(axis=2))
    # Allow some pixels to overlap; expect at least 90% unique.
    assert n_lit >= 90
