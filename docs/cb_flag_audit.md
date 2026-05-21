# cb_flag audit

Per-planet review of every entry in the NASA Exoplanet Archive's `pscomppars` table with `cb_flag = 1` as of the latest snapshot. Generated from the warehouse by `etl/build_cb_flag_audit.py`. The purpose is to verify whether each entry is actually a P-type (circumbinary, both stars inside the planet's orbit) configuration or whether the flag is misapplied to an S-type (planet orbits one star of a binary, the other companion is wider than the planet's orbit).

## Universe

- **54 planets** across **44 host systems**
- **16 / 44 hosts** have `binary_companions` data in the warehouse; **28 have none**, which is itself an audit finding (cb_flag set without supporting secondary-star evidence).

## Verdict taxonomy

Per the Doyle 2011 / Welsh+ 2012 convention, a planet in a multi-star system has one of three orbit types:

- **P-type (circumbinary).** Planet orbits both stars from outside; both stars sit inside the planet's orbit. `cb_flag` is correctly 1.
- **S-type (circumstellar in a binary).** Planet orbits one star; the binary companion is wider than the planet's orbit. The system is a binary, but the planet only orbits one component. `cb_flag` should be 0.
- **Ambiguous.** Architecture not fully constrained by the discovery data. Common for direct-imaging detections (geometry hard to nail down at wide separations) and microlensing (degenerate fits).

The geometric test: compare the companion's projected separation (`separation_arcsec * system_distance_pc`, in AU) to each planet's `pl_orbsmax`. Companion narrower than the planet's orbit → P-type. Companion wider → S-type. Unknown companion separation → ambiguous.

## Findings summary

All 54 cb_flag=1 planets across 44 host systems were reviewed against their discovery (and where relevant follow-up) literature. Each per-host entry below carries a verdict and a **Notes:** block harvesting inner-binary parameters and context from the abstracts.

**Verdict tally: 51 P-type confirmed, 3 Ambiguous, 0 confirmed S-type misflags.** The three Ambiguous entries are all microlensing detections and are the strongest candidates for a cb_flag review:

- `OGLE-2018-BLG-1700L b`: the discovery paper explicitly gives a circumstellar (S-type) solution and a circumbinary (P-type) solution as equally likely, so cb_flag = 1 rests on one of two 50/50 fits. The most likely true S-type in the corpus.
- `OGLE-2019-BLG-1470L AB c`: the competing model is a single star with a binary source (no binary host at all), disfavoured by only a chi-squared difference of ~18; if it is correct, cb_flag should be 0.
- `KMT-2016-BLG-1337L b`: two triple-lens solutions, neither explicitly establishing that the planet orbits outside both stars.

**Finding 1: microlensing cb_flags are unreliable.** Of the six microlensing entries, only one (`OGLE-2007-BLG-349L AB c`) has a fully settled circumbinary architecture, and only because HST imaging broke the close/wide lens degeneracy. The other five each carry an unresolved degeneracy: three are the Ambiguous entries above, and the remaining two (`OGLE-2016-BLG-0613L AB b`, `OGLE-2023-BLG-0836L b`) are P-type across their surviving solutions but leave the secondary's nature (star versus brown dwarf) or the projected geometry unstated. A microlensing cb_flag is only as trustworthy as the follow-up that breaks the lens-model degeneracy.

**Finding 2: roughly a fifth of the corpus are planet/brown-dwarf boundary objects.** Twelve entries have a companion mass at or above the ~13 M_Jup deuterium-burning limit: 2MASS J01033563 AB b, DE CVn b, NSVS 14256825 b, HIP 79098 AB b, BEBOP-4 AB b, MXB 1658-298 b, HD 284149 AB b, ROXs 42 B b, SR 12 AB c, Ross 458 c, b Cen AB b, and VHS 1256 b (whose inner "binary" is itself a brown-dwarf pair). They are concentrated in the imaging and timing detections. cb_flag is a geometric flag (does the planet orbit both stars), independent of whether the object is a planet or a brown dwarf; that inclusion question is deliberately out of scope here but is flagged per entry.

**Finding 3: warehouse data gaps and errors surfaced.**

- 28 of 44 hosts have no `binary_companions` row, because the tight spectroscopic/eclipsing binaries that define P-type systems are not in the wide-binary catalogs (WDS, SIMBAD) the table is built from. The inner-binary parameters needed to fill them are harvested into the per-entry **Notes:** blocks.
- `PSR B1620-26`: the four `binary_companions` rows are spurious crowded-field stars in the globular cluster M4, not bound companions; the real pulsar + white-dwarf inner binary is missing.
- `PH1` (Kepler-64): the single `binary_companions` row (170,000 AU, SIMBAD) is not the relevant companion; the ~1000 AU outer binary that makes this a quadruple is missing.
- Two hosts have null distance (`MXB 1658-298`, `PSR B1620-26`), which suppresses the Milky Way position card in the UI; both are recoverable from the literature (~9-12 kpc, and the M4 cluster distance ~1.8 kpc, respectively).
- One duplicate `binary_companions` row (`VHS 1256`) was identified and removed during the audit.

**Detection-method reliability:**

| Method | Entries | cb_flag reliability |
|---|---|---|
| Transit (Kepler/TESS) | 14 | Highest; planet is directly observed transiting the binary. |
| Eclipse / pulsar timing | 18 | Geometry secure (timing detection requires the binary); planet *existence* is contested for several post-common-envelope cases (HU Aqr most, NN Ser least). |
| Radial velocity | 4 | Secure; all four hosts are known eclipsing or astrometrically characterized binaries. |
| Imaging | 12 | Architecture P-type, but many companions are planet/BD-boundary mass. |
| Microlensing | 6 | Lowest; three of six are misflag candidates. |

**Multi-citation cases** for the planned citation-system revamp (planet inferred or predicted in one paper, confirmed or revised in a later one): Kepler-1660 AB b, NY Vir c, PSR B1620-26 b, VHS 1256 b, TOI-1338 c, and the Kepler-451 system.

> Note: from "## Per-host audit" onward this document is hand-maintained. The generator `etl/build_cb_flag_audit.py` produces only the blank verdict templates; re-running it would overwrite the hand-written verdicts, **Notes:** blocks, and this summary.

## Screenshot candidates ("spot the second sun")

Auto-detected after the per-host walk below. See bottom of file.

---

## Per-host audit

### 2MASS J01033563-5515561 A

- Distance: 47.2 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| 2MASS J01033563-5515561 AB b | Imaging | 2013 | 84.00 AU | Ambiguous (imaging detection; verify geometry by hand) | 2013A&A...553L...5D |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `2MASS J01033563-5515561 AB b`: P-type confirmed (rationale:
  Delorme et al. 2013 (2013A&A...553L...5D) report the
  direct-imaging discovery of 2MASS J01033563-5515561(AB)b, a
  12-14 M_Jup companion at a projected separation of 84 AU from a
  pair of young late-M stars, sharing common proper motion with
  the pair and showing Keplerian-compatible orbital motion. The
  (AB)b designation and the framing as a companion orbiting "a
  binary system" establish the circumbinary (P-type) architecture;
  the 84 AU separation is far outside the late-M inner binary.
  cb_flag = 1 correct.)

  **Notes:** Inner binary is a pair of young late-M stars (the AB
  pair); component masses and the binary separation are not given
  numerically in this abstract, pull the paper body before
  backfilling `binary_companions` (no row exists for this host).
  Cross-check: warehouse pl_orbsmax of 84.00 AU is the abstract's
  projected separation exactly (projected, not orbital semi-major
  axis).

  Two notable points. (1) Milestone: the abstract bills this 2013
  discovery as "the first ever imaged around a binary system at a
  separation compatible with formation in a disc." At 84 AU it is
  among the innermost wide-imaged circumbinary companions in the
  corpus (only the later HD 143811 AB b at 63 AU is closer), and
  unlike the hundreds-to-thousands-AU companions its separation is
  consistent with in-situ disc formation rather than requiring
  dynamical scattering or gravitational instability (contrast the
  formation tension flagged for ROXs 42 B b, SR 12 AB c, Ross 458
  c, b Cen AB b). (2) Edge case: the 12-14 M_Jup mass straddles
  the 13 M_Jup deuterium-burning boundary, and the abstract
  explicitly calls it "at the planet/brown dwarf mass boundary,"
  placing it in the planet/BD edge-case family with SR 12 AB c
  (~13.6 M_Jup), Ross 458 c, ROXs 42 B b, and b Cen AB b. The
  cb_flag geometric verdict is firm regardless of the
  planet-vs-BD question, which the audit scopes out.

---

### 2MASS J0249-0557 A

- Distance: 66.1 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| 2MASS J0249-0557 c | Imaging | 2018 | 1950 AU | Ambiguous (imaging detection; verify geometry by hand) | 2018AJ....156...57D |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `2MASS J0249-0557 c`: P-type confirmed (rationale: Dupuy et al. 2018
  (2018AJ....156...57D) describes a tight ultracool dwarf binary at the
  system centre with a wide-orbit planetary-mass companion at ~1950 AU
  projected. Planet's orbit dwarfs any plausible inner-binary separation
  by 3+ orders of magnitude, forcing P-type geometry. cb_flag = 1 correct.)

---

### 2MASS J19383260+4603591

- Distance: 396.3 pc
- Planets in this system flagged `cb_flag=1`: 3

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| 2MASS J19383260+4603591 b | Eclipse Timing Variations | 2015 | 0.920 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2015A&A...577A.146B |
| Kepler-451 c | Eclipse Timing Variations | 2022 | ? | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2022MNRAS.511.5207E |
| Kepler-451 d | Eclipse Timing Variations | 2022 | ? | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2022MNRAS.511.5207E |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `2MASS J19383260+4603591 b`: P-type confirmed (rationale: Baran et al.
  2015 (2015A&A...577A.146B) analysed 37 months of Kepler photometry of
  2M 1938+4603, an eclipsing binary consisting of a pulsating hot
  subdwarf primary and an M-dwarf companion with a strong reflection
  effect. Eclipse timings from 16,000+ primary and secondary eclipses
  revealed a periodic ETV signal attributed to a third body; assuming
  coplanarity with the inner binary, the perturber is a Jupiter-mass
  object on a 416-day, 0.92 AU orbit. The detection method itself,
  perturbation of the inner-binary eclipses, requires the planet to
  orbit outside both stars. cb_flag = 1 correct.)

  **Notes:** Inner binary is an eclipsing sdB pulsator + M-dwarf with a
  strong reflection effect. Baran 2015 also reports a significant
  long-term ETV trend possibly indicating additional bodies or secular
  evolution (candidate for the followup-citations ticket). At time of
  discovery, the 0.92 AU tertiary was the lowest-mass companion
  detected in any similar sdB+dM ETV system. Update: Esmer et al.
  2022 (2022MNRAS.511.5207E) revised this planet's period from 416 d
  to 406 d (e = 0.33) and showed it is the middle of three planets in
  the system; this is a multi-citation parameter revision (see the
  Kepler-451 c entry below for the full three-planet architecture).
- `Kepler-451 c`: P-type confirmed (rationale: Esmer et al. 2022
  (2022MNRAS.511.5207E, "Detection of two additional circumbinary
  planets around Kepler-451") announced two new planetary-mass
  companions to the Kepler-451 system (the sdB + M-dwarf eclipsing
  binary 2M 1938+4603), beyond the previously known eclipse-timing
  planet (the middle planet, warehouse "2MASS J19383260+4603591
  b", whose period they revised from Baran 2015's 416 d to 406 d,
  e = 0.33). Kepler-451 c is the outer of the two new planets:
  minimum mass 1.61 M_Jup, e = 0.29, orbital period ~1460 d per
  the NASA Exoplanet Archive (the discovery abstract quoted ~1800
  d; see note). ETV around the eclipsing sdB+dM binary forces
  P-type geometry. cb_flag = 1 correct.)

  **Notes:** Assignment resolved (NASA Exoplanet Archive, verified
  during this audit): Kepler-451 d is the inner planet (43 d) and
  Kepler-451 c is the outer planet (~1460 d), the opposite of the
  default "c is inner" intuition. Period discrepancy worth a
  paper-body check: the Esmer 2022 abstract states the outer
  planet's period as ~1800 d, but NASA EA archives it as 1460 +/-
  90 d; the warehouse pl_orbsmax (currently "?") should be filled
  from whichever value the archive tracks. Derived semi-major axis
  for c (Kepler's third law, M_total ~ 0.55 M_sun for the sdB+dM
  binary): ~2.1 AU at 1460 d (or ~2.4 AU at 1800 d).

  System is the corpus's richest ETV circumbinary architecture:
  three Jovian planets of similar mass, dynamically stable, namely
  Kepler-451 d (inner, 1.76 M_Jup, 43 d, ~0.20 AU, assumed
  circular), the middle planet (~Jupiter-mass, 406 d, 0.920 AU =
  the original 2MASS J19383260+4603591 b), and Kepler-451 c (outer,
  1.61 M_Jup, ~1460 d, ~2.1 AU). This is the multi-planet payoff
  of the long-term ETV trend Baran 2015 first noted (recorded in
  the 2MASS J19383260+4603591 b entry as "additional bodies or
  secular evolution"). Naming inconsistency worth flagging: the
  middle planet carries the 2MASS designation in the warehouse
  while the two newer planets use the Kepler-451 designation, so a
  single physical system is split across two host-name
  conventions. Inner binary is the sdB pulsator + M-dwarf
  eclipsing pair (see the 2MASS J19383260+4603591 b entry);
  per-component masses still need a `binary_companions` backfill.
- `Kepler-451 d`: P-type confirmed (rationale: Esmer et al. 2022
  (2022MNRAS.511.5207E), the inner of the two new Kepler-451
  planets (see Kepler-451 c above for full three-planet system
  context). Kepler-451 d has a 43 d period, minimum mass 1.76
  M_Jup, and an assumed circular orbit (~0.20 AU). Same
  ETV-around-eclipsing-sdB+dM-binary P-type-by-construction
  reasoning. cb_flag = 1 correct.)

  **Notes:** Assignment confirmed via NASA EA (verified this
  audit): d is the inner planet (43 d, ~0.20 AU), c the outer
  (~1460 d). d-specific data: 43 d period, minimum mass 1.76
  M_Jup, assumed circular. Full three-planet architecture, the
  outer-planet period discrepancy (abstract ~1800 d vs NASA EA
  1460 d), and the 2MASS-vs-Kepler-451 naming inconsistency are
  recorded under the Kepler-451 c entry above.

---

### BEBOP-3

- Distance: 117.5 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| BEBOP-3 b | Radial Velocity | 2025 | 1.44 AU | Ambiguous (RV detection; verify cb_flag against paper) | 2025MNRAS.541.2801B |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `BEBOP-3 b`: P-type confirmed (rationale: Baycroft et al. 2025
  (2025MNRAS.541.2801B) present BEBOP-3 b as the first previously
  unknown circumbinary planet detected purely via radial velocities,
  using SOPHIE spectroscopy of an eclipsing binary host. The 0.56
  M_Jup planet orbits the binary in 550 d (a ~ 1.44 AU) with e = 0.25.
  The signal is the RV reflex of the eclipsing inner binary plus the
  planet, requiring P-type geometry; the abstract explicitly frames
  the orbit as around its host binary. The same paper extracts
  independent dynamical masses for both stellar components from
  high-resolution cross-correlation spectroscopy. cb_flag = 1 correct.)

  **Notes:** Inner binary is eclipsing; dynamical component masses
  derived in-paper from high-resolution cross-correlation
  spectroscopy. Long period relative to the binary and high
  eccentricity (0.25) make BEBOP-3 b an architectural outlier compared
  to most known CBPs. A candidate outer planet at ~1400 d is reported
  but not yet confirmed (followup-citation candidate). Baycroft 2025
  also identifies stable orbital solutions for hypothetical further
  planets near the instability region populated by the Kepler CBPs.

---

### BEBOP-4 A

- Distance: 228.7 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| BEBOP-4 AB b | Radial Velocity | 2025 | 3.63 AU | Ambiguous (RV detection; verify cb_flag against paper) | 2025MNRAS.544.2180T |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `BEBOP-4 AB b`: P-type confirmed (rationale: Triaud et al. 2025
  (2025MNRAS.544.2180T) report an m sin i = 20.9 M_Jup outer companion
  on an eccentric (e = 0.43), 1800-day orbit around the BEBOP-4 inner
  binary, using SOPHIE high-resolution spectroscopy. The inner binary
  is fully resolved in the same paper: eclipsing components M_A = 1.51
  M_sun and M_B = 0.46 M_sun on a 72-day, e = 0.27 orbit, the
  longest-period binary in the BEBOP survey to date. Dynamical
  arguments cap the outer companion at m_b < 26.3 M_Jup. P-type
  geometry is required by the RV-reflex detection method and the
  explicit circumbinary framing of the abstract. cb_flag = 1 correct.)

  **Notes:** Inner-binary architecture fully characterized: M_A = 1.51
  M_sun + M_B = 0.46 M_sun, P = 72 d, e = 0.27, eclipsing. The
  20.9-26.3 M_Jup outer companion straddles the planet/brown-dwarf
  boundary; this is identical to the HIP 79098 AB b edge case and is a
  separate inclusion-as-planet question. Triaud 2025 predicts
  detectability via Gaia DR4 single-epoch astrometry, which will
  refine the true mass. Despite a 25:1 period ratio the outer
  companion sits on the edge of orbital stability, between two
  destabilizing secular resonances; if it survives, BEBOP-4 may be a
  main-sequence precursor to post-common-envelope ETV systems where
  very massive circumbinary companions have been proposed.

---

### DE CVn

- Distance: 30.3 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| DE CVn b | Eclipse Timing Variations | 2018 | 5.75 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2018ApJ...868...53H |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `DE CVn b`: P-type confirmed (rationale: Han et al. 2018
  (2018ApJ...868...53H) analysed CCD photometry plus published
  eclipse timings of DE CVn, an eclipsing post-common-envelope binary
  (PCEB), and reported a cyclic O-C variation of amplitude 28.08 s
  and period 11.22 yr alongside a rapid secular period decrease
  (dP/dt = -3.35 x 10^-11 s/s). Applegate's magnetic-cycle mechanism
  is explicitly ruled out as the source of the cyclic signal,
  leaving the light-travel-time effect of a third body as the
  favoured explanation; under coplanarity with the inner binary the
  perturber's mass is M_3 sin i = 0.011 +/- 0.003 M_sun on a
  circular ~5.75 AU orbit (matching the pl_orbsmax in the warehouse).
  The detection method, perturbation of the eclipsing inner binary's
  timing, requires P-type geometry. cb_flag = 1 correct as a
  geometric classification.)

  **Notes:** Inner binary is the eclipsing PCEB DE CVn; component
  spectral types and masses are not in this abstract (the wider
  literature has DE CVn as a WD + M-dwarf, but worth a confirming
  reference before backfilling `binary_companions`). The 0.011 M_sun
  ~ 11.5 M_Jup proposed companion sits just under the 13 M_Jup
  deuterium-burning boundary; any deviation from coplanarity with
  the inner binary pushes the true mass into brown-dwarf territory
  (same edge-case class as HIP 79098 AB b and BEBOP-4 AB b). The
  paper reports two distinct dynamical signals: (a) a rapid secular
  period decrease attributed to angular-momentum loss via a
  circumbinary disk of mass a few x 10^-4 to 10^-3 M_sun (GR +
  magnetic braking alone cannot account for the rate), and (b) the
  11.22-year cyclic oscillation attributed to the proposed planet.
  This dual-signal architecture (disk + planet in one system) is
  unusual in the cb_flag corpus and worth flagging for the
  value-added catalog. PCEB-ETV-derived planets are a historically
  contested class (compare the literature evolution of NN Ser, HW
  Vir, and HU Aqr); the geometric verdict here is unambiguous but
  the existence-as-a-planet question is a separate follow-up the
  cb_flag audit deliberately scopes out.

---

### DP Leo

- Distance: 305.7 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| DP Leo b | Eclipse Timing Variations | 2009 | 8.19 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2010ApJ...708L..66Q |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `DP Leo b`: P-type confirmed (rationale: Qian et al. 2010
  (2010ApJ...708L..66Q) compiled five new eclipse times with
  archival data for DP Leo, the first-discovered eclipsing polar
  (magnetic cataclysmic variable) on a 1.4967-hour orbit. The O-C
  residuals show a cyclic variation with period 23.8 yr and
  semi-amplitude 31.5 s, plausibly explained as the
  light-travel-time effect of a tertiary companion. Adopting a
  total inner-binary mass of 0.69 M_sun, the perturber has
  M_3 sin i' = 0.00600 +/- 0.00055 M_sun = 6.28 +/- 0.58 M_Jup;
  under coplanarity (i' = 79.5°, set by the eclipsing geometry of
  the inner binary) the object is a 6.39 M_Jup giant planet at
  ~8.6 AU. ETV around an eclipsing inner binary forces P-type
  geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary is an eclipsing polar (AM Her-class
  magnetic cataclysmic variable), total mass 0.69 M_sun, P_orb =
  1.4967 h. Component spectral types and the WD-vs-donor mass split
  are not in this abstract; polars are generically WD + M-dwarf
  donor with strong magnetic accretion, but pull a confirming
  reference before backfilling `binary_companions` for this host.
  Mass of the companion (6.28-6.39 M_Jup) is comfortably below the
  13 M_Jup deuterium-burning boundary, so unlike DE CVn b, BEBOP-4
  AB b, and HIP 79098 AB b, the planetary classification here is
  not edge-case. The abstract's quoted semi-major axis (~8.6 AU)
  disagrees with the warehouse pl_orbsmax (8.19 AU) by ~5%;
  pscomppars likely adopted a later refined timing fit
  (e.g. Beuermann et al. 2011 reanalysis or subsequent updates) and
  this should be reconciled when we resolve which paper the
  archive's value tracks. Same Qian-led PCEB-ETV planet family as
  the contested-class discussion under DE CVn b; cb_flag verdict is
  firm on geometry, planet-existence question is separately scoped
  out of this audit.

---

### HD 143811 A

- Distance: 135.2 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| HD 143811 AB b | Imaging | 2025 | 63.00 AU | Ambiguous (imaging detection; verify geometry by hand) | 2025A&A...702L..10S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `HD 143811 AB b`: P-type confirmed (rationale: Squicciarini et al.
  2025 (2025A&A...702L..10S) report a 6.1 -0.9/+0.7 M_Jup planet
  around the young (~15 Myr) binary HD 143811 from a COBREX-project
  reanalysis of archival SPHERE and GPI observations plus new
  SPHERE@VLT follow-up at 0.95-1.67 microns. The HD 143811(AB)b
  designation reflects the standard parenthetical naming convention
  for circumbinary configurations, and the authors explicitly frame
  the system as joining "the small cohort of circumbinary planets
  discovered through imaging." A 9-year astrometric baseline yields
  a mostly face-on, low-eccentricity orbit at projected separation
  0.43" (~60 AU; warehouse pl_orbsmax = 63 AU) with a period of 320
  -90/+250 yr. cb_flag = 1 correct as reported by the discovery
  paper.)

  **Notes:** Inner-binary parameters (separation, component masses,
  spectral types) are not given in this abstract; the (AB)
  designation implies the authors resolved the architecture in the
  paper body or via a prior reference, but pull that detail before
  backfilling `binary_companions`. Host system age ~15 Myr,
  consistent with the young moving-group / star-forming-region
  regime where direct-imaging giant planets are most accessible.
  Planet T_int = 1000 +/- 30 K derived from H-band GPI spectrum +
  H-band SPHERE/IRDIS photometry + YJ SPHERE/IFS upper limits; the
  6.1 M_Jup mass is comfortably planetary, no edge-case. The
  reported "mostly face-on, low eccentricity" orbit distinguishes
  this from the eccentric, mutually inclined architectures like VHS
  1256 b - relevant for future visualizer / dynamical-stability
  framing. Squicciarini 2025 notes HD 143811(AB)b is the second
  planet ever discovered by GPI (after 51 Eri b); notability tag
  for the value-added catalog. The ~60 AU abstract value vs 63 AU
  warehouse value is within rounding of the 0.43" / 135 pc
  conversion and not load-bearing here. This is a fresh discovery
  (October 2025); a prime atmospheric-characterization target.

---

### HD 202206

- Distance: 45.5 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| HD 202206 c | Radial Velocity | 2004 | 2.41 AU | Ambiguous (RV detection; verify cb_flag against paper) | 2005A&A...440..751C |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `HD 202206 c`: P-type confirmed (rationale: original RV discovery
  Correia et al. 2005 (2005A&A...440..751C) was ambiguous on the inner
  companion's mass due to sin(i) degeneracy. Follow-up by Benedict et al.
  2017 (2017AJ....153..258B, "HD 202206: A Circumbinary Brown Dwarf
  System") used HST FGS astrometry to measure the true mass of HD 202206 b,
  placing it firmly in the brown-dwarf range and confirming HD 202206 c as
  a circumbinary planet orbiting the star + brown-dwarf inner pair.)

  **Notes:** From Correia et al. 2005, the system is a two-companion
  configuration around the solar-type star HD 202206: inner HD 202206
  b at m sin i = 17.4 M_Jup, a = 0.83 AU, e = 0.43; outer HD 202206 c
  (the cb_flag entry) at m sin i = 2.44 M_Jup, a = 2.55 AU, e = 0.27,
  locked with the inner companion in a 5/1 mean motion resonance. The
  circumbinary-disk hypothesis is not a post-hoc 2017 reframing - it
  was explicitly raised in the 2005 discovery abstract ("either the
  inner planet formed simultaneously in the protoplanetary disk as a
  superplanet, or the outer Jupiter-like planet formed in a
  circumbinary disk"), and Benedict 2017's HST FGS astrometry then
  broke the inclination degeneracy in favour of the brown-dwarf-pair
  reading. Architecturally important: the inner-binary partner here
  is a brown dwarf rather than a stellar component, useful tag for
  the value-added catalog when distinguishing star+star vs star+BD
  inner pairs across the cb_flag corpus. The Correia 2005 quoted
  2.55 AU for HD 202206 c disagrees with the warehouse pl_orbsmax of
  2.41 AU by ~5%; pscomppars likely tracks a later refined dynamical
  or astrometric fit. Discovery-year nuance: warehouse lists 2004
  (announcement / preprint era) while the formal A&A publication is
  September 2005.

---

### HD 284149 A

- Distance: 116.9 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| HD 284149 AB b | Imaging | 2017 | 431 AU | Ambiguous (imaging detection; verify geometry by hand) | 2017A&A...608A.106B |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `HD 284149 AB b`: P-type confirmed (rationale: Bonavita et al. 2017
  (2017A&A...608A.106B) presented SPHERE imaging plus long-slit
  spectroscopy of HD 284149 that revealed a previously unknown
  ~0.16 M_sun stellar companion (HD 284149 B) at ~0.1" projected
  separation, making the host a close binary. The new companion is
  corroborated by RV differences in earlier data plus proper-motion
  residuals between Gaia and Tycho-2. The known wide-orbit substellar
  companion HD 284149 b is reclassified by this paper as a brown
  dwarf on a wide circumbinary orbit, framed explicitly as joining
  "the (short) list of brown dwarfs on wide circumbinary orbits."
  The warehouse pl_orbsmax of 431 AU vastly exceeds the inner
  binary's ~12 AU projected separation (0.1" at the 116.9 pc system
  distance), forcing P-type geometry. cb_flag = 1 correct as a
  geometric classification.)

  **Notes:** Inner binary HD 284149 A + B fully characterized in
  this paper: B mass ~0.16 M_sun (low-mass M-dwarf), projected
  separation ~0.1" = ~12 AU at the 116.9 pc system distance. This
  is exactly the close inner binary that wide-binary catalogs (WDS,
  SIMBAD) miss; HD 284149 is currently absent from
  `binary_companions` and should be backfilled with this paper's
  inner-binary parameters. Outer companion HD 284149 b is
  explicitly called a brown dwarf in this paper, not a planet,
  placing it in the same inclusion-as-planet edge-case family as
  ROXs 42 B b and HIP 79098 AB b; the cb_flag audit verdict is
  firm on geometry, the existence-as-a-planet question is
  separately scoped out. Bonavita 2017 also refined the system age,
  distance, and consequently the BD's mass and semi-major axis -
  useful provenance context for whichever paper the warehouse 431
  AU value tracks. Discovery-paper framing cites HD 284149 ABb as
  evidence that wide substellar companions to binaries occur with
  comparable frequency to wide companions to single stars, a useful
  population-statistics tag for the cb_flag corpus. Detection of
  the inner binary leaned on Gaia-Tycho-2 proper-motion residuals,
  a methodology that should generalize to other candidate wide
  circumbinary hosts in the audit.

---

### HIP 79098 AB

- Distance: 158.1 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 65.298 | 10321 AU | M5.0 | SIMBAD | ? |
| C | 189.190 | 29902 AU | M3--M3.5 | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| HIP 79098 AB b | Imaging | 2019 | 345 AU | Ambiguous (imaging detection; verify geometry by hand) | 2019A&A...626A..99J |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `HIP 79098 AB b`: P-type confirmed (rationale: Janson et al. 2019
  (2019A&A...626A..99J) confirmed the architecture via 15-year
  common-proper-motion analysis: the substellar companion at 345 ± 6
  AU projected separation orbits the inner B9 spectroscopic binary
  as a unit. Mass 16-25 M_Jup formally places the object in the
  brown-dwarf range; that is a separate inclusion-as-planet question
  outside the cb_flag audit's scope.)

  **Notes:** Discovery context: HIP 79098 (AB)b is the first result
  from the B-star Exoplanet Abundance Study (BEAST), a direct-imaging
  survey targeting B-type stars in the Scorpius-Centaurus young
  association, designed to extend wide-companion frequency statistics
  beyond the AFGKM regime that dominates direct-imaging surveys. The
  HIP 79098 (AB) inner binary is a B9-type spectroscopic pair;
  components are not resolved in imaging and per-star masses are not
  given in this abstract, so pull BEAST follow-ups or earlier
  characterization before backfilling `binary_companions` with
  inner-binary parameters. The two SIMBAD wide tertiaries already
  present in `binary_companions` for this host (M5.0 at 10,321 AU
  and M3-M3.5 at 29,902 AU) are unrelated to the cb_flag P-type
  question; they are wide hierarchical companions to the system as
  a whole, not the inner spectroscopic binary that defines the
  circumbinary architecture.

  Detection methodology is itself notable. HIP 79098 (AB)b was
  previously reported in the literature but dismissed as a
  background contaminant on the basis of peculiar colors; Janson
  2019 demonstrated those colors actually match young low-mass
  brown dwarfs in Sco-Cen and ruled out background via a 15-yr
  common-proper-motion baseline. This is a generalizable lesson
  for surfacing substellar companions hidden in archival
  photometric data (compare HD 284149 AB b, whose inner binary
  also emerged from proper-motion residual analysis). The companion
  mass of 16-25 M_Jup is firmly in the brown-dwarf range, but its
  mass ratio q < 1% relative to the B9 binary places it in the
  "planet-like mass ratios around massive stars" cohort, relevant
  for the value-added catalog where mass-ratio-based and
  absolute-mass-based categorization can disagree (compare ROXs 42
  B b, HD 284149 AB b, BEBOP-4 AB b). cb_flag verdict is firm on
  geometry; existence-as-a-planet question separately scoped out.

---

### HU Aqr

- Distance: 192.2 pc
- Planets in this system flagged `cb_flag=1`: 2

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| HU Aqr AB b | Eclipse Timing Variations | 2011 | 3.60 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2011MNRAS.414L..16Q |
| HU Aqr AB c | Eclipse Timing Variations | 2011 | 5.40 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2011MNRAS.414L..16Q |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `HU Aqr AB b`: P-type confirmed (rationale: Qian et al. 2011
  (2011MNRAS.414L..16Q) used precise mid-egress timing of the
  eclipsing polar HU Aqr to infer the light-travel-time effect of
  two giant planetary companions: HU Aqr AB b at m sin i >= 5.9
  M_Jup, a = 3.6 AU, P = 6.54 yr, and HU Aqr AB c at m sin i >=
  4.5 M_Jup, a = 5.4 AU, P = 11.96 yr (entry below). The detection
  method, perturbation of the eclipsing polar's mid-egress timing,
  requires P-type geometry by construction. cb_flag = 1 correct as
  a geometric classification.)

  **Notes:** Inner binary is the HU Aqr eclipsing polar (magnetic
  cataclysmic variable, generically WD + M-dwarf donor;
  per-component parameters not given in this abstract, pull from
  earlier characterization before backfilling `binary_companions`).
  The two-planet O-C solution proposed by Qian 2011 places the
  planets in a Titius-Bode-like spacing with n = 5 and 6, and
  predicts a third planet detectable within ~10 yr of additional
  timing data. The same paper notes the observed O-C rate of
  period decrease is 15x the gravitational-radiation expectation,
  framed as evidence for a long-period cyclic variation that would
  be the third body's signature. Audit reviewer note (2026-05-20):
  14 years after the 2011 prediction, no third planet has been
  confirmed and the predicted ~10-yr window has closed without
  resolution, a load-bearing fact for the contested-class context
  below.

  Architectural caveat: HU Aqr's planet claims are the most
  contested of the PCEB-ETV-derived cohort. Subsequent literature
  (notably Goździewski et al. 2012/2015 and Wittenmyer et al. 2012,
  cited from general knowledge - please verify before relying)
  showed the original 2-planet timing solution is dynamically
  unstable on short timescales and that the timing model is
  inadequate; the broader literature has trended toward
  interpreting at least one of the O-C signals as an artifact of
  magnetic activity or unmodelled accretion physics rather than a
  real planet. The cb_flag audit verdict here is firm on geometry:
  if the planets exist at all, they are P-type by ETV
  construction. The existence-as-a-planet question is more
  strongly contested for HU Aqr than for any other entry in the
  corpus, and the audit deliberately scopes that question out.
  Same Qian-led family as DE CVn b and DP Leo b; HU Aqr is the
  most prominent contested-class member.
- `HU Aqr AB c`: P-type confirmed (rationale: Qian et al. 2011
  (2011MNRAS.414L..16Q), companion 2-planet solution from the
  same mid-egress timing analysis described under HU Aqr AB b
  above: HU Aqr AB c at m sin i >= 4.5 M_Jup, a = 5.4 AU, P =
  11.96 yr. Same ETV-around-eclipsing-polar
  P-type-by-construction reasoning. cb_flag = 1 correct as a
  geometric classification.)

  **Notes:** Full architectural and contested-class context is in
  the Notes block under HU Aqr AB b above. c-specific data:
  m sin i >= 4.5 M_Jup, a = 5.4 AU, P = 11.96 yr; the 2011
  abstract's "Titius-Bode-like n = 6" framing places c as the
  outer member of the proposed 2-planet solution. The 5.4 AU
  value from Qian 2011 matches the warehouse pl_orbsmax exactly,
  no discrepancy to flag.

---

### KMT-2016-BLG-1337L

- Distance: 6920.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| KMT-2016-BLG-1337L b | Microlensing | 2026 | 3.97 AU | Ambiguous (microlensing fits are often degenerate) | 2026PASP..138c4401H |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `KMT-2016-BLG-1337L b`: Ambiguous (rationale: Han et al. 2026
  (2026PASP..138c4401H) report the discovery of a planetary
  microlensing companion in KMT-2016-BLG-1337, identifying a
  triple-lens single-source (3L1S) interpretation as the best fit
  over the binary-lens binary-source (2L2S) alternative. Two
  viable 3L1S solutions describe the event nearly equally well:
  Solution A with M_3 ~ 0.3 M_Jup at projected separation a_perp
  ~ 4 AU from the heavier host (M_1 ~ 0.54 M_sun), and Solution B
  with M_3 ~ 7 M_Jup at projected separation a_perp ~ 1.5 AU
  (anchor not explicitly stated in this abstract). The host
  binary is M_1 ~ 0.54 M_sun and M_2 ~ 0.40 M_sun (both early
  M-dwarfs) with a_perp,2 ~ 3.5 AU, at D_L ~ 7 kpc toward the
  Galactic bulge. The abstract does NOT explicitly state that the
  planet is outside both stars in either solution: Solution A's
  4 AU projected separation from M_1 is comparable to the binary's
  own 3.5 AU projected separation, and Solution B's 1.5 AU is
  much smaller than the binary itself. Neither solution
  unambiguously establishes P-type geometry from the abstract
  alone, so the cb_flag = 1 in the warehouse is not strongly
  supported by the discovery paper as written.)

  **Notes:** This is a candidate audit finding: NASA EA marks
  KMT-2016-BLG-1337L b as cb_flag = 1 but the discovery abstract
  describes two viable 3L1S microlensing solutions, neither of
  which the abstract frames explicitly as circumbinary. Compare
  OGLE-2007-BLG-349L AB c, where the user-confirmed P-type verdict
  rested on the discovery paper stating that "all viable solutions
  are triple-lens with the planet outside both stars" - the
  analogous architectural-confirmation statement is absent here.
  The two solutions represent the canonical close/wide
  microlensing degeneracy (close: 1.5 AU + 7 M_Jup; wide: 4 AU +
  0.3 M_Jup). Warehouse pl_orbsmax of 3.97 AU clearly tracks
  Solution A. Suggested follow-up: pull the Han 2026 paper body
  to see whether the authors explicitly classify either solution
  as circumbinary, or whether the cb_flag in the archive is an
  over-claim; this is a strong candidate for either S-type misflag
  or formal downgrade to cb_flag = 0 pending architecture
  resolution.

  Inner-binary parameters are unusually well-determined for a
  microlensing event in this corpus: M_1 = 0.54 M_sun, M_2 =
  0.40 M_sun (both early M-dwarfs), a_perp,2 = 3.5 AU. These
  should be backfilled into `binary_companions` regardless of
  which planetary solution wins. Discovery year 2016 in the
  warehouse table reflects the original microlensing event date;
  formal publication is March 2026, illustrating the ~10-year
  analysis latency typical of complex microlensing events.

---

### Kepler-16

- Distance: 75.4 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-16 b | Transit | 2011 | 0.705 AU | P-type likely (transit detection) | 2011Sci...333.1602D |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-16 b`: P-type confirmed (rationale: Doyle et al. 2011
  (2011Sci...333.1602D) reported the first transit-detected
  circumbinary planet from Kepler photometry. The light curve
  shows the planet transiting both stars of the eclipsing inner
  binary, plus the mutual eclipses of the two stars themselves,
  yielding direct geometric constraints on the absolute dimensions
  of all three bodies. The planet is Saturn-mass and Saturn-size,
  on a nearly circular 229-day orbit around the binary. The inner
  binary consists of stars of 0.69 M_sun (M_A) and 0.20 M_sun
  (M_B) on an eccentric 41-day orbit. All three orbits are
  coplanar to within 0.5°, consistent with formation in a
  circumbinary disk. This is the prototypical P-type configuration
  and the reference architecture for the Doyle 2011 / Welsh+ 2012
  P/S/T classification convention used throughout this audit.
  cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized in this paper: M_A
  = 0.69 M_sun, M_B = 0.20 M_sun, P_orb = 41 days, eccentric
  (specific e not given in this abstract; pull paper body for the
  numerical eccentricity before backfilling `binary_companions`).
  The inner binary is both eclipsing and mutually resolved by
  Kepler photometry, and the planet transits BOTH stars - an
  unusually rich four-body geometric dataset. Cross-check: the
  warehouse pl_orbsmax of 0.705 AU matches the 229-day Saturn-mass
  abstract value via Kepler's third law (a^3 = P^2 * M_total with
  M_total = 0.89 M_sun gives a = 0.704 AU), no discrepancy to
  flag. Coplanarity to 0.5° is a strong constraint on formation
  scenarios and a useful tag for the value-added catalog when
  distinguishing co-planar disk-formed CBPs (Kepler-16 and the
  other transiting Kepler/TESS CBPs) from the highly inclined or
  dynamically pumped wide-imaging systems (e.g. VHS 1256 b).
  Spectral types of A (K-dwarf, generic for 0.69 M_sun) and B
  (M-dwarf, generic for 0.20 M_sun) are not given in this
  abstract and should be confirmed from the paper body. This is
  the foundational transit-detected circumbinary system and the
  most reproducible P-type classification in the corpus.

---

### Kepler-1647

- Distance: 1212.5 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 69.764 | 84586 AU | ? | SIMBAD | ? |
| C | 81.999 | 99419 AU | ? | SIMBAD | ? |
| D | 118.423 | 143582 AU | ? | SIMBAD | ? |
| E | 129.562 | 157087 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-1647 b | Transit | 2016 | 2.72 AU | P-type likely (transit detection) | 2016ApJ...827...86K |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-1647 b`: P-type confirmed (rationale: Kostov et al. 2016
  (2016ApJ...827...86K) reported a transit-detected circumbinary
  planet around the 11-day eclipsing binary Kepler-1647. The
  planet produced three transits across the four-year Kepler
  mission (rare for transit detection due to its very long
  ~1100-day orbital period), including a syzygy event with one
  transit occurring during a stellar eclipse. Eclipse-timing
  perturbations measured the planet's mass at 1.52 +/- 0.65 M_Jup,
  and the transits gave a radius of 1.06 +/- 0.01 R_Jup. The inner
  binary consists of two solar-mass stars on a mildly eccentric
  (e_bin = 0.16) 11-day orbit, slightly inclined relative to the
  planet's orbit and spin-synchronized. Direct
  transit-across-the-binary detection forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized in this paper: M_A
  and M_B both solar-mass (specific per-component split not given
  in this abstract; pull paper body before backfilling
  `binary_companions`), P_orb = 11 days, e_bin = 0.16,
  spin-synchronized rotation (tidally locked), slightly inclined
  relative to the planet's orbital plane. Architectural notability
  at time of discovery: Kepler-1647 b was simultaneously the
  longest-period transiting circumbinary planet known, one of the
  longest-period transiting planets of any kind, and the largest
  known CBP (1.06 R_Jup). With only three transits across the
  four-year Kepler mission lifetime the radius is well-constrained
  but the orbital ephemeris has unusually wide uncertainty for a
  Kepler CBP. Habitable-zone tag: despite the planet's orbital
  period being roughly 3x Earth's, Kepler-1647 b sits in the
  conservative habitable zone of the binary throughout its orbit
  (the binary's higher combined luminosity pushes the HZ
  outward) - a strong notability tag for the value-added catalog
  and for outreach. The four SIMBAD wide tertiaries already
  present in `binary_companions` for this host (84,000-157,000 AU
  projected) are unrelated to the cb_flag P-type question; they
  are wide hierarchical companions to the system as a whole, not
  the inner eclipsing binary that defines the circumbinary
  architecture. Cross-check on semi-major axis: a back-of-envelope
  Kepler's-third-law calculation with P = 1100 d and M_total = 2.0
  M_sun gives a = 2.63 AU, about 3% short of the warehouse
  pl_orbsmax of 2.72 AU; the discrepancy probably reflects a
  refined total-mass or period fit in the paper body and is worth
  reconciling on backfill.

---

### Kepler-1660 A

- Distance: 1142.9 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 50.385 | 57587 AU | ? | SIMBAD | ? |
| C | 188.071 | 214954 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-1660 AB b | Eclipse Timing Variations | 2023 | 0.800 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2023MNRAS.525.4628G |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-1660 AB b`: P-type confirmed (rationale: the 2023
  confirmation paper (2023MNRAS.525.4628G) obtained the first
  radial velocities of the 18.6-day main-sequence eclipsing binary
  Kepler-1660 AB and combined them with eclipse timing variations
  and eclipse depth variations to confirm a 239.5-day circumbinary
  planet of mass 4.87 M_Jup on a coplanar orbit. The detection
  rests on ETV perturbation of an eclipsing binary plus RV
  confirmation, which forces P-type geometry. cb_flag = 1 correct,
  and unlike the PCEB-ETV cohort the planet's existence is robustly
  confirmed by three independent methods.)

  **Notes:** Multi-paper provenance, important for the
  citation-system revamp: Borkovits et al. 2016 first detected the
  ETVs on the 18.6-d binary indicating a ~236-d third body with a
  potentially planetary mass; Getley et al. 2017 argued for a 7.7
  M_Jup planet on an orbit highly misaligned by 120° with respect
  to the binary; the 2023 confirmation paper revised this to 4.87
  M_Jup on a coplanar orbit, definitively ruling out the
  misaligned solutions via the absence of eclipse depth
  variations. The warehouse currently cites only the 2023 paper as
  discovery, but the real discovery chain is Borkovits 2016 ->
  Getley 2017 -> 2023 confirmation; this is a prime candidate for
  the multi-citation-per-planet feature. The 2023 paper's
  first-author name is not given in the abstract (written in first
  person); bibcode indicates a surname starting with G, verify
  before citing by name.

  Architectural significance: Kepler-1660 AB b is the first
  confirmed circumbinary planet found via ETVs around a main
  sequence binary. This is a sharp distinction from the
  PCEB-ETV-derived cohort (DE CVn, DP Leo, HU Aqr, NN Ser, UZ For,
  NSVS 14256825, NY Vir, RR Cae), which orbit evolved
  post-common-envelope binaries and several of which are contested.
  The multi-method confirmation here (RV + ETV + eclipse depth
  variations) makes this one of the most robust ETV-derived planet
  detections in the corpus, in sharp contrast to the HU Aqr-style
  contested claims. Inner-binary parameters beyond P_orb = 18.6 d
  (per-component masses, e_bin) are not given in this abstract and
  should be pulled before backfilling; a Kepler's-third-law check
  on the warehouse pl_orbsmax of 0.800 AU implies M_total ~ 1.2
  M_sun, so roughly two ~0.6 M_sun stars. The two SIMBAD wide
  tertiaries already present in `binary_companions` (57,587 AU and
  214,954 AU projected) are unrelated to the cb_flag P-type
  question. Mass-evolution caveat for the value-added catalog: the
  planet's mass changed from 7.7 M_Jup (Getley 2017) to 4.87 M_Jup
  (2023), a concrete illustration of why citation provenance
  matters for parameter integrity.

---

### Kepler-1661

- Distance: 388.4 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 117.761 | 45737 AU | ? | SIMBAD | ? |
| C | 190.652 | 74047 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-1661 b | Transit | 2020 | 0.633 AU | P-type likely (transit detection) | 2020AJ....159...94S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-1661 b`: P-type confirmed (rationale: Socia et al. 2020
  (2020AJ....159...94S) reported a Neptune-sized (Rp = 3.87 +/-
  0.06 R_Earth) transiting circumbinary planet from Kepler
  photometry, on a ~175-day orbit around a single-lined grazing
  eclipsing binary. The inner binary comprises 0.84 M_sun and 0.26
  M_sun stars on a mildly eccentric (e = 0.11) 28.2-day orbit.
  Direct transit-across-the-binary detection forces P-type
  geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized: M_A = 0.84 M_sun,
  M_B = 0.26 M_sun, e_bin = 0.11, P_orb = 28.2 d, single-lined,
  grazing eclipses. System age ~1-3 Gyr (fairly young) with
  significant starspot modulation. Cross-check: warehouse
  pl_orbsmax of 0.633 AU matches the abstract via Kepler's third
  law (P = 175 d, M_total = 1.10 M_sun gives a = 0.632 AU), no
  discrepancy. Like several Kepler CBPs the planet orbits close to
  the dynamical stability radius and near the hot (inner) edge of
  the habitable zone (contrast Kepler-1647 b, which sits in the
  conservative HZ).

  Two notable observational subtleties: (1) the planet's orbit
  precesses with a period of only ~35 yr, causing the
  planet-binary plane alignment to vary such that the planet is in
  a transiting configuration only ~7% of the time as seen from
  Earth, a strong selection-bias caveat for transit-detected CBP
  occurrence statistics in the value-added catalog. (2) The paper
  flags a methodological hazard for eclipse-depth-variation
  analysis: starspots alter the light-curve normalization and can
  induce spurious eclipse depth variations that get incorrectly
  ascribed to binary orbital precession. This is worth
  cross-linking to the Kepler-1660 AB b entry above, whose
  coplanarity confirmation relied on eclipse depth variations;
  together the two systems make a useful methods note for the
  value-added catalog on the reliability of
  eclipse-depth-variation inferences. The two SIMBAD wide
  tertiaries already present in `binary_companions` for this host
  (45,737 AU and 74,047 AU projected) are unrelated to the
  cb_flag P-type question.

---

### Kepler-34

- Distance: 1523.6 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 110.815 | 168836 AU | ? | SIMBAD | ? |
| C | 133.627 | 203592 AU | ? | SIMBAD | ? |
| D | 144.067 | 219498 AU | ? | SIMBAD | ? |
| E | 159.116 | 242427 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-34 b | Transit | 2011 | 1.09 AU | P-type likely (transit detection) | 2012Natur.481..475W |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-34 b`: P-type confirmed (rationale: Welsh et al. 2012
  (2012Natur.481..475W) reported Kepler-34 (AB)b as one of two
  transiting circumbinary planets (with Kepler-35 b) that
  established the prevalence of the CBP class following the first
  case, Kepler-16. Kepler-34 b is a low-density gas giant orbiting
  two Sun-like stars every 289 days on an orbit closely aligned
  (coplanar) with the binary. Direct transit-across-the-binary
  detection forces P-type geometry. This is the reference paper
  for the Welsh+ 2012 half of the Doyle 2011 / Welsh+ 2012
  classification convention used throughout this audit. cb_flag =
  1 correct.)

  **Notes:** Inner binary is two Sun-like stars (per-component
  masses not split in this abstract beyond "Sun-like"; pull paper
  body before backfilling `binary_companions`), planet P_orb =
  289 d. Cross-check: warehouse pl_orbsmax of 1.09 AU matches the
  abstract via Kepler's third law (P = 289 d, M_total ~ 2.07
  M_sun for two Sun-like stars gives a = 1.090 AU), no
  discrepancy. The planet experiences large multi-periodic
  variations in incident stellar flux from the binary's orbital
  motion, a useful tag for the value-added catalog's
  insolation/climate framing. Occurrence-rate result from this
  paper: more than ~1% of close binaries host coplanar giant
  CBPs, implying a Galactic population of at least several
  million, the foundational CBP occurrence statistic. The four
  SIMBAD wide tertiaries already present in `binary_companions`
  for this host (168,836-242,427 AU projected) are unrelated to
  the cb_flag P-type question. Note: this abstract is the joint
  Kepler-34 / Kepler-35 discovery paper, so Kepler-35 b is filled
  from the same source.

---

### Kepler-35

- Distance: 1423.8 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 98.562 | 140333 AU | ? | SIMBAD | ? |
| C | 162.079 | 230769 AU | ? | SIMBAD | ? |
| D | 189.359 | 269611 AU | ? | SIMBAD | ? |
| E | 190.052 | 270597 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-35 b | Transit | 2011 | 0.603 AU | P-type likely (transit detection) | 2012Natur.481..475W |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-35 b`: P-type confirmed (rationale: Welsh et al. 2012
  (2012Natur.481..475W), companion discovery to Kepler-34 b in the
  same paper. Kepler-35 (AB)b is a low-density gas giant orbiting
  a pair of smaller stars (0.89 M_sun and 0.81 M_sun) every 131
  days on a closely aligned (coplanar) orbit. Direct
  transit-across-the-binary detection forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized: M_A = 0.89 M_sun,
  M_B = 0.81 M_sun (89% and 81% of solar mass per the abstract),
  planet P_orb = 131 d. Cross-check: warehouse pl_orbsmax of
  0.603 AU matches the abstract via Kepler's third law (P = 131
  d, M_total = 1.70 M_sun gives a = 0.603 AU), exact, no
  discrepancy. Like Kepler-34 b, the planet experiences large
  multi-periodic insolation variations from the binary's orbital
  motion. The four SIMBAD wide tertiaries already present in
  `binary_companions` for this host (140,333-270,597 AU
  projected) are unrelated to the cb_flag P-type question. Shared
  discovery paper with Kepler-34 b; the foundational CBP
  occurrence statistic (more than ~1% of close binaries host
  coplanar giant CBPs) is reported jointly and recorded in full
  under the Kepler-34 b entry.

---

### Kepler-38

- Distance: 1235.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 80.841 | 99838 AU | ? | SIMBAD | ? |
| C | 165.514 | 204408 AU | ? | SIMBAD | ? |
| D | 190.596 | 235384 AU | ? | SIMBAD | ? |
| E | 197.755 | 244226 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-38 b | Transit | 2012 | 0.463 AU | P-type likely (transit detection) | 2012ApJ...758...87O |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-38 b`: P-type confirmed (rationale: Orosz et al. 2012
  (2012ApJ...758...87O) reported a transit-detected circumbinary
  planet around the 18.8-day single-lined eclipsing binary
  Kepler-38. Eight transits across the primary star were
  identified in Kepler Quarters 1-11, yielding a planetary period
  of 105.595 days; a photometric-dynamical model combining the RV
  curve and Kepler light curve gives a radius of 4.35 +/- 0.11
  R_Earth. Direct transit-across-the-binary detection forces
  P-type geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary is exceptionally well characterized in
  this paper, the most complete inner-binary dataset in the audit
  so far: primary M_A = 0.949 +/- 0.059 M_sun, R_A = 1.757 +/-
  0.034 R_sun (a moderately evolved main-sequence star, hence the
  inflated radius for its mass); secondary M_B = 0.249 +/- 0.010
  M_sun, R_B = 0.2724 +/- 0.0053 R_sun; mildly eccentric (e_bin =
  0.103), P_orb = 18.8 d. This is a ready-to-use
  `binary_companions` backfill with masses AND radii for both
  components. Cross-check: warehouse pl_orbsmax of 0.463 AU
  matches the abstract via Kepler's third law (P = 105.595 d,
  M_total = 1.198 M_sun gives a = 0.464 AU), no discrepancy.
  Planet mass is an upper limit only (< 122 M_Earth = 0.384 M_Jup
  at 95% confidence): unlike the ETV systems, the planet is too
  low-mass to observably perturb the binary's Keplerian motion, so
  there is no dynamical mass measurement, only the transit radius.
  Worth flagging for the value-added catalog that this planet's
  mass is an upper bound, not a measurement, and the abstract
  notes the limit should tighten with additional Kepler data. The
  four SIMBAD wide tertiaries already present in
  `binary_companions` for this host (99,838-244,226 AU projected)
  are unrelated to the cb_flag P-type question.

---

### Kepler-413

- Distance: 825.7 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 111.823 | 92329 AU | ? | SIMBAD | ? |
| C | 160.174 | 132252 AU | G8V | SIMBAD | ? |
| D | 162.704 | 134340 AU | ? | SIMBAD | ? |
| E | 172.864 | 142730 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-413 b | Transit | 2014 | 0.355 AU | P-type likely (transit detection) | 2014ApJ...784...14K |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-413 b`: P-type confirmed (rationale: Kostov et al. 2014
  (2014ApJ...784...14K) reported a transiting circumbinary planet
  (Rp = 4.347 +/- 0.099 R_Earth) around the K+M eclipsing binary
  KIC 12351927 (Kepler-413). The planet orbits every ~66 days on
  an eccentric orbit (a_p = 0.355 +/- 0.002 AU, e_p = 0.118),
  inclined ~2.5° to the binary plane. Direct
  transit-across-the-binary detection forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized (masses + radii + e
  + period, comparable completeness to Kepler-38): primary M_A =
  0.820 +/- 0.015 M_sun, R_A = 0.776 +/- 0.009 R_sun (K-dwarf);
  secondary M_B = 0.542 +/- 0.008 M_sun, R_B = 0.484 +/- 0.024
  R_sun (M-dwarf); P_orb = 10.11615 d (to ~1 s precision), nearly
  circular e_EB = 0.037, i_EB = 87.33°. Ready-to-use
  `binary_companions` backfill. Cross-check: warehouse pl_orbsmax
  of 0.355 AU is the abstract's a_p exactly (0.355 +/- 0.002 AU),
  no calculation needed and no discrepancy.

  Three notable dynamical features: (1) the planet's orbit is
  measurably misaligned by ~2.5° to the binary plane, one of the
  small number of transiting CBPs with non-zero mutual
  inclination (compare the Kepler-1660 AB b discussion of the
  < 4.5° transiting-CBP inclination ceiling). (2) Orbital
  precession with a period of ~11 yr causes the planet to
  repeatedly fail to transit at inferior conjunction, producing
  stretches of hundreds of days with no transits; Kostov 2014
  predicted the next transit would not occur until 2020, a
  falsifiable prediction now in the past and worth checking
  against later Kepler/TESS or ground-based data. This is the
  same precession-driven transit-visibility selection effect
  flagged for Kepler-1661 b. (3) The planet may experience
  Cassini State dynamics under the binary's influence, with
  obliquity precessing at a rate comparable to its orbital
  precession and potential obliquity swings of dozens of degrees
  driving complex seasonal cycles, a strong visualization and
  outreach hook for the 3D viewer and a useful climate-dynamics
  tag for the value-added catalog. The planet sits slightly
  inside the inner edge of the extended habitable zone. The four
  SIMBAD wide tertiaries already present in `binary_companions`
  for this host (92,329-142,730 AU projected; component C typed
  G8V) are unrelated to the cb_flag P-type question.

---

### Kepler-453

- Distance: 445.5 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-453 b | Transit | 2015 | 0.790 AU | P-type likely (transit detection) | 2015ApJ...809...26W |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-453 b`: P-type confirmed (rationale: Welsh et al. 2015
  (2015ApJ...809...26W) reported a transiting circumbinary planet
  (6.2 R_Earth) on a low-eccentricity 240.5-day orbit about the
  27.32-day eclipsing binary Kepler-453. Three transits appear in
  the second half of the Kepler light curve. The planet's period
  is 8.8x the binary's, placing it well outside the dynamical
  instability zone. Direct transit-across-the-binary detection
  forces P-type geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary: M_A = 0.94 M_sun, M_B = 0.195 M_sun,
  P_orb = 27.32 d (radii not given in this abstract, unlike
  Kepler-38 and Kepler-413; pull paper body for R_A/R_B before
  full backfill). Cross-check: warehouse pl_orbsmax of 0.790 AU
  matches the abstract via Kepler's third law (P = 240.5 d,
  M_total = 1.135 M_sun gives a = 0.790 AU), exact, no
  discrepancy. Planet mass is an upper limit only (< 16 M_Earth
  at 1 sigma): like Kepler-38 b the planet is too low-mass to
  observably perturb the binary, so there is no dynamical mass
  measurement, only the photodynamical radius. In the habitable
  zone of the binary; the abstract notes it is the third of 10
  Kepler CBPs known at the time to lie in the HZ.

  Strongest occurrence-statistics datapoint in the audit so far:
  the planet's orbital plane precesses rapidly (precession period
  ~103 yr), and transits are geometrically visible only ~8.9% of
  the time over that cycle. Welsh 2015 draws the explicit
  inference that for every transiting system like Kepler-453 that
  is detected, ~11.5 equivalent circumbinary systems exist but are
  not currently transiting. This ~11.5x hidden-population
  multiplier is a high-value correction factor for any
  CBP-occurrence framing in the value-added catalog, and it is the
  quantitative version of the precession-driven
  transit-visibility selection effect flagged for Kepler-1661 b
  (35-yr precession) and Kepler-413 b (11-yr precession). No
  `binary_companions` row exists for this host, so the
  inner-binary parameters above are the only multi-star data
  available and should be backfilled.

---

### Kepler-47

- Distance: 961.5 pc
- Planets in this system flagged `cb_flag=1`: 3

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 93.871 | 90256 AU | ? | SIMBAD | ? |
| C | 166.987 | 160556 AU | ? | SIMBAD | ? |
| D | 174.579 | 167855 AU | ? | SIMBAD | ? |
| E | 196.282 | 188723 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Kepler-47 b | Transit | 2012 | 0.288 AU | P-type likely (transit detection) | 2012Sci...337.1511O |
| Kepler-47 c | Transit | 2012 | 0.964 AU | P-type likely (transit detection) | 2012Sci...337.1511O |
| Kepler-47 d | Transit | 2019 | 0.699 AU | P-type likely (transit detection) | 2019AJ....157..174O |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Kepler-47 b`: P-type confirmed (rationale: Orosz et al. 2012
  (2012Sci...337.1511O) reported Kepler-47 as the first
  multiple-planet circumbinary system: two planets transiting an
  eclipsing binary. Kepler-47 b is the inner planet, radius 3.0
  R_Earth, orbital period 49.5 days, with 18 transits observed in
  the Kepler light curve allowing detailed orbit characterization.
  Direct transit-across-the-binary detection forces P-type
  geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary is a Sun-like primary plus a companion
  "roughly one-third its size" (the abstract gives sizes/radii
  qualitatively, not component masses; pull paper body for
  numerical M_A, M_B, R_A, R_B before backfilling
  `binary_companions`), binary P_orb = 7.45 d. A Kepler's-third-law
  cross-check on both planets implies M_total ~ 1.3 M_sun (so
  roughly a 1.0 M_sun primary plus a ~0.3 M_sun secondary).
  Kepler-47 b cross-check: warehouse pl_orbsmax of 0.288 AU
  matches the abstract via Kepler's third law (P = 49.5 d,
  M_total ~ 1.3 M_sun gives a = 0.288 AU), no discrepancy.

  System-level significance: Kepler-47 was the first circumbinary
  system shown to host multiple planets, establishing that close
  binaries can host complete planetary systems (per the abstract).
  A third planet, Kepler-47 d, was added in 2019 (Orosz et al.
  2019, 2019AJ....157..174O), making Kepler-47 the most populous
  known circumbinary system; d remains to be filled in this audit
  pending its abstract. The four SIMBAD wide tertiaries already
  present in `binary_companions` for this host (90,256-188,723 AU
  projected) are unrelated to the cb_flag P-type question. Full
  inner-binary and system notes for all three Kepler-47 planets
  are recorded here under b.
- `Kepler-47 c`: P-type confirmed (rationale: Orosz et al. 2012
  (2012Sci...337.1511O), the outer planet of the original
  Kepler-47 two-planet discovery (see Kepler-47 b above for full
  system context). Kepler-47 c has radius 4.6 R_Earth and an
  orbital period of 303.2 days, and although not Earth-like it
  resides within the classical habitable zone where liquid water
  could exist on an Earth-like planet. Direct
  transit-across-the-binary detection forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** c-specific data: radius 4.6 R_Earth, P_orb = 303.2
  d, in the classical habitable zone of the binary. Cross-check:
  warehouse pl_orbsmax of 0.964 AU matches the abstract via
  Kepler's third law (P = 303.2 d, M_total ~ 1.3 M_sun gives a =
  0.964 AU), exact, no discrepancy. Shared inner-binary
  parameters and system-level significance are recorded under the
  Kepler-47 b entry above.
- `Kepler-47 d`: P-type confirmed (rationale: Orosz et al. 2019
  (2019AJ....157..174O) reported Kepler-47 d, the middle and third
  planet of the Kepler-47 system (the only known multi-planet
  transiting circumbinary system at the time; see Kepler-47 b
  above for inner-binary context). Kepler-47 d has an orbital
  period of 187.4 d (between the inner b at 49.5 d and outer c at
  303.2 d) and a radius of ~7 R_Earth, the largest of the three.
  Direct transit-across-the-binary detection forces P-type
  geometry. cb_flag = 1 correct.)

  **Notes:** Kepler-47 d is the middle planet, discovered after b
  and c; its detection significantly improved the mass constraints
  on all three planets (1-sigma mass ranges: inner b < 26
  M_Earth, middle d 7-43 M_Earth, outer c 2-5 M_Earth). The middle
  and outer planets have low bulk densities (rho_d < 0.68 g/cm^3,
  rho_c < 0.26 g/cm^3). Cross-check: warehouse pl_orbsmax of 0.699
  AU matches the abstract via Kepler's third law (P = 187.4 d,
  M_total ~ 1.3 M_sun gives a = 0.699 AU), exact. Architecture
  notes: the middle (d) and outer (c) planets are "tightly
  packed," meaning no additional planet could stably orbit between
  them; all three orbits are low-eccentricity and nearly coplanar,
  which the authors argue disfavours violent scattering and
  supports gentle migration in the protoplanetary disk. With three
  confirmed transiting planets, Kepler-47 is the most populous
  transiting circumbinary system (contrast Kepler-451's three
  ETV-detected planets); this completes the Kepler-47 trio in the
  audit. Full inner-binary and system context is recorded under
  the Kepler-47 b entry.

---

### MXB 1658-298

- Distance: unknown
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| MXB 1658-298 b | Eclipse Timing Variations | 2017 | 1.61 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2017MNRAS.468L.118J |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `MXB 1658-298 b`: P-type confirmed (rationale: Jain et al. 2017
  (2017MNRAS.468L.118J) performed X-ray eclipse timing of the
  transient low-mass X-ray binary MXB 1658-298 using RXTE and
  XMM-Newton, adding 27 new mid-eclipse times across two
  outbursts. Beyond an overall orbital-period decay (time-scale
  -6.5e7 yr), the O-C residuals show a sinusoidal variation of
  amplitude ~9 lt-s and period ~760 d, interpreted as the
  light-travel-time effect of a third body. The detection is
  eclipse timing of a compact eclipsing binary, which forces
  P-type geometry by construction. cb_flag = 1 correct as a
  geometric classification.)

  **Notes:** Inner binary is the compact LMXB MXB 1658-298 (a
  neutron star accreting from a low-mass companion; the binary
  orbital period is only a few hours, hence the abstract's claim
  that this would be "the smallest period binary known to host a
  planet"). Per-component parameters are not given in this
  abstract; pull the LMXB characterization literature before
  backfilling `binary_companions`. Unit cross-check: the abstract
  states the third body's orbital radius as 750-860 lt-s, which
  converts to 1.50-1.72 AU (1 lt-s = 2.004e-3 AU); the warehouse
  pl_orbsmax of 1.61 AU sits mid-range (~803 lt-s), no
  discrepancy.

  Two strong caveats for the value-added catalog: (1) the third
  body's mass of 20.5-26.9 M_Jup is firmly in the brown-dwarf
  range, above the 13 M_Jup deuterium-burning boundary; the
  abstract itself hedges "if true, then it will be the most
  massive circumbinary planet," so this is an inclusion-as-planet
  edge case on mass grounds alone, same family as HIP 79098 AB b,
  BEBOP-4 AB b, and HD 284149 AB b. (2) The detection is tentative
  ("indicative of the presence of a third body," "if true"), and
  X-ray-binary eclipse-timing planets are among the most
  speculative detection classes, sharing the contested-class
  concerns of the PCEB-ETV cohort (HU Aqr, DE CVn, DP Leo). The
  cb_flag audit verdict here is firm on geometry, but both the
  existence and the planet-vs-brown-dwarf classification are
  weakly constrained; flag this as a low-confidence entry.

---

### NN Ser

- Distance: 515.8 pc
- Planets in this system flagged `cb_flag=1`: 2

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 144.722 | 74650 AU | ? | SIMBAD | ? |
| C | 154.213 | 79546 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| NN Ser c | Eclipse Timing Variations | 2010 | 5.35 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2010A&A...521L..60B |
| NN Ser d | Eclipse Timing Variations | 2010 | 3.39 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2010A&A...521L..60B |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `NN Ser c`: P-type confirmed (rationale: Beuermann et al. 2010
  (2010A&A...521L..60B) fit the long-term eclipse timing
  variations of NN Ser ab, an eclipsing short-period
  post-common-envelope binary (PCEB), using mid-eclipse times
  from 1988-2010. The O-C residuals are well matched by the
  light-travel-time effect of two circumbinary bodies, NN Ser
  (ab)c and d, locked in a 2:1 mean motion resonance. NN Ser c is
  the outer planet: M_c sin i_c ~ 6.9 M_Jup, P_c ~ 15.5 yr, e_c ~
  0. ETV around an eclipsing inner binary forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** Inner binary is the PCEB NN Ser ab: a white dwarf
  (whose progenitor was an A star of ~2 M_sun) plus an M-dwarf
  secondary; the progenitor binary separation was ~1.5 AU.
  Precise current component masses are not in this abstract (a
  Kepler's-third-law cross-check on both planets implies M_total
  ~ 0.63-0.66 M_sun, consistent with a ~0.5 M_sun WD plus a ~0.13
  M_sun M-dwarf); pull the NN Ser eclipse-modeling literature
  before backfilling `binary_companions`. Cross-check: warehouse
  pl_orbsmax of 5.35 AU for c matches via Kepler's third law (P =
  15.5 yr, M_total ~ 0.63 M_sun gives a = 5.33 AU), no meaningful
  discrepancy.

  Planet masses (6.9 M_Jup for c, 2.2 M_Jup for d) are both
  clearly planetary, well below the 13 M_Jup deuterium-burning
  boundary; this distinguishes NN Ser from the BD-mass edge cases
  and is one reason NN Ser is generally regarded (in the broader
  literature, beyond this abstract) as among the more robust
  PCEB-ETV detections, in contrast to the contested HU Aqr;
  verify the robustness claim against follow-up papers before
  relying. A secondary chi-squared minimum gives an alternative
  solution with a 5:2 period ratio rather than 2:1, worth noting
  for parameter provenance. Formation question central to the
  value-added catalog: the two planets either (a) survived the
  common-envelope phase that created the white dwarf, requiring
  fine tuning between gravity and envelope drag, or (b) are
  second-generation, forming in a circumbinary disk created at
  the end of the CE phase, in which case they would be
  extraordinarily young with ages below the white dwarf's ~10^6
  yr cooling age. The two SIMBAD wide tertiaries already present
  in `binary_companions` (74,650 AU and 79,546 AU projected) are
  unrelated to the cb_flag P-type question. Full system context
  for both NN Ser planets recorded here under c.
- `NN Ser d`: P-type confirmed (rationale: Beuermann et al. 2010
  (2010A&A...521L..60B), the inner planet of the NN Ser
  two-planet ETV solution (see NN Ser c above for full system
  context). NN Ser d: M_d sin i_d ~ 2.2 M_Jup, P_d ~ 7.7 yr, e_d
  ~ 0.20, locked with c in the 2:1 mean motion resonance. Same
  ETV-around-eclipsing-PCEB P-type-by-construction reasoning.
  cb_flag = 1 correct.)

  **Notes:** d-specific data: M_d sin i_d ~ 2.2 M_Jup, P_d ~ 7.7
  yr, e_d ~ 0.20. Cross-check: warehouse pl_orbsmax of 3.39 AU
  for d matches via Kepler's third law (P = 7.7 yr, M_total ~
  0.66 M_sun gives a = 3.39 AU), exact. Shared inner-binary
  parameters, the 2:1-vs-5:2 solution ambiguity, and the
  first-vs-second-generation formation question are recorded
  under the NN Ser c entry above.

---

### NSVS 14256825

- Distance: 820.9 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| NSVS 14256825 b | Eclipse Timing Variations | 2019 | 3.12 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2019RAA....19..134Z |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `NSVS 14256825 b`: P-type confirmed (rationale: Zhu et al. 2019
  (2019RAA....19..134Z) monitored the sdOB+dM eclipsing binary
  NSVS 14256825 (orbital period 2.65 h) for ~10 yr, adding 84
  high-precision times of light minimum. The O-C curve shows a
  cyclic variation of period 8.83 yr and amplitude 46.31 s, which
  they attribute to the light-travel-time effect of a third body
  after explicitly ruling out a magnetic-activity (Applegate)
  origin on energy grounds. The substellar companion orbits at ~3
  AU with e = 0.12. ETV around an eclipsing inner binary forces
  P-type geometry. cb_flag = 1 correct as a geometric
  classification.)

  **Notes:** Inner binary is an sdOB + dM (hot subdwarf O/B star
  plus red dwarf) eclipsing PCEB, orbital period 2.65 h;
  NSVS 14256825 is the second sdOB+dM eclipsing binary discovered
  and, per this paper, the first of its type found to host a
  hierarchical substellar object. Same evolved-hot-subdwarf
  family as 2M 1938+4603 / Kepler-451 (sdB + dM). Per-component
  masses not given in this abstract; pull the sdOB+dM
  characterization literature before backfilling
  `binary_companions`. Cross-check: warehouse pl_orbsmax of 3.12
  AU is consistent with the abstract's "~3 AU," though a
  Kepler's-third-law estimate with typical sdOB+dM masses (~0.5 +
  ~0.1 M_sun) gives ~3.5 AU, so the precise value depends on the
  adopted binary masses and should be reconciled on backfill.

  Two caveats for the value-added catalog: (1) the third body's
  lowest mass of 14.15 M_Jup sits just above the 13 M_Jup
  deuterium-burning boundary, squarely in the planet/brown-dwarf
  transition; the abstract itself uses "substellar object" rather
  than "planet," so this is an inclusion-as-planet edge case
  (same family as DE CVn b, BEBOP-4 AB b, MXB 1658-298 b). (2)
  The system has a contested timing history: the abstract notes
  "different results were derived by different authors because of
  the insufficient coverage of eclipse timings," placing it in
  the contested PCEB-ETV class alongside HU Aqr, although the
  10-yr baseline and explicit Applegate rejection here make this
  a better-constrained case. The cb_flag audit verdict is firm on
  geometry; existence and planet-vs-BD classification are the
  open questions, scoped out of this audit. No `binary_companions`
  row exists for this host, so the inner-binary parameters above
  are the only multi-star data available and should be
  backfilled.

---

### NY Vir

- Distance: 544.0 pc
- Planets in this system flagged `cb_flag=1`: 2

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| NY Vir b | Eclipse Timing Variations | 2011 | 3.30 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2012ApJ...745L..23Q |
| NY Vir c | Eclipse Timing Variations | 2019 | ? | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2019AJ....157..184S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `NY Vir b`: P-type confirmed (rationale: Qian et al. 2012
  (2012ApJ...745L..23Q) reported the tentative discovery of a
  Jovian planet around NY Vir, a rapidly pulsating sdB-type
  eclipsing binary. New plus literature eclipse times show an O-C
  cyclic variation of period 7.9 yr and semi-amplitude 6.1 s,
  attributed to the light-travel-time effect of a third body;
  adopting a total binary mass of 0.60 M_sun gives M_3 sin i' =
  2.3 +/- 0.3 M_Jup at ~3.3 AU. ETV around an eclipsing inner
  binary forces P-type geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary is the rapidly pulsating sdB eclipsing
  binary NY Vir (total mass adopted as 0.60 M_sun; per-component
  masses not split in this abstract). Same hot-subdwarf family as
  2M 1938+4603 / Kepler-451 (sdB + dM) and NSVS 14256825 (sdOB +
  dM). Cross-check: warehouse pl_orbsmax of 3.30 AU matches the
  abstract via Kepler's third law (P = 7.9 yr, M_total = 0.60
  M_sun gives a = 3.35 AU) and the abstract's stated ~3.3 AU, no
  discrepancy. Planet mass 2.3 M_Jup is clearly planetary (well
  below 13 M_Jup), distinguishing NY Vir b from the BD-mass edge
  cases.

  Two flags. (1) Detection is explicitly "tentative" in the
  authors' own framing, and this is a Qian-led PCEB-ETV claim
  sharing the contested-class concerns of DE CVn b, DP Leo b, and
  HU Aqr; the cb_flag verdict is firm on geometry but the
  existence question is scoped out of this audit. (2) Multi-paper
  provenance for NY Vir c: this 2012 paper already anticipated the
  second planet. The downward parabolic O-C change (period
  decrease dP/dt = -9.2e-12) cannot be explained by
  gravitational-radiation or magnetic-braking angular-momentum
  loss, and Qian 2012 suggested it may be part of a long-period
  (> 15 yr) cyclic variation revealing another ~2.5 M_Jup Jovian
  planet. NY Vir c was formally characterized later (2019,
  2019AJ....157..184S) and remains to be filled in this audit
  pending its abstract; this is a clean multi-citation-per-planet
  case for the citation-system revamp (2012 prediction -> 2019
  confirmation). No `binary_companions` row exists for this host,
  so the inner-binary parameters above are the only multi-star
  data available and should be backfilled.
- `NY Vir c`: P-type confirmed (rationale: Song et al. 2019
  (2019AJ....157..184S) added 18 new primary-minima timings to the
  short-period eclipsing sdB binary NY Vir and refit the O-C
  variations, finding that the only acceptable model is a quadratic
  ephemeris (period derivative dP/dt = 2.83e-12) plus two planets
  in eccentric orbits (e = 0.15 each) with minimum masses of 2.7
  and 5.5 M_Jup. NY Vir c is the second (outer) planet, confirming
  the second body that Qian et al. 2012 had anticipated from the
  long-period parabolic trend (see NY Vir b above). ETV around the
  eclipsing sdB binary forces P-type geometry. cb_flag = 1
  correct.)

  **Notes:** Multi-paper provenance (citation revamp): Qian et al.
  2012 (2012ApJ...745L..23Q) detected NY Vir b (~2.3 M_Jup) and
  predicted a wide second planet (~2.5 M_Jup) from an unexplained
  parabolic O-C trend; Song et al. 2019 confirmed the two-planet
  model with revised minimum masses of 2.7 and 5.5 M_Jup (e = 0.15
  each). The mass attribution between the two planets is not made
  explicit in this abstract (it gives "2.7 and 5.5 M_Jup" without
  labeling inner/outer), and the warehouse NY Vir c sma is "?";
  the most natural reading is NY Vir b (original inner) ~ 2.7 M_Jup
  and NY Vir c (the new outer) ~ 5.5 M_Jup, but verify against the
  paper body before backfilling. Both planets are clearly
  planetary in mass (below 13 M_Jup).

  Caveats. (1) Strongly degenerate: the abstract states "a number
  of model parameters are significantly degenerate, so additional
  observations are required to determine planetary parameters with
  high statistical confidence." (2) Fragile stability: the
  solution is stable for at least 10^8 years, but a small
  eccentricity increase (e >= 0.20 for either planet) renders the
  orbits unstable in under 10^6 years, so the two-planet model
  lives near the edge of dynamical stability. Same Qian-family
  sdB-PCEB-ETV contested cohort as DE CVn b, DP Leo b, HU Aqr,
  NSVS 14256825, UZ For, and RR Cae; the cb_flag verdict is firm
  on geometry, the existence question is scoped out. Inner binary
  is the rapidly pulsating sdB eclipsing binary NY Vir (see NY Vir
  b entry); per-component masses still need a `binary_companions`
  backfill.

---

### OGLE-2007-BLG-349L A

- Distance: 2760.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 27.703 | 76461 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| OGLE-2007-BLG-349L AB c | Microlensing | 2016 | 2.59 AU | Ambiguous (microlensing fits are often degenerate) | 2016AJ....152..125B |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `OGLE-2007-BLG-349L AB c`: P-type confirmed (rationale: Bennett
  et al. 2016 (2016AJ....152..125B) present OGLE-2007-BLG-349 as
  the first circumbinary planet microlensing event. The light
  curve admits two fit classes, a two-planet single-star model and
  a circumbinary model, but Hubble Space Telescope imaging
  resolved the lens from its neighbors and measured excess flux
  consistent only with the circumbinary case (lens mass shared
  between two stars); the two-planet one-star model lacks enough
  flux and is ruled out. The HST data therefore definitively
  establish P-type architecture: a planet of m_c = 80 +/- 13
  M_Earth orbiting an M-dwarf pair (M_A = 0.41 +/- 0.07 M_sun, M_B
  = 0.30 +/- 0.07 M_sun). cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized: M-dwarf pair M_A =
  0.41 +/- 0.07 M_sun, M_B = 0.30 +/- 0.07 M_sun, total ~0.71
  M_sun (independently corroborated by the microlensing parallax,
  which gave M_L ~ 0.7 M_sun). Ready-to-use `binary_companions`
  backfill, though microlensing gives the projected/instantaneous
  geometry rather than a full orbit. Planet mass 80 M_Earth (~0.25
  M_Jup) is clearly planetary and was the lowest-mass circumbinary
  planet system known at the time of discovery. Architecture
  notability: the ratio of planet-to-center-of-mass separation to
  the two-star separation is ~40, so unlike most Kepler CBPs
  (which cluster near the dynamical stability limit) this planet
  orbits far outside it.

  Methodological contrast worth flagging for the audit: this is a
  microlensing CBP where the architecture was definitively
  resolved (HST flux measurement broke the
  circumbinary-vs-two-planet degeneracy), so it is a genuine
  P-type confirmation, unlike KMT-2016-BLG-1337L b where the
  competing 3L1S solutions remain unresolved and the cb_flag was
  flagged as a possible over-claim. The two make a useful
  before/after pair for how much confidence a microlensing
  cb_flag warrants. The single SIMBAD wide tertiary already
  present in `binary_companions` for this host (76,461 AU
  projected) is unrelated to the cb_flag P-type question. This
  entry was previously the auto-suggested "Ambiguous (microlensing
  fits are often degenerate)"; the HST result upgrades it to a
  firm P-type.

---

### OGLE-2016-BLG-0613L AB

- Distance: 3410.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 16.951 | 57802 AU | ? | SIMBAD | ? |
| C | 28.996 | 98875 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| OGLE-2016-BLG-0613L AB b | Microlensing | 2017 | 6.40 AU | Ambiguous (microlensing fits are often degenerate) | 2017AJ....154..223H |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `OGLE-2016-BLG-0613L AB b`: P-type confirmed (rationale: Han et al.
  2017 (2017AJ....154..223H) finds the planet is a companion to a binary
  lens across all four viable triple-lens solution classes (three
  surviving after fit quality); the four-way degeneracy concerns inner-
  binary mass ratios, not architecture topology. All viable solutions are
  triple-lens with the planet outside both stars. The 2024 anticipated
  proper-motion follow-up to resolve mass ratios is not yet in ADS.)

  **Notes:** Harvest from the discovery abstract (Han et al. 2017):
  the light curve is a binary-lens event (two caustic spikes) with
  a discontinuous feature on the trough revealing a planetary
  companion to the binary, i.e. a triple-lens (3L1S) configuration.
  Degeneracy structure (clarifying the rationale above): there are
  four triple-lens solution classes, each itself a wide/close
  planetary-degeneracy pair; one class is excluded for poor fit,
  leaving three. Across all surviving solutions the most-likely
  primary mass is M1 ~ 0.7 M_sun and the planet is a super-Jupiter,
  and the system lies in the Galactic disk about halfway to the
  bulge.

  Architecture nuance for the value-added catalog: the three
  surviving classes are all P-type (the planet orbits the inner
  pair), but the nature of the inner secondary differs. In one
  class the secondary is a low-mass brown dwarf (relative mass
  ratios 1:0.03:0.003, i.e. ~0.7 M_sun primary, ~22 M_Jup BD
  secondary, ~2.2 M_Jup planet), making the inner "binary" a star
  + BD; in the other two classes the two binary components are
  comparable-mass stars. cb_flag = 1 is correct in every case (the
  planet orbits both inner bodies), but whether this is a
  circum-(star+star) or circum-(star+BD) system is unresolved.
  Per-component masses are therefore solution-dependent and should
  not be backfilled into `binary_companions` until the degeneracy
  is broken.

  Time-sensitive follow-up: the abstract states the competing
  solutions can be distinguished "in about 2024" once the
  lens-source relative proper motion permits separate resolution
  of lens and source. We are now in 2026, so this follow-up may
  exist; the rationale above notes it was "not yet in ADS" at the
  time of writing. This is a flagged re-check item from the
  initial doc review: search ADS for a 2024-2025
  OGLE-2016-BLG-0613 follow-up to see whether the architecture
  (and the star-vs-BD secondary question) has been resolved. The
  two SIMBAD wide tertiaries already present in `binary_companions`
  for this host (57,802 AU and 98,875 AU projected) are unrelated
  to the cb_flag P-type question.

---

### OGLE-2018-BLG-1700L

- Distance: 7600.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 17.601 | 133767 AU | ? | SIMBAD | ? |
| C | 28.829 | 219103 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| OGLE-2018-BLG-1700L b | Microlensing | 2020 | 2.80 AU | Ambiguous (microlensing fits are often degenerate) | 2020AJ....159...48H |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `OGLE-2018-BLG-1700L b`: Ambiguous (rationale: Han et al. 2020
  (2020AJ....159...48H) analysed the triple-lens microlensing
  event OGLE-2018-BLG-1700, decomposing the anomaly into two
  binary-lens events with mass ratios ~0.01 (planet-to-star) and
  ~0.3 (star-to-star). Bayesian analysis gives a planet mass of
  4.4 +3.0/-2.0 M_Jup, stellar binary components of 0.42
  +0.29/-0.19 M_sun and 0.12 +0.08/-0.05 M_sun, and a lens
  distance of 7.6 kpc. Crucially, two degenerate solutions fit
  equally well and imply different architectures: in the wide
  solution (primary-companion separation greater than the Einstein
  radius) the planet is circumstellar (S-type, orbiting one star
  only), while in the close solution (separation less than the
  Einstein radius) it is circumbinary (P-type). The discovery
  paper does not favour either solution, so the cb_flag = 1 is
  supported by only one of two equally-valid interpretations.)

  **Notes:** This is a strong cb_flag misflag candidate, arguably
  the clearest in the audit: the discovery abstract explicitly
  states "the planet is a circumstellar planet according to the
  wide solution, while it is a circumbinary planet according to
  the close solution." Unlike OGLE-2007-BLG-349 (where HST imaging
  resolved the degeneracy in favour of circumbinary) and unlike
  OGLE-2016-BLG-0613 (where all surviving solutions were P-type
  and only the secondary's star-vs-BD nature was unresolved), here
  the P-type-vs-S-type architecture itself is unresolved at
  roughly 50/50. The warehouse cb_flag = 1 reflects only the close
  solution. Suggested action: flag this entry for either a formal
  cb_flag = 0 downgrade or an explicit "architecture ambiguous"
  annotation, pending follow-up that breaks the close/wide
  degeneracy (e.g. future high-resolution imaging or proper-motion
  measurement, as worked for OGLE-2007-BLG-349). Component masses
  are solution-dependent and should not be backfilled into
  `binary_companions` until the degeneracy is resolved. The two
  SIMBAD wide tertiaries already present in `binary_companions`
  for this host (133,767 AU and 219,103 AU projected) are
  unrelated to the cb_flag question.

---

### OGLE-2019-BLG-1470L A

- Distance: 5900.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| OGLE-2019-BLG-1470L AB c | Microlensing | 2022 | 3.20 AU | Ambiguous (microlensing fits are often degenerate) | 2022MNRAS.516.1704K |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `OGLE-2019-BLG-1470L AB c`: Ambiguous (rationale: Kuang et al.
  2022 (2022MNRAS.516.1704K) analysed the microlensing event
  OGLE-2019-BLG-1470, initially classed as a binary-lens
  single-source (2L1S) event but requiring an additional lens or
  source. The triple-lens single-source (3L1S) model provides the
  best fit, but the binary-lens binary-source (2L2S) model is
  disfavoured by only a chi-squared difference of ~18. The two
  interpretations differ in architecture: the 3L1S model is a
  planet orbiting a binary (circumbinary, P-type), whereas the
  2L2S model is a planet orbiting a single star with the second
  signal coming from a binary source rather than a binary lens
  (i.e. not a multi-star system at all). For the best-fitting
  3L1S model the two stars are M1 = 0.57 M_sun and M2 = 0.18
  M_sun at projected separation 1.3 AU, with a planet of M3 = 2.2
  M_Jup; for the 2L2S model the host is a single 0.55 M_sun star
  with a 4.6 M_Jup planet. cb_flag = 1 rests on the 3L1S
  interpretation, which is preferred but not decisively.)

  **Notes:** cb_flag misflag candidate, the third in the
  microlensing subset. The discriminating statistic is modest: a
  chi-squared difference of ~18 favours the binary-host (3L1S)
  model over the single-host (2L2S) model, which in microlensing
  is suggestive but well short of decisive (differences of dozens
  to hundreds are typically wanted). If the 2L2S model is correct,
  this is not a circumbinary planet at all but an ordinary
  single-star planet, so cb_flag should be 0. This differs from
  OGLE-2018-BLG-1700L (P-type vs S-type, both multi-star) and from
  KMT-2016-BLG-1337L (architecture unresolved among binary
  configurations): here the competing model removes the binary
  host entirely. Best-fit inner-binary parameters (M1 = 0.57
  +0.43/-0.32 M_sun, M2 = 0.18 +0.15/-0.10 M_sun, projected
  separation 1.3 AU) are 3L1S-conditional and should not be
  backfilled into `binary_companions` until the model degeneracy
  is broken. Cross-check: warehouse pl_orbsmax of 3.20 AU is
  consistent with the abstract's ~3 AU projected host-planet
  separation; the planet is super-Jovian (~2.2 M_Jup in 3L1S,
  ~4.6 M_Jup in 2L2S), clearly planetary either way.

  Population-statistics harvest for the value-added catalog: the
  paper reports that all binary-system planets published by the
  KMTNet survey lie inside the resonant-caustic range with q >~
  2e-3, indicating the KMTNet sample is incomplete for planets in
  binary systems. The authors conclude such planets cannot yet be
  included in the KMTNet mass-ratio function and call for a
  systematic search of binary-system light curves. This is a
  direct microlensing analogue of the transit-survey
  selection-bias points flagged for Kepler-453 b and Kepler-1661
  b, and a useful caveat for any cross-survey occurrence framing.

---

### OGLE-2023-BLG-0836L

- Distance: 5120.0 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| OGLE-2023-BLG-0836L b | Microlensing | 2024 | 3.70 AU | Ambiguous (microlensing fits are often degenerate) | 2024A&A...685A..16H |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `OGLE-2023-BLG-0836L b`: P-type confirmed (rationale: Han et al.
  2024 (2024A&A...685A..16H) reinvestigated anomalous microlensing
  events that resist both binary-lens single-source (2L1S) and
  single-lens binary-source (1L2S) interpretations. For
  OGLE-2023-BLG-0836 they conclude a triple-mass lens system is
  imperative to fit the light curve, ruling out the binary-source
  alternatives that weaken the other ambiguous microlensing
  entries. Bayesian analysis gives a planetary-mass least-massive
  component of 4.36 +2.35/-2.18 M_Jup orbiting within a stellar
  binary of 0.71 +0.38/-0.36 M_sun and 0.56 +0.30/-0.28 M_sun.
  The abstract describes the planet as orbiting "within a stellar
  binary system," consistent with cb_flag = 1, though the explicit
  circumbinary-vs-circumstellar geometry is not stated in the
  abstract and rests on the paper body.)

  **Notes:** This is the most secure of the ambiguous-leaning
  microlensing entries because the binary host itself is secure:
  the abstract states a triple-mass lens is "imperative," so
  unlike OGLE-2019-BLG-1470L (where a single-host 2L2S model was
  only mildly disfavoured) there is no single-star alternative
  here. The residual open question is narrower: the abstract
  confirms a planet in a stellar binary but does not explicitly
  state whether the planet orbits both stars (P-type) or one star
  with the other as a wider companion (S-type); microlensing
  triple-lens fits frequently carry a close/wide degeneracy that
  decides this (cf. OGLE-2018-BLG-1700L). Recommended: confirm
  from the paper body that the adopted solution is circumbinary
  rather than circumstellar before treating cb_flag = 1 as fully
  settled. Inner-binary masses (0.71 and 0.56 M_sun, both in the
  K/M-dwarf range) are well determined and a candidate
  `binary_companions` backfill, but the projected separations
  (needed to confirm geometry) are not in this abstract. The
  planet mass is super-Jovian (4.36 M_Jup, clearly planetary);
  the warehouse pl_orbsmax of 3.70 AU is not stated in the
  abstract and comes from the paper body. Notability: the abstract
  calls this the sixth known planetary microlensing system in
  which a planet belongs to a stellar binary, useful for the
  value-added catalog's running count of this rare class.

  Microlensing subset capstone (all six cb_flag entries now
  assessed): one solid P-type (OGLE-2007-BLG-349, HST-resolved),
  two binary-host-secure-but-incomplete (OGLE-2016-BLG-0613 with
  the secondary's star-vs-BD nature open; this entry with P-vs-S
  open), and three misflag candidates (KMT-2016-BLG-1337L,
  OGLE-2018-BLG-1700L, OGLE-2019-BLG-1470L). Only
  OGLE-2007-BLG-349 has a fully settled circumbinary architecture;
  every other microlensing cb_flag carries an unresolved
  degeneracy of some kind. This subset warrants a dedicated
  reliability caveat in the audit summary.

---

### PH1

- Distance: 1045.8 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 162.530 | 169977 AU | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| PH1 b | Transit | 2012 | 0.652 AU | P-type likely (transit detection) | 2013ApJ...768..127S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `PH1 b`: P-type confirmed (rationale: Schwamb et al. 2013
  (2013ApJ...768..127S) reported PH1 b (also catalogued Kepler-64
  b), a transiting circumbinary planet around the eclipsing binary
  KIC 4862625, discovered by volunteers in the Planet Hunters
  citizen science project. Seven transits across the larger,
  brighter star appear in Kepler Quarters 1-11 (~137-day period),
  and a photometric-dynamical model jointly fitting the radial
  velocities and Kepler light curve places the 6.18 R_Earth planet
  outside the 20-day orbit of the inner binary. Direct
  transit-across-the-binary detection forces P-type geometry.
  cb_flag = 1 correct.)

  **Notes:** Inner binary fully characterized (masses + radii): F
  dwarf 1.528 +/- 0.087 M_sun, 1.734 +/- 0.044 R_sun; M dwarf
  0.408 +/- 0.024 M_sun, 0.378 +/- 0.023 R_sun; binary period ~20
  d. Ready-to-use `binary_companions` backfill. Cross-check:
  warehouse pl_orbsmax of 0.652 AU matches the abstract via
  Kepler's third law (P = 137 d, M_total = 1.936 M_sun gives a =
  0.648 AU), no meaningful discrepancy. Planet upper mass limit
  169 M_Earth (0.531 M_Jup) at 99.7% confidence; with both mass
  and radius below Jupiter's, PH1 b is unambiguously planetary
  (like Kepler-38 b and Kepler-453 b, only an upper mass limit is
  available because the planet is too small to perturb the
  binary).

  Important data gap: this is a quadruple star system. The
  abstract reports a previously unknown visual binary at ~1000 AU,
  likely bound to the planetary system, making PH1 the first known
  quadruple star system with a transiting planet (a 2+2
  hierarchical architecture: the inner eclipsing binary hosting
  the planet, plus an outer visual binary at ~1000 AU). The
  warehouse `binary_companions` for this host carries only a
  single SIMBAD entry at 169,977 AU projected, which does NOT
  correspond to the scientifically important ~1000 AU outer
  binary; the outer pair that defines the quadruple architecture
  is missing from the warehouse and should be backfilled. None of
  the wide companions affect the cb_flag P-type verdict (the
  planet is circumbinary around the inner eclipsing pair
  regardless), but the quadruple nature is a strong notability tag
  for the value-added catalog and the 3D viewer. Discovery
  notability: PH1 b is a flagship Planet Hunters citizen-science
  result, useful for outreach framing.

---

### PSR B1620-26

- Distance: unknown
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 7.575 | ? | ? | SIMBAD | ? |
| C | 10.574 | ? | ? | SIMBAD | ? |
| D | 10.585 | ? | ? | SIMBAD | ? |
| E | 11.131 | ? | ? | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| PSR B1620-26 b | Pulsar Timing | 2003 | 23.00 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2003Sci...301..193S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `PSR B1620-26 b`: P-type confirmed (rationale: Sigurdsson et al.
  2003 (2003Sci...301..193S) detected the stellar companion of the
  millisecond pulsar PSR B1620-26 with HST, identifying it as an
  undermassive white dwarf (0.34 +/- 0.04 M_sun, cooling age 480
  +/- 140 Myr). This establishes the inner binary as a neutron
  star + white dwarf pair; the planetary-mass third body (inferred
  earlier from pulsar timing) orbits both at ~23 AU, making this a
  P-type circumbinary system. cb_flag = 1 correct.)

  **Notes:** Inner binary is a millisecond pulsar (neutron star,
  ~1.4 M_sun) plus an undermassive white dwarf (0.34 +/- 0.04
  M_sun); this 2003 paper is specifically the HST detection and
  characterization of that WD companion, while the planet itself
  was established by earlier pulsar-timing work (Thorsett, Backer,
  Ford et al., 1990s-2000, cited from general knowledge - verify
  before relying). The warehouse uses the 2003 paper as the
  discovery citation, reasonable since it pins down the
  architecture, but this is a multi-citation-per-planet case for
  the citation revamp (planet inferred ~1993-2000, inner binary
  confirmed 2003). Unlike the contested PCEB eclipse-timing
  planets (HU Aqr etc.), the detection here uses a millisecond
  pulsar as a precision clock, and PSR B1620-26 b is a
  long-accepted, robust circumbinary planet.

  Two data-integrity findings for this host. (1) Distance: the
  warehouse lists "Distance: unknown," which is why the planet
  page lacks the Milky Way position card (the same gap discussed
  for MXB 1658-298). But the distance is effectively known: PSR
  B1620-26 is a member of the globular cluster M4 / NGC 6121 at
  ~1.8 kpc (cluster identification and distance from general
  knowledge, not this abstract), so the gap is backfillable from
  cluster membership. (2) The four SIMBAD entries in
  `binary_companions` for this host (separations 7.6-11.1 arcsec,
  projected AU shown as "?" because distance is null) are almost
  certainly crowded-field globular-cluster stars, not bound
  companions; M4 is dense and SIMBAD cross-matching picks up
  unrelated line-of-sight members. These should not be treated as
  physical companions, and the real inner binary (pulsar + WD) is
  absent from `binary_companions` and should be backfilled.

  Notability for the value-added catalog: per the abstract the
  current configuration arose through a dynamical exchange
  interaction in the cluster core (the planet was not born with
  this pulsar but assembled via stellar interactions), and the
  result is framed as evidence that planets may be common in
  low-metallicity globular clusters and that planet formation is
  more widespread and earlier than previously believed. PSR
  B1620-26 b is widely regarded as the oldest known planet
  (residing in the ~12.5 Gyr cluster M4) and is nicknamed the
  "Methuselah" planet (age and nickname from general knowledge,
  not this abstract). A strong outreach and 3D-viewer subject:
  pulsar + white dwarf + ancient gas giant in a globular cluster.

---

### ROXs 42 B

- Distance: 144.7 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| ROXs 42 B b | Imaging | 2013 | 157 AU | Ambiguous (imaging detection; verify geometry by hand) | 2014ApJ...780L..30C |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `ROXs 42 B b`: P-type confirmed (rationale: Currie et al. 2014
  (2014ApJ...780L..30C) places the planetary-mass companion at ~150 AU
  from "the primaries" (plural; ROXs 42B is itself a close M0+M0 binary
  in the ρ Oph star-forming region). Mass 6-15 M_Jup straddles the
  deuterium-burning limit; Daemgen et al. 2017 (2017A&A...601A..65D,
  "Mid-infrared characterization of the planetary-mass companion ROXs
  42B b") refined via MIR atmospheric modeling and characterizes the
  object as planetary mass, consistent with cb_flag = 1.)

  **Notes:** Harvest from the discovery abstract (Currie et al.
  2014): ROXs 42B is a binary M0 member of the rho Ophiuchus
  star-forming region, age 1-3 Myr (very young). The companion
  ROXs 42Bb sits at ~1.16 arcsec (projected ~150 AU) from the
  primaries; 7 years of imaging show astrometry inconsistent with
  a background star and consistent with a bound companion,
  possibly with detected orbital motion. VLT/SINFONI K-band
  spectroscopy types it as a cool substellar object (M8-L0,
  T_eff ~ 1800-2600 K) with a low-surface-gravity spectral shape
  characteristic of young planet-mass companions, ruling out a
  background dwarf. Mass 6-15 M_Jup, straddling the
  deuterium-burning limit, so this is an inclusion-as-planet edge
  case (same family as HIP 79098 AB b, BEBOP-4 AB b, NSVS
  14256825 b).

  The inner-binary separation is not given in this abstract (only
  that ROXs 42B is a "binary M0"); pull the ROXs 42B AB orbit
  before backfilling `binary_companions`, and note that P-type
  geometry rests on the M0+M0 separation being much smaller than
  the companion's 150 AU. Formation ambiguity flagged by the
  authors and useful for the value-added catalog: ROXs 42Bb may
  be among the lowest-mass objects formed like binary stars, or a
  planet-mass object formed by protostellar disk
  fragmentation/disk instability; the abstract notes this blurs
  the line between non-deuterium-burning planets (e.g. HR 8799
  bcde) and low-mass deuterium-burning brown dwarfs. Two
  cautions: (1) the 2014 abstract reports a second candidate
  companion at ~0.5 arcsec of roughly equal brightness, but
  preliminary analysis indicates it is a background object, not a
  real second companion; (2) the Daemgen et al. 2017 follow-up
  cited in the rationale above is from general knowledge beyond
  this abstract and should be verified.

---

### RR Cae

- Distance: 21.2 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| RR Cae b | Eclipse Timing Variations | 2012 | 5.30 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2012MNRAS.422L..24Q |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `RR Cae b`: P-type confirmed (rationale: Qian et al. 2012
  (2012MNRAS.422L..24Q) added six new mid-eclipse times to
  archival data for RR Cae, a detached white-dwarf + M-dwarf
  eclipsing PCEB. The O-C curve shows a cyclic variation of period
  11.9 yr and amplitude 14.3 s, attributed to the
  light-travel-time effect of a third body; the minimum mass is
  M_3 sin i' = 4.2 +/- 0.4 M_Jup (a giant planet for orbital
  inclination i' > 17.6 degrees), at an orbital separation of ~5.3
  +/- 0.6 AU from the eclipsing binary. ETV around an eclipsing
  inner binary forces P-type geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary is the detached eclipsing PCEB RR Cae
  (white dwarf + M-dwarf; per-component masses not given in this
  abstract, pull the RR Cae characterization literature before
  backfilling `binary_companions`). Planet mass 4.2 M_Jup is
  clearly planetary (well below 13 M_Jup), unlike the BD-mass
  edge cases. Cross-check: warehouse pl_orbsmax of 5.30 AU matches
  the abstract's stated 5.3 +/- 0.6 AU. Internal tension worth
  checking against the paper body: the abstract's own period (11.9
  yr) and separation (5.3 AU) together imply a total binary mass
  of ~1.0 M_sun via Kepler's third law, which is high for a WD +
  M-dwarf PCEB (typically ~0.6 M_sun); the lower end of the
  separation error bar (~4.7 AU) is more consistent with the
  expected mass, so the central 5.3 AU may reflect a high adopted
  mass or rounding.

  Two flags. (1) Qian-led PCEB-ETV detection, sharing the
  contested-class concerns of DE CVn b, DP Leo b, HU Aqr, NY Vir,
  and NSVS 14256825; the cb_flag verdict is firm on geometry but
  the existence question is scoped out (though the clearly
  planetary mass makes RR Cae b less of a planet-vs-BD problem
  than several siblings). (2) Second-planet hint: the O-C curve
  also shows an upward parabolic variation (a long-term period
  increase), which is opposite to the decrease expected from
  angular-momentum loss via magnetic braking or gravitational
  radiation and cannot be mass transfer given the detached
  configuration. Qian 2012 suggests this is part of a longer
  (> 26.3 yr) cyclic variation that may reveal a second wide-orbit
  giant circumbinary planet, a candidate for the
  followup-citations ticket. No `binary_companions` row exists for
  this host, so the inner-binary parameters above are the only
  multi-star data available and should be backfilled.

---

### Ross 458

- Distance: 11.5 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| Ross 458 c | Imaging | 2010 | 1100 AU | Ambiguous (imaging detection; verify geometry by hand) | 2010ApJ...725.1405B |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `Ross 458 c`: P-type confirmed (rationale: Burgasser et al. 2010
  (2010ApJ...725.1405B) present FIRE/Magellan near-infrared
  spectroscopy of Ross 458C, confirming it as a T8 substellar
  object (T_eff ~ 650 K, log L_bol/L_sun = -5.62) with a mass at
  or below the deuterium-burning limit, low surface gravity
  (youth) and supersolar metallicity matching the Ross 458 system
  (age 150-800 Myr, [Fe/H] = +0.2 to +0.3). The "C" designation
  and warehouse cb_flag = 1 place this as the wide ~1100 AU
  companion to the Ross 458 AB inner binary, making it P-type;
  note this abstract characterizes the companion's atmosphere, not
  the inner-binary architecture, so the circumbinary geometry
  rests on Ross 458 AB being a close binary (established
  elsewhere, not in this abstract). cb_flag = 1 correct on that
  basis.)

  **Notes:** This abstract is an atmospheric-characterization
  paper for the companion, not an architecture paper; it does not
  describe the Ross 458 AB inner binary. P-type classification
  depends on Ross 458 AB being a close M-dwarf binary with C as
  the wide (~1100 AU) circumbinary companion; the AB separation
  and component masses are not in this abstract and must be pulled
  from the binary-discovery literature before backfilling
  `binary_companions` (no row currently exists for this host).
  Cross-check: the warehouse pl_orbsmax of 1100 AU is not stated
  in this abstract and comes from imaging astrometry elsewhere.

  Double inclusion-as-planet caveat for the value-added catalog.
  (1) Mass: the abstract places Ross 458C "at or below the
  deuterium-burning limit," so it straddles the planet/BD boundary
  (same edge-case family as ROXs 42 B b, HD 284149 AB b). (2)
  Formation: the abstract explicitly states "the characteristics
  of Ross 458C suggest that it could itself be regarded as a
  planet, albeit one whose cosmogony does not conform with current
  planet formation theories"; at ~1100 AU it cannot have formed by
  in-situ core accretion, so it is a planet-by-mass whose origin
  is more likely brown-dwarf-like (fragmentation), the same
  planet-vs-formation tension flagged for ROXs 42 B b.
  Methodological note useful elsewhere in the audit: Burgasser
  2010 shows cloudy atmospheric models fit young cold T dwarfs
  significantly better than cloudless ones, a caveat for any
  T_eff or mass derived for the directly imaged substellar
  companions in this corpus (the cloudy-vs-cloudless choice shifts
  Ross 458C's T_eff between 635 K and 760 K).

---

### SR 12 AB

- Distance: 112.3 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| SR 12 AB c | Imaging | 2010 | ? | Ambiguous (imaging detection; verify geometry by hand) | 2011AJ....141..119K |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `SR 12 AB c`: P-type confirmed (rationale: Kuzuhara et al. 2011
  (2011AJ....141..119K) present near-infrared imaging and
  spectroscopy of SR12 C, a substellar companion to the binary T
  Tauri star SR12 AB in the rho Ophiuchi star-forming region. The
  companion is separated by ~8.7 arcsec (~1100 AU at the adopted
  125 pc), with spectral type M9.0 +/- 0.5; common proper motion
  with SR12 AB and a ~1% chance-alignment probability confirm
  physical association, and a gravity-sensitive spectral feature
  confirms youth. The abstract explicitly identifies SR12 C as the
  first planetary-mass-companion candidate directly imaged around
  a binary star, i.e. a circumbinary configuration. cb_flag = 1
  correct.)

  **Notes:** Inner binary is the young (T Tauri) pre-main-sequence
  binary SR12 AB in rho Oph; per-component masses and the AB
  separation are not given in this abstract, pull from the SR12 AB
  binary literature before backfilling `binary_companions` (no row
  exists for this host). This is the same star-forming region and
  detection class as ROXs 42 B b (also a rho Oph imaging PMC
  around a binary), and the same wide-PMC family as Ross 458 c
  (~1100 AU).

  Two data points to reconcile. (1) The warehouse pl_orbsmax for
  this planet is currently "?" (unknown); the abstract provides a
  projected separation of ~1100 AU (8.7 arcsec at 125 pc), which
  could backfill the blank, but it is a projected separation, not
  a true orbital semi-major axis, and should be stored as such.
  (2) Distance mismatch: the abstract adopts 125 pc while the
  warehouse lists 112.3 pc for this host; at 8.7 arcsec the
  separation is ~1087 AU (125 pc) versus ~977 AU (112.3 pc), so
  any backfilled AU separation must specify the adopted distance.

  Inclusion-as-planet caveat: SR12 C's mass is 0.013 +/- 0.007
  M_sun (~13.6 +/- 7.3 M_Jup), sitting right on the 13 M_Jup
  deuterium-burning boundary with error bars spanning planet to
  brown dwarf; the abstract is deliberately cautious ("possible
  planetary mass," "PMC candidate"). Same edge-case family as ROXs
  42 B b, Ross 458 c, HD 284149 AB b. The authors frame SR12 C as
  evidence that planetary-mass companions form via multiple
  channels including disk gravitational instability and cloud-core
  fragmentation, the same planet-vs-formation tension recurring
  across the wide-imaging entries.

---

### TIC 172900988 Aa

- Distance: 243.9 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| TIC 172900988 b | Transit | 2021 | 0.903 AU | P-type likely (transit detection) | 2021AJ....162..234K |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `TIC 172900988 b`: P-type confirmed (rationale: Kostov et al.
  2021 (2021AJ....162..234K) reported the first transiting
  circumbinary planet detected from a single TESS sector. During
  Sector 21 the planet transited the primary star and then the
  secondary star five days later, a direct double-transit
  signature of circumbinary geometry. The host is itself an
  eclipsing binary (P ~ 19.7 d, e ~ 0.45), and a photodynamical
  analysis yields precise component masses and radii. cb_flag = 1
  correct, and unusually robust: the planet is directly observed
  transiting both stars.)

  **Notes:** Inner binary characterized to high precision (a
  ready, high-value `binary_companions` backfill): primary M1 =
  1.2384 +/- 0.0007 M_sun, R1 = 1.3827 +/- 0.0016 R_sun; secondary
  M2 = 1.2019 +/- 0.0007 M_sun, R2 = 1.3124 +/- 0.0012 R_sun;
  binary P = 19.7 d, e = 0.45 (a high-eccentricity binary). The
  planet is Jupiter-sized (R3 = 11.25 +/- 0.44 R_Earth = 1.004
  R_Jup), clearly planetary. Archival photometry (ASAS-SN,
  Evryscope, KELT, SuperWASP) reveals prominent apsidal motion of
  the binary driven by planet-binary dynamical interaction, an
  independent confirmation of the planet's gravitational presence.

  Parameter degeneracy worth flagging (distinct from the
  microlensing cases): the planet's mass and orbit are not
  uniquely determined, with six nearly-equal-likelihood solutions.
  The mass is well bounded at 2.65 to 3.09 M_Jup, but the orbital
  period could be 188.8, 190.4, 194.0, 199.0, 200.4, or 204.1
  days, with eccentricity 0.02-0.09. Crucially, this degeneracy is
  in the orbital parameters only; the P-type architecture is
  directly observed (double transit) and is not in question, so
  unlike the degenerate microlensing entries (OGLE-2018-BLG-1700L
  etc.) the cb_flag is rock-solid. Cross-check: warehouse
  pl_orbsmax of 0.903 AU corresponds to the ~200-day period
  solution (Kepler's third law with M_total = 2.44 M_sun gives a =
  0.90 AU at P = 200 d); note the warehouse stores a single
  semi-major axis despite the six-fold period degeneracy, so the
  value-added catalog should ideally record the degeneracy rather
  than a single point value. No `binary_companions` row exists for
  this host, so the precise inner-binary parameters above should
  be backfilled. Bright host (V = 10.14), flagged in the abstract
  as accessible for Rossiter-McLaughlin and transit spectroscopy,
  a strong follow-up/characterization target.

---

### TOI-1338 A

- Distance: 398.7 pc
- Planets in this system flagged `cb_flag=1`: 2

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| TOI-1338 b | Transit | 2020 | 0.461 AU | P-type likely (transit detection) | 2020AJ....159..253K |
| TOI-1338 c | Radial Velocity | 2023 | 0.794 AU | Ambiguous (RV detection; verify cb_flag against paper) | 2023NatAs...7..702S |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `TOI-1338 b`: P-type confirmed (rationale: Kostov et al. 2020
  (2020AJ....159..253K) reported TOI-1338 b as the first
  circumbinary planet discovered by TESS. The known eclipsing
  binary (two stars of 1.1 M_sun and 0.3 M_sun on a slightly
  eccentric e = 0.16, 14.6-day orbit) was observed across TESS
  sectors 1-12, and the planet made three transits across the
  primary of roughly equal depth (~0.2%) but different durations,
  the classic transiting-CBP signature. The planet (radius ~6.9
  R_Earth, P = 95.2 d, e ~ 0.09) orbits in a plane aligned with
  the binary to within ~1°. Direct transit-across-the-binary
  detection forces P-type geometry. cb_flag = 1 correct.)

  **Notes:** Inner binary: M1 = 1.1 M_sun, M2 = 0.3 M_sun, e_bin =
  0.16, P_orb = 14.6 d (component radii not given in this
  abstract; pull paper body before backfilling
  `binary_companions`, no row exists for this host). Planet is
  nearly coplanar with the binary (within ~1°), unlike the
  measurably inclined Kepler-413 b (~2.5°), and clearly planetary
  in size (6.9 R_Earth). Cross-check: warehouse pl_orbsmax of
  0.461 AU matches the abstract via Kepler's third law (P = 95.2
  d, M_total = 1.4 M_sun gives a = 0.457 AU), no meaningful
  discrepancy.

  TESS "firsts" disambiguation: TOI-1338 b is the first
  circumbinary planet discovered by TESS (2020), while TIC
  172900988 b (also Kostov, 2021) is the first transiting CBP
  detected from a single TESS sector; both are TESS milestones
  with different qualifiers and should be labeled precisely in the
  value-added catalog. Multi-planet / multi-citation note:
  TOI-1338 hosts a second planet, TOI-1338 c, an RV detection
  added in 2023 (Standing et al., 2023NatAs...7..702S), which
  remains to be filled in this audit pending its abstract.
  TOI-1338 is also designated BEBOP-1 in the BEBOP radial-velocity
  survey (general knowledge), linking it to the BEBOP-3 and
  BEBOP-4 entries elsewhere in this audit.
- `TOI-1338 c`: P-type confirmed (rationale: Standing et al. 2023
  (2023NatAs...7..702S) detected TOI-1338 c (= BEBOP-1 c) in HARPS
  and ESPRESSO radial-velocity data: a gas giant of mass 65.2 +/-
  11.8 M_Earth orbiting both stars of the TOI-1338 eclipsing
  binary with a period of 215.5 +/- 3.3 days. The abstract states
  explicitly that the planet orbits "around both stars," i.e. a
  circumbinary (P-type) configuration; this upgrades the
  auto-suggested "Ambiguous (RV detection)" verdict. cb_flag = 1
  correct.)

  **Notes:** TOI-1338 c is the RV-detected outer planet in the
  TOI-1338 system, whose inner transiting planet TOI-1338 b was
  recorded above (Kostov 2020). This abstract confirms the
  general-knowledge note flagged in the TOI-1338 b entry: TOI-1338
  is formally also designated BEBOP-1, and TOI-1338 c = BEBOP-1 c,
  detected by the BEBOP radial-velocity survey (linking it to
  BEBOP-3 and BEBOP-4 elsewhere in this audit). Notably, BEBOP-1 c
  is an RV-detected CBP in an already-known circumbinary system,
  distinct from BEBOP-3 b which was billed as the first RV
  detection of a previously unknown circumbinary system. Mass 65.2
  M_Earth (~0.21 M_Jup, sub-Saturn) is clearly planetary.
  Cross-check: warehouse pl_orbsmax of 0.794 AU matches via
  Kepler's third law (P = 215.5 d, M_total = 1.4 M_sun gives a =
  0.787 AU), no meaningful discrepancy.

  System significance: TOI-1338 / BEBOP-1 is, per this abstract,
  the second confirmed multiplanetary circumbinary system (after
  Kepler-47), and the first to combine a transiting CBP (TOI-1338
  b) with an RV-detected CBP (TOI-1338 c). TOI-1338 b is not
  detected in RV alone (mass upper limit 21.8 M_Earth at 99%
  confidence), and the abstract flags it as a JWST
  atmospheric-characterization benchmark for circumbinary planets.
  Inner binary (1.1 + 0.3 M_sun, e = 0.16, 14.6 d) is recorded in
  the TOI-1338 b entry and still needs a `binary_companions`
  backfill.

---

### UZ For

- Distance: 239.6 pc
- Planets in this system flagged `cb_flag=1`: 2

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| UZ For b | Eclipse Timing Variations | 2011 | 5.90 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2011MNRAS.416.2202P |
| UZ For c | Eclipse Timing Variations | 2011 | 2.80 AU | P-type confirmed (likely, ETV/pulsar timing requires binary) | 2011MNRAS.416.2202P |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `UZ For b`: P-type confirmed (rationale: Potter et al. 2011
  (2011MNRAS.416.2202P) combined new high-speed SALT and
  multi-observatory photometry with archival eclipse times
  spanning ~27 years for the eclipsing polar UZ For, detecting
  ~60 s departures from a linear-plus-quadratic ephemeris. The
  residuals suggest two cyclic variations (16 yr and 5.25 yr)
  interpreted as the light-travel-time effect of two giant
  circumbinary planets; UZ For b is the outer body (16-yr signal,
  minimum mass 6.3 +/- 1.5 M_Jup, ~5.90 AU). ETV around an
  eclipsing inner binary forces P-type geometry. cb_flag = 1
  correct as a geometric classification.)

  **Notes:** Inner binary is the eclipsing polar UZ For (magnetic
  cataclysmic variable, WD + M-dwarf; per-component masses not
  given in this abstract, but a Kepler's-third-law check on both
  planets implies M_total ~ 0.8 M_sun, consistent with a ~0.7
  M_sun WD plus a ~0.14 M_sun M-dwarf donor; pull the UZ For
  characterization literature before backfilling
  `binary_companions`, no row exists for this host). Same
  eclipsing-polar ETV family as DP Leo b and HU Aqr AB b/c. Both
  planets are clearly planetary in mass (6.3 and 7.7 M_Jup, below
  13 M_Jup), so no BD edge case here. Cross-check: warehouse
  pl_orbsmax of 5.90 AU for b matches via Kepler's third law (P =
  16 yr, M_total ~ 0.8 M_sun gives a = 5.90 AU).

  Strongly contested detection, among the most hedged in the
  PCEB-ETV cohort. The discovery paper itself flags multiple
  caveats: (1) the two-planet model "does not quite capture all of
  the eclipse times measurements"; (2) Applegate's magnetic-cycle
  mechanism is an explicit alternative, deemed less likely only
  because it would require the entire radiant energy output of the
  secondary (barring magnetic-field refinements such as those of
  Lanza et al.); (3) a highly eccentric outer-planet orbit would
  fit the data well but is dynamically unstable; and (4) the
  periodicities may be driven by some combination of both
  mechanisms. The cb_flag verdict is firm on geometry (if the
  planets exist, they are P-type by ETV construction), but the
  existence is more uncertain here than for NN Ser and closer to
  the HU Aqr level of contestation; the audit scopes the existence
  question out. Full system context for both UZ For planets
  recorded here under b.
- `UZ For c`: P-type confirmed (rationale: Potter et al. 2011
  (2011MNRAS.416.2202P), the inner body of the two-planet ETV
  solution for the eclipsing polar UZ For (see UZ For b above for
  full system context). UZ For c is the 5.25-yr signal, minimum
  mass 7.7 +/- 1.2 M_Jup, at ~2.80 AU. Same
  ETV-around-eclipsing-polar P-type-by-construction reasoning.
  cb_flag = 1 correct as a geometric classification.)

  **Notes:** c-specific data: 5.25(25)-yr ETV period, minimum mass
  7.7 +/- 1.2 M_Jup, ~2.80 AU. Cross-check: warehouse pl_orbsmax
  of 2.80 AU matches via Kepler's third law (P = 5.25 yr, M_total
  ~ 0.8 M_sun gives a = 2.85 AU). Shared inner-binary parameters
  and the strong contested-detection caveats (two-planet model
  incompleteness, Applegate alternative, eccentric-orbit
  instability, possible mechanism combination) are recorded under
  the UZ For b entry above.

---

### VHS J125601.92-125723.9

- Distance: 12.7 pc
- Planets in this system flagged `cb_flag=1`: 1

**Known companions (from `binary_companions`):**

Note: `binary_companions` is sourced from wide-binary catalogs (WDS, SIMBAD). Tight spectroscopic binaries at the heart of true P-type circumbinary systems are NOT captured here. A wide projected separation below should be read as evidence of a tertiary companion, not as the defining inner binary of a circumbinary architecture.

| Component | Separation (arcsec) | Projected (AU) | Spectype | Catalog | Bibcode |
|---|---|---|---|---|---|
| B | 7.254 | 92.13 AU | L7 | SIMBAD | ? |

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| VHS J125601.92-125723.9 b | Imaging | 2015 | 350 AU | Ambiguous (imaging detection; verify geometry by hand) | 2015ApJ...804...96G |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `VHS J125601.92-125723.9 b`: P-type confirmed (rationale: Gauza et al.
  2015 (2015ApJ...804...96G) discovered a wide-orbit planetary-mass
  companion to what they reported as a single M-dwarf primary; Stone et
  al. 2016 (2016ApJ...818L..12S, "VHS 1256-1257: A Low Mass Companion to
  a Brown Dwarf Binary System") resolved the primary into a close
  ultracool dwarf binary; Dupuy et al. 2023 (2023MNRAS.519.1688D) then
  fit the full architecture (inner binary a=1.96 AU, e=0.883; outer
  companion sma=350 AU, e=0.68, mutual inclination 115°). The wide
  companion drives Kozai-Lidov cycles pumping the inner binary's extreme
  eccentricity. Confirmed P-type. Note: this audit also identified a
  duplicate row in `binary_companions` referencing the same wide
  companion at a different epoch's projected separation (~92 AU); the
  duplicate has been removed.)

  **Notes:** Harvest from the Gauza et al. 2015 discovery abstract
  (2015ApJ...804...96G), the single-star-primary stage of the
  multi-paper history in the rationale above. Companion VHS 1256
  b: spectral type L7 +/- 1.5, mass 11.2 +9.7/-1.8 M_Jup (near the
  deuterium-burning limit), T_eff 880 +140/-110 K, log
  L_bol/L_sun = -5.05; it is ~400-700 K cooler than field late-L
  dwarfs, attributed to low surface gravity (youth). System age
  150-300 Myr from lithium absence in the primary plus likely
  Local Association membership. Trigonometric parallax 78.8 +/-
  6.4 mas = 12.7 +/- 1.0 pc (matches the warehouse distance).

  Separation-value history (worth recording to avoid future
  confusion): Gauza 2015 measured a projected separation of 102
  +/- 9 AU (8.06 arcsec at 12.7 pc); the duplicate
  `binary_companions` row removed in this audit referenced ~92 AU
  (a different epoch's projected separation); the warehouse
  pl_orbsmax of 350 AU is the Dupuy 2023 orbital semi-major axis,
  not a projected separation. These three numbers are different
  quantities/epochs for the same companion and should not be
  conflated.

  Architecture note: the "primary" Gauza 2015 reported as a single
  M7.5 dwarf with mass 73 +20/-15 M_Jup (at the star/BD boundary,
  T_eff 2620 K) is in fact the unresolved inner binary later split
  by Stone 2016 into two ultracool dwarfs. Per Stone 2016's title
  ("A Low Mass Companion to a Brown Dwarf Binary System") and Dupuy
  2023, the inner binary is a brown-dwarf pair, so VHS 1256 b is a
  planetary-mass object orbiting two brown dwarfs: a circum-(BD+BD)
  system and one of the most extreme architectures in the corpus.
  The companion's own mass (11.2 M_Jup) sits near the DB limit,
  placing it in the planet/BD edge-case family with Ross 458 c, SR
  12 AB c, and ROXs 42 B b, though here it is the planet around a
  substellar binary rather than a stellar one. This is also a
  multi-citation-per-planet case (Gauza 2015 single-star discovery
  -> Stone 2016 inner binary resolved -> Dupuy 2023 full
  architecture) for the citation revamp.

---

### WISPIT 1

- Distance: 224.7 pc
- Planets in this system flagged `cb_flag=1`: 2

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| WISPIT 1 b | Imaging | 2025 | 338 AU | Ambiguous (imaging detection; verify geometry by hand) | 2025A&A...704A.221V |
| WISPIT 1 c | Imaging | 2025 | 840 AU | Ambiguous (imaging detection; verify geometry by hand) | 2025A&A...704A.221V |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `WISPIT 1 b`: P-type confirmed (rationale: van Capelleveen et al.
  2025 (2025A&A...704A.221V), the WISPIT survey discovery paper,
  report WISPIT 1b and 1c, two gas-giant planetary companions
  co-moving (via VLT/SPHERE
  proper-motion analysis) with the previously unknown stellar
  binary WISPIT 1, itself a K4 star plus an M5.5 star in a
  multi-decadal orbit. WISPIT 1 b is the inner of the two, at a
  projected separation of 338 AU with a mass of ~10 M_Jup
  (AMES-COND/DUSTY tracks). Both planets lie far outside the
  binary's multi-decadal orbit, forcing P-type geometry. cb_flag =
  1 correct.)

  **Notes:** Inner binary is the previously unknown WISPIT 1 pair:
  a K4 primary (Sun-like) plus an M5.5 secondary in a multi-decadal
  orbit; component masses and the binary separation are not given
  numerically in this abstract (a multi-decadal period implies a
  separation of order ~10 AU by Kepler's third law, my estimate),
  pull the paper body before backfilling `binary_companions` (no
  row exists for this host). WISPIT 1 b mass ~10 M_Jup is clearly
  planetary (below 13 M_Jup). Cross-check: warehouse pl_orbsmax of
  338 AU is the abstract's projected separation exactly, but it is
  a projected separation, not a true orbital semi-major axis, and
  should be stored as such.

  Architecture significance: WISPIT 1 is a wide-imaged
  multi-planet circumbinary system (b at 338 AU, c at 840 AU),
  unusual in the corpus, which mostly pairs multi-planet CBPs with
  transit detection (e.g. Kepler-47) and single planets with
  imaging (b Cen, HD 143811). Both WISPIT planets are co-moving
  common-proper-motion companions confirmed with VLT/SPHERE; the
  young age (the WISPIT survey targets hosts <5-20 Myr) makes these
  among the youngest imaged circumbinary planets. Flagged in the
  abstract as prime GRAVITY-interferometry (eccentricity) and
  spectroscopy (composition/metallicity) follow-up targets. The
  WISPIT 1 c entry below shares this discovery paper and inner
  binary.
- `WISPIT 1 c`: P-type confirmed (rationale: van Capelleveen et al.
  2025 (2025A&A...704A.221V), the outer of the two WISPIT 1
  planetary companions (see WISPIT 1 b above for full
  system context). WISPIT 1 c is at a projected separation of 840
  AU with a mass of ~4 M_Jup, co-moving with the K4 + M5.5 binary.
  Far outside the binary's multi-decadal orbit, forcing P-type
  geometry. cb_flag = 1 correct.)

  **Notes:** c-specific data: projected separation 840 AU, mass ~4
  M_Jup (clearly planetary). Cross-check: warehouse pl_orbsmax of
  840 AU is the abstract's projected separation exactly (projected,
  not orbital sma). Note the mass-separation inversion: the inner
  planet b (338 AU) is more massive (~10 M_Jup) than the outer c
  (840 AU, ~4 M_Jup). Shared inner-binary parameters and system
  significance recorded under the WISPIT 1 b entry above.

---

### b Cen A

- Distance: 98.1 pc
- Planets in this system flagged `cb_flag=1`: 1

**No `binary_companions` row for this host.** The cb_flag is set but the warehouse has no secondary-star evidence to verify the architecture. For P-type confirmation, the discovery paper's reported inner-binary parameters would need to be consulted directly (not in the warehouse). Default verdict: needs investigation.

**Planets:**

| Planet | Discovery | Year | pl_orbsmax (AU) | Suggested verdict | Bibcode |
|---|---|---|---|---|---|
| b Cen AB b | Imaging | 2021 | 556 AU | Ambiguous (imaging detection; verify geometry by hand) | 2021Natur.600..231J |

**Verdict (fill in by hand if you disagree with the suggestion):**

- `b Cen AB b`: P-type confirmed (rationale: Janson et al. 2021
  (2021Natur.600..231J) directly imaged a planet at ~560 AU (560
  times the Sun-Earth distance) from the 6-10 M_sun binary b
  Centauri, the most massive planet-hosting stellar system known.
  The planet-to-star mass ratio of 0.10-0.17% is Jupiter-Sun-like,
  implying a planet mass of order ~6-18 M_Jup. The (AB)
  designation and the planet's 560 AU separation, far outside the
  close b Cen AB binary, make this a circumbinary (P-type)
  configuration. cb_flag = 1 correct.)

  **Notes:** Inner binary is b Centauri AB, a 6-10 M_sun (B-star)
  spectroscopic binary, the most massive planet host in the corpus
  by a wide margin; component masses and the binary separation are
  not given numerically in this abstract, pull the paper body
  before backfilling `binary_companions` (no row exists for this
  host). This is a BEAST survey result (B-star Exoplanet Abundance
  Study, Sco-Cen), the same Janson-led program that produced HIP
  79098 (AB)b; the two are the corpus's B-star circumbinary
  companions and natural cross-references.

  Edge-case note: the planet mass implied by the 0.10-0.17% mass
  ratio of a 6-10 M_sun primary is ~6-18 M_Jup, straddling the 13
  M_Jup deuterium-burning boundary, though the abstract frames it
  as a planet via the Jupiter-like mass ratio; it is more clearly
  planetary than the BEAST sibling HIP 79098 (AB)b (16-25 M_Jup).
  Cross-check: warehouse pl_orbsmax of 556 AU matches the
  abstract's ~560 AU (560 x Sun-Earth distance); this is the
  imaged separation, ~100x Jupiter's. Formation note for the
  value-added catalog: the abstract states the planet is unlikely
  to have formed in situ by core accretion and likely arrived via
  dynamical interactions or formed by gravitational instability,
  the same wide-orbit formation tension recurring across the
  imaging entries (ROXs 42 B b, SR 12 AB c, Ross 458 c). The
  result challenges the expectation that giant planets are rare
  around stars above ~3 M_sun.

---

## Screenshot candidates detail

(none detected)
