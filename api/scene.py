"""Pure derivation functions for VR-scene hints.

No DB access here — everything in this module is a function from measured
exoplanet/host-star properties to a single scene parameter (color, angle,
classification, etc.). Keeps the rendering contract testable in isolation
from the API layer.

Maps directly to the `scene_hints` block defined in vr-experience-plan.md.
"""

from __future__ import annotations

import math

# Physical constants (IAU 2015 nominal where applicable)
SOLAR_RADIUS_M = 6.957e8
AU_M           = 1.495978707e11
SUN_TEFF_K     = 5778


def teff_to_rgb_hex(teff_k: float | None) -> str:
    """Blackbody-to-sRGB approximation (Tanner Helland's piecewise fit).

    Used to color the host-star sphere. Returns "#RRGGBB". Defaults to a
    Sun-yellow if Teff is unknown (we don't pretend to know the color).
    """
    if teff_k is None or teff_k <= 0:
        return "#fff4ea"   # ≈ 5778 K Sun-color, marked as the "unknown" fallback
    t = teff_k / 100.0

    if t <= 66:
        r = 255.0
    else:
        r = 329.698727446 * ((t - 60) ** -0.1332047592)

    if t <= 66:
        g = 99.4708025861 * math.log(t) - 161.1195681661
    else:
        g = 288.1221695283 * ((t - 60) ** -0.0755148492)

    if t >= 66:
        b = 255.0
    elif t <= 19:
        b = 0.0
    else:
        b = 138.5177312231 * math.log(t - 10) - 305.0447927307

    def clamp(v: float) -> int:
        return max(0, min(255, int(round(v))))

    return f"#{clamp(r):02x}{clamp(g):02x}{clamp(b):02x}"


def sun_angular_size_deg(st_rad_solar: float | None, pl_orbsmax_au: float | None) -> float | None:
    """Angular diameter of the host star as seen from the planet, in degrees.

    Earth's Sun: 0.534°. Hot Jupiters can exceed 70° (sun fills the sky).
    """
    if st_rad_solar is None or pl_orbsmax_au is None or pl_orbsmax_au <= 0:
        return None
    physical_radius_m = st_rad_solar * SOLAR_RADIUS_M
    distance_m        = pl_orbsmax_au * AU_M
    return math.degrees(2.0 * math.atan(physical_radius_m / distance_m))


def day_length_hours(pl_orbper_days: float | None) -> float | None:
    """Approximate sidereal day length in hours.

    Caveat: we don't know rotation periods for almost any exoplanet. We
    return the *orbital* period in hours as a stand-in — accurate for
    tidally-locked close-in worlds (most hot Jupiters, the inner rocky
    planets of M dwarfs), an unknown overestimate for everything else.
    The renderer is responsible for surfacing the assumption to users.
    """
    if pl_orbper_days is None or pl_orbper_days <= 0:
        return None
    return pl_orbper_days * 24.0


def body_type_from_density(pl_dens_gcc: float | None, pl_rade_earth: float | None) -> str:
    """Gross body classification: 'rocky' | 'icy' | 'gas_giant' | 'uncertain'.

    Mirrors the 2D taxonomy in docs/PROCEDURAL_RENDERING.md.
    Density (when present) is the dominant signal; radius is a fallback.
    """
    if pl_dens_gcc is not None:
        if pl_dens_gcc >= 4.0:
            return "rocky"
        if pl_dens_gcc >= 1.5:
            return "icy"
        return "gas_giant"
    if pl_rade_earth is not None:
        if pl_rade_earth < 1.6:
            return "rocky"
        if pl_rade_earth < 4.0:
            return "icy"
        return "gas_giant"
    return "uncertain"


def death_seconds_estimate(pl_eqt_k: float | None, body_type: str) -> int | None:
    """Crude survival-without-suit estimate. Order-of-magnitude only.

    Pressure is unknown for nearly every planet, so we assume ~1 bar Earth-like
    and let equilibrium temperature dominate. Gas giants have no surface — you'd
    be in deep, opaque atmosphere getting compressed; we hardcode a token "1
    second" for those rather than pretend to model the descent.
    """
    if body_type == "gas_giant":
        return 1
    if pl_eqt_k is None:
        return None
    if pl_eqt_k > 600:
        return 2       # skin chars instantly
    if pl_eqt_k > 400:
        return 30      # severe burn in seconds
    if pl_eqt_k > 320:
        return 600     # heat exhaustion within ten minutes
    if pl_eqt_k >= 273:
        return None    # not lethal on temperature alone
    if pl_eqt_k > 200:
        return 1800    # half-hour from cold
    if pl_eqt_k > 100:
        return 60      # cold death within a minute
    return 5           # cryogenic — frostbite shock immediate


def insolation_label(pl_insol_earth: float | None) -> str | None:
    """Single-line text label for daytime brightness vs Earth's noon."""
    if pl_insol_earth is None:
        return None
    if pl_insol_earth > 100:
        return "blinding (>100× Earth)"
    if pl_insol_earth > 10:
        return "intensely bright"
    if pl_insol_earth > 2:
        return "much brighter than Earth"
    if pl_insol_earth > 0.5:
        return "comparable to Earth"
    if pl_insol_earth > 0.1:
        return "dim"
    return "dark"


def derive_scene_hints(planet: dict) -> dict:
    """Compose all scene_hints from a planet detail dict.

    Expected planet keys (any may be None): st_teff, st_rad, pl_orbsmax,
    pl_orbper, pl_insol, pl_eqt, pl_dens, pl_rade.
    """
    body_type = body_type_from_density(planet.get("pl_dens"), planet.get("pl_rade"))
    return {
        "sun_color_hex":             teff_to_rgb_hex(planet.get("st_teff")),
        "sun_angular_size_deg":      sun_angular_size_deg(planet.get("st_rad"),
                                                          planet.get("pl_orbsmax")),
        "day_length_hours":          day_length_hours(planet.get("pl_orbper")),
        "insolation_relative_earth": planet.get("pl_insol"),
        "insolation_label":          insolation_label(planet.get("pl_insol")),
        "body_type":                 body_type,
        "death_seconds":             death_seconds_estimate(planet.get("pl_eqt"), body_type),
    }
