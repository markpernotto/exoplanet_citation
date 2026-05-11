"""arXiv API client.

Resolves arXiv preprint IDs (e.g. '1007.4552' or '2602.18207') to paper
metadata using arXiv's public Atom-XML query endpoint. Used by Tier 2 of
etl/resolve_citations.py to handle planets whose ADS bibcode is of the
form YYYYarXivNNNN.NNNNX — papers ADS knows about but doesn't index
under that exact bibcode key (typically arXiv-only preprints whose
formal journal version doesn't exist or wasn't catalogued).

API docs: https://info.arxiv.org/help/api/index.html
Rate limit: arXiv asks for ≤1 request per 3 seconds (polite pool).
"""

from __future__ import annotations

import os
import re
import time
from typing import Any
from xml.etree import ElementTree as ET

import httpx
from tenacity import retry, retry_if_exception, stop_after_attempt, wait_exponential

BASE = "https://export.arxiv.org/api/query"

# arXiv's published guideline (https://info.arxiv.org/help/api/tou.html):
# "make no more than 1 request every 3 seconds." We sleep BEFORE each fetch
# so a failed call still leaves the cooldown intact for the next one.
SLEEP_BETWEEN = 3.5  # extra 0.5s of safety margin

# Module-level last-call timestamp so the sleep applies across calls within
# a single process run (the resolver's main loop calls fetch_by_bibcode once
# per planet, and we want the gap to be measured between those calls).
_last_call_ts: float = 0.0

# Atom + arXiv namespaces used in the response XML.
NS = {
    "atom":  "http://www.w3.org/2005/Atom",
    "arxiv": "http://arxiv.org/schemas/atom",
}


def extract_arxiv_id(bibcode: str) -> str | None:
    """Convert an ADS arXiv-form bibcode to the canonical arXiv ID.

    Examples:
        2010arXiv1007.4552J  → "1007.4552"   (4-digit suffix; dot present)
        2026arXiv260218207S  → "2602.18207"  (5-digit suffix; ADS strips the
                                              dot to fit the 19-char bibcode
                                              limit, so we re-insert it)
        2007arXivastro-ph0701592M → "astro-ph/0701592"  (old subject-class form)

    Returns None if the bibcode doesn't look like an arXiv-form ADS bibcode.
    """
    m = re.match(r"^\d{4}arXiv(.+)[A-Z]$", bibcode)
    if not m:
        return None
    body = m.group(1)

    # Old-style subject-class IDs (rare in our domain but supported)
    if body.startswith(("astro-ph", "physics", "math", "hep")):
        # ADS form is "astro-ph0701592"; canonical form is "astro-ph/0701592".
        # Insert a slash before the 7-digit suffix.
        sm = re.match(r"^([a-z\-]+)(\d{7})$", body)
        if sm:
            return f"{sm.group(1)}/{sm.group(2)}"
        return body

    # Modern YYMM.NNNN(N) form
    if "." in body:
        return body
    # Dot got stripped: 4-digit YYMM + 5-digit suffix = 9 chars total
    if len(body) == 9 and body.isdigit():
        return f"{body[:4]}.{body[4:]}"
    return body


def _is_retryable(exc: BaseException) -> bool:
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code >= 500
    return isinstance(exc, (httpx.TransportError, httpx.TimeoutException))


def _user_agent() -> str:
    project = os.environ.get("USER_AGENT_PROJECT", "exoplanet_citation/0.1")
    email   = os.environ.get("USER_AGENT_EMAIL", "")
    return f"{project} ({email})" if email else project


def _wait_for_polite_window() -> None:
    """Block until at least SLEEP_BETWEEN seconds have passed since the last call."""
    global _last_call_ts
    elapsed = time.monotonic() - _last_call_ts
    if elapsed < SLEEP_BETWEEN:
        time.sleep(SLEEP_BETWEEN - elapsed)
    _last_call_ts = time.monotonic()


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=15),
    retry=retry_if_exception(_is_retryable),
    reraise=True,
)
def _fetch_atom(arxiv_id: str) -> ET.Element | None:
    """Return the first <entry> element for the given arXiv ID, or None."""
    _wait_for_polite_window()
    resp = httpx.get(
        BASE,
        params={"id_list": arxiv_id},
        headers={"User-Agent": _user_agent()},
        timeout=20,
    )
    resp.raise_for_status()
    root = ET.fromstring(resp.text)
    entry = root.find("atom:entry", NS)
    if entry is None:
        return None
    # arXiv returns a fake "no results" entry with no id when the lookup misses.
    eid = entry.find("atom:id", NS)
    if eid is None or eid.text is None or "/abs/" not in eid.text:
        return None
    return entry


def _normalize(entry: ET.Element, source_bibcode: str, arxiv_id: str) -> dict[str, Any]:
    """Map an arXiv Atom <entry> to our canonical publication shape."""
    def _text(elem: ET.Element | None) -> str | None:
        return elem.text.strip() if (elem is not None and elem.text) else None

    title    = _text(entry.find("atom:title", NS))
    abstract = _text(entry.find("atom:summary", NS))
    pub_iso  = _text(entry.find("atom:published", NS))  # "YYYY-MM-DDTHH:MM:SSZ"
    pub_date = pub_iso[:10] if pub_iso else None

    authors: list[str] = []
    for a in entry.findall("atom:author/atom:name", NS):
        name = _text(a)
        if not name:
            continue
        # Convert "Firstname Lastname" → "Lastname, F." to match ADS author shape.
        parts = name.split()
        if len(parts) >= 2:
            authors.append(f"{parts[-1]}, {parts[0][0]}.")
        else:
            authors.append(name)

    # arXiv sometimes carries the published-journal DOI in <arxiv:doi>
    doi_elem = entry.find("arxiv:doi", NS)
    doi = _text(doi_elem)

    return {
        "bibcode":        source_bibcode,
        "doi":            doi,
        "arxiv_id":       arxiv_id,
        "title":          title,
        "authors":        authors,
        "abstract":       abstract,
        "journal":        None,    # arXiv preprints predate journal placement
        "pub_date":       pub_date,
        "citation_count": None,    # arXiv doesn't track citations
    }


def fetch_by_bibcode(bibcode: str) -> dict[str, Any] | None:
    """Resolve an arXiv-form ADS bibcode to publication metadata.

    Returns the normalized dict, or None if the bibcode isn't arXiv-form or
    arXiv has no record of the ID. Inter-call rate limiting is handled
    inside _fetch_atom() so a failed call still pays the cooldown.
    """
    arxiv_id = extract_arxiv_id(bibcode)
    if not arxiv_id:
        return None
    entry = _fetch_atom(arxiv_id)
    if entry is None:
        return None
    return _normalize(entry, source_bibcode=bibcode, arxiv_id=arxiv_id)
