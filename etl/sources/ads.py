"""NASA ADS API client.

Fetches paper metadata from the NASA Astrophysics Data System.
Used by both etl/enrich_ads.py (discovery_papers backfill) and
etl/resolve_citations.py (citation graph resolution).

API docs: https://ui.adsabs.harvard.edu/help/api/
"""

from __future__ import annotations

import logging
import time
from datetime import UTC, datetime
from typing import Any

import httpx
from tenacity import retry, retry_if_exception, stop_after_attempt, wait_exponential

log = logging.getLogger(__name__)

BASE          = "https://api.adsabs.harvard.edu/v1/search/query"
BATCH_SIZE    = 5    # small batches keep OR queries short; ADS 503s on large ones
SLEEP_BETWEEN = 0.3  # seconds between batches

FIELDS = "bibcode,title,author,abstract,citation_count,pubdate,pub,doi,identifier"


class QuotaExhausted(Exception):
    """ADS daily quota is exhausted. Fields tell the caller when it resets."""
    def __init__(self, reset_unix: int | None):
        self.reset_unix = reset_unix
        msg = "ADS daily quota exhausted"
        if reset_unix:
            reset_dt = datetime.fromtimestamp(reset_unix, tz=UTC)
            msg += f" — resets at {reset_dt.isoformat()}"
        super().__init__(msg)


# Module-level circuit-breaker. Once tripped, every call short-circuits without
# hitting the network until the process restarts. Keeps the 4-tier resolver
# from wasting a roundtrip per planet after we've been told we're done.
_quota_exhausted: QuotaExhausted | None = None


def quota_status() -> QuotaExhausted | None:
    return _quota_exhausted


def _headers(api_key: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {api_key}"}


def _is_retryable(exc: BaseException) -> bool:
    """Retry on transient errors. 429 is not retryable — handled separately."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code != 429
    return isinstance(exc, (httpx.TransportError, httpx.TimeoutException))


def _check_quota_headers(resp: httpx.Response) -> None:
    """Trip the circuit breaker if ADS says we're at zero."""
    global _quota_exhausted
    remaining = resp.headers.get("X-RateLimit-Remaining")
    reset     = resp.headers.get("X-RateLimit-Reset")
    if remaining == "0":
        reset_unix = int(reset) if reset and reset.isdigit() else None
        _quota_exhausted = QuotaExhausted(reset_unix)
        log.error(str(_quota_exhausted))


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    retry=retry_if_exception(_is_retryable),
    reraise=True,
)
def _get(params: dict[str, Any], api_key: str) -> list[dict[str, Any]]:
    if _quota_exhausted is not None:
        raise _quota_exhausted
    resp = httpx.get(BASE, params=params, headers=_headers(api_key), timeout=30)
    _check_quota_headers(resp)
    resp.raise_for_status()
    return resp.json()["response"]["docs"]


def fetch_by_bibcodes(bibcodes: list[str], api_key: str) -> list[dict[str, Any]]:
    """Fetch multiple papers by bibcode in a single OR query."""
    query = " OR ".join(f"bibcode:{bc}" for bc in bibcodes)
    return _get({"q": query, "fl": FIELDS, "rows": len(bibcodes)}, api_key)


def fetch_by_doi(doi: str, api_key: str) -> dict[str, Any] | None:
    """Fetch a single paper by DOI. Returns None if not found."""
    docs = _get({"q": f"doi:{doi}", "fl": FIELDS, "rows": 1}, api_key)
    return docs[0] if docs else None


def fetch_by_title(title: str, first_author: str, api_key: str) -> dict[str, Any] | None:
    """Title + first-author fuzzy search. Returns the top hit or None."""
    safe_title = title.replace('"', '\\"')
    safe_author = first_author.replace('"', '\\"')
    query = f'title:"{safe_title}" author:"{safe_author}"'
    docs = _get({"q": query, "fl": FIELDS, "rows": 1, "sort": "score desc"}, api_key)
    return docs[0] if docs else None


def extract_arxiv_id(identifiers: list[str]) -> str | None:
    for ident in identifiers:
        if ident.startswith("arXiv:"):
            return ident[6:]
    return None


def normalize_doc(doc: dict[str, Any]) -> dict[str, Any]:
    """Map an ADS response doc to our canonical field shape."""
    title_list = doc.get("title") or []
    doi_list   = doc.get("doi") or []
    raw_date   = doc.get("pubdate")  # "YYYY-MM", "YYYY-MM-DD", "YYYY-MM-00", "YYYY-00-00"
    # Coerce to ISO date string accepted by Postgres DATE; pad month/day as needed.
    # ADS uses "00" for unknown month or day — clamp both to 01.
    pub_date: str | None = None
    if raw_date:
        parts = raw_date.split("-")
        year  = parts[0] if len(parts) > 0 else "0001"
        month = parts[1] if len(parts) > 1 else "01"
        day   = parts[2] if len(parts) > 2 else "01"
        if month == "00":
            month = "01"
        if day == "00":
            day = "01"
        pub_date = f"{year}-{month}-{day}"

    return {
        "bibcode":        doc.get("bibcode"),
        "doi":            doi_list[0] if doi_list else None,
        "arxiv_id":       extract_arxiv_id(doc.get("identifier") or []),
        "title":          title_list[0] if title_list else None,
        "authors":        doc.get("author") or [],
        "abstract":       doc.get("abstract"),
        "journal":        doc.get("pub"),
        "pub_date":       pub_date,
        "citation_count": doc.get("citation_count"),
    }


def fetch_normalized_batch(
    bibcodes: list[str],
    api_key: str,
    *,
    sleep: bool = True,
) -> list[dict[str, Any]]:
    """Convenience wrapper: fetch + normalize, with optional inter-batch sleep."""
    docs = fetch_by_bibcodes(bibcodes, api_key)
    if sleep:
        time.sleep(SLEEP_BETWEEN)
    return [normalize_doc(d) for d in docs]
