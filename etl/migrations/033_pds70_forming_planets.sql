-- PDS 70 deep dive (manual literature review, 2026-05-23). PDS 70 b and c are the
-- only confirmed planets caught in the act of forming -- accreting inside the gap
-- of their protoplanetary disk, with a resolved circumplanetary disk around c.
-- They are dusty, accreting young giants with no clean molecule detections, so the
-- value-add is in planet_derived_measurements (accretion + circumplanetary disk),
-- not planet_atmospheres. Values read from the cited papers; bibcodes verified via
-- ADS. Citations linked role='characterization' in etl/seed_followup_citations.py.
--
--   Wagner et al. 2018 (MagAO Halpha) -- first mass-accretion rate of a forming
--     planet, PDS 70 b: log10(Mdot) = -8 +/- 1 (M_Jup/yr).
--   Haffert et al. 2019 (VLT/MUSE Halpha) -- both b and c are accreting; near a
--     2:1 mean-motion resonance (also the discovery paper for c).
--   Benisty et al. 2021 (ALMA 855 um) -- the first resolved circumplanetary disk,
--     around PDS 70 c: dust mass ~0.031 M_earth (1 um grains) / ~0.007 (1 mm),
--     radius < ~1.2 au.
--
-- Apply after 024_planet_derived_measurements.sql. Idempotent.

INSERT INTO planet_derived_measurements
    (pl_name, quantity, value, unc_hi, unc_lo, unit, model, bibcode, curator_note)
VALUES
    ('PDS 70 b', 'accretion_rate', 1e-8, NULL, NULL, 'M_jup_per_yr', 'Halpha line luminosity (MagAO)',
     '2018ApJ...863L...8W',
     'Wagner et al. 2018. First mass-accretion rate measured for a forming planet: '
     'log10(Mdot) = -8 +/- 1 (M_Jup/yr), i.e. ~1e-9 to 1e-7; the large 1-dex error is '
     'from unknown circumstellar/circumplanetary extinction. Haffert et al. 2019 '
     'independently confirmed b is accreting (Halpha).'),
    ('PDS 70 c', 'circumplanetary_disk_dust_mass', 0.031, NULL, NULL, 'M_earth', 'ALMA 855um continuum (1um grains)',
     '2021ApJ...916L...2B',
     'Benisty et al. 2021. First resolved circumplanetary disk: dust mass ~0.031 M_earth '
     '(assuming 1 um grains) or ~0.007 M_earth (1 mm grains); radius < ~1.2 au (~1/3 of '
     'the Hill radius), peak 855 um intensity 86 +/- 16 uJy/beam. c is still accreting '
     'through this disk, near a 2:1 resonance with b (Haffert et al. 2019).')
ON CONFLICT (pl_name, quantity, bibcode) DO UPDATE SET
    value        = EXCLUDED.value,
    unc_hi       = EXCLUDED.unc_hi,
    unc_lo       = EXCLUDED.unc_lo,
    unit         = EXCLUDED.unit,
    model        = EXCLUDED.model,
    curator_note = EXCLUDED.curator_note;
