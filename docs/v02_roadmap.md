# v0.2 roadmap

Working scope for the v0.2 release line. v0.1 wraps with v0.1.3
(stellar-multiplicity audit + atmospheric deep-dive backlog); v0.2 takes the
project past data-completeness into a few specific weight classes the v0.1
shape couldn't carry. Not committed to dates.

## Themes

1. **Alias resolution** (data layer)
2. **3D push** (visual layer)
3. **VR parity** (XR layer)
4. **Renderer data plumbing** (the gap between what we harvest and what the
   3D engine consumes)

Themes 2-4 are partially scoped already in [PROCEDURAL_RENDERING.md](PROCEDURAL_RENDERING.md)
and the in-repo project notes; this file is the cross-cutting index, not a
duplicate spec.

---

## 1. `planet_aliases` table (data layer)

**Surfaced by:** the S-type stellar-multiplicity audit Q1 result during the
v0.1.3 wrap. Of 31 missing planet-pub links from Mugrauer 2019 (migration
077), 10 were fixable inside v0.1 by renaming hostnames to the catalog's
canonical form (migration 084 + 7 seed renames in `etl/seed_followup_citations.py`);
the remaining 21 are alias-only and stay unlinked until the alias layer
exists.

**Why a table, not a rename:**

- The papers don't agree on a canonical name. Mugrauer 2019 writes
  "Aldebaran", the catalog writes "alf Tau", SIMBAD knows both. A unilateral
  rename in either direction loses fidelity to one of the sources.
- The site needs to return search results on either form (user feedback
  during the audit: "we'll have to return search results on either system
  name").
- Several historical bugs in the v0.1 audit were name-only mismatches that a
  proper alias resolver would have caught at write time.

**Minimum-viable schema:**

```sql
CREATE TABLE planet_aliases (
  canonical_name  TEXT NOT NULL,            -- matches planets_current.pl_name (or hostname)
  alias           TEXT NOT NULL,
  alias_kind      TEXT NOT NULL,            -- 'planet' | 'host'
  source          TEXT NOT NULL,            -- 'simbad' | 'paper' | 'catalog_history' | 'manual'
  source_bibcode  TEXT,                     -- when the alias comes from a specific paper
  note            TEXT,
  PRIMARY KEY (alias, alias_kind)
);
```

Resolver helper (a SQL function or a small Python utility) takes any string
and returns the canonical name plus the resolution path, so any seed script
or API endpoint can opt in.

**Initial seed:**

- The 21 alias-only hosts from the v0.1.3 audit, captured per-row with their
  source paper.
- The 9 hostname pairs collapsed by migration 084 (preserve both directions,
  not only the canonical we wrote).
- A first pass over SIMBAD's most-cited identifiers for our hosts (`HD ###`,
  `HIP ###`, Bayer designations, survey names).

**Out of scope:**

- Catalog-wide rebuild of `pl_name` / `hostname`. The alias layer is read-side
  resolution, not a rewrite of the warehouse.
- Cross-mission name translation (Kepler ↔ KOI ↔ KIC, K2 ↔ EPIC, TESS ↔ TIC).
  Useful but separate from the audit-driven need; queue as a follow-up after
  the initial seed proves the schema.

---

## 2. 3D push (visual layer)

Two tickets carried over from v0.1, both blocked on visual polish rather
than data:

- **Diffuse galaxy shader, Phase 4** (the layer beyond Gaia reprojection
  and procedural galactic particles): see `docs/STARFIELD_PLAN.md` for the
  four-layer architecture and the per-vantage rationale.
- **Surface-mode ride-the-orbit XR regression** (memory: `project_surface_mode_vr_bug`):
  desktop path works, VR path broken; needs a Quest 3 to repro.

Add to the v0.2 list:

- **Obliquity / spin visualization** for the planets we now hold harvested
  values for (5 systems from migration 051-055, plus beta Pic b's ~25 km/s
  equatorial rotation from migration 025).
- **Day-night contrast rendering** for the WASP-43 b / WASP-127 b /
  WASP-76 b / LTT 9779 b class — the harvested phase-curve and 3D-wind data
  exists in `planet_derived_measurements` but the renderer treats dayside
  brightness uniformly.

See `docs/PROCEDURAL_RENDERING.md` for the current pipeline and the
"data-driven visuals only" framing.

---

## 3. VR parity

Bring the WebXR experience up to the same level as the desktop 3D view.
Memory: `project_v02_direction`. Specifics live in `docs/PROCEDURAL_RENDERING.md`
under the XR gotcha section; the goal here is just that the gap is
acknowledged as a v0.2 deliverable, not an ongoing back-burner.

---

## 4. Renderer data plumbing

The harvested `planet_derived_measurements` layer (composition, obliquity,
spin, day-night temperature contrast, mass-loss rate, envelope fraction,
circumplanetary-disk mass, etc.) is largely not consumed by the 3D engine
yet. See the `project_renderer_data_gaps` memory for what the engine reads
today vs what we hold. Scoping this is the prerequisite for the visual work
in theme 2.

---

## Tracking

When a v0.2 item starts, link it back here from the relevant doc
(`PROCEDURAL_RENDERING.md`, `STARFIELD_PLAN.md`, or a new per-feature doc).
When v0.1.4 / v0.1.5 patches land that touch any of these themes
incidentally, note them in the CHANGELOG but don't graduate them out of
v0.2 until the full theme ships.
