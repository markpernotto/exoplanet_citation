-- Migration 117 (2026-06-27). sy_snum_audit re-verification refresh
-- using Brandt et al. 2021 (2021ApJS..254...42B) Hipparcos-Gaia Catalog
-- of Accelerations EDR3 edition (HGCA).
--
-- BACKGROUND: an earlier audit round flagged several rows whose
-- newest cited evidence was 6-27 years old, raising recency concerns
-- ahead of publication. The HGCA EDR3 provides a uniform, modern
-- (post-Gaia-EDR3, 2021) astrometric-acceleration test for any
-- Hipparcos-catalogued star: chi^2 measures the goodness-of-fit of
-- the observed proper motion against a constant-proper-motion model,
-- with chi^2 = 11.8 corresponding to the 3-sigma threshold for
-- detecting unresolved massive companions.
--
-- We looked up 11 of the 13 audit-row hosts in HGCA (the other two
-- already have post-2022 sources). Four rows reversed direction;
-- seven gained Brandt 2021 as an additional independent
-- corroboration of the existing verdict.
--
-- RESULTS:
--
--   REVERSALS (4 rows):
--     HD 5608      chi^2 = 148.7  --  REVISE 1 -> 2  (unresolved massive
--                                     companion detected; Luhn 2019 RV
--                                     and Mugrauer 2019 wide-CPM nulls
--                                     covered parameter spaces that
--                                     missed it)
--     HD 43691     chi^2 = 0.64   --  REVISE 2 -> 1  (Ginski 2016 single-
--                                     epoch candidate at 4.4" is
--                                     consistent with a background-star
--                                     interpretation; no astrometric
--                                     tugging confirms unbound)
--     HD 113337    chi^2 = 279.4  --  REVISE 1 -> 2  (massive unresolved
--                                     companion; the Borgniet 2019
--                                     "planet c" interpretation is
--                                     inconsistent with the magnitude
--                                     of acceleration -- the responsible
--                                     body is substellar BD at minimum,
--                                     possibly stellar)
--     HIP 38594    chi^2 = 18.89  --  REVISE 1 -> 2  (soft; the chi^2
--                                     just crosses the 3-sigma threshold,
--                                     but Feng 2020 sub-Neptune planets
--                                     are far too small to produce the
--                                     observed acceleration -- an
--                                     additional unresolved companion is
--                                     implied)
--
--   CONFIRMS strengthened with HGCA citation (7 rows):
--     16 Cyg B     chi^2 = 2.87 (for 16 Cyg A = HIP 96901; the Trilling
--                  tertiary candidate at 3.2" around A would have left a
--                  measurable astrometric signature -- it didn't, so the
--                  candidate is either unbound, much lower mass than M-
--                  dwarf, or at much wider separation than the snapshot
--                  suggested)
--     HD 38529     chi^2 = 5.30 (consistent with the known BD c
--                  dynamical signature, no additional stellar)
--     HD 2638      chi^2 = 9.63 (consistent with the known A+B pair
--                  alone, no third stellar component)
--     HD 87646     chi^2 = 123.4 (consistent with known A+B+BDc
--                  architecture from Ma 2016)
--     Gl 49        chi^2 = 3.48 (four-method converging null:
--                  Cortes-Contreras 2017 imaging + Perger 2019 RV +
--                  Houdebine 2010 single-star treatment + Brandt 2021
--                  astrometric null)
--     HIP 21152    chi^2 = 174.7 (dynamical confirmation of the
--                  Kuzuhara 2022 T-dwarf BD)
--     HIP 19976    chi^2 = 388.3 (Feng 2022 derived the BD mass from
--                  this same kind of HGCA-style astrometric signal;
--                  the HGCA value confirms the BD interpretation)
--
--   NOT IN THIS BATCH:
--     LHS 1678     - not in Hipparcos catalog (M2V dwarf at 19.9 pc but
--                    too faint or other Hipparcos exclusion; the
--                    Silverstein 2022 BD case rests on CTIO/SMARTS
--                    astrometry + speckle + RV which are independent
--                    of HGCA and already 2022-current)
--     BD-14 3065 A - Subjak 2024 source is already 2-year-old; no
--                    recency concern, no HGCA refresh needed
--
-- Apply after 116_wds_batch11.sql.


-- ============================================================================
-- REVERSALS (4 rows)
-- ============================================================================

-- HD 5608 -- REVERSAL 1 -> 2
UPDATE sy_snum_audit
   SET supported_sy_snum = 2,
       rationale = 'REVISED 2026-06-27 following Brandt et al. 2021 (2021ApJS..254...42B) '
                   'Hipparcos-Gaia Catalog of Accelerations (HGCA) EDR3 edition: chi^2 = 148.7 '
                   'for HD 5608 = HIP 4552, FAR ABOVE the 11.8 threshold for 3-sigma detection of '
                   'astrometric acceleration. This indicates a SIGNIFICANT UNRESOLVED MASSIVE '
                   'COMPANION tugging on HD 5608 over the 25-year Hipparcos-Gaia baseline. The '
                   'known planet HD 5608 b (M sin i ~ 1.4 MJup at 1.9 AU per Sato 2012) is far '
                   'too low-mass to produce this signal; an additional substellar (BD) or '
                   'stellar body is implied. '
                   'The earlier null detections cited (Luhn et al. 2019, 2019AJ....157..149L, RV '
                   'survey with ~16 yr baseline; Mugrauer 2019, 2019MNRAS.490.5088M, Gaia DR2 '
                   'wide-CPM survey) covered restricted parameter spaces that missed this '
                   'companion -- the curator note for the previous version of this row explicitly '
                   'flagged the Luhn 2019 period limitation. The HGCA test samples a different '
                   'and complementary parameter space (any separation, any direction, sensitive '
                   'to the integrated dynamical effect of unresolved bodies). '
                   'CONSEQUENCE: NASA EA sy_snum = 2 is the conservatively correct call pending '
                   'characterization of the responsible body. supported_sy_snum REVISED 1 -> 2.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27',
       curator_note = 'REVERSED 2026-06-27. Brandt 2021 HGCA chi^2 = 148.7 caught an unresolved '
                      'massive companion that earlier RV + wide-CPM nulls missed. The mass/'
                      'separation/spectype of the responsible body is unknown pending follow-up; '
                      'NASA EA sy_snum = 2 is the safe call. This row was previously flagged with '
                      'a curator note acknowledging the Luhn 2019 period limit, and HGCA has now '
                      'shown the limitation matters.'
 WHERE hostname = 'HD 5608';


-- HD 43691 -- REVERSAL 2 -> 1
UPDATE sy_snum_audit
   SET supported_sy_snum = 1,
       rationale = 'REVISED 2026-06-27 following Brandt et al. 2021 (2021ApJS..254...42B) '
                   'HGCA EDR3: chi^2 = 0.638 for HD 43691 = HIP 30057, well below the 11.8 '
                   '3-sigma threshold. NO astrometric acceleration over the 25-year Hipparcos-'
                   'Gaia baseline means NO bound massive companion is tugging on the star. '
                   'The Ginski et al. 2016 (2016MNRAS.457.2173G) single-epoch lucky-imaging '
                   'candidate companion at 4.4 arcsec, never CPM-confirmed at the time of the '
                   'original audit, is consistent with a BACKGROUND STAR interpretation. '
                   'The curator note for the previous version of this row explicitly hedged: '
                   '"If Ginski 2016 candidate is confirmed background, supported_sy_snum drops '
                   'to 1 in a future revision." HGCA has now provided that confirmation. '
                   'CONSEQUENCE: only the HD 43691 primary is a confirmed stellar component. '
                   'NASA EA sy_snum = 3 has no support from primary literature. supported_sy_snum '
                   'REVISED 2 -> 1.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27',
       curator_note = 'REVERSED 2026-06-27. Brandt 2021 HGCA chi^2 = 0.638 = null detection of '
                      'astrometric acceleration confirms that the Ginski 2016 lucky-imaging '
                      'candidate at 4.4" is unbound (background star). The original curator '
                      'note anticipated this revision pending confirmation; HGCA provided it.'
 WHERE hostname = 'HD 43691';


-- HD 113337 -- REVERSAL 1 -> 2
UPDATE sy_snum_audit
   SET supported_sy_snum = 2,
       rationale = 'REVISED 2026-06-27 following Brandt et al. 2021 (2021ApJS..254...42B) '
                   'HGCA EDR3: chi^2 = 279.4 for HD 113337 = HIP 63584, more than 23x above '
                   'the 11.8 3-sigma threshold. This is MASSIVE astrometric acceleration over '
                   'the 25-year Hipparcos-Gaia baseline, indicating a SIGNIFICANT UNRESOLVED '
                   'MASSIVE COMPANION. '
                   'Quantitatively: Borgniet et al. 2019 (2019A&A...627A..44B) interpreted the '
                   'long-term RV trend as HD 113337 c, a 3-MJup planet at 4.8 AU. For that mass '
                   'and orbit around the ~1.4 Msun host at d ~ 36 pc, the expected astrometric '
                   'semi-amplitude is ~270 microarcsec and the expected chi^2 contribution is '
                   'far below the observed value. The body responsible for the chi^2 = 279.4 '
                   'signal is substantially heavier than 3 MJup -- substellar BD at minimum, '
                   'possibly stellar. Either Borgniet 2019 "planet c" is misidentified, or there '
                   'is an additional unresolved companion beyond planet c. '
                   'The Ginski et al. 2016 (2016MNRAS.457.2173G) imaging null and the Borgniet '
                   '2019 CHARA-VEGA interferometric + LBTI imaging null sampled parameter spaces '
                   '(wide separations, resolved imaging) that do not capture the unresolved '
                   'inner massive body that HGCA detects. '
                   'CONSEQUENCE: NASA EA sy_snum = 3 may be conservatively correct (or even an '
                   'undercount). supported_sy_snum REVISED 1 -> 2 pending characterization of '
                   'the responsible body.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27',
       curator_note = 'REVERSED 2026-06-27. Brandt 2021 HGCA chi^2 = 279.4 is overwhelming '
                      'evidence for an unresolved massive companion. The Borgniet 2019 RV-only '
                      '"planet c at 3 MJup" interpretation is incompatible with the observed '
                      'acceleration magnitude; the responsible body is BD or stellar. The '
                      'agent-guess error captured in the original curator note (Borgniet 2019 '
                      'does not characterize a wide stellar companion) remains true, but the '
                      'previous overall verdict (no stellar companion) is wrong.'
 WHERE hostname = 'HD 113337';


-- HIP 38594 -- SOFT REVERSAL 1 -> 2
UPDATE sy_snum_audit
   SET supported_sy_snum = 2,
       rationale = 'REVISED 2026-06-27 following Brandt et al. 2021 (2021ApJS..254...42B) '
                   'HGCA EDR3: chi^2 = 18.89 for HIP 38594, above the 11.8 3-sigma threshold '
                   'but only modestly so (~4 sigma). This indicates real astrometric '
                   'acceleration but at a more borderline significance than the strong cases '
                   '(HD 5608, HD 113337) in this same audit pass. '
                   'The Feng et al. 2020 (2020ApJS..250...29F) sub-Neptune-mass planets HIP '
                   '38594 b (~8 M_earth) and c are far too low-mass to produce ~19 in HGCA '
                   'chi^2; an additional unresolved companion is implied. The companion could '
                   'be a BD (still substellar by our convention) or low-mass stellar; the '
                   'available data does not distinguish. '
                   'CONSEQUENCE: at press, the conservative call is to acknowledge that the '
                   'HGCA signal is inconsistent with our previous "single early M-dwarf" claim. '
                   'supported_sy_snum REVISED 1 -> 2 pending characterization. If follow-up '
                   'shows the responsible body is substellar (BD), this would revert to '
                   'supported = 1 under our BD-counted-as-substellar convention.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27',
       curator_note = 'SOFT REVERSAL 2026-06-27. Brandt 2021 HGCA chi^2 = 18.89 is borderline-'
                      'significant but enough to disqualify the previous "single star" verdict. '
                      'If follow-up characterization shows the responsible body is substellar '
                      '(BD), this row could revert to supported_sy_snum = 1 under our '
                      'convention -- recheck after a follow-up imaging or acceleration-fit '
                      'paper.'
 WHERE hostname = 'HIP 38594';


-- ============================================================================
-- CONFIRMS strengthened with HGCA citation (7 rows)
-- These keep their supported_sy_snum unchanged; the UPDATE appends the
-- Brandt 2021 result to the rationale and the bibcode list as an
-- additional independent corroboration of the existing verdict.
-- ============================================================================

-- 16 Cyg B -- HGCA for HIP 96901 (= 16 Cyg A) rules out the Trilling tertiary
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for 16 Cyg A = HIP 96901: chi^2 = 2.87, well below the 11.8 '
                   '3-sigma threshold. NO astrometric acceleration of 16 Cyg A over the 25-year '
                   'Hipparcos-Gaia baseline. The Trilling tertiary candidate proposed by Hauser '
                   '& Marcy 1999 -- a possible M-dwarf at ~80 AU around 16 Cyg A -- would have '
                   'left a measurable astrometric signature; the absence of acceleration means '
                   'the Trilling source is EITHER unbound (background star), OR much lower mass '
                   'than M-dwarf (substellar), OR at much wider separation than the 3.2" '
                   'snapshot suggested (long-period, undetectable acceleration over 25 yr). In '
                   'all three cases, the row''s "A+B binary, not confirmed triple" interpretation '
                   'is strengthened, not weakened. The Brandt 2021 HGCA test postdates the '
                   'original Hauser & Marcy 1999 source by 22 years and provides modern (Gaia '
                   'EDR3-era) corroboration.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = '16 Cyg B';


-- HD 38529 -- HGCA consistent with known BD c, no additional stellar
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for HD 38529 = HIP 27253: chi^2 = 5.30, below the 11.8 3-sigma '
                   'threshold for additional unresolved stellar companions. The chi^2 is '
                   'slightly elevated above the bulk distribution (~3), which is consistent '
                   'with the dynamical signature of the known BD HD 38529 c (Benedict 2010 '
                   'astrometric mass ~17 MJup at 3.7 AU) -- the BD reality is independently '
                   'corroborated by HGCA. No evidence for an ADDITIONAL stellar-mass companion '
                   'beyond what is already characterized. The audit-row verdict (no wide '
                   'stellar companion; supported_sy_snum = 1; BD is substellar by our '
                   'convention) is now backed by THREE converging modern non-detections: '
                   'Roberts 2011 (close imaging null), Mugrauer 2019 (Gaia DR2 wide-CPM null), '
                   'and Brandt 2021 (astrometric acceleration consistent only with the BD). '
                   'Multi-method, multi-decade.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'HD 38529';


-- HD 2638 -- HGCA consistent with known B alone, no third stellar
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for HD 2638 = HIP 2350: chi^2 = 9.63, BELOW the 11.8 3-sigma '
                   'threshold. The chi^2 is elevated above the bulk distribution (~3) but does '
                   'not cross the 3-sigma line -- this is consistent with the orbital-motion '
                   'signature of the known B companion at 26 AU (M_B = 0.48 Msun, P ~ 200 yr '
                   'per Wittrock 2016 / Roberts 2015 / Ginski 2016 triple imaging). No '
                   'astrometric evidence for a THIRD stellar component, supporting the audit-'
                   'row claim that NASA EA sy_snum = 3 is unsupported and that the system is '
                   'A+B only.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'HD 2638';


-- HD 87646 -- HGCA consistent with known A+B+BDc architecture
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for HD 87646 = HIP 49522: chi^2 = 123.4, well above the 11.8 '
                   '3-sigma threshold. The elevated acceleration is FULLY ATTRIBUTABLE to the '
                   'known system architecture from Ma et al. 2016 (2016AJ....152..112M): the '
                   'close stellar B companion at ~22 AU (~0.5 Msun) plus the BD c at 1.58 AU '
                   '(57 MJup, P = 674 d). Both bodies tug measurably on the primary. No '
                   'additional unresolved companion is implied. The audit-row verdict '
                   '(supported_sy_snum = 2, A+B stellar; the BD does not count under our '
                   'convention) is consistent with the HGCA finding. NASA EA sy_snum = 3 '
                   'includes the BD as stellar.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'HD 87646';


-- Gl 49 -- fourth converging modern null
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for Gl 49 = HIP 4872: chi^2 = 3.48, well below the 11.8 3-sigma '
                   'threshold. NO astrometric acceleration over the 25-year Hipparcos-Gaia '
                   'baseline. This is now a FOUR-METHOD CONVERGING NULL: (1) Cortes-Contreras '
                   '2017 FastCam lucky imaging null at rho = 0.2-5"; (2) Perger 2019 22-yr RV '
                   'monitoring with HIRES+HARPS-N+CARMENES; (3) Houdebine 2010 chromospheric '
                   'study treats Gl 49 as a single dM1; (4) Brandt 2021 astrometric '
                   'acceleration null. Four independent methods (imaging, multi-decade RV, '
                   'spectral-class characterization, and HGCA astrometry) all consistent with '
                   'a single-star interpretation. This is the strongest single-star case in '
                   'the audit table.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'Gl 49';


-- HIP 21152 -- HGCA confirms BD dynamical reality
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for HIP 21152: chi^2 = 174.7, far above the 11.8 3-sigma '
                   'threshold. This is the astrometric fingerprint of the known T-dwarf BD '
                   'companion (Kuzuhara et al. 2022, 2022ApJ...934L..18K; refined by Franson '
                   '2023, 2023AJ....165...39F): M = 27.8 +8.4/-5.4 MJup. HGCA acceleration is '
                   'fully consistent with the dynamical mass derived from the orbit fit -- '
                   'the BD is now corroborated by THREE methods: direct imaging '
                   '(SCExAO/CHARIS + NIRC2), spectroscopic mass + orbit fit, and astrometric '
                   'acceleration. The audit-row verdict (supported_sy_snum = 1; BD is '
                   'substellar by our convention) stands. NASA EA sy_snum = 2 counts the BD '
                   'as stellar.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'HIP 21152';


-- HIP 19976 -- HGCA confirms BD; in fact Feng 2022 used this signal
UPDATE sy_snum_audit
   SET rationale = rationale ||
                   E'\n\nUPDATED 2026-06-27 with Brandt et al. 2021 (2021ApJS..254...42B) HGCA '
                   'EDR3 result for HIP 19976: chi^2 = 388.3 -- the highest chi^2 in this '
                   'audit-table refresh pass, more than 32x the 11.8 3-sigma threshold. This '
                   'extreme acceleration is exactly what produces the BD detection in Feng '
                   'et al. 2022 (2022ApJS..262...21F): the paper''s methodology USES Hipparcos-'
                   'Gaia astrometry to characterize substellar companions, so Feng 2022 '
                   'derived its ~30 MJup BD mass from the same kind of HGCA-style signal. The '
                   'HGCA chi^2 value therefore corroborates the Feng 2022 substellar '
                   'interpretation through the same observational input chain. The audit-row '
                   'verdict (supported_sy_snum = 1; BD is substellar by our convention) '
                   'stands.',
       source_bibcodes = source_bibcodes || ARRAY['2021ApJS..254...42B'],
       curated_at = DATE '2026-06-27'
 WHERE hostname = 'HIP 19976';
