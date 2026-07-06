-- 0006: admin domain (ADR-0009 dashboard control center; docs/features/admin-dashboard-v1.md)
-- Admin auth is self-issued here (mirrors ADR-0004's anonymous-auth pattern:
-- own-signed JWTs now, swappable for real Supabase Auth roles later without
-- changing the /admin/v1 contract). audit_log is append-only.
create schema if not exists admin;

create table admin.admin_users (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    email text not null,
    password_hash text not null,
    created_at timestamptz not null default now(),
    unique (app_id, email)
);

create table admin.audit_log (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    admin_id uuid not null references admin.admin_users(id),
    collection text not null,
    row_id text not null,
    action text not null check (action in ('create', 'update', 'publish', 'unpublish')),
    before jsonb,
    after jsonb,
    created_at timestamptz not null default now()
);

create index audit_log_collection_idx on admin.audit_log (app_id, collection, created_at desc);

alter table admin.admin_users enable row level security;
alter table admin.audit_log enable row level security;
-- deny-by-default; only the API (service role) reads/writes.
