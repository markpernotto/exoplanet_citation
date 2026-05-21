"""Seed planet_publications with follow-up citations identified by the cb_flag audit.

The citation resolver (resolve_citations.py) links each planet to its *discovery*
paper. The cb_flag audit surfaced cases where a later paper provides the definitive
or supporting evidence the discovery paper lacked (e.g. an astrometric true mass
that resolves an RV sin(i) degeneracy, or imaging that resolves an inner binary).
The schema already supports this: planet_publications.role = 'follow_up' (0 rows
used it before this seed).

Two roles are seeded:
  * 'follow_up'       — genuinely post-discovery papers (the definitive or
                        supporting evidence the discovery paper lacked).
  * 'prior_detection' — papers that PRECEDE the warehouse's discovery cite (the
                        detection or prediction that came first). Requires the
                        'prior_detection' role added by migration 013.

Safeguards: dry-run by default (--execute writes); inserts only, no deletes;
idempotent (ON CONFLICT DO NOTHING on both tables); aborts before writing if any
pl_name is not in planets_current.

Requires migrations 005 (citation graph) and 013 (prior_detection role). Run:
  python -m etl.seed_followup_citations             # dry-run (default)
  python -m etl.seed_followup_citations --execute   # apply to DATABASE_URL (.env)
"""

from __future__ import annotations

import argparse
import os

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()

# Post-discovery follow-up papers. Bibcodes verified via ADS 2026-05-21.
FOLLOWUPS: list[dict] = [
    {
        "pl_name": "HD 202206 c", "bibcode": "2017AJ....153..258B",
        "title": "HD 202206: A Circumbinary Brown Dwarf System",
        "note": "Benedict & Harrison 2017. HST FGS astrometry: true masses HD 202206 B = 0.089 Msun, "
                "HD 202206 c = 17.9 Mjup (resolves the Correia 2005 sin i degeneracy).",
    },
    {
        "pl_name": "ROXs 42 B b", "bibcode": "2017A&A...601A..65D",
        "title": "Mid-infrared characterization of the planetary-mass companion ROXs 42B b",
        "note": "Daemgen et al. 2017. Keck/NIRC2 3-5 micron photometry; atmospheric characterization, planetary mass.",
    },
    {
        "pl_name": "VHS J125601.92-125723.9 b", "bibcode": "2016ApJ...818L..12S",
        "title": "Adaptive Optics Imaging of VHS 1256-1257: A Low Mass Companion to a Brown Dwarf Binary System",
        "note": "Stone et al. 2016. Resolved the 'primary' into a close brown-dwarf binary, making the companion circumbinary.",
    },
    {
        "pl_name": "VHS J125601.92-125723.9 b", "bibcode": "2023MNRAS.519.1688D",
        "title": "On the Masses, Age, and Architecture of the VHS J1256-1257AB b System",
        "note": "Dupuy et al. 2023. Full architecture: inner BD binary a=1.96 AU, P=7.31 yr, e=0.883, total 0.141 Msun.",
    },
    {
        "pl_name": "2MASS J19383260+4603591 b", "bibcode": "2022MNRAS.511.5207E",
        "title": "Detection of two additional circumbinary planets around Kepler-451",
        "note": "Esmer et al. 2022. Revised this planet's period 416 -> 406 d and added two more planets "
                "(also the discovery paper for Kepler-451 c and d).",
    },
]

# Prior-detection papers that PRECEDE the warehouse's discovery cite. Bibcodes
# verified via ADS 2026-05-21. Requires migration 013 (prior_detection role).
PRIOR_DETECTIONS: list[dict] = [
    {
        "pl_name": "Kepler-1660 AB b", "bibcode": "2016MNRAS.455.4136B",
        "title": "A Comprehensive Study of the Kepler Triples via Eclipse Timing",
        "note": "Borkovits et al. 2016. First reported the triple nature of KIC 5095269 (= Kepler-1660AB) from ETV.",
    },
    {
        "pl_name": "Kepler-1660 AB b", "bibcode": "2017MNRAS.468.2932G",
        "title": "Evidence for a planetary mass third body orbiting the binary star KIC 5095269",
        "note": "Getley et al. 2017. Argued for a ~7.7 Mjup planet (later revised to 4.87 Mjup, coplanar, by the 2023 discovery cite).",
    },
    {
        "pl_name": "NY Vir c", "bibcode": "2012ApJ...745L..23Q",
        "title": "A Substellar Companion to the Eclipsing Polar... NY Vir",
        "note": "Qian et al. 2012. Predicted a second planet from the unexplained parabolic O-C trend; Song et al. 2019 confirmed it as NY Vir c.",
    },
    {
        "pl_name": "PSR B1620-26 b", "bibcode": "1999ApJ...523..763T",
        "title": "The Triple Pulsar System PSR B1620-26 in M4",
        "note": "Thorsett et al. 1999. Established the triple system / planetary third body; Sigurdsson et al. 2003 is the warehouse discovery cite.",
    },
]

UPSERT_PUB = """
INSERT INTO publications (bibcode, title, resolved_via, confidence)
VALUES (%(bibcode)s, %(title)s, 'manual', 'high')
ON CONFLICT (bibcode) DO NOTHING
"""

LINK = """
INSERT INTO planet_publications (pl_name, pub_id, role)
VALUES (%(pl_name)s, %(pub_id)s, %(role)s)
ON CONFLICT DO NOTHING
"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Seed audit citations (follow-up + prior-detection)")
    ap.add_argument("--execute", action="store_true", help="Apply to the DB (default is dry-run)")
    args = ap.parse_args()

    entries = ([dict(r, role="follow_up") for r in FOLLOWUPS]
               + [dict(r, role="prior_detection") for r in PRIOR_DETECTIONS])

    print(f"Citations to link: {len(entries)} "
          f"({len(FOLLOWUPS)} follow_up, {len(PRIOR_DETECTIONS)} prior_detection)")
    for r in entries:
        print(f"  [{r['role']:15s}] {r['pl_name']:26s} -> {r['bibcode']}")

    if not args.execute:
        print("\nDRY RUN — nothing written. Re-run with --execute to apply.")
        return 0

    db_url = os.environ["DATABASE_URL"]
    linked = 0
    with psycopg.connect(db_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            # Guard: every pl_name must exist, or the link is an orphan.
            cur.execute("SELECT DISTINCT pl_name FROM planets_current")
            known = {r["pl_name"] for r in cur.fetchall()}
            missing = sorted({r["pl_name"] for r in entries} - known)
            if missing:
                print("ABORT — these pl_names are not in planets_current:")
                for m in missing:
                    print(f"  {m!r}")
                return 1

            for r in entries:
                cur.execute(UPSERT_PUB, r)
                cur.execute("SELECT pub_id FROM publications WHERE bibcode = %s", (r["bibcode"],))
                pub_id = cur.fetchone()["pub_id"]
                cur.execute(LINK, {"pl_name": r["pl_name"], "pub_id": pub_id, "role": r["role"]})
                linked += cur.rowcount
                print(f"  [{r['role']}] {r['pl_name']} -> {r['bibcode']} (pub_id {pub_id})"
                      + ("" if cur.rowcount else "  [already linked]"))
        conn.commit()
    print(f"Done — {linked} new citation link(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
