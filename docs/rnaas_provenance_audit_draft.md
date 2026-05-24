# A Provenance and Completeness Audit of the NASA Exoplanet Archive with a Value-Added Citation-Graph Warehouse

**M. Pernotto**
*Independent Researcher* (affiliation / ORCID to be added)

*Draft Research Note. RNAAS style, no abstract.*

The NASA Exoplanet Archive is the community's reference catalog of confirmed
planets, aggregating parameters from the literature into the `ps`
(per-publication) and `pscomppars` (composite) tables. In practice a tabulated
value is taken together with the reference on its row, and that pairing is not
always faithful: a parameter can carry the discovery citation even when the
number was first measured by a later paper, the derivation behind it (an
inclination, an astrometric orbit) is not retained, and on occasion a published
planet is never ingested at all. This is less an error than a consequence of
summarizing decades of follow-up into a single row.

To quantify the effect we built a value-added warehouse layered over a faithful
mirror of the Archive. For each planet it records every cited paper with two
explicit axes, a *role* (discovery, follow-up, prior-detection,
characterization) and a *contribution* (the specific datum taken: mass,
inclination, a molecular detection), alongside literature-derived scalars and
atmospheric detections, each with its own bibcode. The dataset is archived at
Zenodo (doi:10.5281/zenodo.20191479). Systematic deep-dives of confirmed systems
turn up three recurring classes of issue, illustrated below by anchor cases that
we re-verified against both the warehouse and a live Archive query.

## Uncited and missing mass provenance

For several historically important systems the Archive's tabulated mass is the
correct modern *true* mass, but the only citation linked to the planet is its
discovery paper, so the measurement that broke the `m sin i` degeneracy is
invisible to a reader following the reference.

The clearest example is the first confirmed planetary system,
PSR B1257+12. The Archive carries 4.3 and 3.9 M_Earth for planets c and d.
Those are exactly the dynamical true masses derived by Konacki & Wolszczan
(2003) from the planets' mutual gravitational perturbations on the pulse
arrival times, which also fixed their orbital inclinations (i = 53 deg and
47 deg) and showed the system to be nearly coplanar. The Archive links only the
discovery references (Wolszczan & Frail 1992; Wolszczan 1994); the paper that
produced the masses it tabulates is not among them.

tau Boo b shows the same pattern for a non-pulsar host. Its Archive mass,
5.95 M_Jup, is the true mass that follows from the i = 44.5 deg inclination
measured by Brogi et al. (2012) using high-resolution Doppler spectroscopy of
the planet's own thermal lines, the first such measurement for a non-transiting
planet (and consistent with Lockwood et al. 2014). The linked reference is the
Butler et al. (1997) discovery, which could only report `m sin i`.

HD 168443 c is the complementary case, where the gap is the measurement
itself. The Archive carries 17.3 M_Jup, which is the radial-velocity minimum
mass. Reffert & Quirrenbach (2011) detected the companion's astrometric orbit in
the re-reduced HIPPARCOS data and measured a true mass of 30.3 M_Jup,
unambiguously a brown dwarf rather than a borderline giant planet. That
astrometric result, and the classification it settles, are absent from the
Archive row.

## A resolved mis-classification

rho Coronae Borealis b is a cautionary case in the opposite direction. The same
re-reduced HIPPARCOS astrometry that constrained HD 168443 c yields, for
rho CrB b, a near-face-on orbit (i approx 0.4 deg) and therefore a stellar-mass
companion of order 170 M_Jup, which would make "b" a low-mass star rather than a
planet. That reading is refuted by the system architecture: rho CrB is now known
to host multiple low-mass planets at 0.1 to 0.4 au (Fulton et al. 2016; Brewer
et al. 2023), a configuration that could not survive a 0.17 M_Sun companion at
0.23 au. The astrometric inclination is spurious, and rho CrB b (about 1.1 M_Jup)
is a genuine hot Jupiter. The lesson, recorded as a provenance flag in the
warehouse rather than as a mass, is that a published astrometric mass must be
cross-checked against the dynamical plausibility of the whole system before it is
adopted.

## A completeness gap

The same deep-dive surfaced a planet that the Archive does not list at all.
Brewer et al. (2023) reported two new planets in rho CrB: a 12.9-day super-Earth
and a 281-day, roughly Neptune-mass planet. The Archive ingested the first,
which appears as rho CrB e. A direct TAP query of both `ps` and `pscomppars`
returns only rho CrB b, c, and e; the 281-day planet from the same paper is
absent. We find no retraction or dispute of that signal in the subsequent
literature, so this reads as an ingestion or curation omission rather than a
withdrawn detection. It is the kind of discrepancy that only a literature-versus-
archive comparison exposes, because nothing in the Archive itself signals that a
row is missing.

## Findings

| Object | Archive value | Archive citation | Literature provenance | Source |
|---|---|---|---|---|
| PSR B1257+12 c | 4.3 M_Earth (true mass) | discovery only | mutual perturbations, i = 53 deg | Konacki & Wolszczan (2003) |
| PSR B1257+12 d | 3.9 M_Earth (true mass) | discovery only | mutual perturbations, i = 47 deg | Konacki & Wolszczan (2003) |
| tau Boo b | 5.95 M_Jup (true mass) | Butler et al. (1997) | i = 44.5 deg, high-res Doppler | Brogi et al. (2012) |
| HD 168443 c | 17.3 M_Jup (m sin i) | Marcy et al. (2001) | true mass 30.3 M_Jup (brown dwarf) | Reffert & Quirrenbach (2011) |
| rho CrB b | 1.1 M_Jup (planet) | Noyes et al. (1997) | face-on-star reading refuted by architecture | Brewer et al. (2023) |
| rho CrB d | absent | n/a | 281-day Neptune, not ingested | Brewer et al. (2023) |

## Discussion

These anchor cases are representative, not exhaustive. Across the systems audited
so far the warehouse has added on the order of two hundred non-discovery
citations, each tagged with the specific datum it supplies, plus dozens of
derived scalars (true masses, inclinations, compositions) and atmospheric
detections that the Archive tabulates without a usable provenance pointer or does
not carry at all. The three failure modes generalize: mass provenance pointing to
the discovery rather than the measuring paper, classifications hinging on an
unvetted astrometric inclination, and published planets that never enter the
catalog.

The point is not that the Archive is unreliable; it is indispensable, and our
warehouse mirrors it faithfully. It is that a thin provenance and citation-audit
layer recovers information that aggregation necessarily discards, and surfaces
omissions the catalog cannot flag on its own, a tractable complement to the major
archives. The dataset, including the citation graph and derived-measurement
provenance, is available at Zenodo (doi:10.5281/zenodo.20191479).

## References

- Brewer, J. M., et al. 2023, AJ, 166, 46
- Brogi, M., et al. 2012, Nature, 486, 502
- Butler, R. P., et al. 1997, ApJ, 474, L115
- Fulton, B. J., et al. 2016, ApJ, 830, 46
- Konacki, M., & Wolszczan, A. 2003, ApJ, 591, L147
- Lockwood, A. C., et al. 2014, ApJ, 783, L29
- Marcy, G. W., et al. 2001, ApJ, 555, 418
- Noyes, R. W., et al. 1997, ApJ, 483, L111
- Reffert, S., & Quirrenbach, A. 2011, A&A, 527, A140
- Wolszczan, A., & Frail, D. A. 1992, Nature, 355, 145
- Wolszczan, A. 1994, Science, 264, 538
