"""Per-host 3-D position resolver for the per-vantage starfield endpoint.

Given an exoplanet's host star record, returns its heliocentric Cartesian
position in parsecs — the same frame the gaia_xyz.parquet catalog uses, so
the per-vantage starfield endpoint can do `star_xyz - host_xyz` to compute
each star's direction and distance from the host system.

Two resolution paths:

1. **Equatorial + distance** (primary). For hosts with `ra`, `dec`, and a
   distance (`sy_dist` from pscomppars, or `distance_gspphot_pc` from Gaia
   if available — Gaia parallax is generally tighter for solar-neighborhood
   hosts). This covers >99% of confirmed exoplanets.

2. **Galactic (l, b) + distance** (fallback for microlensing-bulge hosts).
   OGLE / MOA / KMTNet microlensing discoveries are often deep in the
   galactic bulge where Gaia astrometry is unreliable (parallax SNR too
   low). Those discovery papers report `(l, b, d)` natively, which we
   convert to ICRS Cartesian via the IAU 2009 galactic-to-ICRS rotation.
   This path is currently unused — `sy_dist` is present for nearly every
   exoplanet host — but it's wired in so we can ingest microlensing-paper
   distances later without touching this layer.

If neither resolution path has the inputs it needs, the resolver returns
`None`; the endpoint should respond with a 404 or fall back to the static
Earth-vantage texture.

Naming note: an earlier plan called this module `host_galactic_xyz.py`,
implying galactic-frame output. We actually return heliocentric ICRS to
match the Gaia catalog frame; the galactic frame is what the future
procedural Milky Way density model (Layer 2 in docs/STARFIELD_PLAN.md)
will need, not what Phase 2 reprojection needs.
"""

from __future__ import annotations

import math
from typing import Any

# IAU 2009 rotation matrix from galactic to ICRS Cartesian frame.
# Source: standard reference, equivalent to astropy.coordinates.Galactic
# → ICRS frame_transform_graph. Each row is the ICRS unit vector of the
# corresponding galactic axis: G_X (toward galactic center), G_Y (toward
# galactic rotation), G_Z (toward north galactic pole).
_GAL_TO_ICRS = (
    (-0.0548755604162154,  0.4941094278755837, -0.8676661490190047),
    (-0.8734370902348850, -0.4448296299600112, -0.1980763734312015),
    (-0.4838350155487132,  0.7469822444972189,  0.4559837761750669),
)


def equatorial_to_xyz_pc(ra_deg: float, dec_deg: float, distance_pc: float) -> tuple[float, float, float]:
    """Equatorial RA/Dec/distance → heliocentric ICRS Cartesian (parsecs).

    Same convention as `etl/build_gaia_xyz.py:equatorial_to_xyz` — the
    two are kept in sync because both write into the same coordinate
    frame. Sol is at (0, 0, 0); +X toward (RA=0, Dec=0); +Z toward
    Dec=+90° (north celestial pole).
    """
    ra_rad = math.radians(ra_deg)
    dec_rad = math.radians(dec_deg)
    cos_dec = math.cos(dec_rad)
    x = distance_pc * cos_dec * math.cos(ra_rad)
    y = distance_pc * cos_dec * math.sin(ra_rad)
    z = distance_pc * math.sin(dec_rad)
    return x, y, z


def galactic_to_xyz_pc(l_deg: float, b_deg: float, distance_pc: float) -> tuple[float, float, float]:
    """Galactic l/b/distance → heliocentric ICRS Cartesian (parsecs).

    Used for microlensing-bulge hosts where the discovery paper reports
    galactic coordinates + distance directly. We first convert to
    heliocentric galactic Cartesian, then rotate into the ICRS frame so
    the result is directly subtractable from gaia_xyz star positions.
    """
    l_rad = math.radians(l_deg)
    b_rad = math.radians(b_deg)
    cos_b = math.cos(b_rad)
    # Heliocentric galactic Cartesian (parsecs): +X toward GC, +Z toward NGP.
    xg = distance_pc * cos_b * math.cos(l_rad)
    yg = distance_pc * cos_b * math.sin(l_rad)
    zg = distance_pc * math.sin(b_rad)
    # Rotate into ICRS Cartesian.
    return galactic_to_icrs(xg, yg, zg)


def galactic_to_icrs(xg: float, yg: float, zg: float) -> tuple[float, float, float]:
    """Rotate a heliocentric galactic Cartesian point into ICRS Cartesian.

    Pure rotation — no translation, because both frames share the same
    heliocentric origin. Inverse rotation (ICRS → galactic) is the
    transpose of the matrix.
    """
    xi = _GAL_TO_ICRS[0][0] * xg + _GAL_TO_ICRS[0][1] * yg + _GAL_TO_ICRS[0][2] * zg
    yi = _GAL_TO_ICRS[1][0] * xg + _GAL_TO_ICRS[1][1] * yg + _GAL_TO_ICRS[1][2] * zg
    zi = _GAL_TO_ICRS[2][0] * xg + _GAL_TO_ICRS[2][1] * yg + _GAL_TO_ICRS[2][2] * zg
    return xi, yi, zi


def icrs_to_galactic(xi: float, yi: float, zi: float) -> tuple[float, float, float]:
    """Rotate a heliocentric ICRS Cartesian point into galactic Cartesian.

    Inverse of `galactic_to_icrs`. Provided for future Phase 3 work where
    the procedural Milky Way density model is naturally expressed in
    galactic coordinates.
    """
    # Inverse of a pure rotation matrix is its transpose.
    xg = _GAL_TO_ICRS[0][0] * xi + _GAL_TO_ICRS[1][0] * yi + _GAL_TO_ICRS[2][0] * zi
    yg = _GAL_TO_ICRS[0][1] * xi + _GAL_TO_ICRS[1][1] * yi + _GAL_TO_ICRS[2][1] * zi
    zg = _GAL_TO_ICRS[0][2] * xi + _GAL_TO_ICRS[1][2] * yi + _GAL_TO_ICRS[2][2] * zi
    return xg, yg, zg


def resolve_host_xyz(host_record: dict[str, Any]) -> tuple[float, float, float] | None:
    """Resolve a host's heliocentric ICRS Cartesian position (parsecs).

    Expected keys on `host_record` (any subset; the resolver picks the
    most accurate path it has the inputs for):

    - `ra` (deg), `dec` (deg), `sy_dist` (pc) — primary path
    - `ra` (deg), `dec` (deg), `distance_gspphot_pc` (pc) — Gaia-improved
      primary path (preferred over `sy_dist` when available, because
      Gaia DR3's photogeometric distances are typically tighter for
      nearby hosts than literature-aggregate `sy_dist` from pscomppars)
    - `galactic_l_deg`, `galactic_b_deg`, `discovery_distance_pc` —
      microlensing-bulge fallback path

    Returns `None` if none of the paths have the inputs they need.
    """
    ra = _get_float(host_record, "ra")
    dec = _get_float(host_record, "dec")

    # Prefer Gaia distance when available — typically tighter for nearby hosts.
    gaia_distance = _get_float(host_record, "distance_gspphot_pc")
    sy_distance = _get_float(host_record, "sy_dist")
    distance_pc = gaia_distance if gaia_distance is not None else sy_distance

    if ra is not None and dec is not None and distance_pc is not None and distance_pc > 0:
        return equatorial_to_xyz_pc(ra, dec, distance_pc)

    # Microlensing-bulge fallback. Discovery papers often report
    # distance in kpc, so accept either pc or kpc keys.
    l_deg = _get_float(host_record, "galactic_l_deg")
    b_deg = _get_float(host_record, "galactic_b_deg")
    bulge_distance_pc = _get_float(host_record, "discovery_distance_pc")
    bulge_distance_kpc = _get_float(host_record, "discovery_distance_kpc")
    if bulge_distance_pc is None and bulge_distance_kpc is not None:
        bulge_distance_pc = bulge_distance_kpc * 1000.0

    if l_deg is not None and b_deg is not None and bulge_distance_pc is not None and bulge_distance_pc > 0:
        return galactic_to_xyz_pc(l_deg, b_deg, bulge_distance_pc)

    return None


def _get_float(record: dict[str, Any], key: str) -> float | None:
    """Pull a numeric value out of the record, tolerating None / strings / missing."""
    value = record.get(key)
    if value is None:
        return None
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    return f if math.isfinite(f) else None
