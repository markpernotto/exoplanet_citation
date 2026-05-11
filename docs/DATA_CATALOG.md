# Data Catalog

A reference for every dataset this project ingests. One section per source, plus a column-family decoder for the NASA Exoplanet Archive.

---

## NASA Exoplanet Archive — `pscomppars` (Composite Parameters)

| | |
|---|---|
| **Title** | Planetary Systems Composite Parameters |
| **Publisher** | California Institute of Technology (NASA Exoplanet Archive) |
| **Source URL** | https://exoplanetarchive.ipac.caltech.edu/TAP |
| **Schema docs** | https://exoplanetarchive.ipac.caltech.edu/docs/API_PS_columns.html |
| **License / use policy** | https://exoplanetarchive.ipac.caltech.edu/docs/acknowledge.html |
| **Update cadence** | Approximately weekly |
| **Coverage** | All confirmed exoplanets known to NASA's catalog (6,286 as of 2026-05-08) |
| **Row grain** | One row per planet, with archive-preferred parameter values |
| **Citation string** | "This research has made use of the NASA Exoplanet Archive, which is operated by the California Institute of Technology, under contract with the National Aeronautics and Space Administration under the Exoplanet Exploration Program." |
| **Used by** | `etl/sources/exoplanet_archive.py` (extract); `etl/load.py` (raw landing); `etl/transform/models/staging/stg_pscomppars.sql` (staging) |
| **Local landing** | `r2://exoplanet-citation-snapshots/snapshots/YYYY-MM-DD.csv`; manifest in `data/MANIFEST.jsonl`; raw rows in `planets_snapshots.raw_row` JSONB |

### How to read pscomppars columns: the family pattern

`pscomppars` is wide (~370 columns) but most of those columns are not separate concepts. Almost every **measured quantity** ships as a family of 7–9 columns sharing a common stem.

For example, the Gaia G-band magnitude family:

| Column | Meaning |
|---|---|
| `sy_gaiamag` | **The value.** Gaia G-band magnitude. |
| `sy_gaiamagerr1` | Upper (`+`) error bar |
| `sy_gaiamagerr2` | Lower (`−`) error bar |
| `sy_gaiamagsymerr` | Symmetric error (when err1 == −err2) |
| `sy_gaiamaglim` | Limit flag: `1` = upper limit, `-1` = lower limit, `0`/null = measurement |
| `sy_gaiamagstr` | Pre-formatted display string ("10.45 ± 0.02") — UI only, ignore |
| `sy_gaiamagformat` | Display format spec — UI only, ignore |
| `sy_gaiamag_solnid` | Internal solution ID (which row of the source `ps` table the composite came from) |
| `sy_gaiamag_reflink` | HTML link to the publication that produced this value — **provenance** |

So those nine columns describe **one quantity**. The same pattern applies to almost every measured field: `pl_orbper{,err1,err2,symerr,lim,str,format,_solnid,_reflink}`, `st_teff{,err1,err2,...}`, etc.

**For our pipeline, we generally only need:**
- The value column itself.
- The `_reflink` if we want to surface citation provenance per-field in the UI.

Everything else is either redundant (the str/format pair), internal bookkeeping (solnid), or only relevant when you specifically need error bars in a chart.

### Column family suffix reference

| Suffix | Purpose | Use it? |
|---|---|---|
| (none) | The value | **Yes** — always |
| `err1` | Asymmetric upper error | Sometimes — for error bars in plots |
| `err2` | Asymmetric lower error | Sometimes — for error bars in plots |
| `symerr` | Symmetric error | Sometimes — when err1 == −err2 |
| `lim` | Limit flag | Yes if you display the value — exclude rows where this is non-zero, or render with a `≤` / `≥` |
| `str` | Display string | No — recompute from value + err if needed |
| `format` | Display format spec | No |
| `_solnid` | Solution ID | No — internal |
| `_reflink` | Publication link | **Yes** — provenance |

Our typed columns in `planets_snapshots` carry only the **value** column today. Error bars and reflinks remain in `raw_row` (JSONB) and can be surfaced on demand by reading the JSONB field.

### Identity columns (no family pattern, just IDs)

| Column | Meaning |
|---|---|
| `pl_name` | Canonical planet name. Our primary key in `planets_snapshots`. |
| `hostname` | Host star name. All planets sharing a `hostname` are siblings in the same system. |
| `gaia_dr2_id` | Gaia DR2 source ID (2018 catalog) — different integer than DR3 for the same star |
| `gaia_dr3_id` | Gaia DR3 source ID (2022 catalog) — **use this** as the cross-reference key |
| `tic_id` | TESS Input Catalog ID — useful for joining to TESS observations |
| `hd_name`, `hip_name` | Henry Draper / Hipparcos catalog cross-references |
| `kic_id` | Kepler Input Catalog ID (only for Kepler-discovered planets) |

### Quantities we care about (the underlying ~25 measurements)

#### Planet (`pl_*`)

| Column | Meaning | Units |
|---|---|---|
| `pl_orbper` | Orbital period | days |
| `pl_orbsmax` | Semi-major axis (avg distance from host star) | AU (1 AU = Earth-Sun distance) |
| `pl_orbeccen` | Orbital eccentricity (0 = circle, →1 = elongated) | dimensionless |
| `pl_orbincl` | Orbital inclination relative to plane-of-sky | degrees |
| `pl_rade` | Planet radius | Earth radii |
| `pl_radj` | Planet radius | Jupiter radii |
| `pl_bmasse` | Best estimate of planet mass | Earth masses |
| `pl_bmassj` | Best estimate of planet mass | Jupiter masses |
| `pl_dens` | Planet density | g/cc |
| `pl_eqt` | Equilibrium temperature (assumes zero albedo) | Kelvin |
| `pl_insol` | Insolation flux (sunlight received) | multiples of Earth's |

#### Host star (`st_*`)

| Column | Meaning | Units |
|---|---|---|
| `st_teff` | Effective temperature | Kelvin |
| `st_rad` | Stellar radius | solar radii |
| `st_mass` | Stellar mass | solar masses |
| `st_lum` | Stellar luminosity (log10) | log10(L/L⊙) |
| `st_age` | Stellar age | Gyr |
| `st_met` | Metallicity | dex (log relative to solar) |
| `st_spectype` | Spectral type | string (e.g., "G2V") |

#### System (`sy_*`)

| Column | Meaning | Units |
|---|---|---|
| `sy_dist` | Distance from Earth | parsecs (× 3.26 = light years) |
| `sy_pnum` | Number of planets in this system | int |
| `sy_snum` | Number of stars in this system | int |
| `ra` | Right ascension (sky coordinate, longitude-like) | degrees |
| `dec` | Declination (sky coordinate, latitude-like) | degrees |
| `sy_vmag` | Apparent visible-light magnitude (V-band) | magnitudes |
| `sy_kmag` | Apparent infrared magnitude (K-band) | magnitudes |
| `sy_gaiamag` | Apparent Gaia G-band magnitude | magnitudes |

#### Discovery (`disc_*`)

| Column | Meaning |
|---|---|
| `discoverymethod` | "Transit", "Radial Velocity", "Imaging", "Microlensing", etc. (see `vocabularies/discovery_method.yaml`) |
| `disc_year` | Year discovery was published |
| `disc_facility` | Telescope / mission that made the discovery |
| `disc_telescope` | More specific telescope identifier |
| `disc_instrument` | Specific instrument used |
| `disc_refname` | Free-text bibliographic reference (Phase 2 input for citation resolution) |
| `disc_pubdate` | Discovery publication date |

### Tier mapping (project-internal)

How our pipeline classifies each column for change-event handling. See [PLAN.md](../PLAN.md) for the full rationale.

- **Tier A** (RSS-surfaced, public change feed): `discoverymethod`, `disc_year`, `disc_facility`, `pl_orbper`, `pl_rade`, `pl_bmasse`. Tier A floats use 1% relative-tolerance with sub-tolerance demoted to Tier B.
- **Tier B** (logged in `discovery_changes` but not surfaced in feeds, 13 columns after Phase 1.x): `sy_snum`, `sy_pnum`, `pl_eqt`, `pl_orbsmax`, `pl_orbeccen`, `pl_insol`, `pl_dens`, `st_teff`, `st_rad`, `st_mass`, `st_lum`, `st_spectype`, `sy_dist`. Sub-tolerance float changes are *suppressed* (not demoted).
- **Tier C** (preserved in `raw_row` JSONB only, never diffed): everything else, plus the identity-stable typed columns `ra`, `dec`, `gaia_dr3_id`.

### Known quirks and caveats

- **`disc_refname` is HTML-embedded, not free-text reference strings.** Format is typically `<a href="https://ui.adsabs.harvard.edu/abs/{bibcode}/abstract">label</a>`, with `%26` encoding embedded `&` characters. `etl/resolve_citations.py` parses out the bibcode via regex (`abs/([^/]+)/abstract`) as Tier 1 of the citation resolver.
- **Errors are sometimes asymmetric, sometimes symmetric.** When `errN` columns are populated and `symerr` is null, use the asymmetric pair. When `symerr` is populated and `errN` are null, use the symmetric value.
- **Limit flags matter for filtering.** A row with `pl_dens_lim = 1` means the density value is an *upper limit* — the planet is at most that dense, not exactly that dense. UI plots should mark these distinctly.
- **`gaia_dr2_id` and `gaia_dr3_id` are different IDs for the same star.** DR3 superseded DR2 in 2022. Always prefer DR3 for cross-reference queries to Gaia's TAP service.
- **Composite vs. per-publication values.** `pscomppars` carries archive-preferred values per planet. The full `ps` table (Phase 2) contains every published value with the citation that produced it — useful for `fact_parameter_revision`.
- **Snapshot row count grows over time.** As new planets are confirmed, the count rises. Rows can also be removed (rare; usually a retraction or merge with another planet entry).

### Upstream documentation

The authoritative reference for every column is the Exoplanet Archive's own column documentation, which is maintained alongside the data:

- Full column list with definitions: https://exoplanetarchive.ipac.caltech.edu/docs/API_PS_columns.html
- TAP service docs: https://exoplanetarchive.ipac.caltech.edu/docs/TAP/usingTAP.html
- Acknowledgement and citation policy: https://exoplanetarchive.ipac.caltech.edu/docs/acknowledge.html

This catalog reflects our project's *use* of the columns. The upstream docs are the source of truth for definitions; we only document our internal classifications and known quirks.

---

## Phase 2 sources — integrated

### NASA ADS API *(integrated)*
- **Source URL:** `https://api.adsabs.harvard.edu/v1/search/query`
- **Purpose:** Astronomy-specific bibliographic database. Resolves
  bibcodes (extracted from `disc_refname` or via title search) to
  rich paper metadata: title, authors, abstract, citation count, DOI,
  arXiv ID.
- **Used by:** `etl/sources/ads.py` (client with quota-aware circuit
  breaker), `etl/enrich_ads.py` (caches results in `discovery_papers`),
  `etl/resolve_citations.py` (Tier 1 + Tier 3 of the resolver).
- **Quota:** 5,000 requests/user/day on the free tier; reset is
  reported in the `X-RateLimit-Reset` response header (rolling 24h
  window). The client trips a module-level circuit breaker on
  `X-RateLimit-Remaining: 0` and short-circuits all subsequent calls
  for the rest of the process to avoid wasted roundtrips.
- **License / acknowledgement:** see https://ui.adsabs.harvard.edu/help/terms/

### Crossref REST API *(retired)*
- **Source URL:** `https://api.crossref.org/works/{doi}`
- **Purpose (historical):** Tier 2 fallback during initial backfill — when
  the daily ADS quota was exhausted, planets with a known DOI in
  `discovery_papers` were resolved against Crossref instead of going
  straight to the manual queue.
- **Status:** removed 2026-05-08 once ADS coverage hit 98.9% on a single
  fresh-quota run. Crossref produced strictly thinner data than ADS (no
  abstract, no ADS bibcode, no ADS-tracked citation count) so all
  Crossref-resolved publications were purged and re-resolved via ADS.
  `etl/sources/crossref.py` is deleted; the `publications.resolved_via`
  CHECK constraint still permits `'crossref_doi'` for forward
  compatibility, but no code path writes it.

### Gaia DR3 *(integrated)*
- **Source URL:** `https://gea.esac.esa.int/tap-server/tap`
- **Purpose:** Per-host-star astrometry (precise distance, proper
  motion, radial velocity), photometry (BP-RP color → derived surface
  temperature for visualizations), Gaia-derived stellar parameters
  (`teff_gspphot`, `logg_gspphot`, `mh_gspphot`, `distance_gspphot`).
  Cross-referenced via `gaia_dr3_id` from pscomppars.
- **Used by:** `etl/sources/gaia.py` (TAP client),
  `etl/enrich_gaia.py` (UPSERTs into `host_stars_gaia`).
- **Why not just use pscomppars Gaia columns:** pscomppars carries only
  `sy_gaiamag` and the Gaia source IDs. Querying Gaia directly gives
  access to BP-RP photometry, parallax with full precision, proper
  motion, and Gaia-derived stellar parameters not present in pscomppars.

### arXiv API *(integrated)*
- **Source URL:** `https://export.arxiv.org/api/query`
- **Purpose:** Tier 2 of the citation resolver — handles planets whose
  `disc_refname` cites an arXiv-form bibcode (e.g. `2010arXiv1007.4552J`)
  that ADS's bibcode lookup doesn't index. Returns title, authors,
  abstract, publication date, arXiv ID, and (often) the eventual
  journal-publication DOI.
- **Used by:** `etl/sources/arxiv.py`, called by `resolve_citations.py`
  Tier 2.
- **Auth:** none required. We send a `User-Agent` header carrying
  `USER_AGENT_PROJECT (USER_AGENT_EMAIL)` per arXiv ToS.
- **Rate limit:** arXiv asks for ≤1 request per 3 seconds. Enforced
  module-side via a `_last_call_ts` clock so even a failed call
  preserves the cooldown for the next attempt.
- **Bibcode quirks handled:**
  - `2010arXiv1007.4552J` → arXiv ID `1007.4552` (4-digit suffix; dot present)
  - `2026arXiv260218207S` → arXiv ID `2602.18207` (5-digit suffix; ADS strips
    the dot to fit the 19-char bibcode limit, so we re-insert it)
  - `2007arXivastro-ph0701592M` → `astro-ph/0701592` (old subject-class form)

---

## Future sources (Phase 3+)

### Habitable Exoplanets Catalog (PHL @ UPR Arecibo) *(Stretch)*
- **Source URL:** http://phl.upr.edu/projects/habitable-exoplanets-catalog
- **Purpose:** Pre-computed Earth-Similarity Index per planet,
  habitable-zone classification.
- **Status:** Under consideration for Phase 3.
