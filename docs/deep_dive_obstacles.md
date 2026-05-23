# Deep-dive obstacles log

Design input for the planned automated, human-verified literature monitor (the
"automated deep dive"). Each entry is a friction/failure mode hit while doing the
cb_flag inner-binary enrichment by hand, how it was handled manually, and what an
automation would need to do. Append as new obstacles appear.

## Observed during the 2026-05-21 manual pass

1. **Data is in the paper body, not the abstract.** Most component masses
   (BEBOP-3, Kepler-34/47, etc.) live in tables/text, not abstracts.
   → Automation needs full-text retrieval + extraction, not abstract-only.

2. **Cross-identifier aliasing.** KIC 5095269 = Kepler-1660 AB; 2M 1938+4603 =
   Kepler-451; warehouse hostname `Kepler-453` vs the audit section `Kepler-453 A`.
   → Need robust ID resolution (SIMBAD / NASA EA aliases) before matching a paper
   to a system, and a hostname/pl_name cross-check before any write (this caught a
   would-be orphan row manually).

3. **m sin i vs true mass.** HD 202206: RV gave m sin i 17.4 M_Jup; HST astrometry
   gave true masses ~5-7x higher, flipping the inner companion from "brown dwarf"
   to "star" and the cb_flag object from "planet" to "brown dwarf."
   → Capture the mass TYPE (minimum vs true/dynamical); prefer the
   higher-information measurement; never silently mix them.

4. **Non-unique / degenerate solutions.** Microlensing close/wide (OGLE-2018-1700,
   OGLE-2019-1470), the OGLE-2016-0613 multi-solution set, NY Vir mass families.
   → Represent multiple solutions; do not pick one blindly; flag degeneracy for the
   human reviewer.

5. **Explicitly poorly-constrained values.** HIP 79098 secondary mass; MXB 1658-298
   NS + donor. The papers themselves say the value is poorly known.
   → Detect "we don't know X" language and record as unconstrained; do NOT extract
   a false number.

6. **Parameter revisions across papers.** Kepler-1660 planet 7.7 -> 4.87 M_Jup;
   NY Vir; HD 202206. The current value is not in the discovery paper.
   → Track supersession (discovery / prior_detection / follow_up roles) and which
   value is current.

7. **Unit conversions & derived quantities.** lt-s -> AU (MXB 1658); M_Jup <-> M_sun;
   spectral-type -> approximate mass (b Cen, HIP 79098).
   → A units layer; mark spectral-type-derived masses as approximate.

8. **Abstract vs archive discrepancies.** RR Cae (abstract period+separation imply
   ~1.0 M_sun vs the real ~0.62); Kepler-451 c period 1800 d (abstract) vs 1460 d
   (NASA EA).
   → Cross-check extracted values against the warehouse and flag conflicts rather
   than overwrite.

9. **Bibcode/author verification.** Several bibcodes needed ADS verification
   (Esmer, Kuang, van Capelleveen, Borkovits, Getley).
   → Resolve + verify bibcodes via ADS; never trust an inferred bibcode.

10. **Retrieval boundary (being characterized as we go).** Which papers are on
    arXiv (fetchable) vs paywalled-only; how reliably masses parse from full text
    vs needing a human paste.
    → Defines where the automation's auto-fetch must hand off to human input.
    - DATA POINT (BEBOP-3, arXiv 2506.14615): arXiv HTML full text fetched and the
      two component masses parsed cleanly from Table 2 in one pass. arXiv-HTML
      papers look like the easy/automatable case.

11. **Bibcode -> fetchable-URL resolution.** We have ADS bibcodes, but fetching
    needs a URL (arXiv HTML, journal full_html, or ADS). Not every bibcode maps
    obviously to an arXiv ID, and journal pages are often paywalled.
    → Automation needs a resolver: bibcode -> arXiv ID (via ADS links) -> HTML URL,
    with a paywall/no-arXiv fallback flagged for human paste.
    - DATA POINT (HD 143811, arXiv 2509.06009): fetched cleanly; isochrone-fit
      component masses + Teffs + age parsed from text/tables. Second clean arXiv-HTML
      success.
    - DATA POINT (VHS 1256, arXiv 2208.08448): the /html/ URL returned 404 — older
      papers don't always have an arXiv HTML rendering. Automation needs a fallback
      chain (arXiv HTML -> ar5iv HTML -> arXiv PDF -> journal full_html -> human
      paste). RESOLVED via ar5iv (ar5iv.labs.arxiv.org/html/<id>): ar5iv renders
      older papers as HTML and fetched cleanly. Add ar5iv as the first fallback
      after arxiv.org/html.
    - And it confirmed a GENUINE uncertainty vs a retrieval failure (see #15):
      VHS 1256's astrometry measures only the TOTAL mass (0.141 Msun) plus a poorly
      constrained ratio (M_A/M_tot=0.45+/-0.08); the individual split is a real
      literature limitation, not something a better fetch would fix. The full text
      both succeeded AND told us the split is intrinsically weak.
    - DATA POINT (DP Leo, A&A full_html aa15942-10): fetched cleanly, BUT the masses
      it reports (WD 0.6 + dM 0.1) are stated as ASSUMED (from Schwope 2002), not
      measured. A successful fetch can still yield only assumed/low-confidence values
      — extraction must capture the method, not just the number (see #14).

12. **The wanted value isn't in the discovery paper at all.** The inner-binary
    masses for the imaging systems often live in a SEPARATE, older binary-study
    paper, not the planet's discovery paper (ROXs 42 B inner masses -> Kraus 2014,
    not the Currie 2014 planet paper).
    → The resolver must follow the citation graph to the right paper, not assume the
    discovery paper holds the stellar parameters.

13. **Conflicting parameters across papers.** SR 12 AB has two incompatible
    spectral classifications (K4/M2.5 from Bouvier & Appenzeller 1992 vs M3/M8 from
    Gras-Velazquez & Ray 2005), with no agreed component masses.
    → Automation must detect disagreement between sources and surface BOTH to the
    human rather than silently choosing one; record provenance per value.

14. **Bounded-but-indirect values.** HD 143811's secondary is undetected directly;
    masses come from isochrone fitting as ranges (M1 1.24-1.40, M2 1.08-1.28 Msun),
    not a direct dynamical measurement.
    → Capture the method (isochrone vs dynamical vs RV m sin i) alongside the value;
    these are usable but lower-confidence than dynamical masses.

15. **Do NOT declare "unresolvable" from a search snippet.** During the manual pass
    several systems were initially called "intrinsically uncertain" based only on
    web-search snippets, without fetching the full paper (HIP 79098, MXB 1658-298,
    SR 12, OGLE-2016-BLG-0613) or after a single failed fetch (VHS 1256, one arXiv
    HTML 404). That conflates "the snippet didn't surface it" with "the value does
    not exist" — a false negative.
    → Automation (and humans) must EXHAUST the retrieval chain (arXiv HTML -> arXiv
    PDF -> journal full_html -> ADS -> human paste) before recording a value as
    unavailable, and must distinguish "not found yet" from "genuinely unconstrained
    in the literature." Only the latter is a real frontier uncertainty.

16. **A bibcode that resolves is not necessarily the right paper.** When a bibcode
    is *guessed* from journal/volume/page rather than read off the source, it can
    resolve to a real but WRONG paper for a different system. Example (2026-05-23):
    `2018AJ....156...17K` was guessed for WASP-107 b's water paper but is actually
    the WASP-**103**b phase-curve paper; the correct WASP-107 b paper is
    `2018ApJ...858L...6K`. Caught immediately because the abstract named the wrong
    planet, so nothing entered the warehouse.
    → Verify each fetched bibcode's title/abstract names the intended planet, not
    just that it resolves. Prefer bibcodes already in the warehouse (the
    observation table or citation graph) over guessed ones. This is a self-caught
    process slip, not an upstream data error -- nothing to report externally.
