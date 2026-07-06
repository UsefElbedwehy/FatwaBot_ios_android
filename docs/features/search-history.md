# Feature Spec: Search History (M3)

> Ships as the container module the foundation's مزايا section lists, and the exact surface AI search (M5) will later populate with fatwa/hadith queries. In M3 it records in-app content search only (Azkar/Dua/Hadith Collections search boxes already built in M2) — no new search surface, just persistence + a history screen.

## Domain model
- `search_history` (backend, per-user): `id`, `app_id`, `user_id`, `source` (`azkar | dua | hadith_collections | ai_fatwa | ai_hadith | ai_question` — the AI sources are reserved, unused until M5), `query_text`, `locale`, `created_at`.
- Local cache mirrors the same shape for offline display and to avoid a network round-trip just to open the history screen.

## API
- `POST /v1/search-history` — body: `{ source, query_text, locale }`. Authenticated (anonymous or account) — anonymous users get device-scoped history like everything else pre-linking. Fire-and-forget from the client; failures are silent (search still works without history recording succeeding).
- `GET /v1/search-history?source=&limit=&before=` — paginated, most recent first.
- `DELETE /v1/search-history/{id}` — delete one entry.
- `DELETE /v1/search-history` — clear all (with an explicit confirm step in the client — this is a destructive action).

## Client behavior
- Existing Azkar/Dua/Hadith Collections search boxes gain a single line: on a non-empty query that returns results (or after a debounce, whichever the platform's existing search UX already does), submit a `search_history` entry. No new search UI in M3.
- History screen (reachable from Settings or a new مزايا row): reverse-chronological list grouped by day, swipe/long-press to delete one entry, a clear-all action behind confirmation.
- Never records empty queries or queries that errored client-side before reaching a results screen.

## Tests
- Backend: pagination (`limit`/`before`) returns correct ordering and stops correctly at the end; delete-one and delete-all scope correctly to the authenticated user (never another user's history); anonymous history survives account linking (same `user_id`, per `accounts.md`).
- Both platforms: history recording never blocks or errors the search UI itself; delete-all requires explicit confirmation; local cache and server list agree after a sync.
