"""Procedural Milky Way density sampler — Phase 3 of docs/STARFIELD_PLAN.md.

Samples ~1M particles from the standard Galactic structure model
(Bland-Hawthorn & Gerhard 2016 review parameters) covering the four
main stellar components — thin disk, thick disk, bulge, halo. Each
particle gets a position, an absolute G magnitude, and a BP-RP color
sampled from per-component distributions, all stored in the same
heliocentric ICRS pc frame as `data/gaia_xyz.parquet` so the per-
vantage starfield endpoint can concatenate the two catalogs and
rasterize them together.

These particles aren't real stars from any catalog — they're a
procedurally-generated population that statistically matches the
Milky Way's bulk stellar density. The point is filling in the
"background" of unresolved galactic stars that any naked-eye sky
contains but no individual-star catalog (Gaia or otherwise) covers
well past the solar neighborhood. Together with Gaia (Phase 2)
they produce a sky that has both real recognizable nearby stars
AND the dense Milky-Way-band stellar density.

Output: `data/galactic_particles.parquet`. ~16 MB raw, ~6 MB on disk
with snappy compression. Schema identical to gaia_xyz.parquet:
  x_pc, y_pc, z_pc, abs_g_mag, bp_rp  (all float32)

Run (deterministic via --seed):
    python -m etl.build_galactic_particles
    python -m etl.build_galactic_particles --seed 7 --n-thin 500000
"""

from __future__ import annotations

import argparse
import logging
import math
from pathlib import Path

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# ── Sol's position in the galactocentric galactic frame (kpc) ──────────────
# IAU 2015 / GRAVITY Collaboration 2019: ~8.122 kpc from Sgr A*, slightly
# above the disk midplane. The Bland-Hawthorn & Gerhard 2016 review uses
# the same value as the modern consensus.
SOL_X_KPC = 8.122
SOL_Y_KPC = 0.0
SOL_Z_KPC = 0.025

# ── Galactic → ICRS Cartesian rotation matrix (IAU 2009) ──────────────────
# Same matrix as api/host_xyz._GAL_TO_ICRS — inlined here so etl/
# doesn't depend on api/. Source: standard reference, equivalent to
# astropy.coordinates.Galactic → ICRS frame_transform_graph.
_GAL_TO_ICRS = np.array([
    [-0.0548755604162154,  0.4941094278755837, -0.8676661490190047],
    [-0.8734370902348850, -0.4448296299600112, -0.1980763734312015],
    [-0.4838350155487132,  0.7469822444972189,  0.4559837761750669],
])


# ── Component samplers (galactocentric galactic XYZ in kpc) ───────────────

def sample_thin_disk(n: int, rng: np.random.Generator) -> np.ndarray:
    """Thin disk: exponential in R, sech² in z. h_R=2.6 kpc, h_z=300 pc."""
    h_R = 2.6
    h_z = 0.3
    R = -h_R * np.log(1.0 - rng.random(n))
    theta = rng.uniform(0.0, 2.0 * math.pi, n)
    # sech² vertical profile via inverse-CDF on arctanh.
    u = np.clip(rng.uniform(-1.0, 1.0, n), -0.999999, 0.999999)
    z = h_z * 2.0 * np.arctanh(u)
    return np.column_stack([R * np.cos(theta), R * np.sin(theta), z])


def sample_thick_disk(n: int, rng: np.random.Generator) -> np.ndarray:
    """Thick disk: same form as thin disk, h_R=2.0 kpc, h_z=900 pc.

    Older, less centrally concentrated, more vertically extended population.
    """
    h_R = 2.0
    h_z = 0.9
    R = -h_R * np.log(1.0 - rng.random(n))
    theta = rng.uniform(0.0, 2.0 * math.pi, n)
    u = np.clip(rng.uniform(-1.0, 1.0, n), -0.999999, 0.999999)
    z = h_z * 2.0 * np.arctanh(u)
    return np.column_stack([R * np.cos(theta), R * np.sin(theta), z])


def sample_bulge(n: int, rng: np.random.Generator) -> np.ndarray:
    """Bulge: triaxial Gaussian-modulated exponential, R_eff ≈ 700 pc.

    Density: ρ ∝ exp(-r_eff / 0.7 kpc) where
      r_eff = sqrt((x/1.0)² + (y/0.4)² + (z/0.3)²) in kpc.
    The y/z scale-down captures the bulge's bar-like shape (longer
    along the X axis toward the Sun than perpendicular). Real bulge
    sampling is more involved (boxy/peanut, integrated phase-space)
    but this captures the dominant geometry for visual purposes.
    """
    samples: list[np.ndarray] = []
    collected = 0
    box = 3.0   # bulge extends to ~2.5 kpc; sample within ±3
    a_x, a_y, a_z = 1.0, 0.4, 0.3
    while collected < n:
        batch = max(n * 4, 50_000)
        x = rng.uniform(-box, box, batch)
        y = rng.uniform(-box * a_y, box * a_y, batch)
        z = rng.uniform(-box * a_z, box * a_z, batch)
        r_eff = np.sqrt((x / a_x) ** 2 + (y / a_y) ** 2 + (z / a_z) ** 2)
        density = np.exp(-r_eff / 0.7)
        accept = rng.random(batch) < density
        ax = x[accept]
        ay = y[accept]
        az = z[accept]
        samples.append(np.column_stack([ax, ay, az]))
        collected += len(ax)
    return np.vstack(samples)[:n]


def sample_halo(n: int, rng: np.random.Generator) -> np.ndarray:
    """Halo: power-law density ρ ∝ r^-3.5. Sparse, extending to ~30 kpc.

    Drawn as r * unit-sphere direction. r is sampled from the radial
    cumulative distribution of 4πr² × r^-3.5, which is ∝ r^-1.5.
    Inverse-CDF on that gives r = r_min / (1 - u·k)² with appropriate k.
    """
    r_min = 1.0     # avoid the singular interior; halo doesn't start at r=0
    r_max = 30.0    # cuts off near the virial radius of the Galaxy
    k = 1.0 - (r_min / r_max) ** 0.5
    u = rng.random(n)
    r = r_min / (1.0 - u * k) ** 2

    theta = rng.uniform(0.0, 2.0 * math.pi, n)
    cos_phi = rng.uniform(-1.0, 1.0, n)
    sin_phi = np.sqrt(np.clip(1.0 - cos_phi * cos_phi, 0.0, 1.0))
    return np.column_stack([
        r * sin_phi * np.cos(theta),
        r * sin_phi * np.sin(theta),
        r * cos_phi,
    ])


# ── Per-component luminosity + color distributions ─────────────────────────

def sample_luminosity_and_color(
    n: int, component: str, rng: np.random.Generator,
) -> tuple[np.ndarray, np.ndarray]:
    """Per-component (abs_g_mag, bp_rp) drawn as a 3-population mixture.

    Real galactic populations are dominated visually by their LUMINOUS
    minority — red giants and supergiants outshine the main-sequence
    majority by 100–10,000×, so from any vantage more than ~1 kpc away
    those rare bright stars are what you see. A pure main-sequence
    gaussian (as in earlier iterations) leaves the sky empty from
    non-Sol vantages because no MS star is bright enough to reach mag 10
    from kpc distances. Mixture per component:

      - main_sequence: bulk of the count, dim
      - red giant:     ~10% of the count, M ≈ 0.5 (K/M giants)
      - supergiant:    rare, M ≈ -5 (cool red + hot blue tail)

    Fractions vary per component: bulge is giant-rich and old; thin
    disk has young blue supergiants; halo is mostly old MS with old
    horizontal-branch stars filling the giant slot.
    """
    if component == "thin":
        ms_mean, ms_sd = 5.0, 2.0
        ms_color_mean, ms_color_sd = 0.9, 0.4
        f_giant, f_super = 0.08, 0.005
    elif component == "thick":
        ms_mean, ms_sd = 4.5, 1.5
        ms_color_mean, ms_color_sd = 1.1, 0.3
        f_giant, f_super = 0.10, 0.001
    elif component == "bulge":
        # Bulge: very giant-rich (old population, lots of evolved stars).
        ms_mean, ms_sd = 4.0, 1.5
        ms_color_mean, ms_color_sd = 1.4, 0.3
        f_giant, f_super = 0.18, 0.002
    elif component == "halo":
        # Halo is old, mostly MS + horizontal-branch (modeled as giants).
        ms_mean, ms_sd = 5.5, 1.5
        ms_color_mean, ms_color_sd = 0.7, 0.3
        f_giant, f_super = 0.04, 0.0
    else:
        raise ValueError(f"Unknown component: {component!r}")

    n_super = int(round(n * f_super))
    n_giant = int(round(n * f_giant))
    n_ms = n - n_super - n_giant

    ms_mag = rng.normal(ms_mean, ms_sd, n_ms)
    giant_mag = rng.normal(0.5, 0.8, n_giant)            # red giant clump
    # Supergiants: bimodal — cool red supergiants + hot blue supergiants.
    n_red_super = n_super // 2
    n_blue_super = n_super - n_red_super
    red_super_mag = rng.normal(-5.0, 1.0, n_red_super)
    blue_super_mag = rng.normal(-5.5, 1.2, n_blue_super)

    ms_color = rng.normal(ms_color_mean, ms_color_sd, n_ms)
    giant_color = rng.normal(1.6, 0.3, n_giant)          # K/M giants are red
    red_super_color = rng.normal(1.8, 0.3, n_red_super)
    blue_super_color = rng.normal(-0.2, 0.2, n_blue_super)

    abs_mag = np.concatenate([
        ms_mag, giant_mag, red_super_mag, blue_super_mag,
    ]).astype(np.float32)
    bp_rp = np.concatenate([
        ms_color, giant_color, red_super_color, blue_super_color,
    ]).astype(np.float32)
    return abs_mag, bp_rp


# ── Frame conversion ───────────────────────────────────────────────────────

def galactocentric_to_heliocentric_icrs(xyz_kpc: np.ndarray) -> np.ndarray:
    """Galactocentric galactic XYZ (kpc) → heliocentric ICRS XYZ (pc).

    Frame conventions:
      Galactic (heliocentric): Sol at origin, +X toward galactic center,
                               +Z toward north galactic pole.
      Galactocentric: same axes, origin at galactic center.

    With +X pointing from Sol toward GC, Sol's galactocentric position
    is (-SOL_X_KPC, -SOL_Y_KPC, -SOL_Z_KPC) — Sol sits in the -X
    direction *from* the galactic center. Converting back to heliocentric
    galactic adds the (+SOL_X_KPC, ...) offset, NOT subtracts it.

    Three steps:
      1. Translate +(SOL_X_KPC, ...) → heliocentric galactic.
      2. Rotate galactic → ICRS via the IAU 2009 matrix.
      3. Convert kpc → pc (×1000).
    """
    helio_galactic_kpc = xyz_kpc + np.array([SOL_X_KPC, SOL_Y_KPC, SOL_Z_KPC])
    helio_icrs_kpc = helio_galactic_kpc @ _GAL_TO_ICRS.T
    return helio_icrs_kpc * 1000.0


# ── Driver ─────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build procedural Milky Way density catalog",
    )
    parser.add_argument("--seed", type=int, default=42,
                        help="RNG seed (deterministic; default 42)")
    parser.add_argument("--n-thin", type=int, default=600_000,
                        help="Thin disk particle count (default 600k)")
    parser.add_argument("--n-thick", type=int, default=150_000,
                        help="Thick disk particle count (default 150k)")
    parser.add_argument("--n-bulge", type=int, default=200_000,
                        help="Bulge particle count (default 200k)")
    parser.add_argument("--n-halo", type=int, default=50_000,
                        help="Halo particle count (default 50k)")
    parser.add_argument("--output", default="data/galactic_particles.parquet",
                        help="Output parquet path")
    args = parser.parse_args()

    rng = np.random.default_rng(args.seed)

    log.info("Sampling thin disk: %d particles", args.n_thin)
    thin_xyz = sample_thin_disk(args.n_thin, rng)
    thin_mag, thin_color = sample_luminosity_and_color(args.n_thin, "thin", rng)

    log.info("Sampling thick disk: %d particles", args.n_thick)
    thick_xyz = sample_thick_disk(args.n_thick, rng)
    thick_mag, thick_color = sample_luminosity_and_color(args.n_thick, "thick", rng)

    log.info("Sampling bulge: %d particles", args.n_bulge)
    bulge_xyz = sample_bulge(args.n_bulge, rng)
    bulge_mag, bulge_color = sample_luminosity_and_color(args.n_bulge, "bulge", rng)

    log.info("Sampling halo: %d particles", args.n_halo)
    halo_xyz = sample_halo(args.n_halo, rng)
    halo_mag, halo_color = sample_luminosity_and_color(args.n_halo, "halo", rng)

    xyz_kpc = np.vstack([thin_xyz, thick_xyz, bulge_xyz, halo_xyz])
    abs_mag = np.concatenate([thin_mag, thick_mag, bulge_mag, halo_mag])
    bp_rp = np.concatenate([thin_color, thick_color, bulge_color, halo_color])

    log.info("Converting %d particles to heliocentric ICRS pc...", len(xyz_kpc))
    xyz_pc = galactocentric_to_heliocentric_icrs(xyz_kpc)

    df = pd.DataFrame({
        "x_pc": xyz_pc[:, 0].astype(np.float32),
        "y_pc": xyz_pc[:, 1].astype(np.float32),
        "z_pc": xyz_pc[:, 2].astype(np.float32),
        "abs_g_mag": abs_mag,
        "bp_rp": bp_rp,
    })

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(out, compression="snappy", index=False)

    size_mb = out.stat().st_size / (1024 * 1024)
    log.info("Wrote %s — %.2f MB (%d rows)", out, size_mb, len(df))


if __name__ == "__main__":
    main()
