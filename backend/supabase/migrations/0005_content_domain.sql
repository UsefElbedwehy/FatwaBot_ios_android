-- 0005: content domain (ADR-0014 multi-locale content; docs/features/content-pipeline.md)
-- Every text field is stored as {field}_translations jsonb: {"ar": "...", "en": "..."}.
-- Arabic is canonical; version is bumped on any published change so clients can
-- delta-sync per collection via GET /v1/content/{collection}?since_version=N.
create schema if not exists content;

create table content.azkar_categories (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    slug text not null,
    name_translations jsonb not null default '{}'::jsonb,
    sort_order integer not null default 0,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, slug)
);

create table content.azkar_items (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    category_id uuid not null references content.azkar_categories(id) on delete cascade,
    sort_order integer not null default 0,
    arabic_text text not null,
    transliteration_translations jsonb not null default '{}'::jsonb,
    translation_translations jsonb not null default '{}'::jsonb,
    virtue_note_translations jsonb not null default '{}'::jsonb,
    source text not null default '',
    repeat_count integer not null default 1,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now()
);

create table content.dua_categories (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    slug text not null,
    name_translations jsonb not null default '{}'::jsonb,
    sort_order integer not null default 0,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, slug)
);

create table content.duas (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    category_id uuid not null references content.dua_categories(id) on delete cascade,
    sort_order integer not null default 0,
    title_translations jsonb not null default '{}'::jsonb,
    arabic_text text not null,
    transliteration_translations jsonb not null default '{}'::jsonb,
    translation_translations jsonb not null default '{}'::jsonb,
    source text not null default '',
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now()
);

create table content.hadith_collections (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    slug text not null,
    name_translations jsonb not null default '{}'::jsonb,
    description_translations jsonb not null default '{}'::jsonb,
    sort_order integer not null default 0,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, slug)
);

create table content.hadith_entries (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    collection_id uuid not null references content.hadith_collections(id) on delete cascade,
    number integer not null,
    arabic_text text not null,
    translation_translations jsonb not null default '{}'::jsonb,
    grading text not null default '',
    benefit_note_translations jsonb not null default '{}'::jsonb,
    source text not null default '',
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now(),
    unique (app_id, collection_id, number)
);

create table content.wird_templates (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    name_translations jsonb not null default '{}'::jsonb,
    description_translations jsonb not null default '{}'::jsonb,
    type text not null,
    default_target integer not null default 1,
    default_unit text not null default 'times',
    default_frequency text not null default 'daily',
    sort_order integer not null default 0,
    version integer not null default 1,
    published boolean not null default false,
    updated_at timestamptz not null default now()
);

alter table content.azkar_categories enable row level security;
alter table content.azkar_items enable row level security;
alter table content.dua_categories enable row level security;
alter table content.duas enable row level security;
alter table content.hadith_collections enable row level security;
alter table content.hadith_entries enable row level security;
alter table content.wird_templates enable row level security;
-- deny-by-default; content is served publicly only via the API (service role).
