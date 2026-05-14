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

# ── Diffuse galaxy (Phase 4) ─────────────────────────────────────────────
# The original plan compiled a GLSL fragment shader to do per-pixel line-
# of-sight integration through the procedural Milky Way density profiles
# at draw time. That worked on desktop but silently failed inside Quest 3 /
# @react-three/xr 6 multiview after five different shader iterations — the
# pattern matched the original VR-stars debugging session's lesson that
# there's a class of WebGL operations the headset rejects without error.
# Server-side rasterization sidesteps the whole problem: pre-bake the
# diffuse layer into the per-vantage PNG, ship it as part of a single
# textured sphere (which definitively works in VR). Costs ~300ms per
# cold cache-miss, cached forever after.
#
# Math mirrors the GLSL marchDiffuse + densityAt that briefly worked on
# desktop, so the resulting look is identical. Density profiles are
# the same Bland-Hawthorn & Gerhard 2016 parameters used by
# etl/build_galactic_particles.py (thin disk + thick disk + bulge; halo
# omitted as visually negligible from inside the galaxy).

# IAU 2009 galactic ↔ ICRS rotation. Must match etl/build_galactic_particles.py
# and api/host_xyz.py — column-vector convention helio_icrs = M @ helio_galactic.
_GAL_TO_ICRS = np.array([
    [-0.0548755604162154,  0.4941094278755837, -0.8676661490190047],
    [-0.8734370902348850, -0.4448296299600112, -0.1980763734312015],
    [-0.4838350155487132,  0.7469822444972189,  0.4559837761750669],
], dtype=np.float32)
# Sol's galactocentric position in galactic kpc.
_SOL_OFFSET_KPC = np.array([8.122, 0.0, 0.025], dtype=np.float32)

# Per-component relative weights (thin, thick, bulge). Bulge gets the heavy
# boost because the procedural density profiles aren't normalized across
# components — at any galactocentric radius the disk's per-kpc density is
# much higher than the bulge's, so equal weights would let the disk
# dominate even toward Sgr A*.
_COMP_WEIGHTS = np.array([1.0, 0.6, 8.0], dtype=np.float32)

# Master diffuse brightness in LINEAR light space (sRGB-decoded). The same
# 0.08 the GLSL used pre-pivot — composited via the proper linear-space
# add below so the visual result matches the desktop shader's calibration.
_DIFFUSE_GAIN = 0.08

# Log-spaced sample points for the line-of-sight integration in kpc.
# Identical to the manual unroll in the prior GLSL marchDiffuse:
#   t = T_MAX · (exp(u·K) - 1) / (e^K - 1)
# with T_MAX=30, K=3, STEPS=16, u=(i+0.5)/STEPS.
_DIFFUSE_T_STEPS = np.array([
    0.155, 0.510, 0.940, 1.458, 2.083, 2.836, 3.747, 4.844,
    6.168, 7.766, 9.694, 12.020, 14.824, 18.207, 22.288, 27.211,
], dtype=np.float32)

# Generate the diffuse pass at reduced resolution and upsample. The
# diffuse layer is a smooth function of direction — there's nothing
# above the Nyquist of 1024×512 to alias. Cuts gen time ~16×.
_DIFFUSE_GEN_WIDTH = 1024
_DIFFUSE_GEN_HEIGHT = 512

# Apparent G-magnitude cutoff for rendering. Maxed near the catalog's
# own limit (build_gaia_xyz default ~10). The aesthetic goal: pure
# pinpoint stars filling the absence of light — no glow, no halos,
# just many small colored dots. Density does the work.
DEFAULT_MAG_CUTOFF = 10.0

# Halo overlay disabled. Setting cutoff below the realistic-bright
# threshold (-2 ≈ Sun's brightness from very close) means no star
# in the catalog ever triggers the halo path. The bright stars are
# just bigger and brighter pinpoints, not blooming UI dots.
HALO_MAG_CUTOFF = -10.0

# Treat stars closer than this to the host as "the host itself" and drop
# them. 0.001 pc is ~200 AU — beyond any reasonable planet's orbit.
HOST_PROXIMITY_CUTOFF_PC = 0.001

# Catalog locations. Both parquets share the same schema; the endpoint
# concatenates them into one in-memory DataFrame.
DEFAULT_GAIA_PATH = Path("data/gaia_xyz.parquet")
DEFAULT_PARTICLES_PATH = Path("data/galactic_particles.parquet")
# Backward compat with the original Phase 2 API:
DEFAULT_CATALOG_PATH = DEFAULT_GAIA_PATH


@lru_cache(maxsize=1)
def load_catalog(
    gaia_path: str = str(DEFAULT_GAIA_PATH),
    particles_path: str = str(DEFAULT_PARTICLES_PATH),
) -> pd.DataFrame:
    """Load both star catalogs and concatenate into a single DataFrame.

    The two sources play complementary roles (see docs/STARFIELD_PLAN.md):
      - gaia_xyz.parquet: real Gaia DR3 stars in the solar neighborhood
        (~2 kpc), positions from measured parallax. Sol is row 0.
      - galactic_particles.parquet: procedurally-sampled Milky Way
        density (~1M particles) covering disk/bulge/halo out to ~30 kpc.
        Statistically matches galactic structure, doesn't correspond to
        named stars.

    The galactic-particles file is OPTIONAL; if missing (older deploys),
    we fall back to Gaia-only. This keeps the endpoint working through
    Phase 3 rollout without requiring the parquet be present everywhere
    on day one.

    Cached for the process lifetime — the first request pays the parquet
    read (~200ms for ~1.3M total rows); subsequent requests reuse the
    in-memory DataFrame.
    """
    log.info("Loading Gaia XYZ catalog from %s ...", gaia_path)
    gaia_df = pd.read_parquet(gaia_path)
    log.info("  → %d Gaia stars", len(gaia_df))

    particles_file = Path(particles_path)
    if not particles_file.exists():
        log.info("Galactic particle catalog not found at %s; using Gaia only", particles_path)
        return gaia_df

    log.info("Loading galactic-particle catalog from %s ...", particles_path)
    particles_df = pd.read_parquet(particles_path)
    log.info("  → %d procedural particles", len(particles_df))

    combined = pd.concat([gaia_df, particles_df], ignore_index=True)
    log.info("Combined catalog: %d total rows", len(combined))
    return combined


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


@lru_cache(maxsize=4)
def _direction_grid_galactic(width: int, height: int) -> np.ndarray:
    """Per-pixel galactic-frame unit direction for an equirectangular grid.

    The mapping is fixed by the equirectangular UV convention shared with
    the rasterizer (u = (ra+π)/(2π), v = 1-(dec+π/2)/π) and the IAU 2009
    ICRS → galactic rotation. Cached because only (width, height) matters.
    Returned shape: (H, W, 3) float32 galactic unit vectors.
    """
    u = (np.arange(width, dtype=np.float32) + 0.5) / width
    v = (np.arange(height, dtype=np.float32) + 0.5) / height
    ra = u * (2.0 * np.pi) - np.pi
    dec = (0.5 - v) * np.pi
    cos_dec = np.cos(dec)
    dx = (cos_dec[:, None] * np.cos(ra)[None, :]).astype(np.float32)
    dy = (cos_dec[:, None] * np.sin(ra)[None, :]).astype(np.float32)
    dz = np.broadcast_to(np.sin(dec)[:, None], (height, width)).astype(np.float32)
    dirs_icrs = np.stack([dx, dy, dz], axis=-1)
    # ICRS → galactic. Column-vector convention: d_gal = M^T · d_icrs.
    # For row-vector arrays: d_gal_row = d_icrs_row @ M, since
    # (M^T · v)^T = v^T · M.
    return dirs_icrs @ _GAL_TO_ICRS


def _host_galactocentric_kpc(host_xyz_pc: tuple[float, float, float]) -> np.ndarray:
    """Heliocentric ICRS pc → galactocentric galactic kpc.

    Inverse of etl/build_galactic_particles.py::galactocentric_to_heliocentric_icrs.
    """
    helio_icrs_kpc = np.array(host_xyz_pc, dtype=np.float32) / 1000.0
    helio_galactic_kpc = helio_icrs_kpc @ _GAL_TO_ICRS  # row-vector: v @ M = M^T · v^T
    return helio_galactic_kpc - _SOL_OFFSET_KPC


def _sech2(x: np.ndarray) -> np.ndarray:
    """sech²(x), branchless and overflow-safe. Matches the GLSL impl."""
    ax = np.minimum(np.abs(x), 10.0)
    e = np.exp(-ax)
    d = 1.0 + e * e
    return (4.0 * e * e / (d * d)).astype(np.float32)


def _density_at(p_kpc: np.ndarray) -> np.ndarray:
    """Procedural Milky Way density at galactocentric points.

    Args: p_kpc shape (..., 3) in galactocentric galactic kpc.
    Returns: shape (...) float32 weighted density (thin + thick + bulge).

    Density parameters match etl/build_galactic_particles.py sample_*:
      - thin disk : h_R=2.6, h_z=0.3 (1/h pre-multiplied as 0.3846, 3.333)
      - thick disk: h_R=2.0, h_z=0.9 (1/h pre-multiplied as 0.5,    1.111)
      - bulge     : exp(-r_eff/0.7) with triaxial axes (1.0, 0.4, 0.3)
                    → 1/ax pre-multiplied as (1.0, 2.5, 3.333)
    """
    R = np.sqrt(p_kpc[..., 0] ** 2 + p_kpc[..., 1] ** 2)
    az = np.abs(p_kpc[..., 2])
    thin = np.exp(-R * 0.3846153846, dtype=np.float32) * _sech2(az * 3.3333333)
    thick = np.exp(-R * 0.5, dtype=np.float32) * _sech2(az * 1.1111111)
    r_eff = np.sqrt(
        (p_kpc[..., 0]) ** 2
        + (p_kpc[..., 1] * 2.5) ** 2
        + (p_kpc[..., 2] * 3.3333333) ** 2
    )
    bulge = np.exp(-r_eff * 1.4285714, dtype=np.float32)
    return (
        thin * _COMP_WEIGHTS[0]
        + thick * _COMP_WEIGHTS[1]
        + bulge * _COMP_WEIGHTS[2]
    ).astype(np.float32)


def rasterize_diffuse_intensity(
    host_xyz_pc: tuple[float, float, float],
    width: int = _DIFFUSE_GEN_WIDTH,
    height: int = _DIFFUSE_GEN_HEIGHT,
) -> np.ndarray:
    """Per-pixel diffuse Milky Way emissivity (line-of-sight integral).

    Returns: (H, W) float32 in linear-light units, pre-gain. Caller
    multiplies by _DIFFUSE_GAIN and composites in linear space.
    """
    dirs_gal = _direction_grid_galactic(width, height)        # (H, W, 3)
    obs = _host_galactocentric_kpc(host_xyz_pc)               # (3,)
    intensity = np.zeros((height, width), dtype=np.float32)
    prev_t = 0.0
    for t_val in _DIFFUSE_T_STEPS:
        t = float(t_val)
        dt = t - prev_t
        # Broadcast (3,) obs + (H,W,3) * scalar → (H,W,3)
        p = obs + dirs_gal * t
        intensity += _density_at(p) * dt
        prev_t = t
    return intensity


def _srgb_to_linear(c: np.ndarray) -> np.ndarray:
    """sRGB display values in [0,1] → linear-light. IEC 61966-2-1."""
    threshold = 0.04045
    low = c / 12.92
    high = ((c + 0.055) / 1.055) ** 2.4
    return np.where(c <= threshold, low, high).astype(np.float32)


def _linear_to_srgb(c: np.ndarray) -> np.ndarray:
    """Linear-light → sRGB display values in [0,1]. IEC 61966-2-1."""
    c = np.clip(c, 0.0, None)
    threshold = 0.0031308
    low = c * 12.92
    high = 1.055 * (c ** (1.0 / 2.4)) - 0.055
    return np.where(c <= threshold, low, high).astype(np.float32)


def composite_diffuse_onto(
    star_pil: Image.Image,
    host_xyz_pc: tuple[float, float, float],
) -> Image.Image:
    """Add the diffuse galaxy layer to the star canvas in linear-light space.

    Generates the diffuse intensity at low resolution (smooth function →
    no aliasing), bilinearly upsamples to the star canvas size, decodes
    star sRGB → linear, adds gain × diffuse, re-encodes → sRGB.
    """
    width, height = star_pil.size
    diffuse_intensity = rasterize_diffuse_intensity(host_xyz_pc)        # (h_gen, w_gen)
    # Upsample to canvas size via PIL (LANCZOS for a smooth field). PIL
    # operates on uint8/float32 single-channel images; convert via numpy.
    diffuse_img = Image.fromarray(diffuse_intensity, mode="F")          # 32-bit float
    diffuse_img = diffuse_img.resize((width, height), Image.Resampling.LANCZOS)
    diffuse_full = np.asarray(diffuse_img, dtype=np.float32)            # (H, W)

    star_srgb = np.asarray(star_pil, dtype=np.float32) / 255.0          # (H, W, 3)
    star_linear = _srgb_to_linear(star_srgb)
    combined_linear = star_linear + (diffuse_full * _DIFFUSE_GAIN)[..., None]
    combined_srgb = _linear_to_srgb(combined_linear)
    combined_u8 = (np.clip(combined_srgb, 0.0, 1.0) * 255.0).astype(np.uint8)
    return Image.fromarray(combined_u8, mode="RGB")


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
    # Exponent 1.2: dims the faint end (apparent ~mag 7-10 near the cutoff)
    # without touching the bright end (apparent < 0 saturates at 1.0
    # regardless of exponent). The procedural galactic-particles catalog
    # adds ~half a million mag-7-to-10 stars to Sol's view that weren't in
    # Gaia-only; pushing this exponent up surgically thins that haze while
    # leaving SWEEPS-4 b's bright bulge giants (apparent ~-2 to 0) at full
    # brightness. Brightness at apparent mag 7 (intensity_linear = 0.3):
    #   ^0.5  : 0.548   — sqrt, "DRAMATIC"
    #   ^0.75 : 0.405   — previous, tuned for Sol-only Gaia density
    #   ^1.0  : 0.300   — linear
    #   ^1.2  : 0.236   — this, tuned for Gaia + procedural combined density
    intensity_linear = np.clip(1.0 - apparent / mag_cutoff, 0.0, 1.0)
    intensity = intensity_linear ** 1.2

    # ── Color from bp_rp, scaled by intensity, no minimum floor ───────────
    rgb = bprp_to_rgb(bp_rp)                                  # (N, 3) in [0, 1]
    color_u8 = (rgb * intensity[:, None] * 255).clip(0, 255).astype(np.uint8)

    # ── Rasterize: anti-aliased ellipse per star ──────────────────────────
    # PIL's ellipse fill at fractional coords gives sub-pixel anti-
    # aliasing for free — single-pixel writes look chunky on screen
    # because of GPU bilinear magnification, but a 0.6 px disc with
    # fractional center anti-aliases to a soft 2-pixel blob, exactly
    # what reads as "a star" on display. Brighter stars get bigger
    # discs proportional to intensity.
    pil = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(pil)
    order = np.argsort(intensity)         # ascending → brightest drawn last
    px_f_o = px_f[order]
    py_f_o = py_f[order]
    intensity_o = intensity[order]
    color_o = color_u8[order]
    for i in range(len(order)):
        # All-tiny: 0.25 px (microscopic) → 0.85 px (brightest is still
        # only ~1.5 px wide on screen after GPU filtering). Per user
        # feedback: more stars + smaller dots reads as "deep space" more
        # than fewer-bigger ones; halos are over-represented on stars
        # that wouldn't realistically appear as anything but pinpoints
        # to a human observer from light-years away.
        radius = 0.25 + intensity_o[i] * 0.6
        x, y = float(px_f_o[i]), float(py_f_o[i])
        r = float(radius)
        c = (int(color_o[i, 0]), int(color_o[i, 1]), int(color_o[i, 2]))
        draw.ellipse([x - r, y - r, x + r, y + r], fill=c)

    # ── Diffuse galaxy layer (Phase 4) ────────────────────────────────────
    # Composited in linear-light space so the additive math matches the
    # GLSL pipeline that worked on desktop. Done before the halo overlay
    # so naked-eye-bright halos shine through any bright bulge regions.
    pil = composite_diffuse_onto(pil, host_xyz_pc)

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
            # Smaller, dimmer halos than before. Only ~15 stars get
            # these; they're meant to be subtly-glowing standouts, not
            # blooming UI dots.
            halo_r = 2.0 + halo_intensity[i] * 3.0  # 2 px → 5 px
            x, y = float(halo_px[i]), float(halo_py[i])
            r = float(halo_r)
            c = (
                int(halo_color[i, 0] * 0.25),
                int(halo_color[i, 1] * 0.25),
                int(halo_color[i, 2] * 0.25),
            )
            halo_draw.ellipse([x - r, y - r, x + r, y + r], fill=c)
        halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(radius=2.0))
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
