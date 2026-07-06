-- 0007: account linking (M3, docs/features/accounts.md).
-- Extends identity.users with provider identity + profile, preserving the
-- ADR-0004 pattern: self-issued verification today, swappable for real
-- Apple/Google JWKS verification later without a contract change.

alter table identity.users
    add column display_name text,
    add column provider text not null default 'anonymous' check (provider in ('anonymous', 'apple', 'google')),
    add column provider_subject text,
    add column linked_at timestamptz;

-- one account per provider identity per app; NULLs (anonymous users) are unconstrained.
create unique index users_provider_identity_idx
    on identity.users (app_id, provider, provider_subject)
    where provider_subject is not null;
