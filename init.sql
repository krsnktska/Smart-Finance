-- CREATE DATABASE smart_finance IF NOT EXISTS;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE transaction_type AS ENUM ('expense', 'income');

CREATE TYPE special_type AS ENUM ('upcoming', 'subscription', 'repetitive', 'credit', 'debt');

CREATE TABLE users (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT        NOT NULL,
    email         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    birthday      DATE
);

CREATE TABLE groups (
    id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL
);

CREATE TABLE accounts (
    id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name     TEXT NOT NULL,
    currency TEXT NOT NULL,
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE categories (
    id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name    TEXT NOT NULL,
    color   TEXT NOT NULL,
    emoji   TEXT,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE transactions (
    id           UUID             PRIMARY KEY DEFAULT uuid_generate_v4(),
    type         transaction_type NOT NULL,
    special_type special_type,
    value        NUMERIC(15, 2)   NOT NULL,
    occurred_at  TIMESTAMPTZ      NOT NULL,
    name         TEXT             NOT NULL,
    description  TEXT,
    currency     TEXT             NOT NULL,
    account_id   UUID             NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE TABLE user_groups (
    user_id  UUID    NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    group_id UUID    NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    is_owner BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, group_id)
);

CREATE TABLE transaction_categories (
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    category_id    UUID NOT NULL REFERENCES categories(id)   ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, category_id)
);

CREATE TABLE account_groups (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    group_id   UUID NOT NULL REFERENCES groups(id)   ON DELETE CASCADE,
    PRIMARY KEY (account_id, group_id)
);

CREATE TABLE refresh_tokens (
    id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    token      TEXT        NOT NULL UNIQUE,
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_revoked BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE TYPE bank_type AS ENUM ('Monobank');

CREATE TABLE receipt_items (
    id            UUID        PRIMARY KEY,
    transaction_id UUID        NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    name          TEXT        NOT NULL,
    quantity      NUMERIC     NOT NULL DEFAULT 1,
    unit          TEXT,
    unit_price    NUMERIC     NOT NULL,
    total_price   NUMERIC     NOT NULL
);

CREATE TABLE gmail_tokens (
    id             UUID        PRIMARY KEY,
    user_id        UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    access_token   TEXT        NOT NULL,
    refresh_token  TEXT,
    token_expiry   TIMESTAMPTZ NOT NULL,
    gmail_address  TEXT        NOT NULL,
    last_scanned_at TIMESTAMPTZ
);

CREATE TABLE bank_integrations (
    id              UUID        PRIMARY KEY,
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_type       bank_type   NOT NULL,
    api_token       TEXT        NOT NULL,
    account_id      UUID        NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    bank_account_id TEXT,
    last_synced_at  TIMESTAMPTZ
);

CREATE INDEX idx_bank_integrations
    ON bank_integrations (user_id, bank_type, bank_account_id);

CREATE TYPE invitation_status AS ENUM ('Pending', 'Accepted', 'Declined');

CREATE TABLE group_invitations (
    id                  UUID              PRIMARY KEY,
    group_id            UUID              NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    invited_user_id     UUID              NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invited_by_user_id  UUID              NOT NULL REFERENCES users(id),
    status              invitation_status NOT NULL DEFAULT 'Pending',
    created_at          TIMESTAMPTZ       NOT NULL DEFAULT now(),
    responded_at        TIMESTAMPTZ
);

CREATE INDEX idx_group_invitations
    ON group_invitations (group_id, invited_user_id, status);
