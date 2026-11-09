BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username text NOT NULL,
    email text NOT NULL UNIQUE,
    hashed_password text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hostname text NOT NULL,
    os text NOT NULL,
    platform text NOT NULL,
    status text NOT NULL DEFAULT 'offline',
    token_hash text UNIQUE,
    token_expires_at timestamptz,
    last_seen timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS devices_user_created_idx
    ON devices (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    revoked boolean NOT NULL DEFAULT false,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS refresh_tokens_user_idx
    ON refresh_tokens (user_id);

CREATE TABLE IF NOT EXISTS pairing_codes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code char(6) NOT NULL,
    expires_at timestamptz NOT NULL,
    is_used boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS pairing_codes_code_idx ON pairing_codes (code);
CREATE INDEX IF NOT EXISTS pairing_codes_user_idx ON pairing_codes (user_id);

COMMIT;
