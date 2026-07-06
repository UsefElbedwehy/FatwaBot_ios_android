-- 0009: leaderboards (M3, docs/features/leaderboard.md). Implements the
-- leaderboard half of ADR-0012; ranks consistency, never worship volume,
-- per ADR-0007's riya' guardrail.

-- Definition is admin content (draft/published/version) — same generic CRUD
-- as streak_defs/missions/badges.
create table gamification.leaderboard_defs (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    name_translations jsonb not null default '{}'::jsonb,
    scope text not null default 'global' check (scope in ('global', 'country', 'city')),
    period text not null default 'weekly' check (period in ('weekly', 'monthly', 'seasonal', 'lifetime', 'challenge')),
    -- metric: { terms: [{ event_type, weight, cap_per_period }] }
    metric jsonb not null default '{"terms": []}'::jsonb,
    eligibility jsonb not null default '{}'::jsonb,
    tie_breakers text[] not null default '{}',
    visibility text not null default 'public' check (visibility in ('public', 'opt_in_only')),
    display_requirements jsonb not null default '{"requires_published_name": false}'::jsonb,
    rewards_translations jsonb not null default '{}'::jsonb,
    season_starts_at timestamptz,
    season_ends_at timestamptz,
    enabled boolean not null default true,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

-- Membership + materialized snapshots are NOT admin content — user- and
-- job-generated, respectively.
create table gamification.leaderboard_memberships (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    leaderboard_key text not null,
    user_id uuid not null references identity.users(id) on delete cascade,
    handle text not null,
    publish_name boolean not null default false,
    -- captured only when the user explicitly joins a city-scope board (Q2c: opt-in only).
    city text,
    joined_at timestamptz not null default now(),
    unique (app_id, leaderboard_key, user_id)
);

create table gamification.leaderboard_snapshots (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    leaderboard_key text not null,
    period_key text not null,
    user_id uuid not null references identity.users(id) on delete cascade,
    rank integer not null,
    score numeric not null,
    computed_at timestamptz not null default now(),
    unique (app_id, leaderboard_key, period_key, user_id)
);

create index leaderboard_snapshots_lookup_idx
    on gamification.leaderboard_snapshots (app_id, leaderboard_key, period_key);

alter table gamification.leaderboard_defs enable row level security;
alter table gamification.leaderboard_memberships enable row level security;
alter table gamification.leaderboard_snapshots enable row level security;
