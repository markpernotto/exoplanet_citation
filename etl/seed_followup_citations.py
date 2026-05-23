"""Seed planet_publications with follow-up citations identified by the cb_flag audit.

The citation resolver (resolve_citations.py) links each planet to its *discovery*
paper. The cb_flag audit surfaced cases where a later paper provides the definitive
or supporting evidence the discovery paper lacked (e.g. an astrometric true mass
that resolves an RV sin(i) degeneracy, or imaging that resolves an inner binary).
The schema already supports this: planet_publications.role = 'follow_up' (0 rows
used it before this seed).

Three roles are seeded:
  * 'follow_up'       — genuinely post-discovery papers (the definitive or
                        supporting evidence the discovery paper lacked).
  * 'prior_detection' — papers that PRECEDE the warehouse's discovery cite (the
                        detection or prediction that came first; migration 013).
  * 'characterization'— host/binary data sources we pulled measurements from
                        (component masses, distances), tagged with a `contribution`
                        ('binary_masses', 'distance', ...). Migration 014. Rule: if
                        we used a paper's data, we cite it.

Safeguards: dry-run by default (--execute writes); inserts only, no deletes;
idempotent (upsert keyed on (pl_name, pub_id, role)); aborts before writing if any
pl_name is not in planets_current.

Requires migrations 005 (citation graph), 013 (prior_detection), 014
(characterization role + contribution column). Run:
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
    # Old-discovery cohort (manual deep dive 2026-05-21): foundational 1990s systems
    # the catalog held at discovery-only depth. Bibcodes verified via ADS. The
    # atmosphere (HD 209458 b) and mutual-inclination (ups And) papers are filed
    # under CHARACTERIZATIONS below, since migration 015 harvests their measured data.
    {
        "pl_name": "HD 209458 b", "bibcode": "2000ApJ...529L..45C",
        "title": "Detection of Planetary Transits Across a Sun-like Star",
        "note": "Charbonneau et al. 2000. Independent detection of the transits (simultaneous with the "
                "Henry 2000 discovery cite); first radius and orbital inclination, hence true mass.",
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

# Data-source papers (role='characterization'). We pulled measured values from
# these, so they must be credited: binary component masses / distances ->
# binary_companions, host_distances_manual; atmospheric detections ->
# planet_atmospheres; mutual inclinations -> system_orbital_geometry. Bibcodes
# verified via ADS 2026-05-21. Requires migration 014 (and 015 for the atmosphere
# and mutual-inclination data these supply).
CHARACTERIZATIONS: list[dict] = [
    {"pl_names": ["DE CVn b"], "bibcode": "2007A&A...466.1031V", "contribution": "binary_masses",
     "title": "DE CVn: A bright, eclipsing red dwarf - white dwarf binary"},
    {"pl_names": ["RR Cae b"], "bibcode": "2007MNRAS.376..919M", "contribution": "binary_masses",
     "title": "The mass and radius of the M-dwarf in the short period eclipsing binary RR Caeli"},
    {"pl_names": ["NY Vir b", "NY Vir c"], "bibcode": "2007A&A...471..605V", "contribution": "binary_masses",
     "title": "The binary properties of the pulsating subdwarf B eclipsing binary PG 1336-018 (NY Vir)"},
    {"pl_names": ["2MASS J19383260+4603591 b", "Kepler-451 c", "Kepler-451 d"],
     "bibcode": "2012ApJ...753..101B", "contribution": "binary_masses",
     "title": "The Romer Delay and Mass Ratio of the sdB+dM Binary 2M 1938+4603 from Kepler Eclipse Timings"},
    {"pl_names": ["HU Aqr AB b", "HU Aqr AB c"], "bibcode": "2011A&A...531A..34S", "contribution": "binary_masses",
     "title": "Dissecting the donor star in the eclipsing polar HU Aquarii"},
    {"pl_names": ["NSVS 14256825 b"], "bibcode": "2012MNRAS.423..478A", "contribution": "binary_masses",
     "title": "A photometric and spectroscopic study of NSVS 14256825: the second sdOB+dM eclipsing binary"},
    {"pl_names": ["MXB 1658-298 b"], "bibcode": "2018MNRAS.481L..94P", "contribution": "binary_masses",
     "title": "Measuring masses in low mass X-ray binaries via X-ray spectroscopy: the case of MXB 1659-298"},
    {"pl_names": ["ROXs 42 B b"], "bibcode": "2014ApJ...781...20K", "contribution": "binary_masses",
     "title": "Three Wide Planetary-mass Companions to FW Tau, ROXs 12, and ROXs 42B"},
    {"pl_names": ["MXB 1658-298 b"], "bibcode": "2008ApJS..179..360G", "contribution": "distance",
     "title": "Thermonuclear (Type-I) X-Ray Bursts Observed by the Rossi X-ray Timing Explorer"},
    {"pl_names": ["PSR B1620-26 b"], "bibcode": "2015ApJ...808...11N", "contribution": "distance",
     "title": "On the distance of the globular cluster M4 (NGC 6121) using RR Lyrae stars. II."},
    # Old-discovery cohort (manual deep dive 2026-05-21); data harvested in migration 015.
    {"pl_names": ["HD 209458 b"], "bibcode": "2002ApJ...568..377C", "contribution": "atmosphere",
     "title": "Detection of an Extrasolar Planet Atmosphere"},
    {"pl_names": ["HD 209458 b"], "bibcode": "2003Natur.422..143V", "contribution": "atmosphere",
     "title": "An extended upper atmosphere around the extrasolar planet HD209458b"},
    {"pl_names": ["HD 209458 b"], "bibcode": "2010Natur.465.1049S", "contribution": "atmosphere",
     "title": "The orbital motion, absolute mass and high-altitude winds of exoplanet HD209458b"},
    {"pl_names": ["51 Peg b"], "bibcode": "2017AJ....153..138B", "contribution": "atmosphere",
     "title": "Discovery of Water at High Spectral Resolution in the Atmosphere of 51 Peg b"},
    {"pl_names": ["HD 189733 b"], "bibcode": "2008ApJ...673L..87R", "contribution": "atmosphere",
     "title": "Sodium Absorption from the Exoplanetary Atmosphere of HD 189733b"},
    {"pl_names": ["55 Cnc e"], "bibcode": "2024Natur.630..609H", "contribution": "atmosphere",
     "title": "A secondary atmosphere on the rocky exoplanet 55 Cancri e"},
    {"pl_names": ["HD 189733 b"], "bibcode": "2013MNRAS.436L..35B", "contribution": "atmosphere",
     "title": "Detection of water absorption in the day side atmosphere of HD 189733 b"},
    {"pl_names": ["HD 189733 b"], "bibcode": "2013A&A...554A..82D", "contribution": "atmosphere",
     "title": "Detection of carbon monoxide in the high-resolution day-side spectrum of HD 189733b"},
    {"pl_names": ["HD 209458 b"], "bibcode": "2013ApJ...774...95D", "contribution": "atmosphere",
     "title": "Infrared Transmission Spectroscopy of the Exoplanets HD 209458b and XO-1b Using WFC3"},
    {"pl_names": ["ups And c", "ups And d"], "bibcode": "2010ApJ...715.1203M", "contribution": "mutual_inclination",
     "title": "New Observational Constraints on the upsilon Andromedae System"},
    {"pl_names": ["HD 189733 b"], "bibcode": "2006ApJ...641L..57B", "contribution": "binary_separation",
     "title": "A Stellar Companion in the HD 189733 System with a Known Transiting Extrasolar Planet"},
    {"pl_names": ["ups And b", "ups And c", "ups And d"], "bibcode": "2002ApJ...572L..79L", "contribution": "binary_separation",
     "title": "A Distant Stellar Companion in the upsilon Andromedae System"},
    # JWST/HST-era landmark atmospheres (manual deep dive 2026-05-21); data in migration 016.
    {"pl_names": ["WASP-39 b"], "bibcode": "2023Natur.614..649J", "contribution": "atmosphere",
     "title": "Identification of carbon dioxide in an exoplanet atmosphere"},
    {"pl_names": ["WASP-39 b"], "bibcode": "2023Natur.617..483T", "contribution": "atmosphere",
     "title": "Photochemically produced SO2 in the atmosphere of WASP-39b"},
    {"pl_names": ["WASP-96 b"], "bibcode": "2018Natur.557..526N", "contribution": "atmosphere",
     "title": "An absolute sodium abundance for a cloud-free hot Saturn exoplanet"},
    {"pl_names": ["K2-18 b"], "bibcode": "2023ApJ...956L..13M", "contribution": "atmosphere",
     "title": "Carbon-bearing Molecules in a Possible Hycean Atmosphere"},
    # Orbital-geometry citation backfill (manual deep dive 2026-05-22). Migration 010
    # bulk-seeded system_orbital_geometry for these systems but never linked the
    # source papers, so the Atlas displayed mutual inclinations it did not cite. Each
    # bibcode below is the recorded geometry source, re-verified via ADS, EXCEPT the
    # four Kepler TTV systems that migration 010 mis-attributed to Fabrycky et al.
    # 2014 (a statistical architecture study across 365 systems, not a per-system
    # source). Their correct per-system sources, re-verified via ADS, are: Kepler-11
    # -> Lissauer et al. 2013; Kepler-9 -> Borsato et al. 2014 (TRADES N-body fit);
    # Kepler-30 -> Sanchis-Ojeda et al. 2012 (coplanar + spin-aligned); Kepler-36 ->
    # Carter et al. 2012 (dynamical solution). Migration 017 corrects
    # system_orbital_geometry.bibcode for all four to match. (Several of these
    # bibcodes -- Gillon 2017, Rivera 2010, Sanchis-Ojeda 2012, Carter 2012 -- are
    # also discovery cites; the characterization role + mutual_inclination
    # contribution make each a distinct, non-duplicate link.)
    {"pl_names": ["TRAPPIST-1 b", "TRAPPIST-1 c", "TRAPPIST-1 d", "TRAPPIST-1 e",
                  "TRAPPIST-1 f", "TRAPPIST-1 g", "TRAPPIST-1 h"],
     "bibcode": "2017Natur.542..456G", "contribution": "mutual_inclination",
     "title": "Seven temperate terrestrial planets around the nearby ultracool dwarf star TRAPPIST-1"},
    # Agol et al. 2021: refined sky-plane inclinations (photodynamic fit) now the
    # value source for TRAPPIST-1 geometry (migration 021). Gillon 2017 kept above
    # as the paper that established the flat architecture.
    {"pl_names": ["TRAPPIST-1 b", "TRAPPIST-1 c", "TRAPPIST-1 d", "TRAPPIST-1 e",
                  "TRAPPIST-1 f", "TRAPPIST-1 g", "TRAPPIST-1 h"],
     "bibcode": "2021PSJ.....2....1A", "contribution": "mutual_inclination",
     "title": "Refining the Transit-timing and Photometric Analysis of TRAPPIST-1: "
              "Masses, Radii, Densities, Dynamics, and Ephemerides"},
    {"pl_names": ["HR 8799 b", "HR 8799 c", "HR 8799 d", "HR 8799 e"],
     "bibcode": "2018AJ....156..192W", "contribution": "mutual_inclination",
     "title": "Dynamical Constraints on the HR 8799 Planets with GPI"},
    {"pl_names": ["bet Pic b", "bet Pic c"],
     "bibcode": "2020A&A...642L...2N", "contribution": "mutual_inclination",
     "title": "Direct confirmation of the radial-velocity planet β Pictoris c"},
    {"pl_names": ["GJ 876 b", "GJ 876 c", "GJ 876 d", "GJ 876 e"],
     "bibcode": "2010ApJ...719..890R", "contribution": "mutual_inclination",
     "title": "The Lick-Carnegie Exoplanet Survey: a Uranus-Mass Fourth Planet for "
              "GJ 876 in an Extrasolar Laplace Configuration"},
    {"pl_names": ["Kepler-11 b", "Kepler-11 c", "Kepler-11 d", "Kepler-11 e",
                  "Kepler-11 f", "Kepler-11 g"],
     "bibcode": "2013ApJ...770..131L", "contribution": "mutual_inclination",
     "title": "All Six Planets Known to Orbit Kepler-11 Have Low Densities"},
    {"pl_names": ["Kepler-9 b", "Kepler-9 c"],
     "bibcode": "2014A&A...571A..38B", "contribution": "mutual_inclination",
     "title": "TRADES: A new software to derive orbital parameters from observed "
              "transit times and radial velocities. Revisiting Kepler-11 and Kepler-9"},
    {"pl_names": ["Kepler-30 b", "Kepler-30 c", "Kepler-30 d"],
     "bibcode": "2012Natur.487..449S", "contribution": "mutual_inclination",
     "title": "Alignment of the stellar spin with the orbits of a three-planet system"},
    {"pl_names": ["Kepler-36 b", "Kepler-36 c"],
     "bibcode": "2012Sci...337..556C", "contribution": "mutual_inclination",
     "title": "Kepler-36: A Pair of Planets with Neighboring Orbits and Dissimilar Densities"},
    # Orbital-geometry citation backfill, round 2 (manual deep dive 2026-05-22).
    # The remaining migration-010 systems. Each bibcode re-verified via ADS;
    # seven are the recorded source and check out as the per-system
    # architecture/dynamical paper. WASP-47's recorded bibcode was a typo
    # (2017AJ....154..237B -> ...V, Vanderburg et al. 2017), corrected in
    # migration 018. Several recorded bibcodes here are also discovery cites; the
    # characterization role + mutual_inclination contribution keep them distinct.
    # Kepler-90 (geometry hostname KOI-351): migration 019 reconciles its geometry
    # pl_names to the catalog form ('Kepler-90 b'..'h' -> 'KOI-351 b'..'h'; the
    # eighth stays 'Kepler-90 i') and repoints the source off Rowe et al. 2014
    # (bulk validation paper) to the dedicated papers. Cite against the catalog
    # keys: KOI-351 b-h -> Cabrera et al. 2014; Kepler-90 i -> Shallue &
    # Vanderburg 2018 (which discovered it).
    {"pl_names": ["KOI-351 b", "KOI-351 c", "KOI-351 d", "KOI-351 e",
                  "KOI-351 f", "KOI-351 g", "KOI-351 h"],
     "bibcode": "2014ApJ...781...18C", "contribution": "mutual_inclination",
     "title": "The Planetary System to KIC 11442793: A Compact Analogue to the Solar System"},
    {"pl_names": ["Kepler-90 i"],
     "bibcode": "2018AJ....155...94S", "contribution": "mutual_inclination",
     "title": "Identifying Exoplanets with Deep Learning: A Five-planet Resonant Chain "
              "around Kepler-80 and an Eighth Planet around Kepler-90"},
    {"pl_names": ["K2-138 b", "K2-138 c", "K2-138 d", "K2-138 e", "K2-138 f"],
     "bibcode": "2018AJ....155...57C", "contribution": "mutual_inclination",
     "title": "The K2-138 System: A Near-resonant Chain of Five Sub-Neptune Planets "
              "Discovered by Citizen Scientists"},
    {"pl_names": ["Kepler-186 b", "Kepler-186 c", "Kepler-186 d", "Kepler-186 e", "Kepler-186 f"],
     "bibcode": "2014Sci...344..277Q", "contribution": "mutual_inclination",
     "title": "An Earth-Sized Planet in the Habitable Zone of a Cool Star"},
    {"pl_names": ["Kepler-223 b", "Kepler-223 c", "Kepler-223 d", "Kepler-223 e"],
     "bibcode": "2016Natur.533..509M", "contribution": "mutual_inclination",
     "title": "A resonant chain of four transiting, sub-Neptune planets"},
    {"pl_names": ["Kepler-419 b", "Kepler-419 c"],
     "bibcode": "2014ApJ...791...89D", "contribution": "mutual_inclination",
     "title": "Large Eccentricity, Low Mutual Inclination: The Three-dimensional "
              "Architecture of a Hierarchical System of Giant Planets"},
    {"pl_names": ["Kepler-444 b", "Kepler-444 c", "Kepler-444 d", "Kepler-444 e", "Kepler-444 f"],
     "bibcode": "2015ApJ...799..170C", "contribution": "mutual_inclination",
     "title": "An Ancient Extrasolar System with Five Sub-Earth-size Planets"},
    {"pl_names": ["Kepler-56 b", "Kepler-56 c", "Kepler-56 d"],
     "bibcode": "2013Sci...342..331H", "contribution": "mutual_inclination",
     "title": "Stellar Spin-Orbit Misalignment in a Multiplanet System"},
    {"pl_names": ["TOI-178 b", "TOI-178 c", "TOI-178 d", "TOI-178 e", "TOI-178 f", "TOI-178 g"],
     "bibcode": "2021A&A...649A..26L", "contribution": "mutual_inclination",
     "title": "Six transiting planets and a chain of Laplace resonances in TOI-178"},
    {"pl_names": ["WASP-47 b", "WASP-47 c", "WASP-47 d", "WASP-47 e"],
     "bibcode": "2017AJ....154..237V", "contribution": "mutual_inclination",
     "title": "Precise Masses in the WASP-47 System"},
    # TRAPPIST-1 JWST atmosphere deep dive (manual, 2026-05-22; migration 020).
    # All are atmosphere constraints / NON-detections (no molecule detected on any
    # TRAPPIST-1 planet), recorded as ruled_out / inconclusive in planet_atmospheres.
    # contribution='atmosphere' still applies: we took an atmospheric constraint from
    # each paper. Bibcodes verified via ADS. The observation campaigns themselves are
    # already in planet_atmospheric_observations (NASA EA spectra bulk load).
    {"pl_names": ["TRAPPIST-1 b"], "bibcode": "2023Natur.618...39G", "contribution": "atmosphere",
     "title": "Thermal emission from the Earth-sized exoplanet TRAPPIST-1 b using JWST"},
    {"pl_names": ["TRAPPIST-1 b"], "bibcode": "2025NatAs...9..358D", "contribution": "atmosphere",
     "title": "Combined analysis of the 12.8 and 15 micron JWST/MIRI eclipse observations of TRAPPIST-1 b"},
    {"pl_names": ["TRAPPIST-1 c"], "bibcode": "2023Natur.620..746Z", "contribution": "atmosphere",
     "title": "No thick carbon dioxide atmosphere on the rocky exoplanet TRAPPIST-1 c"},
    {"pl_names": ["TRAPPIST-1 c"], "bibcode": "2025ApJ...979L...5R", "contribution": "atmosphere",
     "title": "Promise and Peril: Stellar Contamination and Strict Limits on the Atmosphere "
              "Composition of TRAPPIST-1 c from JWST NIRISS Transmission Spectra"},
    {"pl_names": ["TRAPPIST-1 c"], "bibcode": "2025ApJ...979L..19R", "contribution": "atmosphere",
     "title": "Stellar Contamination Correction Using Back-to-back Transits of TRAPPIST-1 b and c"},
    {"pl_names": ["TRAPPIST-1 d"], "bibcode": "2025ApJ...989..181P", "contribution": "atmosphere",
     "title": "Strict Limits on Potential Secondary Atmospheres on the Temperate Rocky "
              "Exo-Earth TRAPPIST-1 d"},
    {"pl_names": ["TRAPPIST-1 e"], "bibcode": "2025ApJ...990L..52E", "contribution": "atmosphere",
     "title": "JWST-TST DREAMS: NIRSpec/PRISM Transmission Spectroscopy of the Habitable "
              "Zone Planet TRAPPIST-1 e"},
]

UPSERT_PUB = """
INSERT INTO publications (bibcode, title, resolved_via, confidence)
VALUES (%(bibcode)s, %(title)s, 'manual', 'high')
ON CONFLICT (bibcode) DO NOTHING
"""

LINK = """
INSERT INTO planet_publications (pl_name, pub_id, role, contribution)
VALUES (%(pl_name)s, %(pub_id)s, %(role)s, %(contribution)s)
ON CONFLICT (pl_name, pub_id, role) DO UPDATE SET contribution = EXCLUDED.contribution
"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Seed audit citations (follow-up + prior-detection)")
    ap.add_argument("--execute", action="store_true", help="Apply to the DB (default is dry-run)")
    args = ap.parse_args()

    entries: list[dict] = []
    for r in FOLLOWUPS:
        entries.append({"pl_name": r["pl_name"], "bibcode": r["bibcode"], "title": r["title"],
                        "role": "follow_up", "contribution": r.get("contribution")})
    for r in PRIOR_DETECTIONS:
        entries.append({"pl_name": r["pl_name"], "bibcode": r["bibcode"], "title": r["title"],
                        "role": "prior_detection", "contribution": r.get("contribution")})
    for r in CHARACTERIZATIONS:
        for pl in r["pl_names"]:
            entries.append({"pl_name": pl, "bibcode": r["bibcode"], "title": r["title"],
                            "role": "characterization", "contribution": r.get("contribution")})

    n_char = sum(len(r["pl_names"]) for r in CHARACTERIZATIONS)
    print(f"Citations to link: {len(entries)} ({len(FOLLOWUPS)} follow_up, "
          f"{len(PRIOR_DETECTIONS)} prior_detection, {n_char} characterization)")
    for r in entries:
        contrib = f"  [{r['contribution']}]" if r["contribution"] else ""
        print(f"  [{r['role']:15s}] {r['pl_name']:30s} -> {r['bibcode']}{contrib}")

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
                cur.execute(LINK, {"pl_name": r["pl_name"], "pub_id": pub_id,
                                   "role": r["role"], "contribution": r["contribution"]})
                linked += cur.rowcount
                print(f"  [{r['role']}] {r['pl_name']} -> {r['bibcode']} (pub_id {pub_id})")
        conn.commit()
    print(f"Done — {linked} citation link(s) upserted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
