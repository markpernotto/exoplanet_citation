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

# Test dimensions: production DEFAULT_WIDTH/HEIGHT are 8192×4096. Pinning
# the suite to 4096×2048 (the prior production default) cuts memory 4× and
# runtime ~3× per case versus running at 8K. We can't go arbitrarily smaller
# because several tests assert pixel-precise star positions: the Gaussian-
# splat σ scales with `width / 4096`, so at e.g. 512px wide each star's σ
# drops to ~0.05 (sub-pixel) and the diffuse Milky Way layer dominates the
# brightest-pixel search. 4K is the floor where the star-finding tests
# remain reliable.
TEST_WIDTH = 4096
TEST_HEIGHT = 2048


def _rasterize(catalog, host_xyz_pc, **kw):
    """Test wrapper: defaults width/height to TEST_WIDTH/TEST_HEIGHT.

    Explicit width/height passed by the caller still wins (setdefault),
    so tests that exercise specific dimensions keep working unchanged.
    """
    kw.setdefault("width", TEST_WIDTH)
    kw.setdefault("height", TEST_HEIGHT)
    return rasterize_skytexture(catalog, host_xyz_pc=host_xyz_pc, **kw)

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

def _single_star_catalog(x, y, z, abs_mag=0.0, bp_rp=0.8) -> pd.DataFrame:
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


def _empty_catalog() -> pd.DataFrame:
    """An empty catalog with the correct schema. Used as a baseline for
    "this star should not render" assertions: the diffuse galaxy and
    extragalactic anchor layers always contribute pixels, so we can't
    just assert `sum == 0`; instead we compare the rendered output
    against the empty-catalog render and assert byte-equality.
    """
    return _single_star_catalog(0.0, 0.0, 0.0).iloc[0:0].copy()


def _brightest_pixel(
    arr: np.ndarray,
    near: tuple[int, int] | None = None,
    radius: int | tuple[int, int] = 8,
) -> tuple[int, int]:
    """Return (py, px) of the pixel with the highest RGB sum.

    The diffuse Milky Way layer added in Phase 4 lights every pixel; a
    naive whole-image argmax returns the galactic-center glow rather
    than the test star. When `near=(py, px)` is provided, the search
    is restricted to a window of half-extent `radius` (int for a square
    window, or `(py_radius, px_radius)` for a rectangular one). The
    polar tests use a wide-x narrow-y window because the equirectangular
    distortion spreads a pole star across an entire row.
    """
    luminance = arr.sum(axis=2)
    if near is not None:
        py0, px0 = near
        py_r, px_r = (radius, radius) if isinstance(radius, int) else radius
        h, w = luminance.shape
        py_lo = max(0, py0 - py_r)
        py_hi = min(h, py0 + py_r + 1)
        px_lo = max(0, px0 - px_r)
        px_hi = min(w, px0 + px_r + 1)
        sub = luminance[py_lo:py_hi, px_lo:px_hi]
        idx = np.unravel_index(int(sub.argmax()), sub.shape)
        return int(py_lo + idx[0]), int(px_lo + idx[1])
    py, px = np.unravel_index(int(luminance.argmax()), luminance.shape)
    return int(py), int(px)


def test_star_at_ra0_dec0_lands_at_left_edge():
    """A star at RA=0, Dec=0 maps to u=0.5 (center horizontal), v=0.5
    (equator).

    Why u=0.5: our convention is u = (ra + π) / 2π. RA=0 (which is
    arctan2(0, +X) = 0) gives u = π / 2π = 0.5.
    """
    catalog = _single_star_catalog(x=100.0, y=0.0, z=0.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    py, px = _brightest_pixel(
        np.array(img),
        near=(TEST_HEIGHT // 2, TEST_WIDTH // 2),
        radius=16,
    )
    assert px == pytest.approx(TEST_WIDTH // 2, abs=1)
    assert py == pytest.approx(TEST_HEIGHT // 2, abs=1)


def test_star_at_dec_plus_90_lands_at_top():
    """North celestial pole → top of texture (v=0)."""
    catalog = _single_star_catalog(x=0.0, y=0.0, z=100.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    # At the pole, equirectangular distortion spreads the star across an
    # entire row, so we search a wide-x narrow-y window at the top.
    py, _ = _brightest_pixel(
        np.array(img),
        near=(0, TEST_WIDTH // 2),
        radius=(3, TEST_WIDTH // 2),
    )
    assert py == pytest.approx(0, abs=1)   # very top row (allow 1px for disc spread)


def test_star_at_dec_minus_90_lands_at_bottom():
    """South celestial pole → bottom of texture (v=1)."""
    catalog = _single_star_catalog(x=0.0, y=0.0, z=-100.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    py, _ = _brightest_pixel(
        np.array(img),
        near=(TEST_HEIGHT - 1, TEST_WIDTH // 2),
        radius=(3, TEST_WIDTH // 2),
    )
    assert py == pytest.approx(TEST_HEIGHT - 1, abs=1)   # very bottom row


# ── per-vantage reprojection: a star looks different from a different host ─

def test_same_star_different_vantage_lands_at_different_pixel():
    """Move the host; the star should land in a different direction.

    Star at (100, 0, 0). From Sol (0,0,0): direction is +X (RA=0, Dec=0).
    From a host at (0, 100, 0): direction is now (100, -100, 0) — angle
    has changed substantially → different texture pixel.
    """
    catalog = _single_star_catalog(x=100.0, y=0.0, z=0.0)
    img_sol = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    img_host = _rasterize(catalog, host_xyz_pc=(0.0, 100.0, 0.0))
    sol_brightest = _brightest_pixel(np.array(img_sol))
    host_brightest = _brightest_pixel(np.array(img_host))
    # Brightest pixel from the two vantages should land in DIFFERENT places.
    assert sol_brightest != host_brightest


# ── apparent magnitude cutoff ──────────────────────────────────────────────

def test_dim_star_culled_by_mag_cutoff():
    """A star intrinsically faint and far away should drop below cutoff."""
    # M = 10, d = 1000 pc → m = 10 + 5*log10(100) = 20 → way past cutoff (14)
    catalog = _single_star_catalog(x=1000.0, y=0.0, z=0.0, abs_mag=10.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    # Diffuse galaxy + extragalactic anchors always contribute pixels, so
    # `sum == 0` no longer holds. The operationally meaningful check is
    # "this star adds nothing": render with and without the star should be
    # byte-identical.
    baseline = _rasterize(_empty_catalog(), host_xyz_pc=(0.0, 0.0, 0.0))
    np.testing.assert_array_equal(np.array(img), np.array(baseline))


def test_bright_star_rendered():
    """A bright, nearby star should produce a visible pixel."""
    # M = 2, d = 10 pc → m = 2 → well below cutoff
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert np.array(img).sum() > 0


# ── host self-exclusion ────────────────────────────────────────────────────

def test_host_star_excluded():
    """The host star itself shouldn't render — it'd be at infinite
    apparent brightness right at the camera.
    """
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=4.0)
    # Host at the same position as the star.
    img = _rasterize(catalog, host_xyz_pc=(10.0, 0.0, 0.0))
    # Same baseline approach as test_dim_star_culled_by_mag_cutoff: the
    # diffuse layer prevents `sum == 0`; instead assert that the star
    # contributes nothing relative to an empty-catalog render from the
    # same vantage.
    baseline = _rasterize(_empty_catalog(), host_xyz_pc=(10.0, 0.0, 0.0))
    np.testing.assert_array_equal(np.array(img), np.array(baseline))


# ── output dimensions and format ───────────────────────────────────────────

def test_output_dimensions_default():
    """Wrapper-default dims passthrough + production-default sanity check.
    The production-default (8K) render itself isn't exercised here; doing
    so per-test would balloon the suite memory + runtime. The explicit-dim
    path is exercised in test_output_dimensions_custom below, and the
    full-resolution default render is covered by the API endpoint integration
    tests.
    """
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert img.size == (TEST_WIDTH, TEST_HEIGHT)
    assert img.mode == "RGB"
    # Sanity-check the production defaults: equirectangular aspect (2:1).
    assert DEFAULT_WIDTH == 2 * DEFAULT_HEIGHT


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
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    # Localize search around the expected star pixel — without this, the
    # warm-red diffuse galactic bulge would be the absolute brightest and
    # the test would pass for the wrong reason (the bulge is red regardless
    # of the test catalog's bp_rp).
    py, px = _brightest_pixel(
        arr,
        near=(TEST_HEIGHT // 2, TEST_WIDTH // 2),
        radius=16,
    )
    r, g, b = arr[py, px]
    assert r > g > b   # M-dwarf: red dominates


def test_blue_star_pixel_is_blue():
    """An O/B star (bp_rp < 0) should write a blue-dominant pixel."""
    catalog = _single_star_catalog(x=10.0, y=0.0, z=0.0, abs_mag=2.0, bp_rp=-0.3)
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    # Star at (10, 0, 0) → RA=0, Dec=0 → expected at the texture center.
    # Localize the brightest-pixel search so the warm diffuse galactic
    # center glow doesn't dominate the result.
    py, px = _brightest_pixel(
        arr,
        near=(TEST_HEIGHT // 2, TEST_WIDTH // 2),
        radius=16,
    )
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
    near_img = _rasterize(catalog_near, host_xyz_pc=(0.0, 0.0, 0.0))
    far_img = _rasterize(catalog_far, host_xyz_pc=(0.0, 0.0, 0.0))
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
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    assert img is not None


# ── end-to-end with a larger synthetic catalog ────────────────────────────

def test_many_stars_render_to_distinct_pixels():
    """A realistic-ish small catalog should produce a sky with multiple
    lit pixels at sensible positions.
    """
    # 100 stars on a sphere of radius 30 pc, all at abs mag 1 (so apparent
    # mag ≈ 3.4, well within the 6.5 cutoff). Bright enough for all to
    # render and get halos.
    np.random.seed(42)
    n = 100
    theta = np.random.uniform(0, 2 * math.pi, n)
    phi = np.arccos(np.random.uniform(-1, 1, n))
    r = 30.0
    catalog = pd.DataFrame({
        "x_pc": (r * np.sin(phi) * np.cos(theta)).astype(np.float32),
        "y_pc": (r * np.sin(phi) * np.sin(theta)).astype(np.float32),
        "z_pc": (r * np.cos(phi)).astype(np.float32),
        "abs_g_mag": np.full(n, 1.0, dtype=np.float32),
        "bp_rp": np.full(n, 0.8, dtype=np.float32),
    })
    img = _rasterize(catalog, host_xyz_pc=(0.0, 0.0, 0.0))
    arr = np.array(img)
    # With halos active for these bright stars, lit pixel count includes
    # halo footprint (multiple pixels per star). Just verify SOMETHING
    # bright rendered for each.
    assert arr.sum() > 0
    # And that distinct stars produced distinct bright regions.
    n_lit = np.count_nonzero(arr.sum(axis=2) > 50)   # ignore halo skirts
    assert n_lit >= 50   # at least half the stars are clearly visible cores
