"""Generate docs/cb_flag_audit.md, the starter file for the cb_flag audit.

Queries the warehouse for every cb_flag=1 planet in the latest snapshot,
joins each to its host system's binary_companions data (when available),
computes the projected separation in AU vs each planet's pl_orbsmax, and
writes a structured markdown document with one section per host and a
verdict template per planet. Pre-fills verdicts for the geometrically
unambiguous cases:

  S-type misflag (likely)      companion projected separation > every planet's pl_orbsmax
  P-type confirmed (likely)    companion projected separation < every planet's pl_orbsmax
                                AND discovery method is ETV/Transit
  Mixed (worth a screenshot)   multi-planet host where the companion sits between
                                the inner and outer planet's pl_orbsmax
  Needs investigation          no binary_companions data, or geometry is unclear

The user fills in the actual verdict by hand for the ambiguous cases and
confirms or overrides the pre-filled cases. Output is a single markdown
file the RNAAS can cite as supplementary material.

WARNING: docs/cb_flag_audit.md is now hand-maintained (verdicts, Notes blocks, and
a findings summary were filled in by hand). This generator only emits the blank
skeleton, so do NOT pipe it over the live file. Write to a skeleton path and diff
deliberately if you ever need to regenerate.

Run:
    python -m etl.build_cb_flag_audit > docs/cb_flag_audit.skeleton.md
"""

from __future__ import annotations

import math
import os
import sys
from collections import defaultdict
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()


def fmt_au(au: float | None) -> str:
    if au is None:
        return "?"
    if au < 0.01:
        return f"{au:.4f} AU"
    if au < 1:
        return f"{au:.3f} AU"
    if au < 100:
        return f"{au:.2f} AU"
    return f"{au:.0f} AU"


def verdict_label(
    companion_sep_au: float | None,
    planet_orbsmax: list[float],
    discovery_method: str,
) -> str:
    """Suggest a starter verdict based on discovery method + geometry.

    Discovery method is the dominant signal because the binary_companions
    table only carries wide tertiaries (90,000+ AU on Kepler-47, for
    example); the tight inner binaries that define P-type circumbinary
    architectures are NOT in the warehouse. So the geometric test fires
    backwards on real P-types if we lean on it.

    Method → architecture heuristic:
      ETV / Pulsar Timing → P-type by construction (the detection method
        REQUIRES an eclipsing binary or timing-binary host).
      Transit → P-type likely (dual transits / Kepler-discovered CBPs).
      Imaging / Microlensing / RV → architecture not pinned by the
        detection method; verify by hand.
    """
    valid_orbsmax = [a for a in (planet_orbsmax or []) if a is not None]
    has_close_companion = (
        companion_sep_au is not None
        and valid_orbsmax
        and companion_sep_au < 10 * max(valid_orbsmax)
    )

    if discovery_method in ("Eclipse Timing Variations", "Pulsar Timing"):
        return "P-type confirmed (likely, ETV/pulsar timing requires binary)"

    if discovery_method == "Transit":
        if has_close_companion and companion_sep_au > max(valid_orbsmax):
            return "S-type misflag candidate (wide companion in transit system; verify)"
        return "P-type likely (transit detection)"

    if discovery_method == "Imaging":
        if has_close_companion and companion_sep_au > max(valid_orbsmax):
            return "S-type misflag candidate (verify by hand)"
        return "Ambiguous (imaging detection; verify geometry by hand)"

    if discovery_method == "Microlensing":
        return "Ambiguous (microlensing fits are often degenerate)"

    if discovery_method == "Radial Velocity":
        return "Ambiguous (RV detection; verify cb_flag against paper)"

    return "Needs investigation"


def main() -> int:
    out = sys.stdout

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            # All cb_flag=1 planets in the latest snapshot, with host info,
            # discovery context, and citation metadata.
            cur.execute("""
                WITH latest AS (
                  SELECT pl_name, raw_row FROM planets_snapshots
                  WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)
                )
                SELECT
                    pc.pl_name, pc.hostname, pc.discoverymethod, pc.disc_year,
                    pc.pl_orbsmax, pc.pl_orbper,
                    pc.sy_dist, h.distance_gspphot_pc,
                    pub.bibcode AS discovery_bibcode,
                    pub.title AS discovery_title
                FROM planets_current pc
                JOIN latest USING (pl_name)
                LEFT JOIN host_stars_gaia h ON h.hostname = pc.hostname
                LEFT JOIN planet_publications pp
                    ON pp.pl_name = pc.pl_name AND pp.role = 'discovery'
                LEFT JOIN publications pub ON pub.pub_id = pp.pub_id
                WHERE (latest.raw_row->>'cb_flag')::int = 1
                ORDER BY pc.hostname, pc.pl_name
            """)
            planets = cur.fetchall()

            # All binary_companions rows for these hosts, keyed by host.
            hosts = sorted({p["hostname"] for p in planets})
            cur.execute("""
                SELECT hostname, component_designation, separation_arcsec,
                       position_angle_deg, component_spectype, source_catalog,
                       source_bibcode
                FROM binary_companions
                WHERE hostname = ANY(%s)
                ORDER BY hostname, component_designation
            """, (hosts,))
            companions_by_host: dict[str, list[dict[str, Any]]] = defaultdict(list)
            for c in cur.fetchall():
                companions_by_host[c["hostname"]].append(c)

    # Group planets by host so multi-planet systems get one section.
    planets_by_host: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for p in planets:
        planets_by_host[p["hostname"]].append(p)

    total_planets = len(planets)
    total_hosts = len(planets_by_host)
    hosts_with_companions = sum(1 for h in planets_by_host if h in companions_by_host)
    screenshot_candidates: list[str] = []
    spot_the_sun_targets: list[tuple[str, list[float], float]] = []

    # ── header ────────────────────────────────────────────────────────────
    print("# cb_flag audit", file=out)
    print(file=out)
    print(
        "Per-planet review of every entry in the NASA Exoplanet Archive's "
        "`pscomppars` table with `cb_flag = 1` as of the latest snapshot. "
        "Generated from the warehouse by `etl/build_cb_flag_audit.py`. The "
        "purpose is to verify whether each entry is actually a P-type "
        "(circumbinary, both stars inside the planet's orbit) configuration "
        "or whether the flag is misapplied to an S-type (planet orbits one "
        "star of a binary, the other companion is wider than the planet's "
        "orbit).",
        file=out,
    )
    print(file=out)
    print("## Universe", file=out)
    print(file=out)
    print(f"- **{total_planets} planets** across **{total_hosts} host systems**", file=out)
    print(
        f"- **{hosts_with_companions} / {total_hosts} hosts** have "
        "`binary_companions` data in the warehouse; "
        f"**{total_hosts - hosts_with_companions} have none**, "
        "which is itself an audit finding (cb_flag set without supporting "
        "secondary-star evidence).",
        file=out,
    )
    print(file=out)
    print("## Verdict taxonomy", file=out)
    print(file=out)
    print(
        "Per the Doyle 2011 / Welsh+ 2012 convention, a planet in a "
        "multi-star system has one of three orbit types:",
        file=out,
    )
    print(file=out)
    print(
        "- **P-type (circumbinary).** Planet orbits both stars from outside; "
        "both stars sit inside the planet's orbit. `cb_flag` is correctly 1.",
        file=out,
    )
    print(
        "- **S-type (circumstellar in a binary).** Planet orbits one star; "
        "the binary companion is wider than the planet's orbit. The system "
        "is a binary, but the planet only orbits one component. `cb_flag` "
        "should be 0.",
        file=out,
    )
    print(
        "- **Ambiguous.** Architecture not fully constrained by the discovery "
        "data. Common for direct-imaging detections (geometry hard to nail "
        "down at wide separations) and microlensing (degenerate fits).",
        file=out,
    )
    print(file=out)
    print(
        "The geometric test: compare the companion's projected separation "
        "(`separation_arcsec * system_distance_pc`, in AU) to each planet's "
        "`pl_orbsmax`. Companion narrower than the planet's orbit → P-type. "
        "Companion wider → S-type. Unknown companion separation → ambiguous.",
        file=out,
    )
    print(file=out)
    # Reserve a placeholder for the screenshot-candidate section; we'll
    # populate it after we walk every host and know which ones qualify.
    print("## Screenshot candidates (\"spot the second sun\")", file=out)
    print(file=out)
    print("Auto-detected after the per-host walk below. See bottom of file.", file=out)
    print(file=out)
    print("---", file=out)
    print(file=out)
    print("## Per-host audit", file=out)
    print(file=out)

    for host in sorted(planets_by_host):
        host_planets = planets_by_host[host]
        companions = companions_by_host.get(host, [])

        # Resolve a single system distance for projected-separation math.
        # Prefer Gaia (host_stars_gaia.distance_gspphot_pc) over the
        # pscomppars sy_dist column.
        any_planet = host_planets[0]
        dist_pc = any_planet["distance_gspphot_pc"] or any_planet["sy_dist"]

        print(f"### {host}", file=out)
        print(file=out)
        print(f"- Distance: {dist_pc:.1f} pc" if dist_pc else "- Distance: unknown", file=out)
        print(f"- Planets in this system flagged `cb_flag=1`: {len(host_planets)}", file=out)
        print(file=out)

        if companions:
            print("**Known companions (from `binary_companions`):**", file=out)
            print(file=out)
            print(
                "Note: `binary_companions` is sourced from wide-binary "
                "catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the "
                "heart of true P-type circumbinary systems are NOT captured "
                "here. A wide projected separation below should be read as "
                "evidence of a tertiary companion, not as the defining inner "
                "binary of a circumbinary architecture.",
                file=out,
            )
            print(file=out)
            print("| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |", file=out)
            print("|---|---|---|---|---|---|", file=out)
            for c in companions:
                sep_arcsec = c["separation_arcsec"]
                sep_au = (
                    sep_arcsec * dist_pc
                    if sep_arcsec is not None and dist_pc is not None
                    else None
                )
                sep_arcsec_str = f"{sep_arcsec:.3f}" if sep_arcsec is not None else "?"
                print(
                    f"| {c['component_designation']} "
                    f"| {sep_arcsec_str} "
                    f"| {fmt_au(sep_au)} "
                    f"| {c['component_spectype'] or '?'} "
                    f"| {c['source_catalog'] or '?'} "
                    f"| {c['source_bibcode'] or '?'} |",
                    file=out,
                )
            print(file=out)
        else:
            print(
                "**No `binary_companions` row for this host.** The cb_flag is "
                "set but the warehouse has no secondary-star evidence to "
                "verify the architecture. For P-type confirmation, the "
                "discovery paper's reported inner-binary parameters would "
                "need to be consulted directly (not in the warehouse). Default "
                "verdict: needs investigation.",
                file=out,
            )
            print(file=out)

        # Compute the dominant companion projected separation (use the
        # widest companion as a conservative test: if the widest is still
        # narrower than the inner planet's orbit, the planet really is
        # P-type around all of them).
        widest_companion_au: float | None = None
        if companions and dist_pc is not None:
            seps = [
                c["separation_arcsec"] * dist_pc
                for c in companions
                if c["separation_arcsec"] is not None
            ]
            if seps:
                widest_companion_au = max(seps)

        # Per-planet rows.
        print("**Planets:**", file=out)
        print(file=out)
        print("| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |", file=out)
        print("|---|---|---|---|---|---|", file=out)
        for p in host_planets:
            sep_for_verdict = widest_companion_au
            verdict = verdict_label(
                sep_for_verdict,
                [p["pl_orbsmax"]],
                p["discoverymethod"] or "",
            )
            print(
                f"| {p['pl_name']} "
                f"| {p['discoverymethod'] or '?'} "
                f"| {p['disc_year'] or '?'} "
                f"| {fmt_au(p['pl_orbsmax'])} "
                f"| {verdict} "
                f"| {p['discovery_bibcode'] or '?'} |",
                file=out,
            )
        print(file=out)

        # Detect "spot the second sun" candidate: multi-planet host where
        # the widest companion sits between the inner and outer planet.
        valid_orbsmax = [
            p["pl_orbsmax"] for p in host_planets if p["pl_orbsmax"] is not None
        ]
        if (
            len(valid_orbsmax) > 1
            and widest_companion_au is not None
            and min(valid_orbsmax) < widest_companion_au < max(valid_orbsmax)
        ):
            screenshot_candidates.append(host)
            spot_the_sun_targets.append((host, sorted(valid_orbsmax), widest_companion_au))

        print("**Verdict (fill in by hand if you disagree with the suggestion):**", file=out)
        print(file=out)
        for p in host_planets:
            print(
                f"- `{p['pl_name']}`: __________ (rationale: __________)",
                file=out,
            )
        print(file=out)
        print("---", file=out)
        print(file=out)

    # Backfill the screenshot candidates near the top so it's the first
    # thing the user sees. We can't actually rewrite the placeholder we
    # printed above without buffering, so we append a fresh section at the
    # bottom and reference it.
    print("## Screenshot candidates detail", file=out)
    print(file=out)
    if not spot_the_sun_targets:
        print("(none detected)", file=out)
    else:
        print(
            "Multi-planet hosts whose widest binary companion sits **between** "
            "the system's inner and outer planet semi-major axes. From the "
            "outer planet's vantage the companion appears inside the orbit "
            "(P-type-like); from the inner planet's vantage the companion "
            "appears outside the orbit (S-type-like). These produce the "
            "\"spot the second sun in two different positions\" effect in the "
            "3D scene viewer.",
            file=out,
        )
        print(file=out)
        for host, orbsmax_sorted, companion_au in spot_the_sun_targets:
            print(
                f"- **{host}** — companion at ~{fmt_au(companion_au)}; "
                f"planets range from {fmt_au(orbsmax_sorted[0])} to "
                f"{fmt_au(orbsmax_sorted[-1])}",
                file=out,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
