"""Seed binary_companions with the inner (P-type-defining) binaries from the cb_flag audit.

The cb_flag audit (docs/cb_flag_audit.md) hand-harvested inner-binary parameters
from each circumbinary planet's discovery abstract. The wide-binary SIMBAD/WDS ETL
(enrich_binaries.py) cannot see these tight/spectroscopic/eclipsing pairs, so they
are curated here and written with source_catalog='manual', inner_binary=TRUE.

Hierarchical notation: each inner secondary is component 'Ab' orbiting primary 'Aa',
which avoids colliding with the existing wide-companion rows ('B','C',...) and is the
correct designation for a tight pair that hosts a circumbinary planet.

Only values actually stated (or, where noted, derived/from-literature) are filled;
everything else is left NULL for a later deeper-dive pass. The `notes` field records
provenance and which numbers still need sourcing.

Requires migrations 007 and 011.

Safeguards (this script can write to the DB, so they matter):
  * Dry-run is the DEFAULT; only --execute writes. The dry-run prints every row
    and every deletion first.
  * Deletions are restricted to source_catalog = 'SIMBAD' AND a hardcoded
    SPURIOUS_DELETIONS allowlist, so a curated 'manual' row can never be removed.
  * Upserts are idempotent (ON CONFLICT DO UPDATE on the same curated rows), so
    re-running --execute is safe and non-destructive.

Run:
  python -m etl.seed_inner_binaries              # dry-run (default): print plan, write nothing
  python -m etl.seed_inner_binaries --execute    # apply to DATABASE_URL (read from .env)
"""

from __future__ import annotations

import argparse
import os

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()

# Each dict is one inner-binary row. Keys map to binary_companions columns.
# Absent keys are written as NULL. `mass_min` -> component_mass_is_min.
# Masses in M_sun, radii in R_sun, periods in days, separation in AU, Teff in K.
INNER_BINARIES: list[dict] = [
    # ---- fully characterized (component masses + radii + period + e) ----------
    {
        "hostname": "Kepler-38", "binary_class": "main-sequence EB (evolved primary)",
        "orbital_period_d": 18.8, "eccentricity": 0.103,
        "primary_mass_msun": 0.949, "primary_radius_rsun": 1.757, "primary_spectype": "main-sequence",
        "component_mass_msun": 0.249, "component_radius_rsun": 0.2724,
        "source_bibcode": "2012ApJ...758...87O",
        "notes": "Orosz+ 2012. Primary moderately evolved (inflated radius). Single-lined EB.",
    },
    {
        "hostname": "Kepler-413", "binary_class": "K+M eclipsing binary",
        "orbital_period_d": 10.11615, "eccentricity": 0.037, "inclination_deg": 87.33,
        "primary_mass_msun": 0.820, "primary_radius_rsun": 0.776, "primary_spectype": "K",
        "component_mass_msun": 0.542, "component_radius_rsun": 0.484, "component_spectype": "M",
        "source_bibcode": "2014ApJ...784...14K",
        "notes": "Kostov+ 2014 (KIC 12351927). Planet orbit ~2.5 deg misaligned; ~11 yr precession.",
    },
    {
        "hostname": "TIC 172900988 Aa", "binary_class": "main-sequence EB",
        "orbital_period_d": 19.7, "eccentricity": 0.45,
        "primary_mass_msun": 1.2384, "primary_radius_rsun": 1.3827,
        "component_mass_msun": 1.2019, "component_radius_rsun": 1.3124,
        "source_bibcode": "2021AJ....162..234K",
        "notes": "Kostov+ 2021. Planet transited both stars 5 d apart. High-precision photodynamical masses/radii.",
    },
    {
        "hostname": "PH1", "binary_class": "F+M eclipsing binary",
        "orbital_period_d": 20.0,
        "primary_mass_msun": 1.528, "primary_radius_rsun": 1.734, "primary_spectype": "F",
        "component_mass_msun": 0.408, "component_radius_rsun": 0.378, "component_spectype": "M",
        "source_bibcode": "2013ApJ...768..127S",
        "notes": "Schwamb+ 2013 (Kepler-64). Inner eclipsing pair Aa+Ab. System is a 2+2 quadruple; "
                 "a wide ~1000 AU visual binary also exists (not yet rowed). Binary period ~20 d (approx).",
    },
    # ---- masses (+ period / e where given) ------------------------------------
    {
        "hostname": "BEBOP-4 A", "binary_class": "main-sequence EB",
        "orbital_period_d": 72.0, "eccentricity": 0.27,
        "primary_mass_msun": 1.51, "component_mass_msun": 0.46,
        "source_bibcode": "2025MNRAS.544.2180T",
        "notes": "Triaud+ 2025. Longest-period binary in the BEBOP survey.",
    },
    {
        "hostname": "Kepler-16", "binary_class": "K+M eclipsing binary",
        "orbital_period_d": 41.0,
        "primary_mass_msun": 0.69, "primary_spectype": "K",
        "component_mass_msun": 0.20, "component_spectype": "M",
        "source_bibcode": "2011Sci...333.1602D",
        "notes": "Doyle+ 2011. Eccentric (e not given numerically in abstract). Coplanar to <0.5 deg. Spectypes inferred from mass.",
    },
    {
        "hostname": "Kepler-1661", "binary_class": "K+M eclipsing binary (single-lined, grazing)",
        "orbital_period_d": 28.2, "eccentricity": 0.11,
        "primary_mass_msun": 0.84, "component_mass_msun": 0.26,
        "source_bibcode": "2020AJ....159...94S",
        "notes": "Socia+ 2020. Single-lined grazing EB; significant starspot modulation. Age ~1-3 Gyr.",
    },
    {
        "hostname": "Kepler-453", "binary_class": "main-sequence EB",
        "orbital_period_d": 27.32,
        "primary_mass_msun": 0.94, "component_mass_msun": 0.195,
        "source_bibcode": "2015ApJ...809...26W",
        "notes": "Welsh+ 2015. Component radii not in abstract. ~103 yr precession; transits visible ~8.9% of the time.",
    },
    {
        "hostname": "Kepler-35", "binary_class": "G+G eclipsing binary",
        "primary_mass_msun": 0.8877, "component_mass_msun": 0.8094,
        "source_bibcode": "2012Natur.481..475W",
        "notes": "Welsh+ 2012. Masses are the abstract's 89% and 81% of solar. Binary period not given in abstract; deeper dive needed.",
    },
    {
        "hostname": "TOI-1338 A", "binary_class": "G+M eclipsing binary",
        "orbital_period_d": 14.6, "eccentricity": 0.16,
        "primary_mass_msun": 1.1, "component_mass_msun": 0.3,
        "source_bibcode": "2020AJ....159..253K",
        "notes": "Kostov+ 2020 (BEBOP-1). Component radii not in abstract; deeper dive needed.",
    },
    {
        "hostname": "OGLE-2007-BLG-349L A", "binary_class": "M-dwarf pair",
        "primary_mass_msun": 0.41, "component_mass_msun": 0.30,
        "source_bibcode": "2016AJ....152..125B",
        "notes": "Bennett+ 2016. Microlensing + HST. Total ~0.71 M_sun corroborated by parallax. Lowest-mass CBP system at discovery.",
    },
    {
        "hostname": "OGLE-2023-BLG-0836L", "binary_class": "K/M-dwarf pair",
        "primary_mass_msun": 0.71, "component_mass_msun": 0.56,
        "source_bibcode": "2024A&A...685A..16H",
        "notes": "Han+ 2024. Microlensing, triple-lens 'imperative'. P-vs-S not explicitly stated in abstract; projected separations not harvested.",
    },
    {
        "hostname": "KMT-2016-BLG-1337L", "binary_class": "M-dwarf pair",
        "separation_au": 3.5,
        "primary_mass_msun": 0.54, "component_mass_msun": 0.40,
        "source_bibcode": "2026PASP..138c4401H",
        "notes": "Han+ 2026. Microlensing; separation is projected. AMBIGUOUS cb_flag (two 3L1S solutions, neither clearly P-type).",
    },
    {
        "hostname": "OGLE-2018-BLG-1700L", "binary_class": "M-dwarf pair (model-dependent)",
        "primary_mass_msun": 0.42, "component_mass_msun": 0.12,
        "source_bibcode": "2020AJ....159...48H",
        "notes": "Han+ 2020. Best-fit masses; AMBIGUOUS cb_flag (wide solution is S-type, close solution P-type, 50/50).",
    },
    {
        "hostname": "OGLE-2019-BLG-1470L A", "binary_class": "M-dwarf pair (model-dependent)",
        "separation_au": 1.3,
        "primary_mass_msun": 0.57, "component_mass_msun": 0.18,
        "source_bibcode": "2022MNRAS.516.1704K",
        "notes": "Kuang+ 2022. Best-fit 3L1S; AMBIGUOUS cb_flag (2L2S single-host alternative disfavoured by only chi^2~18).",
    },
    {
        "hostname": "HD 284149 A", "binary_class": "M-dwarf companion",
        "separation_arcsec": 0.1, "separation_au": 12.0,
        "component_mass_msun": 0.16,
        "source_bibcode": "2017A&A...608A.106B",
        "notes": "Bonavita+ 2017. Inner companion found via SPHERE + Gaia-Tycho proper-motion residuals. Outer 'b' is a wide BD at 431 AU.",
    },
    {
        "hostname": "HD 202206", "binary_class": "star + brown dwarf",
        "separation_au": 0.83, "orbital_period_d": 256.0, "eccentricity": 0.43,
        "primary_spectype": "G (solar-type)",
        "component_mass_msun": 0.0166, "component_mass_is_min": False,
        "source_bibcode": "2005A&A...440..751C",
        "notes": "Correia+ 2005 + Benedict+ 2017 (HST FGS). Inner companion HD 202206 b is a brown dwarf (~17.4 Mjup = ~0.0166 Msun "
                 "true mass per astrometry). Period ~256 d. The cb_flag planet (c) orbits the star+BD pair.",
    },
    {
        "hostname": "WISPIT 1", "binary_class": "K+M binary",
        "primary_spectype": "K4", "component_spectype": "M5.5",
        "source_bibcode": "2025A&A...704A.221V",
        "notes": "van Capelleveen+ 2025. Multi-decadal orbit (implies separation ~10-20 AU); component masses not given numerically. Deeper dive needed.",
    },
    {
        "hostname": "DP Leo", "binary_class": "WD+dM (eclipsing polar)",
        "orbital_period_d": 0.062362,
        "source_bibcode": "2010ApJ...708L..66Q",
        "notes": "Qian+ 2010. Total binary mass 0.69 Msun (components not split in abstract). P_orb = 1.4967 h. Deeper dive for WD/dM masses.",
    },
    {
        "hostname": "NN Ser", "binary_class": "PCEB (WD+dM)",
        "primary_mass_msun": 0.5, "component_mass_msun": 0.13,
        "source_bibcode": "2010A&A...521L..60B",
        "notes": "Beuermann+ 2010. Component masses are approximate (M_total ~0.63-0.66 Msun derived from the planets). "
                 "Progenitor was an A star ~2 Msun at ~1.5 AU. Precise masses need the eclipse-modeling literature.",
    },
    {
        "hostname": "NY Vir", "binary_class": "sdB+dM (eclipsing, HW Vir-type)",
        "orbital_period_d": 0.101016, "inclination_deg": 81,
        "primary_mass_msun": 0.466, "primary_teff_k": 33000, "primary_spectype": "sdB",
        "component_mass_msun": 0.122, "component_teff_k": 3000, "component_spectype": "M (fully convective)",
        "source_bibcode": "2007A&A...471..605V",
        "notes": "Inner-binary params from Vuckovic et al. 2007 (PG 1336-018): sdB 0.466 Msun (T 33000 K), M-dwarf ~0.122 Msun (T 3000 K), i=81 deg, P_orb 2.4 h. sdB mass solutions non-unique (0.389-0.466 Msun families); confirm dM mass. Planets (ETV) from Qian et al. 2012 (b) and Song et al. 2019 (c).",
    },
    {
        "hostname": "UZ For", "binary_class": "WD+dM (eclipsing polar)",
        "primary_mass_msun": 0.7, "component_mass_msun": 0.14,
        "source_bibcode": "2011MNRAS.416.2202P",
        "notes": "Potter+ 2011. Component masses approximate (M_total ~0.8 Msun derived from the planets). Deeper dive for measured WD/dM masses + period.",
    },
    {
        "hostname": "b Cen A", "binary_class": "B-star spectroscopic binary",
        "primary_spectype": "B",
        "source_bibcode": "2021Natur.600..231J",
        "notes": "Janson+ 2021 (BEAST). Combined mass 6-10 Msun (most massive planet host in corpus). Component split not given. Deeper dive needed.",
    },
    {
        "hostname": "PSR B1620-26", "binary_class": "pulsar + white dwarf",
        "primary_mass_msun": 1.4, "primary_spectype": "millisecond pulsar (NS)",
        "component_mass_msun": 0.34, "component_spectype": "He white dwarf",
        "source_bibcode": "2003Sci...301..193S",
        "notes": "Sigurdsson+ 2003. WD detected via HST; WD cooling age 480 Myr. Pulsar mass assumed canonical ~1.4 Msun (deeper dive for measured value). "
                 "Replaces the four spurious M4 crowded-field rows deleted by this seed.",
    },
    # ---- sparse: class + provenance only, numbers need a deeper dive ----------
    {
        "hostname": "2MASS J01033563-5515561 A", "binary_class": "young M-dwarf pair", "primary_spectype": "late-M",
        "source_bibcode": "2013A&A...553L...5D",
        "notes": "Delorme+ 2013. Pair of young late-M stars; AB separation/masses not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "2MASS J0249-0557 A", "binary_class": "ultracool dwarf binary",
        "source_bibcode": "2018AJ....156...57D",
        "notes": "Dupuy+ 2018. Tight ultracool dwarf binary; parameters not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "2MASS J19383260+4603591", "binary_class": "sdB+dM (eclipsing)",
        "primary_spectype": "sdB", "component_spectype": "M",
        "source_bibcode": "2015A&A...577A.146B",
        "notes": "Baran+ 2015 (= Kepler-451). sdB pulsator + M-dwarf, strong reflection effect. Component masses + binary period not harvested. Deeper dive needed.",
    },
    {
        "hostname": "BEBOP-3", "binary_class": "main-sequence EB",
        "source_bibcode": "2025MNRAS.541.2801B",
        "notes": "Baycroft+ 2025. Eclipsing binary; paper derives dynamical component masses via cross-correlation but values not harvested. Deeper dive needed.",
    },
    {
        "hostname": "DE CVn", "binary_class": "PCEB (WD+dM)",
        "orbital_period_d": 0.3625,
        "primary_mass_msun": 0.51, "primary_teff_k": 8000, "primary_spectype": "DA white dwarf",
        "component_mass_msun": 0.41, "component_spectype": "M3V",
        "source_bibcode": "2007A&A...466.1031V",
        "notes": "Inner-binary masses from van den Besselaar et al. 2007 (DA WD 0.51 +0.06/-0.02 Msun; M3V 0.41 +/- 0.06 Msun; P_orb 8.7 h). Planet (ETV) from Han et al. 2018 (2018ApJ...868...53H).",
    },
    {
        "hostname": "HD 143811 A", "binary_class": "young binary",
        "source_bibcode": "2025A&A...702L..10S",
        "notes": "Squicciarini+ 2025. Young (~15 Myr) binary; (AB) architecture implied by designation but components not quantified in abstract. Deeper dive needed.",
    },
    {
        "hostname": "HIP 79098 AB", "binary_class": "B9 spectroscopic binary",
        "primary_spectype": "B9",
        "source_bibcode": "2019A&A...626A..99J",
        "notes": "Janson+ 2019 (BEAST). B9-type spectroscopic pair, unresolved; component masses not given. Deeper dive needed. "
                 "(Existing wide M-dwarf tertiaries B/C are separate field/hierarchical companions.)",
    },
    {
        "hostname": "HU Aqr", "binary_class": "WD+dM (eclipsing polar)",
        "source_bibcode": "2011MNRAS.414L..16Q",
        "notes": "Qian+ 2011. Eclipsing polar; component masses not in abstract. Planet existence strongly contested. Deeper dive needed.",
    },
    {
        "hostname": "MXB 1658-298", "binary_class": "LMXB (neutron star + low-mass dwarf)",
        "source_bibcode": "2017MNRAS.468L.118J",
        "notes": "Jain+ 2017. Compact LMXB, P_orb ~7.1 h (literature). Component masses not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "NSVS 14256825", "binary_class": "sdOB+dM (eclipsing)",
        "orbital_period_d": 0.110374, "primary_spectype": "sdOB", "component_spectype": "M",
        "source_bibcode": "2019RAA....19..134Z",
        "notes": "Zhu+ 2019. sdOB + red dwarf eclipsing binary, P_orb = 2.65 h. Component masses not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "ROXs 42 B", "binary_class": "M-dwarf pair (T Tauri, rho Oph)",
        "primary_spectype": "M0", "component_spectype": "M0",
        "source_bibcode": "2014ApJ...780L..30C",
        "notes": "Currie+ 2014. Young M0+M0 binary in rho Oph; AB separation/masses not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "RR Cae", "binary_class": "PCEB (WD+dM, detached)",
        "orbital_period_d": 0.3038,
        "primary_mass_msun": 0.440, "primary_spectype": "DA white dwarf",
        "component_mass_msun": 0.183, "component_radius_rsun": 0.20, "component_spectype": "M4",
        "source_bibcode": "2007MNRAS.376..919M",
        "notes": "Inner-binary masses from Maxted et al. 2007 (DA WD 0.440 +/- 0.022 Msun; M4 dwarf 0.183 +/- 0.013 Msun, R 0.20 Rsun; P_orb 7.29 h). Planet (ETV) from Qian et al. 2012 (2012MNRAS.422L..24Q). Confirms the audit's internal-tension flag: real M_total ~0.62 Msun, not the ~1.0 implied by the abstract's period+separation.",
    },
    {
        "hostname": "Ross 458", "binary_class": "M-dwarf binary",
        "source_bibcode": "2010ApJ...725.1405B",
        "notes": "Burgasser+ 2010 characterizes the wide T8 companion, not the AB pair. Inner-binary params from separate literature. Deeper dive needed.",
    },
    {
        "hostname": "SR 12 AB", "binary_class": "T Tauri binary (rho Oph)",
        "source_bibcode": "2011AJ....141..119K",
        "notes": "Kuzuhara+ 2011. Young T Tauri binary; component masses/separation not in abstract. Deeper dive needed.",
    },
    {
        "hostname": "Kepler-1647", "binary_class": "main-sequence EB",
        "orbital_period_d": 11.0, "eccentricity": 0.16,
        "primary_spectype": "G", "component_spectype": "G",
        "source_bibcode": "2016ApJ...827...86K",
        "notes": "Kostov+ 2016. Two ~solar-mass stars, spin-synchronized. Per-component masses not split in abstract. Deeper dive needed.",
    },
    {
        "hostname": "Kepler-1660 A", "binary_class": "main-sequence EB",
        "orbital_period_d": 18.6,
        "source_bibcode": "2023MNRAS.525.4628G",
        "notes": "Getley/2023 confirmation. M_total ~1.2 Msun derived (~two 0.6 Msun). First ETV CBP around a main-sequence binary. Deeper dive for component masses.",
    },
    {
        "hostname": "Kepler-34", "binary_class": "main-sequence EB (two Sun-like stars)",
        "primary_spectype": "G", "component_spectype": "G",
        "source_bibcode": "2012Natur.481..475W",
        "notes": "Welsh+ 2012. 'Two Sun-like stars'; component masses + binary period not given in abstract. Deeper dive needed.",
    },
    {
        "hostname": "Kepler-47", "binary_class": "G+M eclipsing binary",
        "orbital_period_d": 7.45,
        "primary_spectype": "G (Sun-like)", "component_spectype": "M",
        "source_bibcode": "2012Sci...337.1511O",
        "notes": "Orosz+ 2012. Sun-like primary + companion ~1/3 its size. M_total ~1.3 Msun derived. Per-component masses need deeper dive. Hosts 3 planets.",
    },
    {
        "hostname": "VHS J125601.92-125723.9", "binary_class": "BD+BD (ultracool dwarf binary)",
        "separation_au": 1.96, "eccentricity": 0.883,
        "source_bibcode": "2015ApJ...804...96G",
        "notes": "Gauza+ 2015 / Stone+ 2016 / Dupuy+ 2023. Inner pair is two brown dwarfs (a=1.96 AU, e=0.883 per Dupuy 2023). "
                 "Gauza reported the unresolved pair as a single 73 Mjup 'primary'. Deeper dive for the two BD masses.",
    },
    {
        "hostname": "OGLE-2016-BLG-0613L AB", "binary_class": "binary lens (degenerate)",
        "primary_mass_msun": 0.7,
        "source_bibcode": "2017AJ....154..223H",
        "notes": "Han+ 2017. Three surviving 3L1S solutions; secondary is a BD in one, comparable-mass star in two. "
                 "Component masses solution-dependent; do not finalize until the 2024+ proper-motion follow-up resolves it.",
    },
]

# Hosts whose existing rows are spurious or mis-scoped and should be removed.
# SAFEGUARD: the DELETE in main() additionally filters source_catalog = 'SIMBAD',
# so this script can only ever remove auto-fetched catalog rows it judges spurious,
# never a hand-curated ('manual') row. Keep entries here explicit and minimal.
SPURIOUS_DELETIONS = [
    # PSR B1620-26: B/C/D/E are crowded-field M4 cluster stars, not bound companions.
    ("PSR B1620-26", ["B", "C", "D", "E"]),
]

UPSERT_SQL = """
INSERT INTO binary_companions
    (hostname, component_designation, primary_designation, inner_binary, binary_class,
     separation_arcsec, separation_au, orbital_period_d, eccentricity, inclination_deg,
     component_mass_msun, component_radius_rsun, component_teff_k, component_spectype, component_mass_is_min,
     primary_mass_msun, primary_radius_rsun, primary_teff_k, primary_spectype,
     source_catalog, source_bibcode, notes)
VALUES
    (%(hostname)s, 'Ab', 'Aa', TRUE, %(binary_class)s,
     %(separation_arcsec)s, %(separation_au)s, %(orbital_period_d)s, %(eccentricity)s, %(inclination_deg)s,
     %(component_mass_msun)s, %(component_radius_rsun)s, %(component_teff_k)s, %(component_spectype)s, %(component_mass_is_min)s,
     %(primary_mass_msun)s, %(primary_radius_rsun)s, %(primary_teff_k)s, %(primary_spectype)s,
     'manual', %(source_bibcode)s, %(notes)s)
ON CONFLICT (hostname, component_designation) DO UPDATE SET
    primary_designation   = EXCLUDED.primary_designation,
    inner_binary          = EXCLUDED.inner_binary,
    binary_class          = EXCLUDED.binary_class,
    separation_arcsec     = EXCLUDED.separation_arcsec,
    separation_au         = EXCLUDED.separation_au,
    orbital_period_d      = EXCLUDED.orbital_period_d,
    eccentricity          = EXCLUDED.eccentricity,
    inclination_deg       = EXCLUDED.inclination_deg,
    component_mass_msun   = EXCLUDED.component_mass_msun,
    component_radius_rsun = EXCLUDED.component_radius_rsun,
    component_teff_k      = EXCLUDED.component_teff_k,
    component_spectype    = EXCLUDED.component_spectype,
    component_mass_is_min = EXCLUDED.component_mass_is_min,
    primary_mass_msun     = EXCLUDED.primary_mass_msun,
    primary_radius_rsun   = EXCLUDED.primary_radius_rsun,
    primary_teff_k        = EXCLUDED.primary_teff_k,
    primary_spectype      = EXCLUDED.primary_spectype,
    source_catalog        = EXCLUDED.source_catalog,
    source_bibcode        = EXCLUDED.source_bibcode,
    notes                 = EXCLUDED.notes,
    retrieved_at          = now()
"""

NULLABLE = [
    "binary_class", "separation_arcsec", "separation_au", "orbital_period_d",
    "eccentricity", "inclination_deg", "component_mass_msun", "component_radius_rsun",
    "component_teff_k", "component_spectype", "component_mass_is_min",
    "primary_mass_msun", "primary_radius_rsun", "primary_teff_k", "primary_spectype",
    "source_bibcode", "notes",
]


def normalize(row: dict) -> dict:
    out = {"hostname": row["hostname"]}
    for k in NULLABLE:
        out[k] = row.get(k)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Seed inner binaries from the cb_flag audit")
    ap.add_argument("--execute", action="store_true", help="Apply to the DB (default is dry-run)")
    args = ap.parse_args()

    rows = [normalize(r) for r in INNER_BINARIES]

    print(f"Inner-binary rows to upsert: {len(rows)}")
    filled = sum(1 for r in rows if r["component_mass_msun"] is not None)
    print(f"  with a numeric companion mass: {filled}; class/provenance only: {len(rows) - filled}")
    print("Spurious SIMBAD-row deletions (curated 'manual' rows are never touched):")
    for host, comps in SPURIOUS_DELETIONS:
        print(f"  {host}: {', '.join(comps)}")

    if not args.execute:
        print("\nDRY RUN — nothing written. Re-run with --execute to apply.")
        for r in rows:
            bits = [f"{k}={r[k]}" for k in ("binary_class", "primary_mass_msun",
                    "component_mass_msun", "orbital_period_d") if r[k] is not None]
            print(f"  {r['hostname']:32s} Ab  " + ", ".join(bits))
        return 0

    db_url = os.environ["DATABASE_URL"]
    with psycopg.connect(db_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            for host, comps in SPURIOUS_DELETIONS:
                cur.execute(
                    "DELETE FROM binary_companions "
                    "WHERE hostname = %s AND component_designation = ANY(%s) "
                    "AND source_catalog = 'SIMBAD'",  # never delete a curated 'manual' row
                    (host, comps),
                )
                print(f"  deleted {cur.rowcount} spurious SIMBAD row(s) for {host}")
            cur.executemany(UPSERT_SQL, rows)
            print(f"  upserted {len(rows)} inner-binary rows")
        conn.commit()
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
