-- 0008: gamification (M3, docs/features/gamification.md). Implements ADR-0007
-- (server-authoritative streaks) and ADR-0012 (rules-as-data).
create schema if not exists gamification;

-- Raw, immutable activity events (source of truth). NOT admin content —
-- streaks/missions/badges are folded from this log on read.
create table gamification.activity_events (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    user_id uuid not null references identity.users(id) on delete cascade,
    event_type text not null,
    client_event_id text not null,
    occurred_at timestamptz not null,
    timezone text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    unique (app_id, user_id, client_event_id)
);

create index activity_events_user_idx on gamification.activity_events (app_id, user_id, event_type);

-- Definitions below are admin content (draft/published/version), same shape
-- as the content-domain tables — reuses the generic /admin/v1/content CRUD.

create table gamification.streak_defs (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    name_translations jsonb not null default '{}'::jsonb,
    event_types text[] not null,
    required_daily_count integer not null default 1,
    day_boundary_type text not null default 'fixed_local_time' check (day_boundary_type in ('fixed_local_time', 'midnight')),
    day_boundary_local_time text not null default '04:00',
    grace_allowance integer not null default 0,
    grace_period_days integer not null default 30,
    enabled boolean not null default true,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

create table gamification.missions (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    name_translations jsonb not null default '{}'::jsonb,
    description_translations jsonb not null default '{}'::jsonb,
    event_type text not null,
    target_count integer not null default 1,
    progress_window text not null default 'daily' check (progress_window in ('daily', 'weekly', 'lifetime')),
    schedule text not null default 'daily' check (schedule in ('daily', 'weekly', 'seasonal')),
    reward_translations jsonb not null default '{}'::jsonb,
    starts_at timestamptz,
    ends_at timestamptz,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

create table gamification.badges (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    name_translations jsonb not null default '{}'::jsonb,
    description_translations jsonb not null default '{}'::jsonb,
    icon_ref text not null default '',
    event_type text not null,
    target_count integer not null default 1,
    progress_window text not null default 'lifetime' check (progress_window in ('daily', 'weekly', 'lifetime')),
    hidden_until_earned boolean not null default false,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

alter table gamification.activity_events enable row level security;
alter table gamification.streak_defs enable row level security;
alter table gamification.missions enable row level security;
alter table gamification.badges enable row level security;
-- deny-by-default; served publicly (definitions) or per-user (events) only via the API.
