# Citation & data-enrichment playbook

A handoff for continuing the literature deep-dive that enriches the Atlas with
data (and citations) the NASA Exoplanet Archive does not surface. Written 2026-05-22.

## Why we do this

The Atlas is a value-added catalog: it audits and enriches the archives rather
than mirroring them. The governing rule is simple and non-negotiable: **if we
display a data point harvested from a paper, we must cite that paper.** Doing
this rigorously is what separates the project from a "science-fair" data dump,
it is the credibility argument, and it is the backbone of the Research Note in
preparation. See [project memory: value-added catalog, academic-tool framing].

## How we do it (the workflow)

1. **Pick a target.** A single system, or a cohort (e.g. all `cb_flag = 1`
   systems; the 1990s "single-citation" cohort; planets with known atmospheres).
2. **Check the warehouse FIRST.** Query what we already hold before harvesting,
   so we refine rather than duplicate. (Example from yesterday: ups And's mutual
   inclination was already seeded in migration 010; we refined the value, did not
   re-add it.)
3. **Fetch + verify against ADS.** Use `etl/sources/ads.py`
   (`fetch_normalized_batch(bibcodes, key)`); needs `ADS_API_TOKEN`. Verify every
   bibcode before using it, never assert one from memory.
4. **Harvest the values.** Abstract-first; go to full text (arXiv HTML ->
   ar5iv -> arXiv PDF -> journal -> human paste) only when the number is not in
   the abstract. Record provenance type (m sin i vs true mass, projected vs
   orbital separation, instrument + significance for detections).
5. **Write the data to the right table** via an idempotent migration
   (`INSERT ... ON CONFLICT DO UPDATE`) or seed:
   - `binary_companions` (inner-binary masses/separations) <- `etl/seed_inner_binaries.py`, migration 011
   - `planet_atmospheres` (molecule + instrument + confidence_sigma + bibcode), migrations 008/015/016
   - `system_orbital_geometry` (mutual inclinations), migrations 009/010/015
   - `host_distances_manual` (literature distances), migration 012
6. **Credit the sources** in the citation graph via `etl/seed_followup_citations.py`:
   `role` = the relationship (`follow_up`, `prior_detection`, `characterization`),
   `contribution` = what data we took (`binary_masses`, `distance`, `atmosphere`,
   `mutual_inclination`, `binary_separation`). Two axes, kept separate so the role
   enum does not bloat. Migrations 013 (prior_detection) + 014 (characterization +
   contribution column).
7. **Backfill author metadata** for the hand-seeded publications with
   `etl/enrich_publication_metadata.py` (ADS), so they join the author graph.
8. **Verify before handing off:** dry-run the seed (`python -m etl.seed_followup_citations`),
   and rollback-test each migration (execute the SQL inside a psycopg transaction,
   confirm the rows, then `conn.rollback()` so nothing persists). The user applies
   migrations + seeds themselves; do NOT write to the production DB or prescribe
   `psql` run commands (DATABASE_URL lives in `.env`).

## Strategies / lessons from the deep dives

- **Verify, do not assert.** Bibcodes and values get checked against ADS / full
  text. A truncated abstract is not enough to claim a specific molecule or sigma.
- **Check existing warehouse state first** to avoid duplicate or conflicting rows.
- **Two-axis citations** (role + contribution) make "we used this paper's X"
  expressible without inventing per-data-type roles.
- **Idempotent migrations + rollback-test** validate SQL safely without persisting.
- **Mind the caps and units** (API `limit` cap, Earth vs Jupiter masses, etc.).
- **Precision matters** (the user pushed for it): pin contribution to the actual
  data taken, and keep the audit's interpretive findings out of the public per-host
  doc (they live in the private RNAAS draft, `docs/rnaas_cb_flag_audit.md`, gitignored).
- See [docs/deep_dive_obstacles.md](deep_dive_obstacles.md) for the 15 concrete
  retrieval failure patterns the manual passes exposed.

## Current state

- **cb_flag audit complete** ([docs/cb_flag_audit.md](cb_flag_audit.md)): 54
  planets / 44 hosts reviewed; verdicts + inner-binary data seeded.
- **Old-cohort + JWST atmosphere harvest** (migrations 015, 016): 14 atmosphere
  detections across 7 planets, ups And geometry refined, two wide-companion
  separations, all cited.
- **Citation graph** carries discovery / follow_up / prior_detection /
  characterization roles with `contribution` tags; manual pubs have ADS authors.

## Reviewed-systems ledger

What we have already deep-dived, so future passes refine rather than repeat.

**cb_flag audit (54 planets / 44 hosts, complete)** verdicts + inner-binary data
seeded: 2MASS J0103-5515 A, 2MASS J0249-0557 A, 2MASS J1938+4603, BEBOP-3,
BEBOP-4 A, DE CVn, DP Leo, HD 143811 A, HD 202206, HD 284149 A, HIP 79098 AB,
HU Aqr, KMT-2016-BLG-1337L, Kepler-16, Kepler-1647, Kepler-1660 A, Kepler-1661,
Kepler-34, Kepler-35, Kepler-38, Kepler-413, Kepler-453, Kepler-47,
MXB 1658-298, NN Ser, NSVS 14256825, NY Vir, OGLE-2007-BLG-349L A,
OGLE-2016-BLG-0613L AB, OGLE-2018-BLG-1700L, OGLE-2019-BLG-1470L A,
OGLE-2023-BLG-0836L, PH1, PSR B1620-26, ROXs 42 B, RR Cae, Ross 458, SR 12 AB,
TIC 172900988 Aa, TOI-1338 A, UZ For, VHS J1256-1257, WISPIT 1, b Cen A. See
[docs/cb_flag_audit.md](cb_flag_audit.md).

**Atmosphere + old-cohort harvest (migrations 015, 016)** molecules / geometry /
companions seeded and cited: HD 209458 b, 51 Peg b, HD 189733 b, 55 Cnc e,
WASP-39 b, WASP-96 b, K2-18 b, and ups And (geometry refined + wide companion).

**Open citation gap (NOT yet reviewed).** Migration 010 bulk-seeded
`system_orbital_geometry` for 18 systems, but the citation backfill (workflow
step 6) was never run for most of them: they display harvested geometry while
carrying only the discovery paper. This violates the governing rule. Affected,
discovery-only: GJ 876, HR 8799, K2-138, Kepler-9, Kepler-11, Kepler-30,
Kepler-36, Kepler-56, Kepler-186, Kepler-223, Kepler-419, Kepler-444, TOI-178,
TRAPPIST-1, WASP-47, bet Pic. (55 Cnc and ups And are the only two already
backfilled. Kepler-90 has no geometry rows.)

## Where to go next

- **Close the geometry citation gap first** (the list above): we are displaying
  data we do not cite, the one thing the playbook forbids. Each system needs the
  geometry source paper(s) verified via ADS and seeded as `characterization`
  with `contribution = 'mutual_inclination'` (or the relevant geometry tag).
- The **single-citation cohort**: the oldest systems (1992-1999) each still
  carry only the discovery paper despite decades of follow-up, a rich vein.
  Confirmed discovery-only and untouched: PSR B1257+12 (the first confirmed
  exoplanets), 47 UMa, 16 Cyg B, 70 Vir, tau Boo, rho CrB, GJ 876, and the
  HD 168443 / 187123 / 210277 / 217107 group.
- Keep it **human-initiated and human-verified** (detect -> queue -> verify,
  never auto-write). The user has declined to automate this; see
  [project memory: literature monitor idea].
