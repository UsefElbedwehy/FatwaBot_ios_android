-- 0010: search history + notification catalog/campaigns (M3).
-- docs/features/search-history.md, docs/features/notification-campaigns.md.

create schema if not exists search;

create table search.history (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    user_id uuid not null references identity.users(id) on delete cascade,
    source text not null check (source in ('azkar', 'dua', 'hadith_collections', 'ai_fatwa', 'ai_hadith', 'ai_question')),
    query_text text not null,
    locale text not null default 'ar',
    created_at timestamptz not null default now()
);

create index search_history_user_idx on search.history (app_id, user_id, created_at desc);

alter table search.history enable row level security;

-- Layer 1: catalog, admin content in the existing config schema (ADR-0011/0013).
create table config.notification_types (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    category text not null default 'campaign' check (category in ('worship', 'gamification', 'campaign')),
    name_translations jsonb not null default '{}'::jsonb,
    help_text_translations jsonb not null default '{}'::jsonb,
    default_enabled boolean not null default true,
    offset_configurable boolean not null default false,
    delivery_class text not null default 'remote' check (delivery_class in ('local_computed', 'remote')),
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

create schema if not exists notifications;

-- Not admin content — per-user, synced like other settings.
create table notifications.user_prefs (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    user_id uuid not null references identity.users(id) on delete cascade,
    notification_type_key text not null,
    enabled boolean not null default true,
    offset_minutes integer,
    updated_at timestamptz not null default now(),
    unique (app_id, user_id, notification_type_key)
);

-- Layer 2: templates, admin content.
create table notifications.templates (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    locale text not null,
    variant text not null default 'a',
    notification_type_key text not null,
    title_translations jsonb not null default '{}'::jsonb,
    body_translations jsonb not null default '{}'::jsonb,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key, locale, variant)
);

-- Layer 3: campaigns, admin content.
create table notifications.campaigns (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    template_key text not null,
    kind text not null default 'one_time' check (kind in ('one_time', 'recurring', 'event_triggered', 'emergency')),
    schedule jsonb not null default '{}'::jsonb,
    segment jsonb not null default '{}'::jsonb,
    daily_cap_override integer,
    requires_dual_confirmation boolean not null default false,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, key)
);

-- Not admin content — append-only dispatch record, feeds delivery reports.
create table notifications.delivery_log (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    campaign_key text not null,
    user_id uuid not null references identity.users(id) on delete cascade,
    sent_at timestamptz not null default now(),
    status text not null check (status in ('sent', 'failed', 'capped')),
    opened_at timestamptz
);

create index delivery_log_user_campaign_day_idx
    on notifications.delivery_log (app_id, user_id, campaign_key, sent_at);

alter table config.notification_types enable row level security;
alter table notifications.user_prefs enable row level security;
alter table notifications.templates enable row level security;
alter table notifications.campaigns enable row level security;
alter table notifications.delivery_log enable row level security;
