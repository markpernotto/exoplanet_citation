"""Regenerate and verify every machine-derivable number in docs/cb_flag_paper.tex.

Read-only. Recomputes each numeric claim in the cb_flag audit paper directly
from the warehouse (DATABASE_URL, pinned to the snapshot the paper cites) plus a
parse of the public supplement docs/cb_flag_audit.md for the hand-assigned
verdict tally, and prints PASS/FAIL for each. Exits non-zero if any check fails.

The point is author accountability: run this, confirm every PASS, and you can
sign your name to the paper's numbers honestly. The script is also the
reproducibility artifact to deposit with the Zenodo release.

Run:
    python -m etl.verify_cb_flag_paper

Numbers that are NOT machine-derivable from pscomppars (individual companion
masses, the planet/brown-dwarf boundary count, per-system orbital parameters
quoted from discovery papers) are listed at the end with their source papers;
those must be checked against the cited literature / the supplement, not here.
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

results: list[tuple[str, bool, str]] = []


def check(label: str, expected, actual) -> None:
    ok = expected == actual
    results.append((label, ok, f"expected {expected!r}, got {actual!r}"))


def main() -> int:
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            # Resolve the snapshot. Prefer the paper's pinned date; fall back to
            # latest with a loud warning if retention has dropped it.
            cur.execute("SELECT max(snapshot_date) AS d FROM planets_snapshots")
            latest = cur.fetchone()["d"]
            cur.execute(
                "SELECT count(*) AS n FROM planets_snapshots WHERE snapshot_date = %s",
                (PAPER_SNAPSHOT,),
            )
            have_pinned = cur.fetchone()["n"] > 0
            snap = PAPER_SNAPSHOT if have_pinned else str(latest)
            print(f"# cb_flag paper verification")
            print(f"# paper snapshot: {PAPER_SNAPSHOT}   latest in DB: {latest}")
            if not have_pinned:
                print(
                    f"# WARNING: snapshot {PAPER_SNAPSHOT} not retained; "
                    f"verifying against latest ({snap}). Numbers may differ from "
                    "the paper if pscomppars changed."
                )
            print()

            snap_cte = """
                WITH snap AS (
                  SELECT pl_name, raw_row FROM planets_snapshots
                  WHERE snapshot_date = %(snap)s
                ),
                cb AS (
                  SELECT pc.pl_name, pc.hostname, pc.discoverymethod
                  FROM planets_current pc JOIN snap USING (pl_name)
                  WHERE (snap.raw_row->>'cb_flag')::int = 1
                )
            """

            # 1. Totals.
            cur.execute(
                snap_cte + "SELECT count(*) AS planets, count(DISTINCT hostname) AS hosts FROM cb",
                {"snap": snap},
            )
            row = cur.fetchone()
            check("planets (cb_flag=1)", EXPECT["planets"], row["planets"])
            check("host systems", EXPECT["hosts"], row["hosts"])

            # 2. Method breakdown.
            cur.execute(
                snap_cte + "SELECT discoverymethod, count(*) AS n FROM cb GROUP BY discoverymethod",
                {"snap": snap},
            )
            methods = {r["discoverymethod"]: r["n"] for r in cur.fetchall()}
            for m, n in EXPECT["methods"].items():
                check(f"method: {m}", n, methods.get(m, 0))

            # 3. Groupings used in the prose.
            tt = sum(methods.get(m, 0) for m in
                     ("Eclipse Timing Variations", "Pulsar Timing", "Transit"))
            rvi = sum(methods.get(m, 0) for m in ("Radial Velocity", "Imaging"))
            geo = sum(methods.get(m, 0) for m in
                      ("Imaging", "Microlensing", "Radial Velocity"))
            check("timing+transit group", EXPECT["timing_transit_group"], tt)
            check("RV+imaging group", EXPECT["rv_imaging_group"], rvi)
            check("geometric-test group", EXPECT["geometric_test_group"], geo)

            # 4. Companion-data coverage.
            cur.execute(
                snap_cte + """
                SELECT
                  count(DISTINCT cb.hostname) FILTER (
                    WHERE bc.source_catalog IS DISTINCT FROM 'manual') AS simbad_hosts,
                  count(DISTINCT cb.hostname) FILTER (
                    WHERE bc.source_catalog = 'manual') AS manual_hosts
                FROM cb LEFT JOIN binary_companions bc ON bc.hostname = cb.hostname
                """,
                {"snap": snap},
            )
            row = cur.fetchone()
            check("hosts with wide (SIMBAD/WDS) cross-ref", EXPECT["simbad_hosts"], row["simbad_hosts"])
            check("hosts with manual inner-binary row", EXPECT["manual_hosts"], row["manual_hosts"])

            # 5. Inner-binary backfill completeness, counted per DISTINCT host.
            # (cb is per-planet; a host may also carry >1 manual companion row,
            # so we collapse to hosts with bool_or before counting.)
            cur.execute(
                snap_cte + """
                SELECT
                  count(*) FILTER (WHERE m.has_mass) AS masses,
                  count(*) FILTER (WHERE m.has_period) AS periods,
                  count(*) FILTER (WHERE m.has_ecc) AS eccs
                FROM (SELECT DISTINCT hostname FROM cb) h
                LEFT JOIN LATERAL (
                  SELECT bool_or(component_mass_msun IS NOT NULL) AS has_mass,
                         bool_or(orbital_period_d IS NOT NULL) AS has_period,
                         bool_or(eccentricity IS NOT NULL) AS has_ecc
                  FROM binary_companions bc
                  WHERE bc.hostname = h.hostname AND bc.source_catalog = 'manual'
                ) m ON true
                """,
                {"snap": snap},
            )
            row = cur.fetchone()
            check("hosts w/ inner-binary component mass", EXPECT["manual_masses"], row["masses"])
            check("hosts w/ inner-binary orbital period", EXPECT["manual_periods"], row["periods"])
            check("hosts w/ inner-binary eccentricity", EXPECT["manual_eccentricities"], row["eccs"])

            # 6. HIP 79098 wide cross-reference separations (projected AU).
            cur.execute(
                """
                SELECT bc.separation_arcsec,
                       COALESCE(h.distance_gspphot_pc, pc.sy_dist) AS dist_pc
                FROM binary_companions bc
                JOIN planets_current pc ON pc.hostname = bc.hostname
                LEFT JOIN host_stars_gaia h ON h.hostname = bc.hostname
                WHERE bc.hostname = 'HIP 79098 AB'
                  AND bc.source_catalog IS DISTINCT FROM 'manual'
                  AND bc.separation_arcsec IS NOT NULL
                """,
            )
            seps = sorted({round(r["separation_arcsec"] * r["dist_pc"]) for r in cur.fetchall()})
            lo_ok = bool(seps) and EXPECT["hip79098_sep_lo_au"][0] <= seps[0] <= EXPECT["hip79098_sep_lo_au"][1]
            hi_ok = bool(seps) and EXPECT["hip79098_sep_hi_au"][0] <= seps[-1] <= EXPECT["hip79098_sep_hi_au"][1]
            results.append(("HIP 79098 wide cross-ref ~10,000 AU", lo_ok, f"projected separations (AU): {seps}"))
            results.append(("HIP 79098 wide cross-ref ~30,000 AU", hi_ok, f"projected separations (AU): {seps}"))

    # 7. Verdict tally from the public supplement (hand-assigned verdicts).
    text = SUPPLEMENT.read_text()
    verdicts = re.findall(r"^- `[^`]+`: (P-type confirmed|S-type[a-z ]*|Ambiguous|Needs)",
                          text, re.M)
    tally = Counter(v.split()[0] for v in verdicts)
    check("verdict: P-type", EXPECT["verdict_ptype"], tally.get("P-type", 0))
    check("verdict: Ambiguous", EXPECT["verdict_ambiguous"], tally.get("Ambiguous", 0))
    check("verdict: S-type misflag", EXPECT["verdict_stype"], tally.get("S-type", 0))
    amb_names = set(re.findall(r"^- `([^`]+)`: Ambiguous", text, re.M))
    check("ambiguous entry names", EXPECT["ambiguous_names"], amb_names)

    # Report.
    print(f"{'CHECK':<46} RESULT")
    print("-" * 70)
    n_fail = 0
    for label, ok, detail in results:
        tag = "PASS" if ok else "FAIL"
        if not ok:
            n_fail += 1
        print(f"{label:<46} {tag}   {detail if not ok else ''}".rstrip())

    print()
    print("LITERATURE-SOURCED (verify against the cited papers / supplement, not the DB):")
    for line in (
        "  planet/brown-dwarf boundary count ('about a dozen'): qualitative, ~13 M_Jup limit",
        "  HD 202206 c true mass 17.9 M_Jup .......... Benedict & Harrison 2017 (2017AJ....153..258B)",
        "  BEBOP-4 AB b 20.9 M_Jup ................... Triaud et al. 2025 (2025MNRAS.544.2180T)",
        "  HIP 79098 AB b 16-25 M_Jup ................ Janson et al. 2019 (2019A&A...626A..99J)",
        "  Kepler-16 inner binary 0.69/0.20 M_sun, 41 d, coplanar 0.5 deg .. Doyle et al. 2011",
        "  PSR B1620-26 / PH1 companion-table artifacts: see supplement per-host notes",
    ):
        print(line)

    print()
    print(f"{'ALL CHECKS PASSED' if n_fail == 0 else f'{n_fail} CHECK(S) FAILED'}")
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
