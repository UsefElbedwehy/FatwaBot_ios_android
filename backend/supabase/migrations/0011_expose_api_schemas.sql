-- 0011: expose the API's custom schemas to the Data API + grant service_role.
--
-- The edge function talks to Postgres via @supabase/supabase-js, which goes
-- through PostgREST. PostgREST only serves schemas in its `db-schemas` list
-- (default: public, graphql_public) and each role only sees tables it's been
-- granted. Migrations 0002–0010 created `identity`, `config`, `content`,
-- `admin`, `gamification`, `search`, `notifications` but never exposed or
-- granted them — so every /v1/* call 500s with "schema must be one of ...".
-- This migration makes the API's own schema (service_role) reachable. RLS stays
-- deny-by-default, so anon/authenticated still see nothing.

do $$
declare
    s text;
    api_schemas text[] := array[
        'config', 'identity', 'content', 'admin', 'gamification', 'search', 'notifications'
    ];
begin
    foreach s in array api_schemas loop
        -- schema must be resolvable by the PostgREST roles…
        execute format('grant usage on schema %I to anon, authenticated, service_role', s);
        -- …but only service_role (used by the API, BYPASSRLS) gets table access.
        execute format('grant all privileges on all tables in schema %I to service_role', s);
        execute format('grant all privileges on all sequences in schema %I to service_role', s);
        execute format('grant all privileges on all routines in schema %I to service_role', s);
        -- future tables/sequences added by later migrations inherit the grant.
        execute format('alter default privileges in schema %I grant all on tables to service_role', s);
        execute format('alter default privileges in schema %I grant all on sequences to service_role', s);
    end loop;
end $$;

-- Add the schemas to PostgREST's exposed set (in-database config) and reload.
-- NOTE: Supabase's dashboard "Exposed schemas" (Settings → API) is authoritative
-- and should be set to match; this covers the DB side / self-hosted.
alter role authenticator
    set pgrst.db_schemas = 'public, graphql_public, config, identity, content, admin, gamification, search, notifications';

notify pgrst, 'reload config';
