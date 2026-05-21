-- Manually curated, literature-sourced system distances for hosts that have
-- neither a Gaia distance (host_stars_gaia.distance_gspphot_pc) nor a NASA EA
-- snapshot distance (sy_dist).
--
-- Motivation: the cb_flag audit found two cb_flag=1 hosts with no distance in the
-- warehouse, which suppresses the Milky Way position card (GalaxyMap) on their
-- planet pages even though both distances are well known from the literature:
--   * MXB 1658-298  — faint LMXB toward the bulge, no Gaia parallax
--   * PSR B1620-26  — pulsar in globular cluster M4, distance = cluster distance
--
-- Provenance is kept honest by living in its own table rather than polluting the
-- Gaia table or the (snapshot-overwritten) sy_dist column. Application code reads
-- this as the *last* fallback: distance_gspphot_pc -> sy_dist -> manual.
--
-- Idempotent.

CREATE TABLE IF NOT EXISTS host_distances_manual (
    hostname        TEXT PRIMARY KEY,
    distance_pc     DOUBLE PRECISION NOT NULL,
    distance_pc_err DOUBLE PRECISION,
    source_bibcode  TEXT,
    source_note     TEXT,
    retrieved_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO host_distances_manual
    (hostname, distance_pc, distance_pc_err, source_bibcode, source_note)
VALUES
    ('MXB 1658-298', 9000, 2000, '2008ApJS..179..360G',
     'X-ray burst distance 9 +/- 2 kpc (H-rich) to 12 +/- 3 kpc (He-rich), Galloway et al. 2008; ~10 kpc from a PRE burst (Sharma et al. 2018). Same object as MXB 1659-298 / X 1659-298. Adopted 9 kpc.'),
    ('PSR B1620-26', 1905, 50, '2015ApJ...808...11N',
     'Member of globular cluster M4 (NGC 6121); system distance is the cluster distance, distance modulus mu = 11.399 +/- 0.007 from RR Lyrae mid-IR PL relations (Neeley et al. 2015).')
ON CONFLICT (hostname) DO UPDATE SET
    distance_pc     = EXCLUDED.distance_pc,
    distance_pc_err = EXCLUDED.distance_pc_err,
    source_bibcode  = EXCLUDED.source_bibcode,
    source_note     = EXCLUDED.source_note,
    retrieved_at    = now();
