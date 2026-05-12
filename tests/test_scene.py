"""Unit tests for api/scene.py — the scene_hints derivation contract.

Each test pins a specific astrophysics-side claim. If we change the math,
these have to change too — that's the point. The renderer is downstream of
these values; if they're wrong, every visualization is wrong.
"""

from __future__ import annotations

import pytest

from api.scene import (
    body_type_from_density,
    day_length_hours,
    death_seconds_estimate,
    derive_scene_hints,
    insolation_label,
    sun_angular_size_deg,
    teff_to_rgb_hex,
)

# ---------- sun color ------------------------------------------------------

def test_teff_solar_is_warm_white():
    """Sun (5778 K) should land near a warm white, not cold blue or fire-engine red."""
    color = teff_to_rgb_hex(5778)
    r, g, b = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
    assert r >= 250                       # near-saturated red channel
    assert 230 <= g <= 250                # full but not maxed
    assert 215 <= b <= 240                # slightly less than green → warm
    assert r >= g >= b                    # warm-leaning


def test_teff_red_dwarf_is_red():
    """A 3000 K M dwarf should be unambiguously red — green and blue both
    well below the saturated red channel."""
    color = teff_to_rgb_hex(3000)
    r, g, b = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
    assert r == 255
    assert g < 200
    assert b < r - 100   # red dominates blue by a wide margin


def test_teff_blue_giant_is_blue():
    """A 30000 K O-type star should be blue-white — blue channel maxed, less red."""
    color = teff_to_rgb_hex(30000)
    r, g, b = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
    assert b == 255
    assert r < g                          # red below green for hot stars


def test_teff_none_returns_neutral_default():
    assert teff_to_rgb_hex(None).startswith("#")
    assert teff_to_rgb_hex(0).startswith("#")


# ---------- angular size ---------------------------------------------------

def test_sun_from_earth_is_half_a_degree():
    """The Sun (1.0 R_sun) at 1 AU subtends ≈ 0.534°."""
    angle = sun_angular_size_deg(1.0, 1.0)
    assert angle == pytest.approx(0.534, abs=0.01)


def test_hot_jupiter_sun_dominates_sky():
    """WASP-12b: 0.023 AU from a 1.6 R_sun star → sun ≈ 36° across, ~70× the
    angular size of Earth's Sun. Not literally half the sky, but the dominant
    feature of it."""
    angle = sun_angular_size_deg(1.6, 0.023)
    assert 30 < angle < 45
    earth_sun = sun_angular_size_deg(1.0, 1.0)
    assert angle / earth_sun > 60   # at least 60× larger than Earth's Sun


def test_outer_planet_sun_is_small():
    """HR 8799b: 70 AU from a 1.4 R_sun star → sun is < 0.05°."""
    angle = sun_angular_size_deg(1.4, 70.0)
    assert angle < 0.05


def test_missing_inputs_return_none():
    assert sun_angular_size_deg(None, 1.0) is None
    assert sun_angular_size_deg(1.0, None) is None
    assert sun_angular_size_deg(1.0, 0) is None


# ---------- day length -----------------------------------------------------

def test_day_length_in_hours():
    assert day_length_hours(1.09) == pytest.approx(26.16)   # WASP-12b
    assert day_length_hours(365.25) == pytest.approx(8766)  # Earth-like
    assert day_length_hours(None) is None
    assert day_length_hours(0) is None


# ---------- body type ------------------------------------------------------

def test_body_type_density_dominates():
    """Density classification overrides radius when both present."""
    # Earth: 5.5 g/cc, 1 R⊕ → rocky
    assert body_type_from_density(5.5, 1.0) == "rocky"
    # Saturn: 0.69 g/cc, 9.4 R⊕ → gas giant by density
    assert body_type_from_density(0.69, 9.4) == "gas_giant"
    # Neptune-like: 1.6 g/cc → icy
    assert body_type_from_density(1.6, 4.0) == "icy"


def test_body_type_radius_fallback():
    assert body_type_from_density(None, 1.0) == "rocky"
    assert body_type_from_density(None, 3.0) == "icy"
    assert body_type_from_density(None, 11.0) == "gas_giant"


def test_body_type_uncertain():
    assert body_type_from_density(None, None) == "uncertain"


# ---------- death seconds --------------------------------------------------

def test_gas_giant_kills_immediately():
    """No surface to stand on; deep atmosphere crushes."""
    assert death_seconds_estimate(150, "gas_giant") == 1
    assert death_seconds_estimate(None, "gas_giant") == 1


def test_kelt9_class_is_seconds():
    """KELT-9b is ~4000 K equilibrium — instantly fatal."""
    assert death_seconds_estimate(4000, "rocky") == 2


def test_temperate_returns_none():
    """Earth-like equilibrium temp shouldn't be lethal on temperature alone."""
    assert death_seconds_estimate(280, "rocky") is None
    assert death_seconds_estimate(290, "icy") is None


def test_cryogenic_kills_quickly():
    assert death_seconds_estimate(50, "rocky") == 5


def test_missing_temp_returns_none_for_rocky():
    assert death_seconds_estimate(None, "rocky") is None


# ---------- insolation labels ----------------------------------------------

def test_insolation_label_buckets():
    assert insolation_label(1.0) == "comparable to Earth"
    assert insolation_label(0.05) == "dark"
    assert insolation_label(500) == "blinding (>100× Earth)"
    assert insolation_label(None) is None


# ---------- end-to-end -----------------------------------------------------

def test_derive_scene_hints_earth_analog():
    """Smoke test: an Earth-around-Sun stand-in produces sane values."""
    hints = derive_scene_hints({
        "st_teff": 5778, "st_rad": 1.0,
        "pl_orbsmax": 1.0, "pl_orbper": 365.25,
        "pl_insol": 1.0, "pl_eqt": 288, "pl_dens": 5.5, "pl_rade": 1.0,
    })
    assert hints["body_type"] == "rocky"
    assert hints["sun_angular_size_deg"] == pytest.approx(0.534, abs=0.01)
    assert hints["day_length_hours"] == pytest.approx(8766)
    assert hints["death_seconds"] is None
    assert hints["insolation_label"] == "comparable to Earth"


def test_derive_scene_hints_hot_jupiter():
    """WASP-12b stand-in: sun fills the sky, planet is gaseous, lethal."""
    hints = derive_scene_hints({
        "st_teff": 6300, "st_rad": 1.6,
        "pl_orbsmax": 0.023, "pl_orbper": 1.09,
        "pl_insol": 9000, "pl_eqt": 2580, "pl_dens": 0.4, "pl_rade": 19,
    })
    assert hints["body_type"] == "gas_giant"
    assert hints["sun_angular_size_deg"] > 30
    assert hints["death_seconds"] == 1   # gas-giant trumps temperature
    assert hints["insolation_label"] == "blinding (>100× Earth)"


def test_derive_scene_hints_handles_all_nulls():
    """NULL-heavy planet: should not crash, should return sensible defaults."""
    hints = derive_scene_hints({
        "st_teff": None, "st_rad": None,
        "pl_orbsmax": None, "pl_orbper": None,
        "pl_insol": None, "pl_eqt": None, "pl_dens": None, "pl_rade": None,
    })
    assert hints["body_type"] == "uncertain"
    assert hints["sun_color_hex"].startswith("#")   # fallback color, not crash
    assert hints["sun_angular_size_deg"] is None
    assert hints["death_seconds"] is None
