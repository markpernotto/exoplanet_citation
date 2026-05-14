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
import math
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

# Per-component LINEAR-LIGHT tints (R, G, B). Composited additively so the
# diffuse layer takes on a population-appropriate color. Chosen to roughly
# match the dominant stellar populations of each component (cf. the
# luminosity-and-color samplers in etl/build_galactic_particles.py):
#   - Thin disk : Sun-like G/F mix + young blue stars + HII → warm white.
#   - Thick disk: older redder F/K population → cream/tan.
#   - Bulge     : old K/M giant dominated → warm orange-red, the visible
#                 hallmark of bulge photos like the Sgr A* region.
# Values stay ≤1.0 in linear space so saturation only happens via the
# uDiffuseGain × density product at the top end (where it desaturates
# toward white — the standard linear-blending limitation, acceptable for v1).
_THIN_COLOR  = np.array([1.00, 0.95, 0.85], dtype=np.float32)
_THICK_COLOR = np.array([1.00, 0.80, 0.60], dtype=np.float32)
_BULGE_COLOR = np.array([1.00, 0.55, 0.30], dtype=np.float32)
# Young OB-association tint — the blue light a Milky Way photo gets from
# spiral-arm star-forming regions (Carina, Cygnus X, Orion Arm). Linear
# RGB with B > 1 so the channel saturates first and arms read clearly as
# blue-white rather than washing out to neutral against the warm thin disk.
_YOUNG_COLOR = np.array([0.55, 0.75, 1.05], dtype=np.float32)

# Logarithmic spiral arms — Milky-Way-ish 4-arm pattern with ~12° pitch
# (cot(12°) ≈ 4.70). At each radius the arm phase is
#   φ_arm(R) = (1/tan(p)) · ln(R/R_ref)
# so the 4-arm cos²(4·(φ-φ_arm)) modulation produces 4 narrow peaks per
# revolution that wind outward. The cos² gives sharper-than-sinusoidal
# arms; multiplied by the thin-disk density it concentrates the blue
# population where stars are actually being born today, not in the inter-
# arm regions. Halo radius _SPIRAL_R_REF anchors the spiral pattern at
# Sol's galactocentric radius so the local view matches Sun's Orion Spur.
_SPIRAL_COT_PITCH = 4.70
_SPIRAL_N_ARMS    = 4.0
_SPIRAL_R_REF_KPC = 8.0
# Relative brightness of the young population vs the underlying thin disk
# AT ARM PEAKS. The narrow-peak modulation drops to nearly zero in
# inter-arm gaps, so this peak value sets how much the arms stand out
# against the smooth warm disk. 1.0× keeps arms subtly visible — they
# tint the band cooler in clear stretches without dominating the look.
_YOUNG_REL_TO_THIN = 1.0

# Dust extinction. Real-world Milky Way: A_V ≈ 1.5 mag/kpc in the local
# midplane, which is τ ≈ 1.4 per kpc (A_V = 1.086 · τ). Cranking that all
# the way up would black out the galactic center from Sol's vantage — which
# is actually correct astrophysically (the visible bulge is invisible naked-
# eye through 8 kpc of disk dust), but kills the headline bulge view. We
# turn it down ~10× to a level that produces visible dust lanes through the
# plane without completely obscuring the bulge. Dust profile is an
# exponential disk like the stars but thinner (h_z = 100 pc — dust settles
# to the midplane more than stars), slightly more extended radially.
_DUST_OPACITY = 1.0           # τ per kpc at midplane × density-normalization
_DUST_H_R_KPC = 4.0           # dust radial scale length (kpc)
_DUST_H_Z_KPC = 0.1           # dust vertical scale height (kpc) — thinner than stars

# Extragalactic anchors (Phase 5 / Layer 4 of docs/STARFIELD_PLAN.md).
# Hand-curated catalog of the visually significant nearby galaxies — the
# ones a naked-eye observer would recognize. Per-anchor:
#   - ra_deg/dec_deg : ICRS, from SIMBAD / NED
#   - distance_pc    : Cepheid or TRGB measurement (best modern values)
#   - ang_size_deg   : major-axis angular size as seen from Sol
#   - linear_color   : population-appropriate tint (linear RGB)
#   - peak_intensity : Gaussian-peak brightness in linear-light units;
#                      tuned so naked-eye-mag-2 LMC dominates and
#                      naked-eye-mag-5 M33 is a faint smudge
# 3D positions are recomputed per host so bulge-vantage planets (where
# the 8-kpc displacement matters relative to ~24 kpc Sgr-DEG) see them
# in the correct direction. M31/M33 are far enough that the shift is
# subpixel.
_EXTRAGALACTIC_ANCHORS = [
    {
        "name": "LMC", "ra_deg": 80.894, "dec_deg": -69.756,
        "distance_pc": 49_970, "ang_size_deg": 10.0,
        "linear_color": (0.85, 0.92, 1.00),
        "peak_intensity": 0.30,
    },
    {
        "name": "SMC", "ra_deg": 13.158, "dec_deg": -72.800,
        "distance_pc": 62_440, "ang_size_deg": 5.0,
        "linear_color": (0.92, 0.95, 1.00),
        "peak_intensity": 0.18,
    },
    {
        "name": "M31", "ra_deg": 10.685, "dec_deg": 41.269,
        "distance_pc": 778_000, "ang_size_deg": 3.2,
        "linear_color": (0.95, 0.92, 0.85),
        "peak_intensity": 0.20,
    },
    {
        "name": "M33", "ra_deg": 23.462, "dec_deg": 30.660,
        "distance_pc": 840_000, "ang_size_deg": 1.2,
        "linear_color": (0.90, 0.95, 1.00),
        "peak_intensity": 0.08,
    },
    {
        "name": "SagDEG", "ra_deg": 283.838, "dec_deg": -30.545,
        "distance_pc": 24_000, "ang_size_deg": 7.0,
        "linear_color": (1.00, 0.75, 0.55),
        "peak_intensity": 0.05,
    },
]

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


def _dust_density(p_kpc: np.ndarray) -> np.ndarray:
    """Interstellar dust density (relative, unitless).

    Exponential disk model — same form as the thin stellar disk but with
    a thinner vertical scale height (dust settles further toward the
    midplane than stars). Args: p_kpc shape (..., 3). Returns: (...) float32.
    """
    R = np.sqrt(p_kpc[..., 0] ** 2 + p_kpc[..., 1] ** 2)
    az = np.abs(p_kpc[..., 2])
    return (
        np.exp(-R / _DUST_H_R_KPC, dtype=np.float32)
        * _sech2(az / _DUST_H_Z_KPC)
    ).astype(np.float32)


def _spiral_arm_strength(p_kpc: np.ndarray) -> np.ndarray:
    """4-arm logarithmic-spiral modulation in [0, 1].

    Peaks (≈1) along narrow arm centerlines, drops to ≈0 in inter-arm
    gaps. Power-4 makes the peaks narrower than a plain cos² so the arms
    read as discrete features rather than smooth azimuthal swells —
    important because LOS integration through the disk already blurs
    azimuthal structure, and we need the *raw* modulation to be sharp
    for arm features to survive averaging along the line of sight.
    R clamped at 0.5 kpc to avoid the log singularity at the galactic
    center (where arms aren't well-defined anyway).
    """
    R = np.sqrt(p_kpc[..., 0] ** 2 + p_kpc[..., 1] ** 2)
    phi = np.arctan2(p_kpc[..., 1], p_kpc[..., 0])
    log_R = np.log(np.maximum(R, 0.5) / _SPIRAL_R_REF_KPC)
    twist = _SPIRAL_COT_PITCH * log_R
    s = np.cos(_SPIRAL_N_ARMS * (phi - twist))
    return ((0.5 + 0.5 * s) ** 3).astype(np.float32)


def _component_densities(p_kpc: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Per-component density (thin, thick, bulge, young-spiral) at galactocentric points.

    Args: p_kpc shape (..., 3) in galactocentric galactic kpc.
    Returns: four (...) float32 arrays — thin, thick, bulge, young — each
    already multiplied by _COMP_WEIGHTS / spiral modulation so the caller
    can tint and sum directly.

    Parameters match etl/build_galactic_particles.py sample_*:
      - thin disk : h_R=2.6, h_z=0.3 (1/h pre-multiplied as 0.3846, 3.333)
      - thick disk: h_R=2.0, h_z=0.9 (1/h pre-multiplied as 0.5,    1.111)
      - bulge     : exp(-r_eff/0.7) with triaxial axes (1.0, 0.4, 0.3)
                    → 1/ax pre-multiplied as (1.0, 2.5, 3.333)
      - young     : thin × 4-arm spiral modulation × _YOUNG_REL_TO_THIN.
                    Captures the OB-association blue light that traces
                    Milky Way spiral arms in real photos.
    """
    R = np.sqrt(p_kpc[..., 0] ** 2 + p_kpc[..., 1] ** 2)
    az = np.abs(p_kpc[..., 2])
    thin = (
        np.exp(-R * 0.3846153846, dtype=np.float32)
        * _sech2(az * 3.3333333)
        * _COMP_WEIGHTS[0]
    )
    thick = (
        np.exp(-R * 0.5, dtype=np.float32)
        * _sech2(az * 1.1111111)
        * _COMP_WEIGHTS[1]
    )
    r_eff = np.sqrt(
        (p_kpc[..., 0]) ** 2
        + (p_kpc[..., 1] * 2.5) ** 2
        + (p_kpc[..., 2] * 3.3333333) ** 2
    )
    bulge = np.exp(-r_eff * 1.4285714, dtype=np.float32) * _COMP_WEIGHTS[2]
    young = thin * _spiral_arm_strength(p_kpc) * _YOUNG_REL_TO_THIN
    return (
        thin.astype(np.float32),
        thick.astype(np.float32),
        bulge.astype(np.float32),
        young.astype(np.float32),
    )


def rasterize_diffuse_rgb(
    host_xyz_pc: tuple[float, float, float],
    width: int = _DIFFUSE_GEN_WIDTH,
    height: int = _DIFFUSE_GEN_HEIGHT,
) -> np.ndarray:
    """Per-pixel diffuse Milky Way RGB emissivity (line-of-sight integral).

    Each component (thin disk / thick disk / bulge) is tinted with a
    population-appropriate linear-light color, then summed along the
    line of sight. Result is in linear-light units, pre-gain — the
    caller multiplies by _DIFFUSE_GAIN and composites onto the star
    canvas in linear space.

    Returns: (H, W, 3) float32.
    """
    dirs_gal = _direction_grid_galactic(width, height)        # (H, W, 3)
    obs = _host_galactocentric_kpc(host_xyz_pc)               # (3,)
    rgb = np.zeros((height, width, 3), dtype=np.float32)
    # Cumulative dust optical depth from observer outward, per pixel. Each
    # step accumulates dust column for that step's slice; emission at the
    # step is attenuated by exp(-tau) so dust between observer and the
    # emitter dims its contribution. Result: dark lanes through the plane
    # plus partial obscuration of the bulge by foreground disk dust —
    # the iconic Milky Way photo look.
    tau = np.zeros((height, width), dtype=np.float32)
    prev_t = 0.0
    for t_val in _DIFFUSE_T_STEPS:
        t = float(t_val)
        dt = t - prev_t
        p = obs + dirs_gal * t
        # Update optical depth before emission this step. Including this
        # step's dust in tau slightly overcounts (the emitter at point p
        # isn't attenuated by dust at p itself, only dust closer to the
        # observer), but the discretization smooths it out.
        tau += _dust_density(p) * (_DUST_OPACITY * dt)
        attenuation = np.exp(-tau)                            # (H, W)
        thin, thick, bulge, young = _component_densities(p)
        rgb[..., 0] += (
            thin * _THIN_COLOR[0]
            + thick * _THICK_COLOR[0]
            + bulge * _BULGE_COLOR[0]
            + young * _YOUNG_COLOR[0]
        ) * dt * attenuation
        rgb[..., 1] += (
            thin * _THIN_COLOR[1]
            + thick * _THICK_COLOR[1]
            + bulge * _BULGE_COLOR[1]
            + young * _YOUNG_COLOR[1]
        ) * dt * attenuation
        rgb[..., 2] += (
            thin * _THIN_COLOR[2]
            + thick * _THICK_COLOR[2]
            + bulge * _BULGE_COLOR[2]
            + young * _YOUNG_COLOR[2]
        ) * dt * attenuation
        prev_t = t
    return rgb


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


def composite_extragalactic_onto(
    star_pil: Image.Image,
    host_xyz_pc: tuple[float, float, float],
) -> Image.Image:
    """Paint LMC/SMC/M31/M33/SagDEG soft blobs at their per-vantage positions.

    Each anchor is reprojected to the host's frame (so a bulge-vantage
    planet sees Sgr-DEG in a noticeably different direction than Earth
    does — the dwarf is only ~24 kpc away). Anchor angular size scales
    with `dist_sol / dist_host`; physical size is fixed. Blob is a 2D
    Gaussian, with x-axis sigma stretched by 1/cos(dec) so the blob
    appears circular on the sphere despite equirectangular distortion.
    Composited additively in linear-light space, same convention as the
    diffuse layer; placed BEFORE the diffuse so our Milky Way's haze
    veils distant galaxies (cheap stand-in for atmospheric perspective).
    """
    width, height = star_pil.size
    hx, hy, hz = host_xyz_pc

    overlay = np.zeros((height, width, 3), dtype=np.float32)
    deg_per_px_x = 360.0 / width

    for anchor in _EXTRAGALACTIC_ANCHORS:
        ra_a = math.radians(anchor["ra_deg"])
        dec_a = math.radians(anchor["dec_deg"])
        cos_dec_a = math.cos(dec_a)
        d_sol = float(anchor["distance_pc"])
        ax = d_sol * cos_dec_a * math.cos(ra_a)
        ay = d_sol * cos_dec_a * math.sin(ra_a)
        az = d_sol * math.sin(dec_a)

        dx, dy, dz = ax - hx, ay - hy, az - hz
        d_host = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d_host < 1.0:
            continue  # host is inside the anchor (don't render)

        ra_h = math.atan2(dy, dx)
        dec_h = math.asin(max(-1.0, min(1.0, dz / d_host)))
        u = (ra_h + math.pi) / (2.0 * math.pi)
        v = 1.0 - (dec_h + math.pi / 2.0) / math.pi
        cx_px = u * width
        cy_px = v * height

        # Apparent angular size scales inversely with distance.
        ang_size_deg = anchor["ang_size_deg"] * (d_sol / d_host)
        # FWHM ≈ angular size; sigma = FWHM / 2.355.
        sigma_y_px = ang_size_deg / deg_per_px_x / 2.355
        # cos(dec) stretch keeps the blob looking circular on the sphere.
        sigma_x_px = sigma_y_px / max(0.05, math.cos(dec_h))

        radius_x = max(2, int(3 * sigma_x_px))
        radius_y = max(2, int(3 * sigma_y_px))
        x0 = max(0, int(cx_px) - radius_x)
        x1 = min(width, int(cx_px) + radius_x + 1)
        y0 = max(0, int(cy_px) - radius_y)
        y1 = min(height, int(cy_px) + radius_y + 1)
        if x0 >= x1 or y0 >= y1:
            continue

        xs = np.arange(x0, x1, dtype=np.float32)
        ys = np.arange(y0, y1, dtype=np.float32)
        xx, yy = np.meshgrid(xs, ys)
        gauss = np.exp(
            -0.5 * (
                ((xx - cx_px) / sigma_x_px) ** 2
                + ((yy - cy_px) / sigma_y_px) ** 2
            )
        ).astype(np.float32)
        gauss *= float(anchor["peak_intensity"])
        cr, cg, cb = anchor["linear_color"]
        overlay[y0:y1, x0:x1, 0] += gauss * cr
        overlay[y0:y1, x0:x1, 1] += gauss * cg
        overlay[y0:y1, x0:x1, 2] += gauss * cb

    star_srgb = np.asarray(star_pil, dtype=np.float32) / 255.0
    star_linear = _srgb_to_linear(star_srgb)
    combined_linear = star_linear + overlay
    combined_srgb = _linear_to_srgb(combined_linear)
    combined_u8 = (np.clip(combined_srgb, 0.0, 1.0) * 255.0).astype(np.uint8)
    return Image.fromarray(combined_u8, mode="RGB")


def composite_diffuse_onto(
    star_pil: Image.Image,
    host_xyz_pc: tuple[float, float, float],
) -> Image.Image:
    """Add the diffuse galaxy layer to the star canvas in linear-light space.

    Generates the diffuse RGB at low resolution (smooth function → no
    aliasing), bilinearly upsamples to the star canvas size, decodes
    star sRGB → linear, adds gain × diffuse, re-encodes → sRGB.
    """
    width, height = star_pil.size
    diffuse_rgb = rasterize_diffuse_rgb(host_xyz_pc)                    # (h_gen, w_gen, 3)
    # Upsample. PIL's float-image resize handles one channel at a time,
    # so split-resize-stack each channel. Three single-channel LANCZOS
    # resizes is still cheaper than a single RGB resize at the larger
    # output size and avoids any byte-range clamping (intensity > 1.0
    # values must survive the upsample to stay in linear-light).
    channels_up: list[np.ndarray] = []
    for c in range(3):
        ch_img = Image.fromarray(diffuse_rgb[..., c], mode="F")
        ch_img = ch_img.resize((width, height), Image.Resampling.LANCZOS)
        channels_up.append(np.asarray(ch_img, dtype=np.float32))
    diffuse_full = np.stack(channels_up, axis=-1)                       # (H, W, 3)

    star_srgb = np.asarray(star_pil, dtype=np.float32) / 255.0
    star_linear = _srgb_to_linear(star_srgb)
    combined_linear = star_linear + diffuse_full * _DIFFUSE_GAIN
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

    # ── Extragalactic anchors (Phase 5, Layer 4) ─────────────────────────
    # Placed before the diffuse so our own Milky Way's haze veils distant
    # galaxies (cheap atmospheric-perspective stand-in).
    pil = composite_extragalactic_onto(pil, host_xyz_pc)

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
