-- 0002: config domain (ADR-0011 server-driven configuration platform)
create schema if not exists config;

-- Layer 1: remote config — typed keys, JSON values, version-gated.
create table config.remote_config (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    value jsonb not null,
    description text not null default '',
    min_app_version text,          -- semver string; null = all versions
    platform text not null default 'all' check (platform in ('ios','android','all')),
    updated_at timestamptz not null default now(),
    primary key (app_id, key, platform)
);

create table config.feature_flags (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    key text not null,
    enabled boolean not null default false,
    -- staged rollout: {"percentage": 0-100, "countries": [...], "min_app_version": "..."}
    rollout jsonb not null default '{}'::jsonb,
    description text not null default '',
    updated_at timestamptz not null default now(),
    primary key (app_id, key)
);

-- Layer 2: theme tokens as data over a fixed schema (values overridable, structure not).
create table config.themes (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    version integer not null,
    -- {"light": {...token values...}, "dark": {...}, "assets": {"logo_url": ...}, "product_name": "..."}
    tokens jsonb not null,
    published boolean not null default false,
    created_at timestamptz not null default now(),
    primary key (app_id, version)
);

-- Layer 3: localized string packs, delta-synced by version.
create table config.string_packs (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    locale text not null,          -- bcp47: 'ar', 'en', ...
    version integer not null,
    strings jsonb not null,        -- flat {"key": "value"} map
    published boolean not null default false,
    created_at timestamptz not null default now(),
    primary key (app_id, locale, version)
);

-- Locale registry (ADR-0014): which languages the apps offer, with script metadata.
create table config.locales (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    locale text not null,
    display_name text not null,          -- endonym, e.g. 'العربية'
    direction text not null default 'ltr' check (direction in ('ltr','rtl')),
    digits text not null default 'western' check (digits in ('western','eastern')),
    enabled boolean not null default false,
    sort_order integer not null default 0,
    primary key (app_id, locale)
);

-- Layer 4: Home layout — ordered typed sections rendered by the native catalog.
create table config.home_layouts (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    platform text not null default 'all' check (platform in ('ios','android','all')),
    version integer not null,
    -- [{"type": "prayer_hero", "id": "...", "props": {...}}, ...]
    sections jsonb not null,
    published boolean not null default false,
    created_at timestamptz not null default now(),
    primary key (app_id, platform, version)
);

-- Prayer calculation defaults by country (ADR-0003: backend owns policy, device computes).
create table config.prayer_defaults (
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    country_code text not null,    -- ISO 3166-1 alpha-2; '*' = global fallback
    method text not null,          -- e.g. 'umm_al_qura', 'egyptian', 'mwl', 'isna', 'karachi'
    -- {"madhab": "shafi", "high_latitude_rule": "...", "adjustments": {"fajr": 0, ...}}
    params jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    primary key (app_id, country_code)
);

alter table config.remote_config enable row level security;
alter table config.feature_flags enable row level security;
alter table config.themes enable row level security;
alter table config.string_packs enable row level security;
alter table config.locales enable row level security;
alter table config.home_layouts enable row level security;
alter table config.prayer_defaults enable row level security;
-- deny-by-default; only the API (service role) reads/writes.
