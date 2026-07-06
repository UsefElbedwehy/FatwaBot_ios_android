# Feature Spec: Accounts & Profile (M3)

> Extends ADR-0004's anonymous-first auth with real sign-in and anonymous→account linking, without losing any local/synced state the anonymous identity already accumulated.

## Principles
- The app stays fully usable with zero sign-up (Q3). Accounts exist only to unlock leaderboards with a published name, cross-device sync, and (later) AI history.
- Linking an anonymous identity to Apple/Google **preserves `user_id`** — no data migration, no re-registration of devices, no reset of gamification progress.
- Provider verification is **self-issued and stubbed today, swappable for real Apple/Google token verification later without changing the `/v1/auth/*` contract** — the same pattern ADR-0004 already established for anonymous auth pending real Supabase Auth. This is *not* a product compromise: real sign-in requires an Apple Developer account + Google OAuth client (Q8, blocked on credentials), so the verification step is built as a pluggable `IdentityProviderVerifier` interface with a deterministic dev-mode implementation (verifies a signed test assertion) that a real Apple/Google verifier drops into later.

## Domain model
- `identity.users` (already exists) gains: `display_name` (nullable, user-chosen, distinct from any provider name), `provider` (`anonymous | apple | google`), `provider_subject` (nullable, the provider's stable user id), `linked_at`.
- Anonymous users have `provider = 'anonymous'`, `provider_subject = null`.

## API
- `POST /v1/auth/apple`, `POST /v1/auth/google` — body: `{ identity_token, device }`. Verifies the token via `IdentityProviderVerifier` (stubbed today), upserts a user by `(provider, provider_subject)`, returns the same `TokenResponse` shape as `/v1/auth/anonymous`.
- `POST /v1/auth/link` — body: `{ provider: apple|google, identity_token }`, **authenticated as the anonymous user being upgraded**. Verifies the token, attaches `provider`/`provider_subject`/`linked_at` to the *existing* `user_id` (no new row), rejects if that provider identity is already linked to a different account (`409 already_linked`).
- `PATCH /v1/me/profile` — body: `{ display_name }` (nullable to clear). Authenticated, any account kind.
- `GET /v1/me` (existing) gains `display_name`, `provider` to its response.

## Client behavior
- Sign-in entry points are optional, surfaced from Settings and from the leaderboard opt-in flow (leaderboard.md) — never a blocking wall.
- On successful link, the client keeps its existing `user_id`-scoped local caches (gamification profile, favorites, wird instances) — nothing is invalidated, since the server-side identity didn't change.
- Display name is optional and independent of the account name from Apple/Google — set explicitly in Settings or during the leaderboard opt-in flow (never auto-filled from the provider to avoid surprising publication of a real name).

## Tests
- Backend: sign-in via each provider stub creates/reuses a user by `(provider, provider_subject)`; linking preserves `user_id` and rejects double-linking a provider identity to a second account; `/v1/me` reflects `display_name`/`provider`; profile PATCH validates length and allows clearing.
- Both platforms: linking flow doesn't reset local gamification/favorites state; display name defaults to unset (pseudonymous) until explicitly chosen.
