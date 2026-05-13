"""Per-vantage starfield rasterization (Phase 2 of docs/STARFIELD_PLAN.md).

Pure rendering core. Given a Gaia XYZ catalog and a host's heliocentric
ICRS position, reprojects every catalog star into the host's reference
frame and rasterizes the resulting sky into an equirectangular RGB image.
No DB access in this module — the FastAPI endpoint in api/index.py is
responsible for looking up host data, calling this module, and emitting
the PNG response with appropriate caching headers.

Frame conventions (must match etl/build_gaia_xyz.py and api/host_xyz.py):
- All XYZ values are in PARSECS, heliocentric ICRS frame.
- Sol is at (0, 0, 0). +X toward (RA=0, Dec=0); +Z toward Dec=+90°.

The output texture has the same equirectangular UV convention used by the
frontend skydome sphere: u = (ra + π) / 2π (0 at RA=-π, 1 at RA=+π);
v = 1 - (dec + π/2) / π (0 at the north celestial pole, 1 at the south).
"""

from __future__ import annotations

import logging
from functools import lru_cache
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw, ImageFilter

log = logging.getLogger(__name__)

# Default output dimensions. The frontend skydome's sphereGeometry uses
# 64×32 segments which at this resolution gives ~0.09° angular resolution
# per texture pixel — slightly under naked-eye acuity.
DEFAULT_WIDTH = 4096
DEFAULT_HEIGHT = 2048

# Apparent G-magnitude cutoff for rendering. Naked-eye is mag 6 at a
# perfect dark site; we cut at 6.5 for a "real night sky" feel rather
# than a noise field. Each tighter step has visible payoff:
#   mag 12 (v0): ~300k stars — uniform polka-dot noise
#   mag 9.5    : ~80k stars  — still reads as noise
#   mag 6.5    : ~10k stars  — looks like a sky
DEFAULT_MAG_CUTOFF = 6.5

# Below this magnitude, stars get an additional halo overlay — the
# "naked-eye standouts" that give a sky visual variety against the dim
# majority. Mag 3 corresponds roughly to the brightest ~100 stars in
# the night sky (Sirius is -1, Vega is 0, Polaris is 2, etc.).
HALO_MAG_CUTOFF = 3.0

# Treat stars closer than this to the host as "the host itself" and drop
# them. 0.001 pc is ~200 AU — beyond any reasonable planet's orbit.
HOST_PROXIMITY_CUTOFF_PC = 0.001

# Canonical location of the catalog. The endpoint can override per env.
DEFAULT_CATALOG_PATH = Path("data/gaia_xyz.parquet")


@lru_cache(maxsize=1)
def load_catalog(path: str = str(DEFAULT_CATALOG_PATH)) -> pd.DataFrame:
    """Load the Gaia XYZ catalog. Cached for the process lifetime.

    The first request pays the parquet read (~100ms for 300k rows);
    subsequent requests get the in-memory DataFrame for free.
    """
    log.info("Loading Gaia XYZ catalog from %s ...", path)
    df = pd.read_parquet(path)
    log.info("  → %d stars in catalog", len(df))
    return df


def bprp_to_rgb(bp_rp: np.ndarray) -> np.ndarray:
    """Gaia BP-RP color index → normalized RGB. Vectorized.

    Mapping mirrors the buckets in web/src/pages/ScenePage.tsx::bpRpToRgb
    so server-rendered and client-rendered starfields visually agree.

    Returns: (N, 3) float32 array with values in [0, 1].
    """
    n = bp_rp.shape[0]
    rgb = np.empty((n, 3), dtype=np.float32)
    # Default (any unhandled value): generic warm white.
    rgb[:] = (1.00, 0.93, 0.75)

    # O/B
    mask = bp_rp < 0
    rgb[mask] = (0.62, 0.78, 1.00)
    # A
    mask = (bp_rp >= 0) & (bp_rp < 0.5)
    rgb[mask] = (0.86, 0.92, 1.00)
    # F/G — Sun-color
    mask = (bp_rp >= 0.5) & (bp_rp < 1.0)
    rgb[mask] = (1.00, 0.97, 0.85)
    # K
    mask = (bp_rp >= 1.0) & (bp_rp < 1.5)
    rgb[mask] = (1.00, 0.83, 0.60)
    # M
    mask = (bp_rp >= 1.5) & (bp_rp < 3.0)
    rgb[mask] = (1.00, 0.61, 0.42)
    # Late M / brown dwarf
    mask = bp_rp >= 3.0
    rgb[mask] = (0.81, 0.31, 0.25)

    return rgb


def rasterize_skytexture(
    catalog: pd.DataFrame,
    host_xyz_pc: tuple[float, float, float],
    width: int = DEFAULT_WIDTH,
    height: int = DEFAULT_HEIGHT,
    mag_cutoff: float = DEFAULT_MAG_CUTOFF,
) -> Image.Image:
    """Reproject the Gaia catalog from `host_xyz_pc` and rasterize an
    equirectangular sky texture.

    Args:
        catalog: DataFrame with columns x_pc, y_pc, z_pc, abs_g_mag, bp_rp
            in heliocentric ICRS. Sol is expected at row 0 at (0,0,0)
            so it appears as a real star from non-Sol vantages.
        host_xyz_pc: host's heliocentric ICRS position in parsecs.
        width, height: output image dimensions.
        mag_cutoff: stars with apparent G mag > cutoff are dropped.

    Returns:
        PIL.Image.Image in RGB mode, shape (height, width, 3).
    """
    # ── Compute star-from-host direction + distance (heliocentric ICRS) ───
    hx, hy, hz = host_xyz_pc
    dx = catalog["x_pc"].to_numpy() - hx
    dy = catalog["y_pc"].to_numpy() - hy
    dz = catalog["z_pc"].to_numpy() - hz
    d_pc = np.sqrt(dx * dx + dy * dy + dz * dz)

    # Drop the host star itself (and anything implausibly close to it).
    keep = d_pc > HOST_PROXIMITY_CUTOFF_PC
    dx, dy, dz, d_pc = dx[keep], dy[keep], dz[keep], d_pc[keep]
    abs_g = catalog["abs_g_mag"].to_numpy()[keep]
    bp_rp = catalog["bp_rp"].to_numpy()[keep]

    # ── Apparent magnitude from the new vantage; cull dim stars ───────────
    # m = M + 5 * log10(d_pc / 10)
    apparent = abs_g + 5.0 * np.log10(d_pc / 10.0)
    visible = apparent < mag_cutoff
    dx, dy, dz, d_pc = dx[visible], dy[visible], dz[visible], d_pc[visible]
    apparent = apparent[visible]
    bp_rp = bp_rp[visible]

    # ── Direction → RA/Dec from the host's perspective ────────────────────
    inv_d = 1.0 / d_pc
    ra = np.arctan2(dy * inv_d, dx * inv_d)                  # [-π, π]
    dec = np.arcsin(np.clip(dz * inv_d, -1.0, 1.0))          # [-π/2, π/2]

    # ── Equirectangular UV → FLOAT pixel coordinates (sub-pixel) ──────────
    u = (ra + np.pi) / (2.0 * np.pi)
    v = 1.0 - (dec + np.pi / 2.0) / np.pi
    px_f = u * width
    py_f = v * height

    # ── Per-star intensity from apparent magnitude ────────────────────────
    # Brightest stars saturate; dimmest fade toward black. Squared
    # falloff (not sqrt) is correct: a real magnitude scale is
    # logarithmic, so an apparent-mag-6 star truly is ~100x dimmer to
    # the eye than an apparent-mag-1 star. We want most stars on screen
    # to be barely visible "background" with a small population of
    # bright standouts, not a uniformly-lit field.
    intensity_linear = np.clip(1.0 - apparent / mag_cutoff, 0.0, 1.0)
    intensity = intensity_linear * intensity_linear

    # ── Color from bp_rp, scaled by intensity, no minimum floor ───────────
    # No floor: dim stars truly fade toward black. The whole point of
    # the visual is that the brightest few stand out.
    rgb = bprp_to_rgb(bp_rp)                                  # (N, 3) in [0, 1]
    color_u8 = (rgb * intensity[:, None] * 255).clip(0, 255).astype(np.uint8)

    # ── Rasterize: single-pixel writes per star, no global blur ───────────
    # Why no blur: the GPU's linear texture filtering on the frontend
    # already spreads each texture pixel across a few screen pixels.
    # Pre-blurring on the CPU compounded that into chunky 4-5 px blobs.
    # Keep the texture sharp; let the GPU's bilinear interpolation
    # produce the soft anti-aliased points.
    px_i = np.clip(px_f.astype(np.int32), 0, width - 1)
    py_i = np.clip(py_f.astype(np.int32), 0, height - 1)
    img_arr = np.zeros((height, width, 3), dtype=np.uint8)
    order = np.argsort(intensity)         # ascending → brightest written last
    img_arr[py_i[order], px_i[order]] = color_u8[order]
    pil = Image.fromarray(img_arr, mode="RGB")

    # ── Halo overlay for naked-eye-bright stars ───────────────────────────
    # The brightest few hundred get a soft radial halo drawn on top.
    # Layered onto a separate canvas, blurred, then additively composited.
    halo_mask = apparent < HALO_MAG_CUTOFF
    if halo_mask.any():
        halo_layer = Image.new("RGB", (width, height), (0, 0, 0))
        halo_draw = ImageDraw.Draw(halo_layer)
        halo_px = px_f[halo_mask]
        halo_py = py_f[halo_mask]
        halo_intensity = intensity[halo_mask]
        halo_color = color_u8[halo_mask]
        for i in range(len(halo_px)):
            halo_r = 3.0 + halo_intensity[i] * 6.0  # 3 px → 9 px
            x, y = float(halo_px[i]), float(halo_py[i])
            r = float(halo_r)
            c = (
                int(halo_color[i, 0] * 0.45),
                int(halo_color[i, 1] * 0.45),
                int(halo_color[i, 2] * 0.45),
            )
            halo_draw.ellipse([x - r, y - r, x + r, y + r], fill=c)
        halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(radius=2.5))
        pil_arr = np.asarray(pil, dtype=np.int16)
        halo_arr = np.asarray(halo_layer, dtype=np.int16)
        combined = np.clip(pil_arr + halo_arr, 0, 255).astype(np.uint8)
        pil = Image.fromarray(combined, mode="RGB")

    return pil


def render_png(
    catalog: pd.DataFrame,
    host_xyz_pc: tuple[float, float, float],
    *,
    width: int = DEFAULT_WIDTH,
    height: int = DEFAULT_HEIGHT,
    mag_cutoff: float = DEFAULT_MAG_CUTOFF,
) -> bytes:
    """Convenience wrapper: rasterize, encode as PNG, return bytes."""
    import io
    img = rasterize_skytexture(
        catalog=catalog,
        host_xyz_pc=host_xyz_pc,
        width=width,
        height=height,
        mag_cutoff=mag_cutoff,
    )
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=False)
    return buf.getvalue()
