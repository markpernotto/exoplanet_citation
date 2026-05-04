# exoplanet_citation

A public data warehouse linking confirmed exoplanets to the scientific papers
that announced them. Built on the NASA Exoplanet Archive, with citation
resolution via Crossref, arXiv, and NASA ADS.

**Status:** scaffolding — see [PLAN.md](PLAN.md) for the implementation roadmap.

## What this is

- Nightly diff of the NASA Exoplanet Archive published as RSS + JSON
- Per-planet history of parameter changes
- Phase 2: a citation graph linking each planet to its discovery publication
  with provenance and confidence scoring

## Quickstart (developers)

```bash
# Python 3.12 required
/opt/homebrew/bin/python3.12 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Configure environment
cp .env.example .env
# edit .env with your Neon DATABASE_URL, R2 keys, ADS token

# Apply schema
psql "$DATABASE_URL" -f etl/schema.sql

# Run tests
pytest
```

## Documentation

- [PLAN.md](PLAN.md) — implementation source-of-truth
- [01-exoplanets.md](01-exoplanets.md) — portfolio framing
- `docs/ARCHITECTURE.md` — *(coming Day 5)*
- `docs/DATA_CATALOG.md` — *(coming Day 5)*
- `docs/CITATION_RESOLUTION.md` — *(coming Day 18)*

## Licenses

- Code: [MIT](LICENSE)
- Data products: [CC BY 4.0](LICENSE-DATA)
- Upstream attribution required per NASA Exoplanet Archive terms

## Contact

Mark Pernotto — mark@pernotto.com
