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
    # 1990s foundational cohort (manual deep dive, 2026-05-24; migration 047+). PSR B1257+12:
    # Wolszczan 1994 confirmed planets c & d via their 3:2-resonance perturbations (it is
    # already the discovery cite for the moon-mass inner planet b), so it is a genuine
    # post-discovery confirmation for c & d. Bibcodes verified via ADS.
    {
        "pl_name": "PSR B1257+12 c", "bibcode": "1994Sci...264..538W",
        "title": "Confirmation of Earth-Mass Planets Orbiting the Millisecond Pulsar PSR B1257+12",
        "note": "Wolszczan 1994. Confirmed planets c & d by detecting their predicted ~3:2 resonance "
                "perturbations, and discovered the moon-mass inner planet b.",
    },
    {
        "pl_name": "PSR B1257+12 d", "bibcode": "1994Sci...264..538W",
        "title": "Confirmation of Earth-Mass Planets Orbiting the Millisecond Pulsar PSR B1257+12",
        "note": "Wolszczan 1994. Confirmed planets c & d by detecting their predicted ~3:2 resonance "
                "perturbations, and discovered the moon-mass inner planet b.",
    },
    # HD 168443 b (1990s cohort, 2026-05-24): inner planet of the HD 168443 planet + brown-dwarf
    # system. Marcy 1999 (b) / Marcy 2001 (c) are the discovery cites (m sin i already catalogued).
    # Reffert & Quirrenbach 2011 analyzed the system astrometrically but did NOT detect b's orbit,
    # so b keeps its RV m sin i -- recorded here as a follow_up. (c's astrometric true mass is
    # harvested in migration 049 and lives in CHARACTERIZATIONS below.) Bibcode via ADS.
    {
        "pl_name": "HD 168443 b", "bibcode": "2011A&A...527A.140R",
        "title": "Mass constraints on substellar companion candidates from the re-reduced Hipparcos "
                 "intermediate astrometric data: nine confirmed planets and two confirmed brown dwarfs",
        "note": "Reffert & Quirrenbach 2011. Astrometric study of the HD 168443 system; b's orbit was "
                "not detected astrometrically, so its RV m sin i (~8 Mjup) applies, while the outer "
                "companion c is confirmed as a brown dwarf.",
    },
    # rho CrB b (1990s cohort, 2026-05-24): a hot Jupiter (Noyes 1997) once claimed to be a
    # low-mass star seen nearly face-on (HIPPARCOS astrometry: Reffert & Quirrenbach 2011 fit
    # i = 0.4 deg, ~170 Mjup). That is refuted by the system architecture: rho CrB now hosts
    # small planets (c super-Neptune, d Neptune, e super-Earth) that could not survive around a
    # 0.17 Msun stellar companion at 0.23 au. So b is a genuine ~1.1 Mjup planet; we do NOT
    # record the face-on stellar mass. Brewer 2023 (EXPRES IV) establishes the 4-planet
    # architecture and explicitly calls b a hot Jupiter. Bibcode via ADS.
    {
        "pl_name": "rho CrB b", "bibcode": "2023AJ....166...46B",
        "title": "EXPRES. IV. Two Additional Planets Orbiting rho Coronae Borealis Reveal "
                 "Uncommon System Architecture",
        "note": "Brewer et al. 2023. Reveals rho CrB as a 4-planet system with b as the hot Jupiter; "
                "the small inner planets confirm b is a genuine ~1.1 Mjup planet and disfavor the "
                "earlier face-on-star astrometric interpretation (Reffert & Quirrenbach 2011, ~170 Mjup).",
    },
    # 16 Cyg B b (1990s cohort, 2026-05-24): the record-eccentricity (e~0.63-0.68) planet.
    # Both 1997 papers attribute that eccentricity to Kozai-Lidov forcing by the wide
    # companion star 16 Cyg A (a genuine post-discovery dynamical characterization). The
    # discovery orbital solution itself (Cochran et al. 1997) is already the catalog source.
    # Bibcodes verified via ADS.
    {
        "pl_name": "16 Cyg B b", "bibcode": "1997Natur.386..254H",
        "title": "Chaotic variations in the eccentricity of the planet orbiting 16 Cygni B",
        "note": "Holman, Touma & Tremaine 1997. The record eccentricity arises from Kozai-Lidov cycles "
                "driven by the wide companion star 16 Cyg A, requiring a planet-binary mutual "
                "inclination of 45-135 deg; e oscillates over 10^7-10^9 yr.",
    },
    {
        "pl_name": "16 Cyg B b", "bibcode": "1997ApJ...477L.103M",
        "title": "The High Eccentricity of the Planet Orbiting 16 Cygni B",
        "note": "Mazeh, Krymolowski & Rosenfeld 1997. Independently attributes the high eccentricity to "
                "secular forcing by 16 Cyg A; requires a relative inclination of at least ~60 deg "
                "between the planet and wide-binary orbital planes.",
    },
    # 1990s cohort light citation pass (2026-05-24): the remaining slate systems had no Gaia DR3
    # astrometric orbit and no recent dedicated literature, so these are the genuine post-discovery
    # follow-ups (system-level dynamics + astrometric mass bounds). HD 217107 was skipped: it is
    # already fully cited (b Fischer 1999 + c Vogt 2005) with no clean new follow-up. Bibcodes via ADS.
    {
        "pl_name": "47 UMa b", "bibcode": "2010MNRAS.403..731G",
        "title": "A Bayesian periodogram finds evidence for three planets in 47 Ursae Majoris",
        "note": "Gregory & Fischer 2010. Joint three-planet dynamical solution for the 47 UMa system "
                "(also the discovery cite for 47 UMa d), refining b's and c's orbits.",
    },
    {
        "pl_name": "47 UMa c", "bibcode": "2010MNRAS.403..731G",
        "title": "A Bayesian periodogram finds evidence for three planets in 47 Ursae Majoris",
        "note": "Gregory & Fischer 2010. Joint three-planet dynamical solution refining the 47 UMa orbits.",
    },
    {
        "pl_name": "70 Vir b", "bibcode": "2011A&A...527A.140R",
        "title": "Mass constraints on substellar companion candidates from the re-reduced Hipparcos "
                 "intermediate astrometric data: nine confirmed planets and two confirmed brown dwarfs",
        "note": "Reffert & Quirrenbach 2011. Re-reduced HIPPARCOS astrometry bounds the companion mass "
                "at <= 45.5 Mjup (no orbit detected), keeping 70 Vir b in the planetary/substellar "
                "regime -- relevant given its early brown-dwarf-candidate history.",
    },
    {
        "pl_name": "HD 222582 b", "bibcode": "2011A&A...527A.140R",
        "title": "Mass constraints on substellar companion candidates from the re-reduced Hipparcos "
                 "intermediate astrometric data: nine confirmed planets and two confirmed brown dwarfs",
        "note": "Reffert & Quirrenbach 2011. Re-reduced HIPPARCOS astrometry bounds the companion mass "
                "at <= 105.9 Mjup (no orbit detected), confirming this eccentric (e=0.73) companion is substellar.",
    },
    # "Wild Orbits" theme (2026-05-24): dynamical-origin follow-ups for the extreme-eccentricity
    # planets (the eccentricity itself is already catalogued; these explain it). Bibcodes via ADS.
    {
        "pl_name": "HD 80606 b", "bibcode": "2003ApJ...589..605W",
        "title": "Planet Migration and Binary Companions: The Case of HD 80606b",
        "note": "Wu & Murray 2003. The e=0.93 orbit arises from Kozai-Lidov migration driven by the "
                "wide stellar companion HD 80607 combined with tidal dissipation (requires a high "
                "initial mutual inclination, ~85 deg, between the planet and binary orbits).",
    },
    {
        "pl_name": "HD 20782 b", "bibcode": "2016ApJ...821...65K",
        "title": "Evidence for Reflected Light from the Most Eccentric Exoplanet Known",
        "note": "Kane et al. 2016. Refined the orbit to e=0.96 -- the most eccentric known exoplanet -- "
                "with periastron radial velocities; confirmed a planetary (not stellar) mass via "
                "combined Keplerian + HIPPARCOS astrometry; and found tentative reflected-light phase "
                "variations near periastron in MOST photometry (no firm geometric albedo derived).",
    },
    {
        "pl_name": "nu Oct A b", "bibcode": "2025Natur.641..866C",
        "title": "A retrograde planet in a tight binary star system with a white dwarf",
        "note": "Cheng et al. 2025. New radial velocities confirm the planet on a RETROGRADE, nearly "
                "coplanar S-type orbit midway between the stars of this 2.6 AU binary; AO imaging shows "
                "the companion is a white dwarf. The tight binary rules out coeval formation, so the "
                "planet is likely second-generation (from the WD progenitor's shed material) or captured "
                "from a circumbinary orbit.",
    },
    # 1990s cohort exhaustive finish (2026-05-24): the last three discovery-only systems. Each gets
    # its genuine post-discovery follow-up (two-planet solution refining the inner planet, or an
    # astrometric mass bound). Closes the cohort at 11/11 systems with recovered provenance. Bibcodes via ADS.
    {
        "pl_name": "HD 187123 b", "bibcode": "2009ApJ...693.1084W",
        "title": "Ten New and Updated Multiplanet Systems and a Survey of Exoplanetary Systems",
        "note": "Wright et al. 2009. The two-planet solution that discovered the long-period HD 187123 c "
                "and refined the orbit of the inner hot Jupiter b.",
    },
    {
        "pl_name": "HD 210277 b", "bibcode": "2011A&A...527A.140R",
        "title": "Mass constraints on substellar companion candidates from the re-reduced Hipparcos "
                 "intermediate astrometric data: nine confirmed planets and two confirmed brown dwarfs",
        "note": "Reffert & Quirrenbach 2011. Re-reduced HIPPARCOS astrometry bounds the companion mass at "
                "<= 30.3 Mjup (no orbit detected), confirming HD 210277 b is planetary/substellar "
                "(RV m sin i = 1.29 Mjup).",
    },
    {
        "pl_name": "HD 217107 b", "bibcode": "2005ApJ...632..638V",
        "title": "Five New Multicomponent Planetary Systems",
        "note": "Vogt et al. 2005. The two-planet solution that discovered the long-period HD 217107 c "
                "and refined the orbit of the inner hot Jupiter b.",
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
    {
        "pl_name": "Kepler-1520 b", "bibcode": "2012ApJ...752....1R",
        "title": "Possible Disintegrating Short-period Super-Mercury Orbiting KIC 12557548",
        "note": "Rappaport et al. 2012. The actual discovery of the disintegrating planet (KIC 12557548 b), "
                "four years before the Morton et al. 2016 validation the warehouse uses as the discovery cite.",
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
    # HR 8799 atmosphere deep dive (manual, 2026-05-23; migration 023). Real
    # molecule detections in the four directly-imaged giants. Bibcodes verified via
    # ADS. Konopacky 2013 (c) and Barman 2015 (b) are the landmark ground-based
    # detections; Xuan 2026 is the JWST/NIRSpec compositional study covering all four.
    {"pl_names": ["HR 8799 c"], "bibcode": "2013Sci...339.1398K", "contribution": "atmosphere",
     "title": "Detection of Carbon Monoxide and Water Absorption Lines in an Exoplanet Atmosphere"},
    {"pl_names": ["HR 8799 b"], "bibcode": "2015ApJ...804...61B", "contribution": "atmosphere",
     "title": "Simultaneous Detection of Water, Methane, and Carbon Monoxide in the "
              "Atmosphere of Exoplanet HR8799b"},
    {"pl_names": ["HR 8799 b", "HR 8799 c", "HR 8799 d", "HR 8799 e"],
     "bibcode": "2026ApJ..1000...27X", "contribution": "atmosphere",
     "title": "The Compositions of the HR 8799 Planets Reflect Accretion of Both Solids "
              "and Metal-enriched Gas"},
    # beta Pictoris b deep dive (manual, 2026-05-23; migration 025). CO + spin
    # (Snellen 2014) and H2O + C/O (GRAVITY 2020). Molecule detections ->
    # planet_atmospheres; spin + C/O -> planet_derived_measurements (provenance in
    # those rows' bibcode). Bibcodes verified via ADS.
    {"pl_names": ["bet Pic b"], "bibcode": "2014Natur.509...63S", "contribution": "atmosphere",
     "title": "Fast spin of the young extrasolar planet β Pictoris b"},
    {"pl_names": ["bet Pic b"], "bibcode": "2020A&A...633A.110G", "contribution": "atmosphere",
     "title": "Peering into the formation history of β Pictoris b with VLTI/GRAVITY "
              "long-baseline interferometry"},
    # GJ 876 deep dive (manual, 2026-05-23). Non-transiting M-dwarf RV system, so no
    # atmospheres; the value-add is the dynamical characterization. Benedict 2002 is
    # the FIRST astrometrically-determined mass of any exoplanet (GJ 876 b, HST FGS3),
    # which is why b's catalog mass is a true mass and not m sin i. Nelson 2016 is the
    # empirical 3-D Laplace-resonance architecture (complements the Rivera 2010
    # geometry already cited). Bibcodes verified via ADS.
    {"pl_names": ["GJ 876 b"], "bibcode": "2002ApJ...581L.115B", "contribution": "mass",
     "title": "A Mass for the Extrasolar Planet Gliese 876b Determined from Hubble Space "
              "Telescope Fine Guidance Sensor 3 Astrometry and High-Precision Radial Velocities"},
    {"pl_names": ["GJ 876 b", "GJ 876 c", "GJ 876 d", "GJ 876 e"],
     "bibcode": "2016MNRAS.455.2484N", "contribution": "mutual_inclination",
     "title": "An empirically derived three-dimensional Laplace resonance in the "
              "Gliese 876 planetary system"},
    # Kepler-11 deep dive (manual, 2026-05-23). Faint transiting multi, no atmosphere
    # spectroscopy; masses/radii/densities are in the catalog. Value-add: Bedell et al.
    # 2017 re-derived the benchmark planet masses and radii from a precise solar-twin
    # stellar characterization of the host. (Lopez et al. 2012 modelled the H/He
    # envelopes; harvest those per-planet fractions into planet_derived_measurements
    # in a follow-up once the table is in hand.) Bibcode verified via ADS.
    {"pl_names": ["Kepler-11 b", "Kepler-11 c", "Kepler-11 d", "Kepler-11 e",
                  "Kepler-11 f", "Kepler-11 g"],
     "bibcode": "2017ApJ...839...94B", "contribution": "mass",
     "title": "Kepler-11 is a Solar Twin: Revising the Masses and Radii of Benchmark "
              "Planets via Precise Stellar Characterization"},
    # Lopez et al. 2012: Kepler-11 envelope/volatile fractions, now harvested into
    # planet_derived_measurements (migration 027), so the paper is cited for the data
    # taken. b-f only (g not modelled). contribution='composition'.
    {"pl_names": ["Kepler-11 b", "Kepler-11 c", "Kepler-11 d", "Kepler-11 e", "Kepler-11 f"],
     "bibcode": "2012ApJ...761...59L", "contribution": "composition",
     "title": "How Thermal Evolution and Mass-loss Sculpt Populations of Super-Earths "
              "and Sub-Neptunes: Application to the Kepler-11 System and Beyond"},
    # WASP-121 b deep dive (manual, 2026-05-23; migration 028). Benchmark ultra-hot
    # Jupiter; a metal zoo + H2O + SiO. Bibcodes verified via ADS.
    {"pl_names": ["WASP-121 b"], "bibcode": "2017Natur.548...58E", "contribution": "atmosphere",
     "title": "An ultrahot gas-giant exoplanet with a stratosphere"},
    {"pl_names": ["WASP-121 b"], "bibcode": "2018AJ....156..283E", "contribution": "atmosphere",
     "title": "An Optical Transmission Spectrum for the Ultra-hot Jupiter WASP-121b "
              "Measured with the Hubble Space Telescope"},
    {"pl_names": ["WASP-121 b"], "bibcode": "2019AJ....158...91S", "contribution": "atmosphere",
     "title": "The Hubble Space Telescope PanCET Program: Exospheric Mg II and Fe II in the "
              "Near-ultraviolet Transmission Spectrum of WASP-121b Using Jitter Decorrelation"},
    {"pl_names": ["WASP-121 b"], "bibcode": "2020A&A...641A.123H", "contribution": "atmosphere",
     "title": "Hot Exoplanet Atmospheres Resolved with Transit Spectroscopy (HEARTS). IV. "
              "A spectral inventory of atoms and molecules in the high-resolution transmission "
              "spectrum of WASP-121 b"},
    {"pl_names": ["WASP-121 b"], "bibcode": "2025AJ....169..341G", "contribution": "atmosphere",
     "title": "WASP-121 b's Transmission Spectrum Observed with JWST/NIRSpec G395H Reveals "
              "Thermal Dissociation and SiO in the Atmosphere"},
    # GJ 1214 b deep dive (manual, 2026-05-23; migration 029). Featureless archetype
    # sub-Neptune: clouds (Kreidberg 2014), JWST phase curve metal-rich/reflective +
    # H2O + albedo/temps (Kempton 2023), tentative CO2/CH4 (Schlawin 2024).
    {"pl_names": ["GJ 1214 b"], "bibcode": "2014Natur.505...69K", "contribution": "atmosphere",
     "title": "Clouds in the atmosphere of the super-Earth exoplanet GJ1214b"},
    {"pl_names": ["GJ 1214 b"], "bibcode": "2023Natur.620...67K", "contribution": "atmosphere",
     "title": "A reflective, metal-rich atmosphere for GJ 1214b from its JWST phase curve"},
    {"pl_names": ["GJ 1214 b"], "bibcode": "2024ApJ...974L..33S", "contribution": "atmosphere",
     "title": "Possible Carbon Dioxide above the Thick Aerosols of GJ 1214 b"},
    # WASP-107 b deep dive (manual, 2026-05-23; migration 030). Warm super-puff
    # Neptune; He + H2O + CH4 + CO + CO2 + SO2. Bibcodes verified via ADS.
    {"pl_names": ["WASP-107 b"], "bibcode": "2018Natur.557...68S", "contribution": "atmosphere",
     "title": "Helium in the eroding atmosphere of an exoplanet"},
    {"pl_names": ["WASP-107 b"], "bibcode": "2018ApJ...858L...6K", "contribution": "atmosphere",
     "title": "Water, High-altitude Condensates, and Possible Methane Depletion in the "
              "Atmosphere of the Warm Super-Neptune WASP-107b"},
    {"pl_names": ["WASP-107 b"], "bibcode": "2024Natur.625...51D", "contribution": "atmosphere",
     "title": "SO2, silicate clouds, but no CH4 detected in a warm Neptune"},
    {"pl_names": ["WASP-107 b"], "bibcode": "2024Natur.630..831S", "contribution": "atmosphere",
     "title": "A warm Neptune's methane reveals core mass and vigorous atmospheric mixing"},
    {"pl_names": ["WASP-107 b"], "bibcode": "2024Natur.630..836W", "contribution": "atmosphere",
     "title": "A high internal heat flux and large core in a warm Neptune exoplanet"},
    # LHS 1140 b deep dive (manual, 2026-05-23; migration 031). Temperate HZ water
    # world; H2-rich atmosphere ruled out, 9-19% water by mass. Bibcodes verified via ADS.
    {"pl_names": ["LHS 1140 b"], "bibcode": "2024ApJ...970L...2C", "contribution": "atmosphere",
     "title": "Transmission Spectroscopy of the Habitable Zone Exoplanet LHS 1140 b with JWST/NIRISS"},
    {"pl_names": ["LHS 1140 b"], "bibcode": "2024ApJ...968L..22D", "contribution": "atmosphere",
     "title": "LHS 1140 b Is a Potentially Habitable Water World"},
    # WASP-76 b deep dive (manual, 2026-05-23; migration 032). "Iron rain" UHJ;
    # Fe asymmetry + metal inventory + VO. Bibcodes verified via ADS.
    {"pl_names": ["WASP-76 b"], "bibcode": "2020Natur.580..597E", "contribution": "atmosphere",
     "title": "Nightside condensation of iron in an ultrahot giant exoplanet"},
    {"pl_names": ["WASP-76 b"], "bibcode": "2021A&A...646A.158T", "contribution": "atmosphere",
     "title": "ESPRESSO high-resolution transmission spectroscopy of WASP-76 b"},
    {"pl_names": ["WASP-76 b"], "bibcode": "2023Natur.619..491P", "contribution": "atmosphere",
     "title": "Vanadium oxide and a sharp onset of cold-trapping on a giant exoplanet"},
    # PDS 70 deep dive (manual, 2026-05-23; migration 033). The only confirmed
    # forming planets: accretion (b) + circumplanetary disk (c). Data in
    # planet_derived_measurements. Bibcodes verified via ADS.
    {"pl_names": ["PDS 70 b"], "bibcode": "2018ApJ...863L...8W", "contribution": "accretion",
     "title": "Magellan Adaptive Optics Imaging of PDS 70: Measuring the Mass Accretion "
              "Rate of a Young Giant Planet within a Gapped Disk"},
    {"pl_names": ["PDS 70 b"], "bibcode": "2019NatAs...3..749H", "contribution": "accretion",
     "title": "Two accreting protoplanets around the young star PDS 70"},
    {"pl_names": ["PDS 70 c"], "bibcode": "2021ApJ...916L...2B", "contribution": "circumplanetary_disk",
     "title": "A Circumplanetary Disk around PDS70c"},
    # WASP-12 b deep dive (manual, 2026-05-23; migration 034). Inspiraling hot
    # Jupiter: orbital decay (derived) + H2O / escaping Mg II (atmosphere).
    {"pl_names": ["WASP-12 b"], "bibcode": "2020ApJ...888L...5Y", "contribution": "orbital_decay",
     "title": "The Orbit of WASP-12b Is Decaying"},
    {"pl_names": ["WASP-12 b"], "bibcode": "2017AJ....154....4P", "contribution": "orbital_decay",
     "title": "The Apparently Decaying Orbit of WASP-12b"},
    {"pl_names": ["WASP-12 b"], "bibcode": "2015ApJ...814...66K", "contribution": "atmosphere",
     "title": "A Detection of Water in the Transmission Spectrum of the Hot Jupiter WASP-12b "
              "and Implications for Its Atmospheric Composition"},
    {"pl_names": ["WASP-12 b"], "bibcode": "2010ApJ...714L.222F", "contribution": "atmosphere",
     "title": "Metals in the Exosphere of the Highly Irradiated Planet WASP-12b"},
    # KELT-9 b deep dive (manual, 2026-05-23; migration 035). Hottest known planet;
    # atomic/ionic metal zoo + escaping H. Bibcodes verified via ADS.
    {"pl_names": ["KELT-9 b"], "bibcode": "2018Natur.560..453H", "contribution": "atmosphere",
     "title": "Atomic iron and titanium in the atmosphere of the exoplanet KELT-9b"},
    {"pl_names": ["KELT-9 b"], "bibcode": "2019A&A...627A.165H", "contribution": "atmosphere",
     "title": "A spectral survey of an ultra-hot Jupiter. Detection of metals in the "
              "transmission spectrum of KELT-9 b"},
    {"pl_names": ["KELT-9 b"], "bibcode": "2018NatAs...2..714Y", "contribution": "atmosphere",
     "title": "An extended hydrogen envelope of the extremely hot giant exoplanet KELT-9b"},
    # Kepler-1520 b deep dive (manual, 2026-05-23; migration 036). Disintegrating
    # planet. Rappaport 2012 is the real discovery (prior_detection, above). Mass /
    # mass-loss data in planet_derived_measurements.
    {"pl_names": ["Kepler-1520 b"], "bibcode": "2013MNRAS.433.2294P", "contribution": "mass_loss",
     "title": "Catastrophic evaporation of rocky planets"},
    {"pl_names": ["Kepler-1520 b"], "bibcode": "2014A&A...561A...3V", "contribution": "mass",
     "title": "Analysis and interpretation of 15 quarters of Kepler data of the disintegrating "
              "planet KIC 12557548 b"},
    # 51 Eri b deep dive (manual, 2026-05-23; migration 038). Cold methane young
    # Jupiter; CH4/H2O (Macintosh 2015, already discovery) + Teff/metallicity/luminosity.
    {"pl_names": ["51 Eri b"], "bibcode": "2017AJ....154...10R", "contribution": "atmosphere",
     "title": "Characterizing 51 Eri b from 1 to 5 micron: A Partly Cloudy Exoplanet"},
    {"pl_names": ["51 Eri b"], "bibcode": "2017A&A...603A..57S", "contribution": "metallicity",
     "title": "Spectral and atmospheric characterization of 51 Eridani b using VLT/SPHERE"},
    # Kepler-51 deep dive (manual, 2026-05-23; migration 039). Super-puffs whose
    # transmission spectra are featureless (high-altitude hazes), so the value-add is
    # the H2O non-detections, not molecule lists. Libby-Roberts 2020 (HST/WFC3) covered
    # b and d; Libby-Roberts 2026 (JWST/NIRSpec-PRISM) re-observed d. Bibcodes via ADS.
    {"pl_names": ["Kepler-51 b", "Kepler-51 d"], "bibcode": "2020AJ....159...57L", "contribution": "atmosphere",
     "title": "The Featureless Transmission Spectra of Two Super-puff Planets"},
    {"pl_names": ["Kepler-51 d"], "bibcode": "2026AJ....171..221L", "contribution": "atmosphere",
     "title": "A JWST Transmission Spectrum of the Super-puff Kepler-51 d"},
    # WASP-18 b deep dive (manual, 2026-05-23; migration 040). Benchmark ultra-hot
    # Jupiter with a dayside thermal inversion. Sheppard 2017 + Arcangeli 2018 (HST/
    # Spitzer) established the inversion and the H-/dissociation picture; Coulombe 2023
    # (JWST/NIRISS) gave the definitive H2O-in-emission detection. Bibcodes via ADS.
    {"pl_names": ["WASP-18 b"], "bibcode": "2017ApJ...850L..32S", "contribution": "atmosphere",
     "title": "Evidence for a Dayside Thermal Inversion and High Metallicity for the "
              "Hot Jupiter WASP-18b"},
    {"pl_names": ["WASP-18 b"], "bibcode": "2018ApJ...855L..30A", "contribution": "atmosphere",
     "title": "H- Opacity and Water Dissociation in the Dayside Atmosphere of the Very "
              "Hot Gas Giant WASP-18b"},
    {"pl_names": ["WASP-18 b"], "bibcode": "2023Natur.620..292C", "contribution": "atmosphere",
     "title": "A broadband thermal emission spectrum of the ultra-hot Jupiter WASP-18b"},
    # HIP 65426 b deep dive (manual, 2026-05-23; migration 041). First JWST-imaged
    # exoplanet. Petrus 2021 (VLT/SINFONI K-band) supplies Teff/[M/H]/C/O + the H2O/CO
    # carriers; Carter 2023 (JWST NIRCam+MIRI) supplies the bolometric luminosity and a
    # refined mass. (Chauvin 2017 discovery cite already linked.) Bibcodes via ADS.
    {"pl_names": ["HIP 65426 b"], "bibcode": "2021A&A...648A..59P", "contribution": "atmosphere",
     "title": "Medium-resolution spectrum of the exoplanet HIP 65426 b"},
    {"pl_names": ["HIP 65426 b"], "bibcode": "2023ApJ...951L..20C", "contribution": "atmosphere",
     "title": "The JWST Early Release Science Program for Direct Observations of "
              "Exoplanetary Systems I: High-contrast Imaging of the Exoplanet HIP 65426 b "
              "from 2 to 16 um"},
    # Directly-imaged young giants theme (manual deep dive, 2026-05-23; migrations 042+).
    # Companion set to the imaged work already done (HR 8799, bet Pic, 51 Eri, HIP 65426).
    # GJ 504 b (migration 042): the first T-dwarf-type imaged planet. Skemer 2016 supplies
    # the methane detection + Teff/metallicity/luminosity. Bibcode via ADS.
    {"pl_names": ["GJ 504 b"], "bibcode": "2016ApJ...817..166S", "contribution": "atmosphere",
     "title": "The LEECH Exoplanet Imaging Survey: Characterization of the Coldest Directly "
              "Imaged Exoplanet, GJ 504 b, and Evidence for Superstellar Metallicity"},
    # kap And b (migration 043): super-Jupiter at the planet/BD boundary. Wilcomb 2020
    # (Keck/OSIRIS R~4000 K-band) supplies resolved H2O + CO and Teff/[M/H]/C/O. Bibcode via ADS.
    {"pl_names": ["kap And b"], "bibcode": "2020AJ....160..207W", "contribution": "atmosphere",
     "title": "Moderate-resolution K-band Spectroscopy of Substellar Companion kappa Andromedae b"},
    # 2M1207 b / TWA 27B = catalog '2MASS J12073346-3932539 b' (migration 044): first
    # directly-imaged exoplanet; methane-poor. Barman 2011 = the cloudy/non-eq atmosphere
    # explanation; Luhman 2023 = JWST/NIRSpec (CH4 absent, CO weak). Bibcodes via ADS.
    {"pl_names": ["2MASS J12073346-3932539 b"], "bibcode": "2011ApJ...735L..39B", "contribution": "atmosphere",
     "title": "The Young Planet-mass Object 2M1207b: A Cool, Cloudy, and Methane-poor Atmosphere"},
    {"pl_names": ["2MASS J12073346-3932539 b"], "bibcode": "2023ApJ...949L..36L", "contribution": "atmosphere",
     "title": "JWST/NIRSpec Observations of the Planetary Mass Companion TWA 27B"},
    # AB Pic b (migration 045): planet/BD-boundary companion. Palma-Bifani 2023 (ForMoSA)
    # supplies refined Teff + first C/O + first vsin(i). Bibcode via ADS.
    {"pl_names": ["AB Pic b"], "bibcode": "2023A&A...670A..90P", "contribution": "atmosphere",
     "title": "Peering into the young planetary system AB Pic. Atmosphere, orbit, "
              "obliquity, and second planetary candidate"},
    # HD 95086 b (migration 046): dusty ~5 Mjup planet in a debris-disk gap. De Rosa 2016
    # (GPI) supplies the featureless cloudy spectrum + Teff. Bibcode via ADS.
    {"pl_names": ["HD 95086 b"], "bibcode": "2016ApJ...824..121D", "contribution": "atmosphere",
     "title": "Spectroscopic Characterization of HD 95086 b with the Gemini Planet Imager"},
    # 1990s foundational cohort (migration 047+). PSR B1257+12 c & d: Konacki & Wolszczan
    # 2003 measured true masses + orbital inclinations from the planets' mutual perturbations
    # (the catalog uses these masses but never cited the paper). Bibcode via ADS.
    {"pl_names": ["PSR B1257+12 c", "PSR B1257+12 d"], "bibcode": "2003ApJ...591L.147K", "contribution": "mass",
     "title": "Masses and Orbital Inclinations of Planets in the PSR B1257+12 System"},
    # HD 168443 c (migration 049): astrometric true mass = 30.3 Mjup (Reffert & Quirrenbach 2011,
    # re-reduced HIPPARCOS), confirming the brown-dwarf nature beyond the RV m sin i. Bibcode via ADS.
    {"pl_names": ["HD 168443 c"], "bibcode": "2011A&A...527A.140R", "contribution": "mass",
     "title": "Mass constraints on substellar companion candidates from the re-reduced Hipparcos "
              "intermediate astrometric data: nine confirmed planets and two confirmed brown dwarfs"},
    # HD 4113 b (migration 058): links the eccentric planet to the paper that imaged its cold T9
    # brown-dwarf companion HD 4113 C (Cheetham 2018) and updated the planet's orbit. Bibcode via ADS.
    {"pl_names": ["HD 4113 b"], "bibcode": "2018A&A...614A..16C", "contribution": "binary_companion",
     "title": "Direct imaging of an ultracool substellar companion to the exoplanet host star HD 4113 A"},
    # GJ 86 b (migration 050): links the planet to the paper confirming its wide companion GJ 86 B
    # is a white dwarf (the first WD found orbiting an exoplanet host). The binary_companions row's
    # source_bibcode is fixed in migration 050; this is the planet->paper link. Bibcode via ADS.
    {"pl_names": ["GJ 86 b"], "bibcode": "2005MNRAS.361L..15M", "contribution": "binary_companion",
     "title": "Gl86B: a white dwarf orbits an exoplanet host star"},
    # "Tilted & Tumbling" theme (spin-orbit-misaligned planets, 2026-05-24; migrations 051+).
    # Obliquity values come from NASA EA's raw_row (reflink papers), promoted into
    # planet_derived_measurements and cited here. WASP-17 b (migration 051): first retrograde
    # planet; lambda from Triaud 2010 (HARPS Rossiter-McLaughlin). Bibcode via ADS.
    {"pl_names": ["WASP-17 b"], "bibcode": "2010A&A...524A..25T", "contribution": "obliquity",
     "title": "Spin-orbit angle measurements for six southern transiting planets. "
              "New insights into the dynamical origins of hot Jupiters"},
    # WASP-33 b (migration 052): retrograde UHJ around a hot, fast-rotating A-star; both lambda
    # and true obliquity psi from Collier Cameron 2010 (also the discovery cite, distinct role). Bibcode via ADS.
    {"pl_names": ["WASP-33 b"], "bibcode": "2010MNRAS.407..507C", "contribution": "obliquity",
     "title": "Line-profile tomography of exoplanet transits - II. A gas-giant planet "
              "transiting a rapidly rotating A5 star"},
    # K2-290 c (migration 053): polar/retrograde warm Jupiter; both planets coplanar but the plane
    # tilted ~124 deg from a "backward-spinning" star -> primordial disk misalignment. Hjorth 2021
    # (PNAS; distinct from the 2019 discovery cite) supplies lambda + true obliquity. Bibcode via ADS.
    {"pl_names": ["K2-290 c"], "bibcode": "2021PNAS..11817418H", "contribution": "obliquity",
     "title": "A backward-spinning star with two coplanar planets"},
    # HAT-P-7 b (migration 054): near-polar hot Jupiter; one of the first misaligned HJs (Winn 2009,
    # alongside WASP-17 b). lambda + true obliquity from Winn 2009 (distinct from 2008 discovery). Bibcode via ADS.
    {"pl_names": ["HAT-P-7 b"], "bibcode": "2009ApJ...703L..99W", "contribution": "obliquity",
     "title": "HAT-P-7: A Retrograde or Polar Orbit, and a Third Body"},
    # WASP-79 b (migration 055): near-polar hot Jupiter (closes the theme). lambda from Brown 2017
    # (distinct from the 2012 discovery cite). Bibcode via ADS.
    {"pl_names": ["WASP-79 b"], "bibcode": "2017MNRAS.464..810B", "contribution": "obliquity",
     "title": "Rossiter-McLaughlin models and their effect on estimates of stellar rotation, "
              "illustrated using four WASP systems"},
    # "Wild Orbits" theme (extreme-eccentricity / dynamics, 2026-05-24; migrations 056+).
    # HD 80606 b (migration 056): Laughlin 2009 caught the periastron flash-heating (dayside
    # 8-um brightness temp); harvested as a derived dayside_temperature. Bibcode via ADS.
    {"pl_names": ["HD 80606 b"], "bibcode": "2009Natur.457..562L", "contribution": "atmosphere",
     "title": "Rapid heating of the atmosphere of an extrasolar planet"},
    # tau Boo b (migration 048): first non-transiting planet atmospherically characterized.
    # Brogi 2012 (CO + inclination/true mass), Lockwood 2014 (H2O), Pelletier 2021 (C/H +
    # water depletion + upper limits). Bibcodes via ADS.
    {"pl_names": ["tau Boo b"], "bibcode": "2012Natur.486..502B", "contribution": "atmosphere",
     "title": "The signature of orbital motion from the dayside of the planet tau Bootis b"},
    {"pl_names": ["tau Boo b"], "bibcode": "2014ApJ...783L..29L", "contribution": "atmosphere",
     "title": "Near-IR Direct Detection of Water Vapor in Tau Bootis b"},
    {"pl_names": ["tau Boo b"], "bibcode": "2021AJ....162...73P", "contribution": "atmosphere",
     "title": "Where Is the Water? Jupiter-like C/H Ratio but Strong H2O Depletion Found "
              "on tau Bootis b Using SPIRou"},
    # Warm-Neptune atmosphere batch (migration 060, 2026-05-24). Curated from JWST-era
    # spectroscopy already in planet_atmospheric_observations. Bibcodes via ADS.
    {"pl_names": ["GJ 3470 b"], "bibcode": "2024ApJ...970L..10B", "contribution": "atmosphere",
     "title": "Sulfur Dioxide and Other Molecular Species in the Atmosphere of the Sub-Neptune GJ 3470 b"},
    {"pl_names": ["GJ 436 b"], "bibcode": "2025ApJ...982L..39M", "contribution": "atmosphere",
     "title": "A JWST Panchromatic Thermal Emission Spectrum of the Warm Neptune Archetype GJ 436b"},
    {"pl_names": ["HAT-P-26 b"], "bibcode": "2017Sci...356..628W", "contribution": "atmosphere",
     "title": "HAT-P-26b: A Neptune-mass exoplanet with a well-constrained heavy element abundance"},
    {"pl_names": ["HAT-P-26 b"], "bibcode": "2025AJ....170..292G", "contribution": "atmosphere",
     "title": "JWST-TST DREAMS: Sulfur Dioxide in the Atmosphere of the Neptune-mass Planet HAT-P-26 b "
              "from NIRSpec G395H Transmission Spectroscopy"},
    {"pl_names": ["TOI-270 d"], "bibcode": "2024A&A...683L...2H", "contribution": "atmosphere",
     "title": "Possible Hycean conditions in the sub-Neptune TOI-270 d"},
    {"pl_names": ["TOI-270 d"], "bibcode": "2025A&A...701A.296F", "contribution": "atmosphere",
     "title": "Competing chemical signatures in the atmosphere of TOI-270 d: Inference of sulfur "
              "and carbon chemistry"},
    # Atmosphere backlog batch 2: fast-follows (migration 061, 2026-05-25). Systems already
    # curated for obliquity/dynamics; bibcodes via ADS.
    {"pl_names": ["WASP-17 b"], "bibcode": "2024AJ....168..123V", "contribution": "atmosphere",
     "title": "JWST-TST DREAMS: Nonuniform Dayside Emission for WASP-17b from MIRI/LRS"},
    {"pl_names": ["WASP-17 b"], "bibcode": "2023ApJ...956L..29G", "contribution": "atmosphere",
     "title": "JWST-TST DREAMS: Quartz Clouds in the Atmosphere of WASP-17b"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2015ApJ...806..146H", "contribution": "atmosphere",
     "title": "Spectroscopic Evidence for a Temperature Inversion in the Dayside Atmosphere of "
              "Hot Jupiter WASP-33b"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2017AJ....154..221N", "contribution": "atmosphere",
     "title": "High-resolution Spectroscopic Detection of TiO and a Stratosphere in the "
              "Day-side of WASP-33b"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2020ApJ...898L..31N", "contribution": "atmosphere",
     "title": "Detection of Fe I Emission in the Dayside Spectrum of WASP-33b"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2021ApJ...910L...9N", "contribution": "atmosphere",
     "title": "First Detection of Hydroxyl Radical Emission from an Exoplanet Atmosphere"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2021A&A...645A..90S", "contribution": "atmosphere",
     "title": "Is TiO emission present in the ultra-hot Jupiter WASP-33b? A reassessment"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2021A&A...651A..33C", "contribution": "atmosphere",
     "title": "Detection of Fe and evidence for TiO in the dayside emission spectrum of WASP-33b"},
    {"pl_names": ["WASP-33 b"], "bibcode": "2022A&A...668A..53C", "contribution": "atmosphere",
     "title": "Atmospheric characterization of the ultra-hot Jupiter WASP-33b. Detection of Ti "
              "and V emission"},
    {"pl_names": ["WASP-79 b"], "bibcode": "2020AJ....159....5S", "contribution": "atmosphere",
     "title": "Transmission Spectroscopy of WASP-79b from 0.6 to 5.0 um"},
    {"pl_names": ["HAT-P-7 b"], "bibcode": "2016ApJ...823..122W", "contribution": "atmosphere",
     "title": "3.6 and 4.5 um Spitzer Phase Curves of the Highly Irradiated Hot Jupiters "
              "WASP-19b and HAT-P-7b"},
    {"pl_names": ["HAT-P-7 b"], "bibcode": "2022ApJS..260....3C", "contribution": "atmosphere",
     "title": "Five Key Exoplanet Questions Answered via the Analysis of 25 Hot-Jupiter "
              "Atmospheres in Eclipse"},
    {"pl_names": ["HD 80606 b"], "bibcode": "2025AJ....170..105S", "contribution": "atmosphere",
     "title": "Seasonal Changes in the Atmosphere of HD 80606 b Observed with JWST's NIRSpec/G395H"},
    # HD 189733 b silicate clouds + H2S (migration 062, 2026-05-25; surfaced while sourcing
    # WASP-17 b's quartz paper). Bibcode via ADS.
    {"pl_names": ["HD 189733 b"], "bibcode": "2024ApJ...973L..41I", "contribution": "atmosphere",
     "title": "Quartz Clouds in the Dayside Atmosphere of the Quintessential Hot Jupiter HD 189733 b"},
    # Atmosphere backlog batch 3: rocky JWST set (migration 063, 2026-05-25). Mostly honest
    # non-detections / constraints; L 98-59 b is the headline (tentative volcanic SO2).
    {"pl_names": ["GJ 1132 b"], "bibcode": "2024ApJ...973L...8X", "contribution": "atmosphere",
     "title": "JWST Thermal Emission of the Terrestrial Exoplanet GJ 1132b"},
    {"pl_names": ["GJ 1132 b"], "bibcode": "2023ApJ...959L...9M", "contribution": "atmosphere",
     "title": "Double Trouble: Two Transits of the Super-Earth GJ 1132 b Observed with JWST NIRSpec G395H"},
    {"pl_names": ["GJ 1132 b"], "bibcode": "2025AJ....170..205B", "contribution": "atmosphere",
     "title": "Additional JWST/NIRSpec Transits of the Rocky M Dwarf Exoplanet GJ 1132 b Reveal "
              "a Featureless Spectrum"},
    {"pl_names": ["GJ 486 b"], "bibcode": "2023ApJ...948L..11M", "contribution": "atmosphere",
     "title": "High Tide or Riptide on the Cosmic Shoreline? A Water-rich Atmosphere or Stellar "
              "Contamination for the Warm Super-Earth GJ 486b from JWST Observations"},
    {"pl_names": ["GJ 486 b"], "bibcode": "2024ApJ...975L..22W", "contribution": "atmosphere",
     "title": "No Thick Atmosphere on the Terrestrial Exoplanet Gl 486b"},
    {"pl_names": ["L 98-59 b"], "bibcode": "2025ApJ...980L..26B", "contribution": "atmosphere",
     "title": "Evidence for a Volcanic Atmosphere on the Sub-Earth L 98-59 b"},
    {"pl_names": ["LTT 1445 A b"], "bibcode": "2025AJ....169..311W", "contribution": "atmosphere",
     "title": "The Thermal Emission Spectrum of the Nearby Rocky Exoplanet LTT 1445A b from JWST MIRI/LRS"},
    {"pl_names": ["L 98-59 c"], "bibcode": "2024AJ....168..276S", "contribution": "atmosphere",
     "title": "JWST COMPASS: The 3-5 um Transmission Spectrum of the Super-Earth L 98-59 c"},
    {"pl_names": ["L 98-59 d"], "bibcode": "2024ApJ...975L..10G", "contribution": "atmosphere",
     "title": "Hints of a Sulfur-rich Atmosphere around the 1.6 R_Earth Super-Earth L 98-59 d from "
              "JWST NIRspec G395H Transmission Spectroscopy"},
    # Atmosphere backlog batch 4: JWST hot Jupiters (migration 064, 2026-05-25).
    {"pl_names": ["WASP-43 b"], "bibcode": "2024NatAs...8..879B", "contribution": "atmosphere",
     "title": "Nightside clouds and disequilibrium chemistry on the hot Jupiter WASP-43b"},
    {"pl_names": ["WASP-80 b"], "bibcode": "2023Natur.623..709B", "contribution": "atmosphere",
     "title": "Methane throughout the atmosphere of the warm exoplanet WASP-80b"},
    {"pl_names": ["WASP-80 b"], "bibcode": "2025AJ....169..277M", "contribution": "atmosphere",
     "title": "A Moderate Albedo from Reflecting Aerosols on the Dayside of WASP-80 b Revealed by "
              "JWST/NIRISS Eclipse Spectroscopy"},
    {"pl_names": ["WASP-77 A b"], "bibcode": "2023ApJ...953L..24A", "contribution": "atmosphere",
     "title": "Confirmation of Subsolar Metallicity for WASP-77Ab from JWST Thermal Emission Spectroscopy"},
    {"pl_names": ["HD 149026 b"], "bibcode": "2023Natur.618...43B", "contribution": "atmosphere",
     "title": "High atmospheric metal enrichment for a Saturn-mass planet"},
    # Atmosphere backlog batch 5: directly-imaged young giants (migration 065, 2026-05-25).
    {"pl_names": ["AF Lep b"], "bibcode": "2023A&A...672A..93M", "contribution": "atmosphere",
     "title": "AF Lep b: The lowest-mass planet detected by coupling astrometric and direct imaging data"},
    {"pl_names": ["AF Lep b"], "bibcode": "2023A&A...672A..94D", "contribution": "atmosphere",
     "title": "Direct imaging discovery of a super-Jovian around the young Sun-like star AF Leporis"},
    {"pl_names": ["AF Lep b"], "bibcode": "2024ApJ...974L..11F", "contribution": "atmosphere",
     "title": "JWST/NIRCam 4-5 um Imaging of the Giant Planet AF Lep b"},
    {"pl_names": ["TYC 8998-760-1 b"], "bibcode": "2025Natur.643..938H", "contribution": "atmosphere",
     "title": "Silicate clouds and a circumplanetary disk in the YSES-1 exoplanet system"},
    {"pl_names": ["TYC 8998-760-1 c"], "bibcode": "2025Natur.643..938H", "contribution": "atmosphere",
     "title": "Silicate clouds and a circumplanetary disk in the YSES-1 exoplanet system"},
    {"pl_names": ["VHS J125601.92-125723.9 b"], "bibcode": "2023ApJ...946L...6M", "contribution": "atmosphere",
     "title": "The JWST Early-release Science Program for Direct Observations of Exoplanetary Systems II: "
              "A 1 to 20 um Spectrum of the Planetary-mass Companion VHS 1256-1257 b"},
    {"pl_names": ["eps Ind A b"], "bibcode": "2024Natur.633..789M", "contribution": "atmosphere",
     "title": "A temperate super-Jupiter imaged with JWST in the mid-infrared"},
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
