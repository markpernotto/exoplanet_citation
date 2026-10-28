"""Unit tests for api/references.py (NASA EA reference anchors -> citations).

Anchor strings are verbatim formats seen in pscomppars (2026-10).
"""

from __future__ import annotations

from api.references import (
    change_description,
    change_ref_role,
    change_refs,
    format_reference,
    parse_reflink,
)

ADS = ("<a refstr=BONOMO_ET_AL_2023 href=https://ui.adsabs.harvard.edu/abs/2023A&A...677A..33B/abstract "
       "target=ref>Bonomo et al. 2023</a>")
CALC = "<a refstr=CALCULATED_VALUE href=/docs/pscp_calc.html target=_blank>Calculated Value</a>"
KOI = ("<a refstr=Q1_Q17_DR25_KOI_TABLE href=https://exoplanetarchive.ipac.caltech.edu/docs/Kepler_KOI_docs.html "
       "target=ref>Q1-Q17 DR25 KOI Table</a>")
EXOFOP = "<a refstr=EXOFOP href=https://exofop.ipac.caltech.edu/tess/view_toi.php target=ref>ExoFOP</a>"
NATURE = ("<a refstr=GUPTA_ET_AL__2024 href=https://www.nature.com/articles/s41586-024-07688-3 "
          "target=ref>Gupta et al. 2024</a>")
ENTITY = ("<a refstr=GONZALEZ_ET_AL_2020 href=https://ui.adsabs.harvard.edu/abs/2020AJ....159..12G/abstract "
          "target=ref> Gonz&aacute;lez et al. 2020 </a>")


def test_ads_paper_keeps_literal_ampersand_in_bibcode():
    r = parse_reflink(ADS, "source")
    assert r.label == "Bonomo et al. 2023"
    assert r.bibcode == "2023A&A...677A..33B"
    assert r.url == "https://ui.adsabs.harvard.edu/abs/2023A&A...677A..33B/abstract"
    assert r.kind == "paper"
    assert r.role == "source"


def test_calculated_value_gets_absolute_nasa_url():
    r = parse_reflink(CALC, "source")
    assert r.kind == "calculated"
    assert r.url == "https://exoplanetarchive.ipac.caltech.edu/docs/pscp_calc.html"
    assert r.bibcode is None


def test_archive_tables_and_services_are_catalogs():
    assert parse_reflink(KOI, "source").kind == "catalog"
    assert parse_reflink(EXOFOP, "source").kind == "catalog"


def test_journal_url_without_bibcode_is_still_a_paper():
    r = parse_reflink(NATURE, "source")
    assert r.kind == "paper"
    assert r.bibcode is None
    assert r.url == "https://www.nature.com/articles/s41586-024-07688-3"


def test_label_entities_unescaped_and_trimmed():
    assert parse_reflink(ENTITY, "source").label == "González et al. 2020"


def test_empty_reference_is_none():
    assert parse_reflink(None, "source") is None
    assert parse_reflink("", "source") is None
    assert parse_reflink("   ", "source") is None


def test_plain_text_reference_kept_without_link():
    r = parse_reflink("Borucki et al. 2011", "discovery")
    assert r.label == "Borucki et al. 2011"
    assert r.url is None


def test_roles():
    assert change_ref_role("NEW", None) == "discovery"
    assert change_ref_role("REMOVED", None) == "discovery"
    assert change_ref_role("PARAMETER_CHANGE", "discoverymethod") == "discovery"
    assert change_ref_role("PARAMETER_CHANGE", "disc_facility") == "discovery"
    assert change_ref_role("PARAMETER_CHANGE", "pl_bmasse") == "source"


def change(change_type="PARAMETER_CHANGE", field_name="pl_bmasse", prev=None, new=None):
    return {"change_type": change_type, "field_name": field_name, "prev_reflink": prev, "new_reflink": new}


def test_change_refs_assigns_role_from_field():
    prev_ref, new_ref = change_refs(change(field_name="discoverymethod", prev=ADS, new=ADS))
    assert prev_ref.role == new_ref.role == "discovery"


def test_description_cites_new_source_and_notes_switch():
    text = change_description(change(prev=KOI, new=ADS), "X b pl_bmasse: 1 → 2")
    assert text == (
        "X b pl_bmasse: 1 → 2. Source: Bonomo et al. 2023 "
        "(https://ui.adsabs.harvard.edu/abs/2023A&A...677A..33B/abstract). "
        "Previously: Q1-Q17 DR25 KOI Table"
    )


def test_description_same_source_has_no_previously():
    assert "Previously" not in change_description(change(prev=ADS, new=ADS), "s")


def test_description_removed_cites_discovery_paper():
    text = change_description(change("REMOVED", None, prev=ADS), "Removed planet: X b")
    assert text.startswith("Removed planet: X b. Discovery reference: Bonomo et al. 2023")


def test_description_without_reference_says_so():
    assert change_description(change(), "s") == "s. Source: none given by NASA Exoplanet Archive"


def test_format_calculated():
    assert format_reference(parse_reflink(CALC, "source")).startswith(
        "Source: Calculated by NASA Exoplanet Archive (https://"
    )
