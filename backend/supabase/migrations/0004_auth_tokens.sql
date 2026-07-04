-- 0004: refresh tokens for backend-issued sessions (ADR-0004 anonymous-first).
-- Access tokens are stateless JWTs; refresh tokens are opaque, stored hashed,
-- single-use (rotation invalidates the predecessor).

create table identity.refresh_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references identity.users(id) on delete cascade,
    device_id uuid not null references identity.devices(id) on delete cascade,
    token_hash text not null unique,       -- sha-256 hex of the opaque token
    expires_at timestamptz not null,
    created_at timestamptz not null default now(),
    rotated_from uuid references identity.refresh_tokens(id),
    revoked_at timestamptz
);

create index refresh_tokens_user_idx on identity.refresh_tokens (user_id);

alter table identity.refresh_tokens enable row level security;
