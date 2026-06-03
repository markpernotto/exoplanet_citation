-- planet_aliases: lookup table mapping alternate names to canonical
-- catalog names. Designed to handle the most common variations a
-- researcher might type into the site search:
--
--   * Greek letter prefixes in any form:
--       "β Pic" / "β Pictoris" / "beta Pic" / "Beta Pictoris" /
--       "bet Pic" / "Bet Pictoris" → bet Pic
--
--   * Both Unicode codepoints for epsilon (ε U+03B5 and ϵ U+03F5):
--       "ε Eri" / "ϵ Eri" / "eps Eri" / "Epsilon Eridani" → eps Eri
--
--   * Constellation genitive vs 3-letter (NASA EA convention):
--       "Pictoris" ↔ "Pic", "Eridani" ↔ "Eri", "Centauri" ↔ "Cen"
--
--   * Punctuation and whitespace variations:
--       "HD 39060" / "HD-39060" / "HD39060" / "hd 39060" → bet Pic
--
--   * Cross-identifier mappings (HD ↔ HIP ↔ Gaia DR3 ↔ Bayer
--     designation ↔ survey designation):
--       "HD 195689" → KELT-9, "Aldebaran" → alf Tau, etc.
--
-- The normalize_alias() function strips and folds an input string to a
-- single comparison key; the table stores the original alias text AND
-- a generated `normalized_alias` column computed via the same function,
-- so a search like "Beta Pictoris" or "β Pictoris" both look up via
-- normalized_alias = 'betpic'. Each row carries a `source` field so we
-- can distinguish curated aliases (from papers / catalog conventions)
-- from bulk SIMBAD/Vizier pulls done later.
--
-- NOT implemented yet (deferred to future migrations / ETL):
--   - The 21 alias-only audit hosts from the v0.1.3 Mugrauer 2019 work
--     (require a Q1 audit query to identify which hostnames are still
--     unlinked after migrations 077 + 084)
--   - Bulk SIMBAD identifier sweep for every host in the catalog
--     (better suited to an ETL script than a static migration)
--   - Boolean-operator search (AND/OR/NOT in search input): future
--     enhancement, mentioned in the v0.2 design discussion but not in
--     this migration's scope
--
-- Idempotent. Re-running is a no-op (function CREATE OR REPLACE, table
-- CREATE IF NOT EXISTS, seed INSERTs use ON CONFLICT DO NOTHING).

-- ─────────────────────────────────────────────────────────────────────
-- 1. normalize_alias() — fold an alias string to a comparison key
-- ─────────────────────────────────────────────────────────────────────
-- Steps applied, in order:
--   a. Lowercase
--   b. Unicode Greek letters → ASCII NASA-EA 3-letter form
--      (α→alf, β→bet, γ→gam, δ→del, ε ϵ→eps, ζ→zet, η→eta, θ ϑ→tet,
--       ι→iot, κ→kap, λ→lam, μ→mu,  ν→nu,  ξ→ksi, ο→omi, π→pi,
--       ρ→rho, σ ς→sig, τ→tau, υ→ups, φ ϕ→phi, χ→chi, ψ→psi, ω→ome)
--   c. English Greek names → 3-letter (alpha→alf, beta→bet, ...) with
--      \y word boundaries so we don't accidentally rewrite substrings
--      of unrelated words
--   d. Common constellation genitive forms → 3-letter abbreviation
--      (pictoris→pic, eridani→eri, centauri→cen, andromedae→and, ...)
--   e. Strip everything that isn't [a-z0-9]
-- IMMUTABLE so we can use it in a STORED generated column.

CREATE OR REPLACE FUNCTION normalize_alias(input text) RETURNS text AS $$
DECLARE
  s text;
BEGIN
  IF input IS NULL THEN RETURN NULL; END IF;
  s := lower(input);

  -- Unicode Greek letters → 3-letter NASA EA form
  s := regexp_replace(s, 'α',     'alf', 'g');
  s := regexp_replace(s, 'β',     'bet', 'g');
  s := regexp_replace(s, 'γ',     'gam', 'g');
  s := regexp_replace(s, 'δ',     'del', 'g');
  s := regexp_replace(s, '[εϵ]',  'eps', 'g');
  s := regexp_replace(s, 'ζ',     'zet', 'g');
  s := regexp_replace(s, 'η',     'eta', 'g');
  s := regexp_replace(s, '[θϑ]',  'tet', 'g');
  s := regexp_replace(s, 'ι',     'iot', 'g');
  s := regexp_replace(s, 'κ',     'kap', 'g');
  s := regexp_replace(s, 'λ',     'lam', 'g');
  s := regexp_replace(s, 'μ',     'mu',  'g');
  s := regexp_replace(s, 'ν',     'nu',  'g');
  s := regexp_replace(s, 'ξ',     'ksi', 'g');
  s := regexp_replace(s, 'ο',     'omi', 'g');
  s := regexp_replace(s, 'π',     'pi',  'g');
  s := regexp_replace(s, 'ρ',     'rho', 'g');
  s := regexp_replace(s, '[σς]',  'sig', 'g');
  s := regexp_replace(s, 'τ',     'tau', 'g');
  s := regexp_replace(s, 'υ',     'ups', 'g');
  s := regexp_replace(s, '[φϕ]',  'phi', 'g');
  s := regexp_replace(s, 'χ',     'chi', 'g');
  s := regexp_replace(s, 'ψ',     'psi', 'g');
  s := regexp_replace(s, 'ω',     'ome', 'g');

  -- English Greek-letter names → 3-letter NASA EA form. Word
  -- boundaries \y match either side so substrings of unrelated words
  -- ("aldebaran" doesn't contain a real "beta" prefix anyway, but the
  -- discipline matters elsewhere). Longest forms first.
  s := regexp_replace(s, '\yomicron\y', 'omi', 'g');
  s := regexp_replace(s, '\yepsilon\y', 'eps', 'g');
  s := regexp_replace(s, '\yupsilon\y', 'ups', 'g');
  s := regexp_replace(s, '\ylambda\y',  'lam', 'g');
  s := regexp_replace(s, '\ysigma\y',   'sig', 'g');
  s := regexp_replace(s, '\yomega\y',   'ome', 'g');
  s := regexp_replace(s, '\yalpha\y',   'alf', 'g');
  s := regexp_replace(s, '\ygamma\y',   'gam', 'g');
  s := regexp_replace(s, '\ydelta\y',   'del', 'g');
  s := regexp_replace(s, '\ytheta\y',   'tet', 'g');
  s := regexp_replace(s, '\ykappa\y',   'kap', 'g');
  s := regexp_replace(s, '\yiota\y',    'iot', 'g');
  s := regexp_replace(s, '\ybeta\y',    'bet', 'g');
  s := regexp_replace(s, '\yzeta\y',    'zet', 'g');
  -- (eta, phi, chi, psi, tau, rho, pi, mu, nu already 3 letters; no
  -- "epi"/"omi" etc shorthand handled because "epi" isn't unique to
  -- epsilon — search input "ε" or "epsilon" or "eps" covers it)

  -- IAU constellation genitive forms → 3-letter abbreviation. Only
  -- the constellations that appear (or could appear) in catalog
  -- hostnames our seed touches are listed. Adding more is cheap.
  s := regexp_replace(s, '\ypictoris\y',          'pic', 'g');
  s := regexp_replace(s, '\yeridani\y',           'eri', 'g');
  s := regexp_replace(s, '\ycentauri\y',          'cen', 'g');
  s := regexp_replace(s, '\yandromedae\y',        'and', 'g');
  s := regexp_replace(s, '\ytauri\y',             'tau', 'g');
  s := regexp_replace(s, '\ycancri\y',            'cnc', 'g');
  s := regexp_replace(s, '\ycygni\y',             'cyg', 'g');
  s := regexp_replace(s, '\ydraconis\y',          'dra', 'g');
  s := regexp_replace(s, '\ydoradus\y',           'dor', 'g');
  s := regexp_replace(s, '\yhydrae\y',            'hya', 'g');
  s := regexp_replace(s, '\yleonis\y',            'leo', 'g');
  s := regexp_replace(s, '\ylyrae\y',             'lyr', 'g');
  s := regexp_replace(s, '\yorionis\y',           'ori', 'g');
  s := regexp_replace(s, '\ypegasi\y',            'peg', 'g');
  s := regexp_replace(s, '\ypersei\y',            'per', 'g');
  s := regexp_replace(s, '\yreticuli\y',          'ret', 'g');
  s := regexp_replace(s, '\ysagittarii\y',        'sgr', 'g');
  s := regexp_replace(s, '\yscorpii\y',           'sco', 'g');
  s := regexp_replace(s, '\yserpentis\y',         'ser', 'g');
  s := regexp_replace(s, '\ytrianguli\y',         'tri', 'g');
  s := regexp_replace(s, '\ytucanae\y',           'tuc', 'g');
  s := regexp_replace(s, '\yursaemajoris\y',      'uma', 'g');
  s := regexp_replace(s, '\yursaeminoris\y',      'umi', 'g');
  s := regexp_replace(s, '\yursae majoris\y',     'uma', 'g');
  s := regexp_replace(s, '\yursae minoris\y',     'umi', 'g');
  s := regexp_replace(s, '\yvirginis\y',          'vir', 'g');
  s := regexp_replace(s, '\yherculis\y',          'her', 'g');
  s := regexp_replace(s, '\ygeminorum\y',         'gem', 'g');
  s := regexp_replace(s, '\yaquilae\y',           'aql', 'g');
  s := regexp_replace(s, '\yaquarii\y',           'aqr', 'g');
  s := regexp_replace(s, '\ycarinae\y',           'car', 'g');
  s := regexp_replace(s, '\ycassiopeiae\y',       'cas', 'g');
  s := regexp_replace(s, '\yceti\y',              'cet', 'g');
  s := regexp_replace(s, '\ycoronaeaustralis\y',  'cra', 'g');
  s := regexp_replace(s, '\ycoronaeborealis\y',   'crb', 'g');
  s := regexp_replace(s, '\yindi\y',              'ind', 'g');
  s := regexp_replace(s, '\ylacertae\y',          'lac', 'g');
  s := regexp_replace(s, '\ylibrae\y',            'lib', 'g');
  s := regexp_replace(s, '\ymonocerotis\y',       'mon', 'g');
  s := regexp_replace(s, '\yophiuchi\y',          'oph', 'g');
  s := regexp_replace(s, '\ypavonis\y',           'pav', 'g');
  s := regexp_replace(s, '\ypiscium\y',           'psc', 'g');
  s := regexp_replace(s, '\ypiscisaustrini\y',    'psa', 'g');
  s := regexp_replace(s, '\yvelorum\y',           'vel', 'g');
  s := regexp_replace(s, '\yvirginis\y',          'vir', 'g');

  -- Strip everything that isn't a-z0-9 (spaces, hyphens, periods,
  -- apostrophes, anything else). After this step "Beta Pictoris" and
  -- "β Pictoris" and "Bet Pic" and "Beta-Pictoris" all reduce to the
  -- same string.
  s := regexp_replace(s, '[^a-z0-9]', '', 'g');

  RETURN s;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ─────────────────────────────────────────────────────────────────────
-- 2. planet_aliases table
-- ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS planet_aliases (
  alias               TEXT NOT NULL,
  alias_kind          TEXT NOT NULL CHECK (alias_kind IN ('planet', 'host')),
  canonical_name      TEXT NOT NULL,
  -- Generated normalized form. STORED so the index works.
  normalized_alias    TEXT GENERATED ALWAYS AS (normalize_alias(alias)) STORED,
  source              TEXT NOT NULL CHECK (source IN ('manual', 'paper', 'catalog_history', 'simbad', 'transliteration')),
  source_bibcode      TEXT,
  note                TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (alias, alias_kind)
);

-- Lookup: given a normalized search query, find the canonical name.
-- Per (normalized_alias, alias_kind) — same normalized form could in
-- principle point to two different canonicals via different alias rows;
-- the application surfaces both if so.
CREATE INDEX IF NOT EXISTS idx_planet_aliases_normalized
  ON planet_aliases (normalized_alias, alias_kind);

-- Reverse lookup: given a canonical name, get its aliases.
CREATE INDEX IF NOT EXISTS idx_planet_aliases_canonical
  ON planet_aliases (canonical_name, alias_kind);

COMMENT ON TABLE planet_aliases IS
  'Alternate names for hosts and planets. Search input is folded via '
  'normalize_alias() and compared against the generated normalized_alias '
  'column. See migration 092 header for design rationale.';

-- ─────────────────────────────────────────────────────────────────────
-- 3. Initial curated seed
-- ─────────────────────────────────────────────────────────────────────
-- Three groups of aliases:
--   A) Catalog-history renames from migration 084 (preserve BOTH
--      directions so a user can search by either form)
--   B) Greek-letter + constellation-genitive variants for systems we
--      actively render (debris-disk + albedo + atmospheric-escape +
--      circumplanetary-disk hosts)
--   C) Common cross-identifier mappings (HD ↔ Bayer ↔ proper name)
--      for the most-searched targets

INSERT INTO planet_aliases (alias, alias_kind, canonical_name, source, note) VALUES

-- A) Migration 084's 9 hostname renames (Mugrauer 2019 → NASA EA forms)
('HAT-P-10',     'host', 'WASP-11',    'catalog_history', 'Same star, two surveys / two discovery papers; catalog uses WASP-11'),
('Kepler-13',    'host', 'KOI-13',     'catalog_history', 'Catalog uses KOI- form for this object'),
('Kepler-89',    'host', 'KOI-94',     'catalog_history', 'Catalog uses KOI- form'),
('HD 132563 B',  'host', 'HD 132563',  'catalog_history', 'Catalog drops the B subscript'),
('HD 195689',    'host', 'KELT-9',     'catalog_history', 'HD 195689 = KELT-9; catalog uses survey name'),
('Pr 0211',      'host', 'Pr0211',     'catalog_history', 'Catalog has no internal space'),
('Qatar 6',      'host', 'Qatar-6',    'catalog_history', 'Catalog uses hyphen'),
('WASP-87 A',    'host', 'WASP-87',    'catalog_history', 'Catalog drops the A suffix'),
('Aldebaran',    'host', 'alf Tau',    'catalog_history', 'Proper name; catalog uses Bayer designation'),

-- B) Greek-letter variants for our actively-rendered debris-disk systems.
-- normalize_alias() handles most of the punctuation/case/Greek folding,
-- so these aliases capture the spellings users are likely to TYPE (and
-- which would otherwise show up in URL bars, papers, etc.).

-- bet Pic ↔ β Pic ↔ Beta Pictoris (host)
('β Pic',          'host', 'bet Pic',  'manual', 'Greek uppercase prefix'),
('β Pictoris',     'host', 'bet Pic',  'manual', 'Greek + genitive constellation'),
('Beta Pic',       'host', 'bet Pic',  'transliteration', 'English Greek name'),
('Beta Pictoris',  'host', 'bet Pic',  'transliteration', 'English Greek + genitive constellation'),
('HD 39060',       'host', 'bet Pic',  'simbad', 'Henry Draper catalog'),
('HIP 27321',      'host', 'bet Pic',  'simbad', 'Hipparcos catalog'),

-- bet Pic b / c (planets)
('β Pic b',         'planet', 'bet Pic b', 'manual', 'Greek prefix'),
('β Pictoris b',    'planet', 'bet Pic b', 'manual', 'Greek + full constellation'),
('Beta Pic b',      'planet', 'bet Pic b', 'transliteration', 'English Greek'),
('Beta Pictoris b', 'planet', 'bet Pic b', 'transliteration', 'English Greek + full constellation'),
('β Pic c',         'planet', 'bet Pic c', 'manual', 'Greek prefix'),
('β Pictoris c',    'planet', 'bet Pic c', 'manual', 'Greek + full constellation'),
('Beta Pic c',      'planet', 'bet Pic c', 'transliteration', 'English Greek'),
('Beta Pictoris c', 'planet', 'bet Pic c', 'transliteration', 'English Greek + full constellation'),

-- eps Eri (both Unicode codepoints for epsilon!)
('ε Eri',          'host', 'eps Eri',  'manual', 'Greek lowercase epsilon (U+03B5)'),
('ϵ Eri',          'host', 'eps Eri',  'manual', 'Greek lunate epsilon (U+03F5)'),
('ε Eridani',      'host', 'eps Eri',  'manual', 'Greek + full constellation'),
('ϵ Eridani',      'host', 'eps Eri',  'manual', 'Greek lunate + full constellation'),
('Epsilon Eri',    'host', 'eps Eri',  'transliteration', 'English Greek'),
('Epsilon Eridani','host', 'eps Eri',  'transliteration', 'English Greek + full constellation'),
('Eps Eri',        'host', 'eps Eri',  'transliteration', 'NASA EA short form, alternate spacing'),
('HD 22049',       'host', 'eps Eri',  'simbad', 'Henry Draper catalog'),
('HIP 16537',      'host', 'eps Eri',  'simbad', 'Hipparcos catalog'),
('Ran',            'host', 'eps Eri',  'manual', 'IAU 2018 approved proper name (Norse god Rán)'),

-- eps Eri b (planet)
('ε Eri b',          'planet', 'eps Eri b', 'manual', 'Greek prefix'),
('ϵ Eri b',          'planet', 'eps Eri b', 'manual', 'Greek lunate'),
('Epsilon Eri b',    'planet', 'eps Eri b', 'transliteration', 'English Greek'),
('Epsilon Eridani b','planet', 'eps Eri b', 'transliteration', 'English Greek + full constellation'),
('AEgir',            'planet', 'eps Eri b', 'manual', 'IAU 2018 approved proper name (Norse god Ægir)'),
('Aegir',            'planet', 'eps Eri b', 'manual', 'IAU 2018 proper name, ASCII spelling'),

-- 51 Eri (host + planet)
('51 Eridani',  'host',   '51 Eri',   'manual', 'Full constellation genitive'),
('HD 29391',    'host',   '51 Eri',   'simbad', 'Henry Draper catalog'),
('HIP 21547',   'host',   '51 Eri',   'simbad', 'Hipparcos catalog'),
('51 Eridani b','planet', '51 Eri b', 'manual', 'Full constellation genitive'),

-- HR 8799 (host + planets b/c/d/e)
('HD 218396',   'host',   'HR 8799',   'simbad', 'Henry Draper catalog'),
('HIP 114189',  'host',   'HR 8799',   'simbad', 'Hipparcos catalog'),
('V342 Peg',    'host',   'HR 8799',   'simbad', 'Variable-star designation, Pegasus'),

-- HD 95086 (host + planet b)
('HIP 53524',   'host',   'HD 95086',  'simbad', 'Hipparcos catalog'),

-- PDS 70 (host + planets b/c)
('IRAS 14050-4109','host', 'PDS 70',   'simbad', 'IRAS catalog (Picture-of-Disk-System)'),
('V1032 Cen',      'host', 'PDS 70',   'simbad', 'Variable-star designation, Centaurus'),

-- KELT-9 (cross-references to migration 084's pair)
('HD 195689 b', 'planet', 'KELT-9 b', 'catalog_history', 'HD 195689 = KELT-9; catalog uses survey name'),

-- C) A few famous cross-identifier mappings for common searches.
('Vega',         'host', 'alf Lyr',  'manual', 'IAU approved proper name; Bayer alpha Lyrae'),
('alpha Lyr',    'host', 'alf Lyr',  'transliteration', 'English Greek'),
('alpha Lyrae',  'host', 'alf Lyr',  'transliteration', 'English Greek + full constellation'),
('Procyon',      'host', 'alf CMi',  'manual', 'IAU approved proper name; Bayer alpha Canis Minoris'),
('Fomalhaut',    'host', 'alf PsA',  'manual', 'IAU approved proper name; Bayer alpha Piscis Austrini'),
('Pollux',       'host', 'bet Gem',  'manual', 'IAU approved proper name; Bayer beta Geminorum'),
('Arcturus',     'host', 'alf Boo',  'manual', 'IAU approved proper name; Bayer alpha Bootis'),
('alpha Tau',    'host', 'alf Tau',  'transliteration', 'English Greek'),
('alpha Tauri',  'host', 'alf Tau',  'transliteration', 'English Greek + full constellation'),
('Proxima',      'host', 'Proxima Cen', 'manual', 'Shortest common name for Proxima Centauri'),
('Proxima Centauri', 'host', 'Proxima Cen', 'manual', 'Full name'),
('alpha Centauri C', 'host', 'Proxima Cen', 'manual', 'Bayer designation as the C component of alpha Cen'),
('51 Pegasi',    'host', '51 Peg',   'manual', 'Full constellation genitive'),
('51 Pegasi b',  'planet', '51 Peg b', 'manual', 'Full constellation genitive'),
('Helvetios',    'host', '51 Peg',   'manual', 'IAU 2015 approved proper name'),
('Dimidium',     'planet', '51 Peg b', 'manual', 'IAU 2015 approved proper name'),
('55 Cancri',    'host', '55 Cnc',   'manual', 'Full constellation genitive'),
('Copernicus',   'planet', '55 Cnc b', 'manual', 'IAU 2015 approved proper name'),
('Janssen',      'planet', '55 Cnc e', 'manual', 'IAU 2015 approved proper name (lava world)'),
('rho1 Cnc',     'host', '55 Cnc',   'simbad', 'Bayer designation'),
('rho 1 Cnc',    'host', '55 Cnc',   'simbad', 'Bayer designation, alternate spacing'),
('HD 75732',     'host', '55 Cnc',   'simbad', 'Henry Draper catalog')

ON CONFLICT (alias, alias_kind) DO NOTHING;
