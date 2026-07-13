# sy_snum audit plan

**Purpose:** systematically document, for each of ~55 target host systems, where NASA Exoplanet Archive's stellar-multiplicity data ends (structured columns) and where it becomes free-text prose or empty rows. Produce a reviewable markdown doc that categorizes each system's structural state so the atlas can either patch the gaps (via sy_snum_audit rows) or preserve them as a known-limitation record.

**Audience:** this doc is a brief for a fresh agent with no prior conversation context. Read this whole file before starting.

---

## Background

### The project

You are working inside the **Exoplanet Citation Atlas**, a PostgreSQL warehouse layered over NASA Exoplanet Archive's `pscomppars` planet+host table. The atlas mirrors NASA's data via nightly snapshots (`planets_snapshots`) and enriches it with:

- `binary_companions` — curated per-host companion stars (inner-binary partners, wide visual companions), with per-row source_bibcode provenance
- `sy_snum_audit` — documented disagreements with NASA EA's `sy_snum` column, each row carrying supported_sy_snum, rationale, and source_bibcodes
- Other tables for derived measurements, atmospheres, orbital geometry, etc.

The user is a librarian (professional research library background, not an exoplanet researcher). Every claim in the atlas is expected to trace back to a specific bibcode. "Librarian-grade" is the recurring quality bar: verifiable, sourced, and not overstated.

### The shelved cb_flag paper

Earlier in the project, the user drafted a short paper auditing NASA EA's `cb_flag` column — the flag that marks a planet as circumbinary. The audit found:

- 51 of 54 P-type circumbinary hosts confirmed correct
- 3 microlensing hosts flagged as architecturally ambiguous
- 0 confirmed misflags
- **Structural finding:** for all 44 cb_flag=1 hosts, the tight inner binary that defines the circumbinary architecture is absent from the wide-binary catalogs (SIMBAD, WDS) that NASA EA cross-references

The paper reached the endorsement stage for arXiv (astro-ph.EP). Before sending emails, the user asked whether two named "data-quality artifacts" (PSR B1620-26 and PH1) still held up. Direct verification against NASA EA's current public pages showed both cases were **not the shape the paper claimed**:

- **PSR B1620-26** — NASA EA has `sy_snum=2` (matches the true architecture: pulsar + white dwarf inner binary). However, the "Stellar Parameters" section on the archive page only shows **1 structured host row**, with multiplicity acknowledged via a free-text note pointing at Sigurdsson et al. 2003. **Gap: structural row missing for the WD partner; the multiplicity lives in prose, not in queryable columns.**
- **PH1 (Kepler-64)** — NASA EA has `sy_snum=4` (matches the true architecture: Aa+Ab inner binary + Ba+Bb outer binary at ~1000 AU). All four stellar entities are structurally recognized. **Gap: the outer-binary components Ba and Bb show `0 stellar parameter solutions` each despite Schwamb et al. 2013 reporting their masses (0.99 + 0.51 M☉), spectral types (G2 + M2), and separation. The data is in the discovery paper's prose, not extracted into queryable NASA EA columns.**

The user shelved the paper because neither named example matched the "wrong companion" framing the draft used. The **broader structural finding still holds** — for 44 hosts collectively, discovery-paper inner-binary parameters are not extracted into NASA EA's queryable columns — but that finding on its own is closer to well-known field knowledge than a publishable claim.

**However:** the atlas benefits from documenting these gaps regardless of the paper's fate. That's what this audit produces.

### Two categories of gap

The gaps the audit surfaces fall into two distinct categories. Every system in scope should be classified:

**Category A: Structural row exists, parameters empty.**
NASA EA records the stellar entity as a host (e.g. `PH1 Ba Stellar Parameters (0 Solutions)`) but has no mass, spectype, radius, or other parameters in queryable form. The discovery paper does report these. Example: PH1 Ba, PH1 Bb.

**Category B: Only free-text acknowledgment.**
NASA EA's "Exoplanet Archive Notes" section points at a specific bibcode with a note like "this reference contains discussion regarding the stellar multiplicity of this system." No structured stellar row exists for the companion; the multiplicity is only mentioned in prose. Example: PSR B1620-26's WD partner.

**Category C (rare): sy_snum itself is wrong.**
NASA EA's `sy_snum` count disagrees with what primary literature supports. This is what the existing `sy_snum_audit` table already documents (11 rows as of migration 117). Include any additional Category C findings you surface.

**Category D: No gap.**
NASA EA fully represents the multiplicity in structured columns, with parameters populated. Log as "no gap" but include in the doc for completeness.

---

## Scope

**Target set:** union of two lists.

**List 1 — 44 cb_flag=1 hosts.** These are the circumbinary systems from the shelved cb_flag paper. Get the current list with:

```sql
SELECT hostname,
       (raw_row->>'sy_snum')::int AS sy_snum,
       (raw_row->>'cb_flag')::int AS cb_flag
  FROM planets_snapshots
 WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)
   AND (raw_row->>'cb_flag')::int = 1
 GROUP BY hostname, sy_snum, cb_flag
 ORDER BY hostname;
```

Expected: ~44 distinct hostnames.

**List 2 — existing sy_snum_audit rows.** These are the 11 systems where the atlas already documents a count disagreement with NASA EA. Get the list with:

```sql
SELECT hostname,
       nasa_ea_sy_snum,
       supported_sy_snum,
       rationale,
       source_bibcodes
  FROM sy_snum_audit
 ORDER BY hostname;
```

Expected: 11 rows (as of migration 117, Brandt 2021 HGCA EDR3 refresh).

**Combined target:** union of hostnames from List 1 and List 2. Expected: 50-55 unique systems (some overlap expected between cb_flag hosts and count-audit hosts).

---

## Methodology (per system)

For each system in the target set, do the following. Do **not** batch or parallelize until you have the shape confirmed on the first 3-5 systems and the user has reviewed the output format.

### Step 1: Pull local state

```sql
-- Our binary_companions rows for this host:
SELECT component_designation, primary_designation,
       inner_binary,
       separation_arcsec, separation_au, position_angle_deg,
       component_mass_msun, component_spectype,
       source_catalog, source_bibcode,
       LEFT(notes, 300) AS notes_preview
  FROM binary_companions
 WHERE hostname = '<hostname>'
 ORDER BY inner_binary DESC NULLS LAST, separation_au NULLS LAST;

-- Our sy_snum_audit row (if any):
SELECT nasa_ea_sy_snum, supported_sy_snum,
       rationale, source_bibcodes
  FROM sy_snum_audit
 WHERE hostname = '<hostname>';

-- NASA EA's current sy_snum + cb_flag:
SELECT pl_name,
       (raw_row->>'sy_snum')::int AS sy_snum,
       (raw_row->>'sy_pnum')::int AS sy_pnum,
       (raw_row->>'cb_flag')::int AS cb_flag
  FROM planets_snapshots
 WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM planets_snapshots)
   AND hostname = '<hostname>';
```

### Step 2: Pull NASA EA's public-page state

Visit the NASA EA overview page for one of the host's planets:

```
https://exoplanetarchive.ipac.caltech.edu/cgi-bin/DisplayOverview/nph-DisplayOverview?objname=<pl_name>
```

Substitute the pl_name from step 1 with `+` for spaces (e.g., `Kepler-16+b`). If the WebFetch tool is available, use it. If not, note that the page must be inspected manually and describe what to look for:

- **"Exoplanet Archive Notes" section:** any bibcode referenced with a multiplicity note? Record the bibcode and the note text verbatim.
- **"Stellar Parameters (N Solutions)" sections:** how many distinct stellar host rows does the page structurally show? Each host might have its own "Stellar Parameters" block (e.g., PH1 Aa, PH1 Ab, PH1 Ba, PH1 Bb). Record the count of solutions for each block; a block with `(0 Solutions)` means the entity exists as a host slot but has no parameters populated.
- **Any "Stellar Companions" or "Stellar Hosts" sidebar:** what does it list, if anything?

### Step 3: Categorize the gap

Given the state from steps 1-2, categorize the system as A, B, C, D (or a combination — a system might have both count mismatch [C] and empty parameters [A]).

- **Cross-check the count.** If NASA EA's `sy_snum` matches the number of stellar entities reflected in our `binary_companions` rows (primary + companion rows), the count is not in dispute. If they differ, it's a Category C candidate.
- **Cross-check the parameters.** For each companion in our `binary_companions` that has masses / spectypes / separations populated, check whether NASA EA's public page has these values in a queryable column. If not, it's a Category A gap.
- **Cross-check the acknowledgment.** If NASA EA's public page only mentions the multiplicity via a free-text note (no structured host row), it's a Category B gap.

### Step 4: Write the system's markdown entry

Use this template (see "Deliverable format" section below for the full spec):

```markdown
## <hostname>

- **NASA EA sy_snum:** N
- **Our count (primary + binary_companions rows):** M
- **Category:** A / B / C / D (or combination)
- **NASA EA structured host rows:** list of stellar entities with "N Solutions" counts
- **NASA EA notes bibcode:** <bibcode> or "none"
- **Our binary_companions summary:** brief list of designations + which have parameters + which have source_bibcodes
- **Gap description:** 1-3 sentence prose describing exactly what NASA EA is missing that we have (or vice versa)
- **Suggested action:** "no action" / "add sy_snum_audit row citing X" / "no atlas action but document for future NASA EA feedback" / etc.
```

### Step 5: Do not modify data

**This audit is documentation only.** Do not:

- write migrations
- INSERT into sy_snum_audit
- UPDATE binary_companions
- DELETE anything

If a system's audit suggests a future migration is warranted, describe it in the "Suggested action" field. The user reviews all migrations before they're written.

---

## Deliverable format

Produce a single markdown file at `docs/sy_snum_gap_audit.md` (create it; don't overwrite this planning doc). Structure:

```markdown
# NASA EA sy_snum gap audit

Generated by <agent name/model>, on <snapshot_date>. See docs/sy_snum_audit_plan.md for methodology.

## Summary

- **Systems audited:** <count>
- **Category A (empty structured params):** <count>
- **Category B (prose-only acknowledgment):** <count>
- **Category C (count mismatch):** <count>
- **Category D (no gap):** <count>
- **Combination cases:** <count>
- **Suggested new sy_snum_audit rows:** <count>

## Per-system findings

<one section per hostname, using the Step 4 template>

## Aggregate observations

<any patterns you notice across the audit — e.g., "12 of the 44 cb_flag hosts fall in Category B because SIMBAD/WDS never carried tight eclipsing pairs at all">

## Cross-references worth pursuing

<list of specific discovery-paper bibcodes that appear across multiple systems and would be high-leverage to extract systematically>
```

---

## Do's and don'ts

Based on the user's working style established across this project:

**Do:**

- Verify every claim you make against the actual data. Do not extrapolate from the SIMBAD-catalog-provenance to the NASA EA public page state without checking.
- Cite bibcodes when referencing published multiplicity findings.
- Note uncertainty explicitly (`"could not confirm from public page alone"`, `"stellar-parameter block absent, may be genuine gap or archive-page rendering variance"`).
- Present findings as data, not as accusations. NASA EA's team maintains a valuable resource; the point of the audit is to identify where the atlas can add value, not to critique the archive.
- Ask the user before expanding scope or changing the deliverable shape.

**Don't:**

- Skip systems if their public page is slow to load or the exact page URL is ambiguous. Note the problem and move on; the user will decide whether to revisit.
- Guess bibcodes. If you don't know the discovery paper for a system, mark it as "primary reference not identified in this pass" and let the user paste the right paper.
- Frame findings using dramatic language. `"NASA EA misses the WD partner"` is fine; `"NASA EA hides critical data"` is not.
- Use em dashes ( — ) in the output prose. The user prefers colons, periods, or parentheses.
- Compare planet properties to Mercury, Venus, Mars, Jupiter, etc. If any comparison to solar-system bodies is needed for illustration, use Earth only.
- Suggest publishing a paper based on the audit. That decision is not yours or the audit's; the user has already thought about publication and shelved the cb_flag paper for well-considered reasons.
- Modify any table or write migrations. Documentation only.

---

## Context on why this matters

The atlas frames itself as a **value-added catalog**: it doesn't compete with NASA EA on scale or maintenance, but it does patch structural gaps where NASA EA's inheritance from SIMBAD/WDS/wide-binary catalogs leaves gaps that discovery-paper prose fills. This audit is a stocktake of those gaps for the highest-stakes subset of systems (circumbinary planets and previously-audited multiplicity disagreements).

The output serves three purposes:

1. **Internal knowledge base.** Future work on individual systems benefits from knowing the shape of NASA EA's coverage before deciding whether to add a binary_companions row, a sy_snum_audit row, or nothing.
2. **Groundwork for a future data note.** If the user later decides to publish an atlas data paper (in ApJS or similar), this audit is one of its foundational data documents.
3. **Feedback loop.** Some findings may warrant filing feedback to the NASA EA team so the archive itself can improve over time.

Take the time to do this well. The user prefers one thorough system per hour over ten shallow systems per hour.

---

## Handoff checklist

Before returning the doc to the user:

- [ ] Every target system has an entry, even if the entry is "not audited due to X"
- [ ] Category counts in the summary match the per-system entries
- [ ] Every bibcode cited traces back to something you actually read or verified
- [ ] No new rows written to sy_snum_audit
- [ ] No migrations authored
- [ ] The doc uses the exact structure specified above so the user can grep it
- [ ] The "Suggested action" fields are conservative: "add sy_snum_audit row" only where you have a specific bibcode and rationale ready to paste

Return the finished `docs/sy_snum_gap_audit.md` and a one-paragraph summary of top surprises.
