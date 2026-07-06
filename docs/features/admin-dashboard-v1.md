# Feature Spec: Admin Dashboard v1 (M2)

> Content-first slice of the control center (ADR-0009). Scope: admin auth + CMS for azkar/duas/hadith collections/wird templates with locale tabs and a draft→review→publish workflow. Later milestones add gamification/notification/AI domains (roadmap M3+) to the same shell.

## Principles
- Dashboard talks only to `/admin/v1/...` on the backend (never Supabase directly) — ADR-0009.
- Every admin mutation is audited (who, what, before/after).
- Content is versioned; apps only ever see `published = true` rows (existing `/v1/content/*` reads are unaffected by drafts).

## Auth
- `POST /admin/v1/auth/login` — email + password against Supabase Auth (proxied), returns an admin-scoped access/refresh JWT pair distinct from the mobile anonymous/account tokens (separate `aud`/role claim: `role: "admin"`).
- All other `/admin/v1/*` routes require a valid admin bearer token; a bootstrap admin is seeded via migration for local/dev use (documented in backend README, not committed as a real credential).
- Dashboard stores the token in an httpOnly-equivalent mechanism appropriate to Next.js (server action / route handler session cookie) — never in client-readable localStorage.

## Content domain API (`/admin/v1/content/{collection}`)
Collections: `azkar-categories`, `azkar-items`, `dua-categories`, `duas`, `hadith-collections`, `hadith-entries`, `wird-templates`.

- `GET /admin/v1/content/{collection}` — list all rows (draft + published), paginated.
- `POST /admin/v1/content/{collection}` — create a draft row (`published=false`, `version` starts at 1).
- `PATCH /admin/v1/content/{collection}/{id}` — update fields (including `{field}_translations` maps); bumps `version` on any change to a published row, leaves version alone for draft-to-draft edits.
- `POST /admin/v1/content/{collection}/{id}/publish` — flips `published=true`; this is the only path that makes a row visible to `/v1/content/*`.
- `POST /admin/v1/content/{collection}/{id}/unpublish` — reverts to draft (removes from public reads; does not delete).
- Every mutating call writes an `admin.audit_log` row: `{admin_id, collection, row_id, action, before, after, at}`.

## Locale tabs & review state
- Each translatable field is edited per-locale in the dashboard (tabs for enabled locales from `config.locales`).
- A collection row's "review state" is derived, not stored separately in v1: `draft` (never published) → `published` (live) → `published, has_unpublished_edits` (edited after going live). This keeps the schema simple while satisfying ADR-0014's draft→review→publish intent; a dedicated `review_status` enum is a natural v2 extension once multi-step review (not just publish/unpublish) is needed.

## Screens
1. **Login** — email/password form, posts to `/admin/v1/auth/login`.
2. **Content collection list** (one per collection, e.g. `/content/azkar`) — table: name (canonical/Arabic), status badge (draft/published/edited), last updated. Row click → editor.
3. **Content editor** — locale-tabbed form matching the collection's fields (per `docs/features/content-pipeline.md`'s schema), Save (draft), Publish, Unpublish actions.
4. **Audit log** (`/audit`) — reverse-chronological table of all admin mutations, filterable by collection.

## Tests
- Backend: auth guard rejects missing/invalid/non-admin tokens on every `/admin/v1/*` route; publish makes a row appear in `/v1/content/*`, unpublish removes it; version bumps only on published-row edits; audit log records every mutation.
- Dashboard: build/typecheck/lint green; smoke-test the login → list → edit → publish flow against a mocked API client.
