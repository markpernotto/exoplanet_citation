// ADS / NASA Exoplanet Archive titles and abstracts arrive with HTML markup:
// entities like &amp; / &gt; / &aacute; and tags like <SUB>/<SUP> used for
// sub- and superscripts. Rendered as React text they show the raw markup
// ("rho<SUP>1</SUP> Cancri", "&gt;T10"), so convert to plain text before display.
// Browser-only (DOMParser); this app is a client-rendered SPA so that is fine.
export function plainText(s: string | null | undefined): string {
  if (!s) return '';
  // Fast path: nothing to decode or strip.
  if (!s.includes('&') && !s.includes('<')) return s;
  return new DOMParser().parseFromString(s, 'text/html').body.textContent ?? s;
}
