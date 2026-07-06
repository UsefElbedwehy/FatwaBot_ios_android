# Feature Spec: Notification Catalog & Campaign Engine (M3)

> Implements ADR-0013's three admin-managed layers over the local/remote delivery split already built in M1 (local adhan/azkar reminders, `NotificationPlanner` both platforms).

## Resolved product decision this spec encodes
- **Q2d:** a default cap of **2 campaign (non-worship) notifications per user per day**, admin-configurable per campaign type. Locally-computed worship reminders (adhan, azkar, wird) are **not** subject to this cap — they're a different delivery class entirely and the user already controls them per-type in Settings.

## Layer 1 — Catalog (`config.notification_types`, extends the existing `config` schema; admin content via the same generic CRUD)
- `key`, `category` (`worship | gamification | campaign`), `name_translations`, `help_text_translations`, `default_enabled`, `offset_configurable: boolean`, `delivery_class` (`local_computed | remote`).
- The Settings screen renders this catalog generically — a new notification type appears with zero app changes, matching the M1 local-engine catalog already partially in place.
- `user_notification_prefs` (not admin content): `user_id`, `notification_type_key`, `enabled`, `offset_minutes?` — synced like other per-user settings.

## Layer 2 — Templates (`notifications.templates`, admin content)
- `key`, `locale`, `variant` (default `"a"` — A/B is a scheduling feature later, not a schema change), `title_translations`, `body_translations` with `{variable}` placeholders (`{next_prayer}`, `{streak_days}`, `{user_name}`, …), `notification_type_key` (FK to catalog).
- Local reminders (adhan/azkar/wird nudges) fetch template packs through the existing content-sync pattern — so even device-scheduled text is admin-editable without a release, closing a gap M1 left as "hardcoded ar/en strings."

## Layer 3 — Campaigns (`notifications.campaigns`, admin content)
- `key`, `template_key`, `kind` (`one_time | recurring | event_triggered | emergency`), `schedule` (`{ cron? , hijri_trigger?: "ramadan_1" | "eid_fitr" | ..., event?: "streak_at_risk" | "mission_completed" }`), `segment` (`{ countries?, locales?, streak_state?, activity?: "active"|"inactive_7d", topic_opt_in?: notification_type_key }` — a reusable, admin-authored audience definition, not a one-off query), `daily_cap_override?` (falls back to the global 2/day default), `requires_dual_confirmation: boolean` (always `true` for `kind: emergency`).
- Per-timezone fan-out: scheduled sends resolve to each recipient's local time before dispatch, not a single global send instant.
- `notifications.delivery_log` (not admin content, append-only): `campaign_id`, `user_id`, `sent_at`, `status` (`sent | failed | capped`), feeding per-campaign delivery reports; `notification_open_events` (client-reported) feed open/tap rates.

## API
- `GET /v1/notification-types` — public catalog read (drives Settings).
- `GET/PATCH /v1/me/notification-prefs` — authenticated, per-type enabled/offset.
- Admin surface (`/admin/v1/content/{notification-types,templates,campaigns}`) reuses task 27's generic CRUD — draft a campaign, preview, publish to actually schedule it; `unpublish` pauses a recurring/scheduled campaign without deleting its definition.
- `POST /admin/v1/campaigns/{id}/send-emergency` — bypasses the normal publish-to-schedule flow, requires a second admin's confirmation token, audit-logged with both admins' ids (never bypasses a user's own opt-outs, only quiet-hours).
- `POST /v1/notifications/{delivery_id}/opened` — client reports a tap, feeding delivery_log.status/open metrics.

## Cap enforcement
Before each campaign send, the dispatcher checks `delivery_log` for sends to that user today (`campaign` category only); if at or above the effective cap (`campaign.daily_cap_override` or the global default), the send is recorded as `status: capped` and skipped — visible in the campaign's delivery report, not silently dropped.

## Tests
- Backend: catalog/template/campaign CRUD via the existing admin-content routes (no new code paths to test beyond the whitelist addition); segment matching selects the correct recipient set; per-timezone fan-out computes the correct local send instant; daily cap correctly skips the 3rd+ campaign send to a user in a day while never capping `worship` or `gamification` categories; emergency send requires two distinct admin confirmations and is audit-logged with both; a user's notification-type opt-out is never bypassed by a campaign (only quiet-hours is, and only for `emergency`).
- Both platforms: Settings renders the catalog generically, including a type added purely server-side; local reminder text comes from the synced template pack, not a hardcoded string.
