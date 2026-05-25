-- Feedback / issue-report sink for the public site (added 2026-05-24). This is the
-- FIRST write path in the otherwise read-only serving layer, so it is deliberately
-- isolated: a standalone, append-only table that never touches the nightly-overwritten
-- catalog tables (planets_snapshots / planets_current and their kin). Rows arrive from
-- POST /api/feedback (a small contact form) and are also emailed to the maintainer.
--
-- Privacy (see PRIVACY.md): we store the message, an OPTIONAL reply-to email (only if
-- the reporter asks to be contacted), the page they were on, the user agent, and a
-- SHA-256 hash of the client IP (never the raw IP) used solely for rate-limiting.
--
-- NOTE: the API connects with the DATABASE_URL role. If that role is SELECT-only,
-- grant it write access to just this table after applying, e.g.:
--   GRANT INSERT, SELECT ON feedback TO <api_role>;
--   GRANT USAGE, SELECT ON SEQUENCE feedback_id_seq TO <api_role>;
-- Idempotent.

CREATE TABLE IF NOT EXISTS feedback (
    id            bigserial PRIMARY KEY,
    created_at    timestamptz NOT NULL DEFAULT now(),
    page_url      text,
    message       text NOT NULL,
    contact_email text,
    user_agent    text,
    ip_hash       text
);

-- Reverse-chronological review + the per-client rate-limit lookup.
CREATE INDEX IF NOT EXISTS feedback_created_at_idx ON feedback (created_at DESC);
CREATE INDEX IF NOT EXISTS feedback_ip_hash_created_at_idx ON feedback (ip_hash, created_at DESC);
