-- Backfill position_angle_deg from curator-note prose into the typed
-- binary_companions.position_angle_deg column for rows curated in
-- migrations 101 / 103 / 105 / 106 / 107 / 108. PAs were recorded in
-- the notes column during those batches but never lifted into the
-- typed column, so the UI's "· PA NNN°" chip rendered as missing.
-- This migration closes that visibility gap.
--
-- Sources for each PA value:
--   * 91 Aqr B/C ........ WDS 23159-0905 STFB 12 A,BC at epoch 2016 (Mason 2001)
--   * BD-14 3065 A B .... SOAR HRCam speckle 2022-04-15 (Subjak 2024)
--                         note the 180-deg degeneracy: 210.5 or 30.5; using 210.5
--   * HD 2638 B ......... Ginski 2016 AstraLux 2014-08-20 cross-check
--   * HD 43691 B ........ Ginski 2016 AstraLux 2015-03-10
--   * Kepler-21 B ....... Ginski 2016 AstraLux 2013-07-02
--   * Kepler-68 B ....... Ginski 2016 AstraLux 2013-07-02
--   * HD 116029 B ....... Ginski 2016 AstraLux 2013-06-30
--   * HAT-P-18 B ........ Ginski 2016 AstraLux 2013-07-01
--   * Kepler-42 B ....... Ginski 2016 AstraLux 2013-07-01
--   * HD 142245 BC ...... Mugrauer & Ginski 2015 NACO 2012-08-31
--   * HD 196885 A B ..... Chauvin 2007 NACO 2006-08-26 (latest epoch with orbital motion noted)
--   * HD 7449 B ......... Rodigas 2016 Magellan/MagAO 2014-11
--   * HD 177830 B ....... Roberts 2011 AEOS 2002-05 (EGN 24 discoverer)
--   * HAT-P-14 B ........ Ngo 2015 NIRC2 2012-06 (representative epoch)
--   * HAT-P-27 B ........ Ngo 2016 NIRC2 2014-07
--   * HAT-P-29 B ........ Ngo 2016 NIRC2 (multi-epoch, ~159.9 deg)
--   * HAT-P-33 B ........ Ngo 2015 NIRC2 2012-02
--   * HAT-P-35 B ........ Ngo 2016 NIRC2 2013-03
--   * HAT-P-35 C ........ Mugrauer 2019 (existing row, also has PA in notes)
--   * HAT-P-39 B ........ Ngo 2016 NIRC2 2013-03 (and 2014-11)
--   * HIP 94235 B ....... Zhou 2022 Gemini-Zorro 2021-10-22
--   * HD 86081 B ........ Ngo 2017 NIRC2 2014-12-05 (lowest-error epoch)
--   * HD 8673 B ......... Roberts 2015 Keck II 2013-07 (orbital motion observed
--                         across 6 epochs 2004-2013; using a representative
--                         late-epoch midpoint)
--
-- All UPDATEs are gated on `position_angle_deg IS NULL` to never clobber
-- an existing value (e.g. HAT-P-35 C may have had PA = 213.95 set earlier).
--
-- Apply after 108_wds_batch6.sql. Idempotent.


UPDATE binary_companions SET position_angle_deg = 312.0
 WHERE hostname = '91 Aqr' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 312.0
 WHERE hostname = '91 Aqr' AND component_designation = 'C' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 210.5
 WHERE hostname = 'BD-14 3065 A' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 167.76
 WHERE hostname = 'HD 2638' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 40.77
 WHERE hostname = 'HD 43691' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 129.74
 WHERE hostname = 'Kepler-21' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 145.39
 WHERE hostname = 'Kepler-68' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 209.11
 WHERE hostname = 'HD 116029' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 185.72
 WHERE hostname = 'HAT-P-18' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 118.93
 WHERE hostname = 'Kepler-42' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 169.07
 WHERE hostname = 'HD 142245' AND component_designation = 'BC' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 65.7
 WHERE hostname = 'HD 196885 A' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 339.99
 WHERE hostname = 'HD 7449' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 84.1
 WHERE hostname = 'HD 177830' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 264.10
 WHERE hostname = 'HAT-P-14' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 25.48
 WHERE hostname = 'HAT-P-27' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 159.9
 WHERE hostname = 'HAT-P-29' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 117.86
 WHERE hostname = 'HAT-P-33' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 139.3
 WHERE hostname = 'HAT-P-35' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 213.95
 WHERE hostname = 'HAT-P-35' AND component_designation = 'C' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 94.4
 WHERE hostname = 'HAT-P-39' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 161.73
 WHERE hostname = 'HIP 94235' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 89.35
 WHERE hostname = 'HD 86081' AND component_designation = 'B' AND position_angle_deg IS NULL;

UPDATE binary_companions SET position_angle_deg = 332.0
 WHERE hostname = 'HD 8673' AND component_designation = 'B' AND position_angle_deg IS NULL;
