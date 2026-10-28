"""Parse NASA Exoplanet Archive reference anchors into citations.

pscomppars gives the source of each composite parameter (`*_reflink`) and the
discovery paper (`disc_refname`) as HTML anchors, stored verbatim:

  <a refstr=BONOMO_ET_AL_2023 href=https://ui.adsabs.harvard.edu/abs/2023A&A...677A..33B/abstract target=ref>Bonomo et al. 2023</a>
  <a refstr=CALCULATED_VALUE href=/docs/pscp_calc.html target=_blank>Calculated Value</a>
  <a refstr=Q1_Q17_DR25_KOI_TABLE href=https://exoplanetarchive.ipac.caltech.edu/docs/Kepler_KOI_docs.html target=ref>Q1-Q17 DR25 KOI Table</a>

Labels carry HTML entities for accented author names (`Gonz&aacute;lez`) and
are unescaped. Hrefs are not: ADS bibcodes contain a literal `A&A`.
"""

from __future__ import annotations

import html
import re

from api.models import ValueReference

NASA_EA_BASE = "https://exoplanetarchive.ipac.caltech.edu"

# Fields whose only reference is the discovery paper (see etl/diff.py FieldSpec.ref_col).
DISCOVERY_REF_FIELDS = {"discoverymethod", "disc_year", "disc_facility"}

_ANCHOR = re.compile(r"<a\b([^>]*)>(.*?)</a>", re.IGNORECASE | re.DOTALL)
_HREF = re.compile(r"href=([^\s>]+)", re.IGNORECASE)
_REFSTR = re.compile(r"refstr=([^\s>]+)", re.IGNORECASE)
_BIBCODE = re.compile(r"abs/([^/]+)/abstract")
_YEAR = re.compile(r"\b(?:19|20)\d{2}\b")


def parse_reflink(raw: str | None, role: str) -> ValueReference | None:
    """Parse one anchor. Returns None for an empty reference; text without
    anchor markup is kept as a label with no link."""
    if not raw or not raw.strip():
        return None
    m = _ANCHOR.search(raw)
    if m is None:
        label = html.unescape(re.sub(r"<[^>]+>", "", raw)).strip()
        return ValueReference(label=label, url=None, bibcode=None, kind="paper", role=role) if label else None

    attrs, text = m.group(1), m.group(2)
    href_m, refstr_m = _HREF.search(attrs), _REFSTR.search(attrs)
    url = href_m.group(1).strip("'\"") if href_m else None
    if url and url.startswith("/"):
        url = NASA_EA_BASE + url
    refstr = refstr_m.group(1).upper() if refstr_m else ""
    label = html.unescape(re.sub(r"\s+", " ", text)).strip()
    bib_m = _BIBCODE.search(url or "")
    bibcode = bib_m.group(1) if bib_m and "adsabs" in (url or "") else None

    if refstr == "CALCULATED_VALUE":
        kind = "calculated"
    elif bibcode or _YEAR.search(label):
        kind = "paper"
    else:
        kind = "catalog"
    return ValueReference(label=label or refstr, url=url, bibcode=bibcode, kind=kind, role=role)


def change_ref_role(change_type: str, field_name: str | None) -> str:
    if change_type in ("NEW", "REMOVED") or field_name in DISCOVERY_REF_FIELDS:
        return "discovery"
    return "source"


def change_refs(change: dict) -> tuple[ValueReference | None, ValueReference | None]:
    """(prev_ref, new_ref) for a discovery_changes row (migration 129 columns)."""
    role = change_ref_role(change["change_type"], change.get("field_name"))
    return parse_reflink(change.get("prev_reflink"), role), parse_reflink(change.get("new_reflink"), role)


def change_description(change: dict, summary: str) -> str:
    """Feed item text: the change, then the reference behind the reported value
    (the removed value's reference for REMOVED, otherwise the new one's), and
    the previous reference when NASA switched to a different source. Shared by
    the live /api/rss feeds and the static feeds etl/publish.py writes."""
    prev_ref, new_ref = change_refs(change)
    if change["change_type"] == "REMOVED":
        return f"{summary}. {format_reference(prev_ref)}"
    text = f"{summary}. {format_reference(new_ref)}"
    if change["change_type"] == "PARAMETER_CHANGE" and prev_ref and prev_ref.label != (new_ref.label if new_ref else None):
        text += f". Previously: {prev_ref.label}"
    return text


def format_reference(ref: ValueReference | None) -> str:
    """Plain-text citation for feeds: 'Source: Bonomo et al. 2023 (url)'."""
    if ref is None:
        return "Source: none given by NASA Exoplanet Archive"
    prefix = "Discovery reference" if ref.role == "discovery" else "Source"
    label = "Calculated by NASA Exoplanet Archive" if ref.kind == "calculated" else ref.label
    return f"{prefix}: {label}" + (f" ({ref.url})" if ref.url else "")
