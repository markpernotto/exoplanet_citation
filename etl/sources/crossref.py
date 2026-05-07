"""Crossref REST API client.

Looks up paper metadata by DOI. No authentication required; Crossref asks
polite users to send a mailto= param so they get routed to the faster pool.
Set USER_AGENT_EMAIL in the environment (already present in nightly.yml).

API docs: https://api.crossref.org/swagger-ui/index.html
"""

from __future__ import annotations

import os
from typing import Any

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

BASE = "https://api.crossref.org/works"


def _mailto() -> str:
    return os.environ.get("USER_AGENT_EMAIL", "")


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=15))
def fetch_by_doi(doi: str) -> dict[str, Any] | None:
    """Return a normalized dict for the given DOI, or None if not found."""
    params: dict[str, str] = {}
    if m := _mailto():
        params["mailto"] = m

    resp = httpx.get(f"{BASE}/{doi}", params=params, timeout=20)
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return _normalize(resp.json()["message"])


def _normalize(msg: dict[str, Any]) -> dict[str, Any]:
    """Map a Crossref work message to our canonical field shape."""
    # title
    titles = msg.get("title") or []
    title = titles[0] if titles else None

    # authors → "Last, F." format (matching ADS style)
    authors: list[str] = []
    for a in msg.get("author") or []:
        family = a.get("family", "")
        given  = a.get("given", "")
        if family and given:
            authors.append(f"{family}, {given[0]}.")
        elif family:
            authors.append(family)

    # pub_date from "issued" → ISO string for Postgres DATE
    pub_date: str | None = None
    issued = (msg.get("issued") or {}).get("date-parts")
    if issued and issued[0]:
        parts = issued[0]
        if len(parts) >= 3:
            pub_date = f"{parts[0]:04d}-{parts[1]:02d}-{parts[2]:02d}"
        elif len(parts) == 2:
            pub_date = f"{parts[0]:04d}-{parts[1]:02d}-01"
        elif len(parts) == 1:
            pub_date = f"{parts[0]:04d}-01-01"

    # journal
    containers = msg.get("container-title") or []
    journal = containers[0] if containers else None

    # arxiv from "link" URLs
    arxiv_id: str | None = None
    for link in msg.get("link") or []:
        url = link.get("URL", "")
        if "arxiv.org/abs/" in url:
            arxiv_id = url.split("arxiv.org/abs/")[-1].strip("/")
            break

    doi = msg.get("DOI")

    return {
        "bibcode":        None,   # Crossref doesn't know ADS bibcodes
        "doi":            doi,
        "arxiv_id":       arxiv_id,
        "title":          title,
        "authors":        authors,
        "abstract":       msg.get("abstract"),
        "journal":        journal,
        "pub_date":       pub_date,
        "citation_count": msg.get("is-referenced-by-count"),
    }
