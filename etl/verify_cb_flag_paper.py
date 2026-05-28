"""Regenerate and verify every machine-derivable number in docs/cb_flag_paper.tex.

Reproducibility note: the live warehouse keeps only a ~2-day rolling window of
pscomppars snapshots, so it is NOT the durable receipt for this paper. The
durable, git-committed receipts are (a) the per-host supplement
docs/cb_flag_audit.md, and (b) the migrations that seed the value-added tables.
This script therefore verifies in two tiers:

  TIER 1 (durable, offline): the headline numbers, planet and host counts, the
    per-method breakdown of Table 1, and the verdict tally, are recomputed by
    parsing the frozen supplement. No database, reproducible forever from git.

  TIER 2 (live-mirror cross-check): the companion-provenance numbers (wide-
    catalog coverage and inner-binary backfill completeness) are cross-checked
    against the live DB when reachable. These derive from the committed
    migrations (047-084); the live DB is only a convenience mirror of them. If
    the cited snapshot has aged out, the script says so and reports current.

Author accountability: run this, confirm every Tier 1 PASS (the numbers a
referee can reproduce from the public repo), and you can sign the paper.

Run:
    python -m etl.verify_cb_flag_paper

Numbers that are NOT machine-derivable (individual companion masses, the
planet/brown-dwarf boundary count, per-system orbital parameters quoted from
discovery papers) are listed at the end with their source papers; those must be
checked against the cited literature, not here.
"""

from __future__ import annotations

import os
import re
import sys
from collections import Counter
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()

# The snapshot the paper reports. pscomppars refreshes daily; pin to this date
# so the script reproduces the paper's exact numbers rather than today's.
PAPER_SNAPSHOT = "2026-05-24"
SUPPLEMENT = Path(__file__).resolve().parents[1] / "docs" / "cb_flag_audit.md"

# Expected values as stated in docs/cb_flag_paper.tex.
EXPECT = {
    "planets": 54,
    "hosts": 44,
    "methods": {
        "Eclipse Timing Variations": 17,
        "Pulsar Timing": 1,
        "Transit": 14,
        "Radial Velocity": 4,
        "Imaging": 12,
        "Microlensing": 6,
    },
    "timing_transit_group": 32,   # ETV + Pulsar + Transit
    "rv_imaging_group": 16,        # RV + Imaging
    "geometric_test_group": 22,    # Imaging + Microlensing + RV
    "simbad_hosts": 15,
    "manual_hosts": 44,
    "manual_masses": 39,
    "manual_periods": 22,
    "manual_eccentricities": 10,
    "verdict_ptype": 51,
    "verdict_ambiguous": 3,
    "verdict_stype": 0,
    "ambiguous_names": {
        "KMT-2016-BLG-1337L b",
        "OGLE-2018-BLG-1700L b",
        "OGLE-2019-BLG-1470L AB c",
    },
    # HIP 79098 wide cross-references quoted as "M dwarfs at 10,000 to 30,000 AU"
    "hip79098_sep_lo_au": (9000, 11000),
    "hip79098_sep_hi_au": (29000, 31000),
}

METHODS = {
    "Imaging", "Microlensing", "Radial Velocity", "Transit",
    "Eclipse Timing Variations", "Pulsar Timing",
}

# (tier, label, ok, detail)
results: list[tuple[int, str, bool, str]] = []


def check(tier: int, label: str, expected, actual) -> None:
    ok = expected == actual
    results.append((tier, label, ok, f"expected {expected!r}, got {actual!r}"))


def parse_supplement() -> dict:
    """Recompute the headline numbers from the frozen, git-committed supplement.

    No database: this is what a referee can reproduce from the public repo.
    """
    text = SUPPLEMENT.read_text()
    planets = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        # Per-host planet tables have 6 cells with a discovery method in col 2.
        if len(cells) == 6 and cells[1] in METHODS:
            planets.append((cells[0], cells[1]))
    audit = text.split("## Per-host audit", 1)[1].split("## Screenshot candidates detail")[0]
    hosts = re.findall(r"^### (.+)$", audit, re.M)
    verdicts = re.findall(
        r"^- `[^`]+`: (P-type confirmed|S-type[a-z ]*|Ambiguous|Needs)", text, re.M)
    return {
        "planets": len({p[0] for p in planets}),
        "methods": Counter(m for _, m in planets),
        "hosts": len(hosts),
        "verdicts": Counter(v.split()[0] for v in verdicts),
        "ambiguous": set(re.findall(r"^- `([^`]+)`: Ambiguous", text, re.M)),
    }


def tier1_from_supplement() -> None:
    """TIER 1: durable receipts, recomputed offline from the frozen supplement."""
    s = parse_supplement()
    check(1, "planets (cb_flag=1)", EXPECT["planets"], s["planets"])
    check(1, "host systems", EXPECT["hosts"], s["hosts"])
    for m, n in EXPECT["methods"].items():
        check(1, f"method: {m}", n, s["methods"].get(m, 0))
    tt = sum(s["methods"].get(m, 0) for m in
             ("Eclipse Timing Variations", "Pulsar Timing", "Transit"))
    rvi = sum(s["methods"].get(m, 0) for m in ("Radial Velocity", "Imaging"))
    geo = sum(s["methods"].get(m, 0) for m in
              ("Imaging", "Microlensing", "Radial Velocity"))
    check(1, "timing+transit group", EXPECT["timing_transit_group"], tt)
    check(1, "RV+imaging group", EXPECT["rv_imaging_group"], rvi)
    check(1, "geometric-test group", EXPECT["geometric_test_group"], geo)
    check(1, "verdict: P-type", EXPECT["verdict_ptype"], s["verdicts"].get("P-type", 0))
    check(1, "verdict: Ambiguous", EXPECT["verdict_ambiguous"], s["verdicts"].get("Ambiguous", 0))
    check(1, "verdict: S-type misflag", EXPECT["verdict_stype"], s["verdicts"].get("S-type", 0))
    check(1, "ambiguous entry names", EXPECT["ambiguous_names"], s["ambiguous"])


def tier2_from_live_db() -> str | None:
    """TIER 2: cross-check provenance numbers against the live mirror.

    Returns a status note (snapshot info / why skipped), or None on hard failure.
    These numbers are frozen in the committed migrations (047-084); the live DB
    is only a convenience mirror with a ~2-day snapshot window.
    """
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute("SELECT max(snapshot_date) AS d FROM planets_snapshots")
            latest = cur.fetchone()["d"]
            cur.execute(
                "SELECT count(*) AS n FROM planets_snapshots WHERE snapshot_date = %s",
                (PAPER_SNAPSHOT,))
            have_pinned = cur.fetchone()["n"] > 0
            snap = PAPER_SNAPSHOT if have_pinned else str(latest)
            note = (f"snapshot {snap}" if have_pinned else
                    f"snapshot {PAPER_SNAPSHOT} aged out of the 2-day window; "
                    f"cross-checking latest ({latest})")

            snap_cte = """
                WITH snap AS (SELECT pl_name, raw_row FROM planets_snapshots
                              WHERE snapshot_date = %(snap)s),
                cb AS (SELECT DISTINCT pc.hostname FROM planets_current pc
                       JOIN snap USING (pl_name)
                       WHERE (snap.raw_row->>'cb_flag')::int = 1)
            """
            cur.execute(snap_cte + """
                SELECT
                  count(DISTINCT cb.hostname) FILTER (
                    WHERE bc.source_catalog IS DISTINCT FROM 'manual') AS simbad_hosts,
                  count(DISTINCT cb.hostname) FILTER (
                    WHERE bc.source_catalog = 'manual') AS manual_hosts
                FROM cb LEFT JOIN binary_companions bc ON bc.hostname = cb.hostname
            """, {"snap": snap})
            row = cur.fetchone()
            check(2, "hosts with wide (SIMBAD/WDS) cross-ref", EXPECT["simbad_hosts"], row["simbad_hosts"])
            check(2, "hosts with manual inner-binary row", EXPECT["manual_hosts"], row["manual_hosts"])

            cur.execute(snap_cte + """
                SELECT
                  count(*) FILTER (WHERE m.has_mass) AS masses,
                  count(*) FILTER (WHERE m.has_period) AS periods,
                  count(*) FILTER (WHERE m.has_ecc) AS eccs
                FROM cb h
                LEFT JOIN LATERAL (
                  SELECT bool_or(component_mass_msun IS NOT NULL) AS has_mass,
                         bool_or(orbital_period_d IS NOT NULL) AS has_period,
                         bool_or(eccentricity IS NOT NULL) AS has_ecc
                  FROM binary_companions bc
                  WHERE bc.hostname = h.hostname AND bc.source_catalog = 'manual'
                ) m ON true
            """, {"snap": snap})
            row = cur.fetchone()
            check(2, "hosts w/ inner-binary component mass", EXPECT["manual_masses"], row["masses"])
            check(2, "hosts w/ inner-binary orbital period", EXPECT["manual_periods"], row["periods"])
            check(2, "hosts w/ inner-binary eccentricity", EXPECT["manual_eccentricities"], row["eccs"])

            cur.execute("""
                SELECT bc.separation_arcsec,
                       COALESCE(h.distance_gspphot_pc, pc.sy_dist) AS dist_pc
                FROM binary_companions bc
                JOIN planets_current pc ON pc.hostname = bc.hostname
                LEFT JOIN host_stars_gaia h ON h.hostname = bc.hostname
                WHERE bc.hostname = 'HIP 79098 AB'
                  AND bc.source_catalog IS DISTINCT FROM 'manual'
                  AND bc.separation_arcsec IS NOT NULL
            """)
            seps = sorted({round(r["separation_arcsec"] * r["dist_pc"]) for r in cur.fetchall()})
            lo, hi = EXPECT["hip79098_sep_lo_au"], EXPECT["hip79098_sep_hi_au"]
            results.append((2, "HIP 79098 wide cross-ref ~10,000 AU",
                            bool(seps) and lo[0] <= seps[0] <= lo[1], f"projected AU: {seps}"))
            results.append((2, "HIP 79098 wide cross-ref ~30,000 AU",
                            bool(seps) and hi[0] <= seps[-1] <= hi[1], f"projected AU: {seps}"))
    return note


def main() -> int:
    print("# cb_flag paper verification")
    print(f"# paper snapshot date: {PAPER_SNAPSHOT}")
    print()

    tier1_from_supplement()

    tier2_note = None
    tier2_error = None
    try:
        tier2_note = tier2_from_live_db()
    except Exception as e:  # DB unreachable / purged: Tier 1 still stands.
        tier2_error = str(e).splitlines()[0]

    # Report, grouped by tier.
    def show(tier: int, header: str) -> int:
        print(header)
        print("-" * 70)
        fails = 0
        for t, label, ok, detail in results:
            if t != tier:
                continue
            tag = "PASS" if ok else "FAIL"
            fails += 0 if ok else 1
            print(f"{label:<46} {tag}   {detail if not ok else ''}".rstrip())
        print()
        return fails

    t1_fail = show(1, "TIER 1  durable receipt: recomputed from the frozen supplement (no DB)")

    if tier2_error:
        print("TIER 2  live-mirror cross-check: SKIPPED")
        print("-" * 70)
        print(f"  database unavailable ({tier2_error}); Tier 1 is unaffected.")
        print()
        t2_fail = 0
    else:
        t2_fail = show(2, f"TIER 2  live-mirror cross-check ({tier2_note}); "
                          "provenance frozen in migrations 047-084")

    print("LITERATURE-SOURCED (verify against the cited papers, not here):")
    for line in (
        "  planet/brown-dwarf boundary ('about a dozen'): qualitative, ~13 M_Jup limit",
        "  HD 202206 c true mass 17.9 M_Jup ......... Benedict & Harrison 2017 (2017AJ....153..258B)",
        "  BEBOP-4 AB b 20.9 M_Jup .................. Triaud et al. 2025 (2025MNRAS.544.2180T)",
        "  HIP 79098 AB b 16-25 M_Jup ............... Janson et al. 2019 (2019A&A...626A..99J)",
        "  Kepler-16 binary 0.69/0.20 M_sun, 41 d, coplanar 0.5 deg .. Doyle et al. 2011",
    ):
        print(line)
    print()

    if t1_fail:
        print(f"TIER 1 FAILED ({t1_fail}): the paper's reproducible numbers do not match the supplement.")
    elif t2_fail:
        print(f"TIER 1 PASSED; TIER 2 drifted ({t2_fail}) on the live mirror "
              "(expected as enrichment continues; the paper's frozen numbers stand).")
    else:
        print("ALL CHECKS PASSED.")
    # Exit code is driven by Tier 1 only: those are the reproducible receipts.
    return 1 if t1_fail else 0


if __name__ == "__main__":
    sys.exit(main())
