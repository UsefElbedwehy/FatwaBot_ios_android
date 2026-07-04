# Backend

Versioned REST API over Supabase (ADR-0002). One Edge Function gateway (`functions/api`) routes `/v1/...`; Postgres owns all state; RLS is deny-by-default and only the API's service role touches the database.

## Layout

```
supabase/migrations/   numbered SQL migrations (config, identity, … one domain per file)
supabase/seed.sql      default config so /v1/config* serves real data immediately
functions/api/         gateway: router.ts (pure) → handlers/ → ConfigRepo
functions/api/supabase_repo.ts   production repo (service role)
openapi/api.v1.yaml    the client contract — update BEFORE implementing changes
tests/                 deno tests against InMemoryConfigRepo (no DB needed)
```

## Development

```sh
cd backend
deno task test    # unit tests
deno task lint
deno task fmt
```

Local stack (requires Docker): `supabase start` in `backend/`, then `supabase functions serve api`.
Deploy (requires linked project + credentials): `supabase db push && supabase functions deploy api`.

## Conventions

- **Contract-first:** every endpoint exists in `openapi/*.yaml` before its handler.
- **Handlers are pure** over a `ConfigRepo`-style interface; Supabase imports live only in `*_repo.ts` and `index.ts` so tests never need the runtime.
- **Tenancy (ADR-0015):** every definition/config/content table carries defaulted `app_id`; unique keys and RLS predicates are app-scoped; use `public.primary_app_id()` in defaults.
- Client context headers: `x-client-platform`, `x-client-version`, `x-client-locale`.
