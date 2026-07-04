-- 0001: extensions + apps registry (ADR-0015 tenancy-readiness)
create extension if not exists pgcrypto;

-- Every config/content/definition table references an app. Single app today;
-- the fixed UUID below is the primary app and the default for all app_id columns.
create table public.apps (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    display_name text not null,
    created_at timestamptz not null default now()
);

insert into public.apps (id, slug, display_name)
values ('00000000-0000-4000-a000-000000000001', 'fatwabot', 'Fatwa Bot');

create or replace function public.primary_app_id()
returns uuid
language sql
immutable
as $$ select '00000000-0000-4000-a000-000000000001'::uuid $$;

alter table public.apps enable row level security;
-- deny-by-default: no policies; only service role reaches these tables via the API.
