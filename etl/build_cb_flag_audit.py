"""Generate docs/cb_flag_audit.md, the cb_flag audit supplement.

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
confirms or overrides the pre-filled cases.

VERDICT-PRESERVING REGENERATE
-----------------------------
docs/cb_flag_audit.md is hand-maintained: hand-written verdicts, **Notes:**
blocks, the Universe section, and the "About this document" section all live in
that file and must survive a regenerate. This generator now MERGES rather than
clobbers: on each run it reads the existing doc, extracts the hand-written
per-host verdict blocks plus the hand-maintained Universe / About sections, and
re-injects them into a freshly rebuilt skeleton. Hosts that have dropped out of
the cb_flag=1 set keep their verdicts under an "Orphaned verdicts" section
rather than vanishing. Only the auto-generated scaffolding (companion tables,
distances, planet tables, screenshot detection) is rebuilt from the warehouse.

Run (preview a merged regenerate to stdout, then diff):
    python -m etl.build_cb_flag_audit | diff docs/cb_flag_audit.md -

Run (apply in place; writes docs/cb_flag_audit.md.bak first, replaces atomically):
    python -m etl.build_cb_flag_audit --in-place

Do NOT do `python -m etl.build_cb_flag_audit > docs/cb_flag_audit.md`: the shell
truncates the file before the program can read it for the merge, which would
lose every hand-written verdict. Use --in-place for that.

Note: the manual inner-binary backfill (source_catalog='manual') is excluded
from the per-host "Known companions" table, which by design lists only the
wide-binary catalog (WDS/SIMBAD) cross-references; the harvested inner-binary
parameters live in each host's **Notes:** block and in binary_companions.
"""

from __future__ import annotations

import argparse
import io
import os
import re
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()

DOC_PATH = Path(__file__).resolve().parents[1] / "docs" / "cb_flag_audit.md"

# Top-level (## ) sections that are hand-maintained and must survive a
# regenerate verbatim. Everything else is rebuilt from the warehouse.
PRESERVED_SECTIONS = ("Universe", "About this document")

# The per-host marker that precedes the hand-written verdict bullets.
VERDICT_MARKER = "**Verdict (fill in by hand if you disagree with the suggestion):**"

# A verdict bullet still in its blank template form (not yet filled in).
_BLANK_VERDICT_RE = re.compile(r"^- `[^`]+`: _+ \(rationale: _+\)\s*$")


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


def parse_existing(text: str) -> tuple[dict[str, str], dict[str, str]]:
    """Extract hand-maintained content from an existing audit doc.

    Returns (preserved_sections, host_verdicts):
      preserved_sections: {section_title: body_without_heading} for each
        title in PRESERVED_SECTIONS that appears in the file.
      host_verdicts: {host_name: verdict_block} for every per-host section
        whose verdict bullets have been filled in by hand. Blank templates
        are skipped so a re-run still offers them.
    """
    preserved: dict[str, str] = {}
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", text, re.S | re.M):
        title = m.group(1).strip()
        if title in PRESERVED_SECTIONS:
            preserved[title] = m.group(2).strip("\n")

    host_verdicts: dict[str, str] = {}
    audit = re.search(r"^## Per-host audit\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if audit:
        for chunk in re.split(r"^### ", audit.group(1), flags=re.M)[1:]:
            host = chunk.splitlines()[0].strip()
            idx = chunk.find(VERDICT_MARKER)
            if idx == -1:
                continue
            block_lines = chunk[idx + len(VERDICT_MARKER):].splitlines()
            # Trim surrounding blank lines and a trailing horizontal rule.
            while block_lines and not block_lines[0].strip():
                block_lines.pop(0)
            while block_lines and not block_lines[-1].strip():
                block_lines.pop()
            if block_lines and re.fullmatch(r"-{3,}", block_lines[-1].strip()):
                block_lines.pop()
            while block_lines and not block_lines[-1].strip():
                block_lines.pop()
            verdict_bullets = [ln for ln in block_lines if ln.startswith("- `")]
            if not verdict_bullets:
                continue
            if all(_BLANK_VERDICT_RE.match(ln) for ln in verdict_bullets):
                continue  # still a blank template; let the generator re-offer it
            host_verdicts[host] = "\n".join(block_lines)
    return preserved, host_verdicts


def build_doc(existing: str) -> str:
    """Build the merged audit doc, preserving hand-written content from `existing`."""
    preserved, host_verdicts = parse_existing(existing)
    out = io.StringIO()

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

            # Wide-binary catalog companions only (WDS/SIMBAD). The manual
            # inner-binary backfill (source_catalog='manual') is intentionally
            # excluded: this table is about the archive's wide cross-references,
            # and the harvested inner binary lives in each host's Notes block.
            hosts = sorted({p["hostname"] for p in planets})
            cur.execute("""
                SELECT hostname, component_designation, separation_arcsec,
                       position_angle_deg, component_spectype, source_catalog,
                       source_bibcode
                FROM binary_companions
                WHERE hostname = ANY(%s)
                  AND source_catalog IS DISTINCT FROM 'manual'
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

    # Universe: preserve the hand-maintained section if present.
    if "Universe" in preserved:
        print("## Universe", file=out)
        print(file=out)
        print(preserved["Universe"], file=out)
        print(file=out)
    else:
        print("## Universe", file=out)
        print(file=out)
        print(f"- **{total_planets} planets** across **{total_hosts} host systems**", file=out)
        print(
            f"- **{hosts_with_companions} / {total_hosts} hosts** have a "
            "wide-binary catalog (WDS/SIMBAD) cross-reference in the warehouse; "
            f"**{total_hosts - hosts_with_companions} have none**. These are "
            "wide tertiaries, not the tight inner binary that defines a "
            "circumbinary system; the inner binary is harvested per host (see "
            "**Notes:** blocks) and stored in `binary_companions` "
            "(`source_catalog = 'manual'`).",
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

    # About this document: preserve the hand-maintained section if present.
    if "About this document" in preserved:
        print("## About this document", file=out)
        print(file=out)
        print(preserved["About this document"], file=out)
        print(file=out)

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
                "**No wide-binary catalog companion for this host.** The "
                "archive's wide-binary cross-references (WDS, SIMBAD) carry no "
                "entry. The defining inner binary, where the literature reports "
                "it, is harvested in this host's **Notes:** block and stored in "
                "`binary_companions` (`source_catalog = 'manual'`).",
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

        # Verdict block: re-inject the hand-written verdict if we have one,
        # otherwise emit the blank template for the user to fill in.
        print(VERDICT_MARKER, file=out)
        print(file=out)
        if host in host_verdicts:
            print(host_verdicts[host], file=out)
        else:
            for p in host_planets:
                print(
                    f"- `{p['pl_name']}`: __________ (rationale: __________)",
                    file=out,
                )
        print(file=out)
        print("---", file=out)
        print(file=out)

    # Preserve verdicts for hosts that have dropped out of the cb_flag=1 set
    # rather than silently discarding hand-written work.
    orphans = sorted(h for h in host_verdicts if h not in planets_by_host)
    if orphans:
        print("## Orphaned verdicts (host no longer in the cb_flag=1 snapshot)", file=out)
        print(file=out)
        print(
            "Hand-written verdicts preserved from a previous version whose "
            "host no longer appears in the current snapshot. Review before "
            "removing.",
            file=out,
        )
        print(file=out)
        for h in orphans:
            print(f"### {h}", file=out)
            print(file=out)
            print(host_verdicts[h], file=out)
            print(file=out)
            print("---", file=out)
            print(file=out)

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

    return out.getvalue()


def write_in_place(doc: str) -> None:
    """Back up the existing doc, then replace it atomically."""
    if DOC_PATH.exists():
        backup = DOC_PATH.with_suffix(DOC_PATH.suffix + ".bak")
        backup.write_text(DOC_PATH.read_text())
    fd, tmp = tempfile.mkstemp(dir=str(DOC_PATH.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(doc)
        os.replace(tmp, DOC_PATH)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Regenerate docs/cb_flag_audit.md, preserving hand-written verdicts."
    )
    ap.add_argument(
        "--in-place",
        action="store_true",
        help=(
            "Apply the merged regenerate to docs/cb_flag_audit.md "
            "(writes a .bak first, replaces atomically). Default: print to stdout."
        ),
    )
    args = ap.parse_args()

    existing = DOC_PATH.read_text() if DOC_PATH.exists() else ""

    # Safety net: refuse to clobber a doc that clearly holds hand verdicts if
    # the parser failed to recover any of them (format drift).
    if existing and existing.count(VERDICT_MARKER):
        _, parsed = parse_existing(existing)
        if not parsed:
            print(
                "Refusing to run: the existing doc contains verdict markers but "
                "none parsed as filled-in verdicts. Aborting to avoid data loss; "
                "check the doc format against parse_existing().",
                file=sys.stderr,
            )
            return 2

    doc = build_doc(existing)

    if args.in_place:
        write_in_place(doc)
        print(f"Wrote {DOC_PATH} (backup at {DOC_PATH}.bak)", file=sys.stderr)
    else:
        sys.stdout.write(doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
