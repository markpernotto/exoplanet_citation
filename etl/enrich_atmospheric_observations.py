"""NASA Exoplanet Archive `spectra` table → planet_atmospheric_observations.

Fetches the bulk catalog of atmospheric spectroscopy observations (transmission,
emission, phase-curve, etc.) — one row per published observation campaign. This
is *observation metadata only* (which planet, which instrument, what wavelength
range, ADS bibcode). Molecule-level detections are NOT in this table; those are
curated separately into `planet_atmospheres`.

Drives the VR scene's "this planet has been atmospherically observed" badge and
seeds the curation queue for `planet_atmospheres` molecule entries.

Prerequisite: apply etl/migrations/008_atmospheres.sql to your DB.

Run:
  python -m etl.enrich_atmospheric_observations              # incremental (default)
  python -m etl.enrich_atmospheric_observations --refresh    # full re-fetch
  python -m etl.enrich_atmospheric_observations --dry-run    # plan only
"""

from __future__ import annotations

import argparse
import logging
import os
from typing import Any

import httpx
import psycopg
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_exponential

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

TAP_BASE = "https://exoplanetarchive.ipac.caltech.edu/TAP/sync"
ADQL_QUERY = """
SELECT pl_name, spec_type, instrument, facility,
       minwavelng, maxwavelng, num_datapoints, bibcode, note
FROM spectra
"""


@retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=1, min=2, max=30))
def fetch_spectra() -> list[dict[str, Any]]:
    resp = httpx.get(
        TAP_BASE,
        params={"query": ADQL_QUERY, "format": "json"},
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()


UPSERT_SQL = """
INSERT INTO planet_atmospheric_observations
    (pl_name, spec_type, instrument, facility,
     min_wavelength_um, max_wavelength_um, num_datapoints, bibcode, notes)
VALUES
    (%(pl_name)s, %(spec_type)s, %(instrument)s, %(facility)s,
     %(min_wavelength_um)s, %(max_wavelength_um)s, %(num_datapoints)s,
     %(bibcode)s, %(notes)s)
ON CONFLICT (pl_name, bibcode, instrument) DO UPDATE SET
    spec_type         = EXCLUDED.spec_type,
    facility          = EXCLUDED.facility,
    min_wavelength_um = EXCLUDED.min_wavelength_um,
    max_wavelength_um = EXCLUDED.max_wavelength_um,
    num_datapoints    = EXCLUDED.num_datapoints,
    notes             = EXCLUDED.notes,
    retrieved_at      = now()
"""


def row_from_doc(doc: dict[str, Any]) -> dict[str, Any]:
    # The `spectra` table reports bibcode + instrument + pl_name as a natural
    # composite key. Some rows carry NULL for any of these — coerce to empty
    # string so the PK never blocks an upsert (we'd rather store noisy data
    # than drop rows).
    return {
        "pl_name":           doc.get("pl_name") or "",
        "spec_type":         doc.get("spec_type"),
        "instrument":        doc.get("instrument") or "",
        "facility":          doc.get("facility"),
        "min_wavelength_um": doc.get("minwavelng"),
        "max_wavelength_um": doc.get("maxwavelng"),
        "num_datapoints":    doc.get("num_datapoints"),
        "bibcode":           doc.get("bibcode") or "",
        "notes":             doc.get("note"),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync NASA spectra into planet_atmospheric_observations")
    parser.add_argument("--refresh", action="store_true",
                        help="Re-fetch and upsert every row (default is upsert-incremental anyway, but this also clears stale rows the upstream removed)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show counts; do not write to DB")
    args = parser.parse_args()

    log.info("Querying NASA Exoplanet Archive `spectra` table…")
    docs = fetch_spectra()
    log.info("Fetched %d observation rows covering %d unique planets",
             len(docs), len({d.get("pl_name") for d in docs if d.get("pl_name")}))

    if args.dry_run:
        log.info("DRY RUN — not writing")
        return

    rows = [row_from_doc(d) for d in docs]
    rows = [r for r in rows if r["pl_name"]]
    log.info("Upserting %d rows", len(rows))

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        if args.refresh:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM planet_atmospheric_observations")
                log.info("Cleared planet_atmospheric_observations (--refresh)")
        with conn.cursor() as cur:
            cur.executemany(UPSERT_SQL, rows)
        conn.commit()

    log.info("Done — %d rows written", len(rows))


if __name__ == "__main__":
    main()
