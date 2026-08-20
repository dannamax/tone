-- 001: Users & Auth
CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(254) UNIQUE NOT NULL,
    nickname    VARCHAR(30) NOT NULL DEFAULT '',
    avatar      VARCHAR(10) NOT NULL DEFAULT 'default',
    device_id   VARCHAR(128) NOT NULL DEFAULT '',
    balance     DECIMAL(12,2) NOT NULL DEFAULT 0,
    frozen_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);

-- Email verification codes
CREATE TABLE IF NOT EXISTS email_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(254) NOT NULL,
    code        VARCHAR(10) NOT NULL,
    used        BOOLEAN NOT NULL DEFAULT false,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_codes_email ON email_codes(email, created_at DESC);
