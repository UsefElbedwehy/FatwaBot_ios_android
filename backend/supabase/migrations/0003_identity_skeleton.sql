-- 0003: identity skeleton (ADR-0004 anonymous-first; full auth lands in M1/M3)
create schema if not exists identity;

create table identity.users (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    kind text not null default 'anonymous' check (kind in ('anonymous','account')),
    -- set when kind = 'account'; links to Supabase Auth user behind the API
    auth_user_id uuid unique,
    country_code text,
    created_at timestamptz not null default now(),
    -- account linking: anonymous user re-parented, never deleted-and-recreated
    linked_from uuid references identity.users(id)
);

create table identity.devices (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references identity.users(id) on delete cascade,
    platform text not null check (platform in ('ios','android')),
    push_token text,
    locale text not null default 'ar',
    timezone text not null default 'UTC',
    app_version text not null,
    last_seen_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index devices_user_idx on identity.devices (user_id);

alter table identity.users enable row level security;
alter table identity.devices enable row level security;
