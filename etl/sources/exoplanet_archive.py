"""NASA Exoplanet Archive TAP client.

Fetches pscomppars (Composite Parameters) — one row per planet with the
archive's preferred parameter values. Phase 1 primary source.

API docs: https://exoplanetarchive.ipac.caltech.edu/docs/TAP/usingTAP.html
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

TAP_BASE_URL = "https://exoplanetarchive.ipac.caltech.edu/TAP/sync"

PSCOMPPARS_QUERY = "SELECT * FROM pscomppars"


@dataclass(frozen=True)
class TapResponse:
    body: bytes
    source_url: str
    checksum_sha256: str
    row_count: int


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=30))
def fetch_pscomppars(*, user_agent: str) -> TapResponse:
    """Fetch the full pscomppars table as CSV bytes."""
    params = {"query": PSCOMPPARS_QUERY, "format": "csv"}
    headers = {"User-Agent": user_agent}

    with httpx.Client(timeout=httpx.Timeout(180.0), headers=headers) as client:
        response = client.get(TAP_BASE_URL, params=params)
        response.raise_for_status()

    body = response.content
    checksum = hashlib.sha256(body).hexdigest()
    # Approximate row count: total \n minus 1 for the header. Off by one if the
    # response doesn't end in a newline; fine for display/manifest purposes.
    row_count = max(0, body.count(b"\n") - 1)

    return TapResponse(
        body=body,
        source_url=str(response.url),
        checksum_sha256=checksum,
        row_count=row_count,
    )
