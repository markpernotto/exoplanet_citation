// Featured collections: curated, sourced groupings that surface the catalog's
// value-added data. Each sits on its natural entity (planets, systems,
// publications, or authors) so the set collectively tours the whole platform.
// `kind` drives the card: 'visual' uses a data-driven render at
// web/public/featured/<key>.jpg; 'typographic' has no image (papers/authors).
export type Collection = {
  key: string;
  label: string;
  tagline: string;   // short, for the filmstrip card
  blurb: string;     // sourced description, for the collection page
  kind: 'visual' | 'typographic';
  // The system actually pictured in <key>.jpg (chosen for the strongest render,
  // not necessarily the canonical example). Revealed as a banner caption on hover.
  imageCredit?: string;
};

export const COLLECTIONS: Collection[] = [
  {
    key: 'beyond-archive',
    label: 'Beyond the Archive',
    tagline: 'Characterizations beyond the catalog basics',
    kind: 'visual',
    imageCredit: 'KELT-9 b',
    blurb:
      'A curated tour of planets where published follow-up work records something the core ' +
      'parameter tables do not carry: a decaying orbit, an accretion rate, a terminator wind, ' +
      'a heavy-element budget. Every value links to its source paper and instrument. This is ' +
      'the showcase view; the full data lives under Characterized atmospheres and Interiors & ' +
      'composition.',
  },
  {
    key: 'circumbinary',
    label: 'Circumbinary planets',
    tagline: 'Worlds that orbit two stars at once',
    kind: 'visual',
    imageCredit: 'TOI-1338',
    blurb:
      'Planets on P-type orbits, circling both members of a stellar binary. Every ' +
      'cb_flag = 1 entry in the catalog was reviewed against its discovery and follow-up ' +
      'literature; inner-binary parameters (component masses, separation) and the source ' +
      'papers are recorded on each planet page. Classification follows the Doyle 2011 / ' +
      'Welsh 2012 P/S taxonomy.',
  },
  {
    key: 'architecture-3d',
    label: 'Measured 3D architecture',
    tagline: 'Systems with measured mutual inclinations',
    kind: 'visual',
    imageCredit: 'ups And',
    blurb:
      'Multi-planet systems where the angles between orbits have actually been measured ' +
      '(astrometry, transit-timing variations, or direct imaging) rather than assumed ' +
      'coplanar. The 3D scene tilts each orbit to the measured architecture, from the ' +
      'flat resonant chains to the strongly misaligned outer giants.',
  },
  {
    key: 'multi-planet',
    label: 'High-multiplicity systems',
    tagline: 'Six or more planets around one star',
    kind: 'visual',
    imageCredit: 'KOI-351',
    blurb:
      'Systems with six or more confirmed planets, the densely packed architectures (TRAPPIST-1, ' +
      'Kepler-90, HD 10180 and their kin) that constrain formation and dynamical-stability models. ' +
      'Counts follow the NASA Exoplanet Archive sy_pnum field; the 3D scene renders every sibling ' +
      'on its measured orbit.',
  },
  {
    key: 'triple-star',
    label: 'Triple-star systems',
    tagline: 'Planets with three or more suns',
    kind: 'visual',
    imageCredit: 'GJ 229',
    blurb:
      'Planets in systems of three or more stars (sy_snum >= 3), where the hierarchy of stellar ' +
      'orbits shapes where a planet can survive. Resolved stellar companions, with their separations ' +
      'and source catalogs, are recorded on each planet page.',
  },
  {
    key: 'atmospheres',
    label: 'Characterized atmospheres',
    tagline: 'Planets with detected molecules',
    kind: 'visual',
    imageCredit: 'HD 189733 b',
    blurb:
      'Planets with published atmospheric detections. Each molecule is recorded with the ' +
      'detecting instrument, the statistical significance, and the source paper, from the ' +
      'first exoplanet atmosphere (HD 209458 b) through the JWST era.',
  },
  {
    key: 'composition',
    label: 'Interiors & composition',
    tagline: 'Derived interiors, abundances, metal budgets',
    kind: 'visual',
    imageCredit: 'HR 8799',
    blurb:
      'Literature-derived scalar properties beyond the catalog basics: interior core mass ' +
      'fractions, atmospheric elemental abundances (C, O, S, N relative to solar), and heavy-' +
      'element mass budgets. Each value carries its asymmetric uncertainty, the modelling ' +
      'assumption it depends on, and the source paper. Interior fractions are degenerate with ' +
      'water content; abundances are reported relative to solar.',
  },
  {
    key: 'boundary',
    label: 'Planet / brown-dwarf boundary',
    tagline: 'Objects near the deuterium-burning limit',
    kind: 'visual',
    imageCredit: '2MASS J22501512+2325342 b',
    blurb:
      'Companions near the ~13 M_Jup deuterium-burning limit, where the planet-versus-brown-' +
      'dwarf distinction is genuinely ambiguous. A population-statistics question the catalog ' +
      'flags per object rather than deciding.',
  },
  {
    key: 'data-quality',
    label: 'Data-quality watchlist',
    tagline: 'Flags worth a second look',
    kind: 'visual',
    imageCredit: 'OGLE-2005-BLG-390L b',
    blurb:
      'Entries the catalog flags for a second look: likely cb_flag misclassifications, and ' +
      'wide-binary cross-references that appear to be line-of-sight optical doubles rather ' +
      'than bound companions. Surfaced for discussion with the upstream archives, not ' +
      'presented as corrections.',
  },
  {
    key: 'contested',
    label: 'Contested detections',
    tagline: 'Planets with a multi-paper history',
    kind: 'visual',
    imageCredit: 'HD 80606 b',
    blurb:
      'Planets whose status or parameters shifted across multiple papers: predicted then ' +
      'confirmed, revised, or still debated. The citation graph shows the discovery, ' +
      'follow-up, prior-detection, and characterization roles side by side.',
  },
  {
    key: 'eccentric',
    label: 'Weird orbits',
    tagline: 'Wildly elongated orbits',
    kind: 'visual',
    imageCredit: 'HD 20782 b',
    blurb:
      'Planets on strongly elongated orbits (eccentricity >= 0.5), where most systems are ' +
      'nearly circular. In the system view these draw as visibly stretched ellipses that sweep ' +
      'from a close periapsis out to a distant apoapsis. The showcase is HD 20782 b at ' +
      'eccentricity 0.95, the most elongated orbit in the confirmed catalog. (Non-coplanar, ' +
      'tilted architectures are covered separately under Measured 3D architecture.)',
  },
  {
    key: 'top-papers',
    label: 'Most-cited discovery papers',
    tagline: 'The literature behind the catalog',
    kind: 'visual',
    imageCredit: '51 Peg b',
    blurb:
      'The discovery literature behind the catalog, ranked by citation count, each paper ' +
      'linked to the planets it announced.',
  },
  {
    key: 'top-discoverers',
    label: 'Prolific discoverers',
    tagline: 'Who has found the most',
    kind: 'visual',
    imageCredit: 'PSR B1257+12 b',
    blurb:
      'The researchers who have co-authored the most confirmed-planet discoveries, drawn ' +
      'from the catalog citation graph.',
  },
];

export const COLLECTION_BY_KEY: Record<string, Collection> =
  Object.fromEntries(COLLECTIONS.map((c) => [c.key, c]));
