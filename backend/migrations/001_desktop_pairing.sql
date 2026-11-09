CREATE TABLE IF NOT EXISTS desktop_pairing_sessions (
    id uuid PRIMARY KEY,
    code char(6) UNIQUE NOT NULL,
    secret_hash char(64) NOT NULL,
    hostname text NOT NULL,
    os text NOT NULL,
    platform text NOT NULL,
    expires_at timestamptz NOT NULL,
    user_id uuid,
    requester text,
    state text NOT NULL DEFAULT 'open'
        CHECK (state IN ('open', 'pending', 'approved', 'denied')),
    device_id uuid
);

CREATE INDEX IF NOT EXISTS desktop_pairing_sessions_expiry
    ON desktop_pairing_sessions (expires_at);
