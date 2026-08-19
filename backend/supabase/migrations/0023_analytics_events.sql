-- 0023: first-party product-analytics event ingest
-- (docs/features/analytics-and-crash-reporting.md).
--
-- WHY ITS OWN SCHEMA/TABLE and not gamification.activity_events (0008):
-- that log is read IN FULL PER USER by SupabaseGamificationRepo.listEvents to
-- fold streaks on every GET /v1/gamification/profile. Writing high-volume
-- screen-view traffic into it would slow every profile load and pollute the
-- streak fold. Analytics therefore gets its own schema, table and endpoint.
--
-- PRIVACY CONTRACT (enforced server-side in functions/api/handlers/analytics.ts):
-- this table must NEVER receive search queries, free text, location, or
-- identity — only screen names, stable keys and counts. The ingest handler
-- rejects any event whose params carry a forbidden key (query/q/search/text/
-- body/content/lat/lng/location/city/coords/name/email/phone/token/user_id/…)
-- so a future client bug cannot leak sensitive data in here. Anything in this
-- table that isn't a stable key or a count is a bug, not a feature.
--
-- HIGH VOLUME / PRUNABLE: rows are aggregate-only and safe to delete by
-- occurred_at once they're past the reporting window. Retention trimming is a
-- future ops task (no job exists yet) — expect this to be the largest table.

create schema if not exists analytics;

create table analytics.events (
    id uuid primary key default gen_random_uuid(),
    app_id uuid not null default public.primary_app_id() references public.apps(id),
    user_id uuid not null references identity.users(id) on delete cascade,
    name text not null,
    params jsonb not null default '{}'::jsonb,
    platform text,
    app_version text,
    client_event_id text not null,
    occurred_at timestamptz not null,
    created_at timestamptz not null default now(),
    -- client-generated id, so a retried flush after a dropped response can't double-count
    unique (app_id, user_id, client_event_id)
);

-- The two queries this table exists to serve: event volume over time, and
-- per-event-name volume over time (funnels, screen popularity, retention).
create index analytics_events_occurred_idx on analytics.events (app_id, occurred_at);
create index analytics_events_name_occurred_idx on analytics.events (app_id, name, occurred_at);

alter table analytics.events enable row level security;
-- deny-by-default, same as every other table in this repo: no policies at all.
-- Only the API's service_role (BYPASSRLS) reaches it; anon/authenticated see nothing.

-- Expose the new schema to the Data API + grant service_role, exactly as 0011
-- did for the earlier schemas. Without this every /v1/analytics/* call 500s
-- with "schema must be one of ...".
grant usage on schema analytics to anon, authenticated, service_role;
grant all privileges on all tables in schema analytics to service_role;
grant all privileges on all sequences in schema analytics to service_role;
grant all privileges on all routines in schema analytics to service_role;
alter default privileges in schema analytics grant all on tables to service_role;
alter default privileges in schema analytics grant all on sequences to service_role;

-- NOTE: Supabase's dashboard "Exposed schemas" (Settings → API) is authoritative
-- and must be updated to include `analytics`; this covers the DB side / self-hosted.
alter role authenticator
    set pgrst.db_schemas =
        'public, graphql_public, config, identity, content, admin, gamification, search, notifications, analytics';

notify pgrst, 'reload config';
