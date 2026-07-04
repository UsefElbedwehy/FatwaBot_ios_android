# ADR-0013: Notification campaign engine (admin-managed templates, schedules, campaigns)

- **Status:** Accepted 2026-07-04 (extends the notification architecture in 02_ARCHITECTURE §5)
- **Date:** 2026-07-04

## Context
Requirement: the dashboard must create scheduled/recurring/one-time/emergency campaigns, reminder templates, categories, localized messages, timing defaults, and seasonal campaigns (Ramadan/Eid) — without app updates. Users keep full control of personal preferences.

## Decision
Split the engine into three admin-managed layers over the existing local/remote delivery split:

1. **Catalog** (`config.notification_types`): every notification type as data — id, category, localized title/help text, default on/off, offset-configurable?, delivery class (`local_computed` | `remote`). The Settings screen renders the catalog; new types appear without app updates. User preferences are stored per type (+ per-type offsets) and synced.
2. **Templates** (`notifications.templates`): localized message variants with variables (`{next_prayer}`, `{streak_days}`, `{user_name}`…), A/B variants later. Local reminders fetch template packs with content sync — so even device-scheduled adhan/azkar texts are admin-editable.
3. **Campaigns** (`notifications.campaigns`): one-time, recurring (cron-like), or event-triggered sends; **segmentation** by saved audience segments — country, language/locale, challenge participation, streak state, activity/inactivity, notification-topic opt-ins — with segment definitions stored as reusable data; schedule semantics **in the user's local timezone** via per-timezone fan-out; Ramadan/Eid/seasonal campaigns are recurring campaigns bound to Hijri-calendar triggers. **Emergency sends** are a privileged campaign type: immediate, bypasses quiet hours but **never** user opt-outs, dual-admin confirmation in the dashboard, audit-logged.
4. **Measurement & experimentation:** per-campaign delivery reports (sent/delivered/failed), open/tap rates (notification-open events from clients), and campaign analytics dashboards; the template schema carries a `variant` dimension from day one so A/B testing is a scheduling feature later, not a schema migration.

Delivery: `pg_cron` scheduler → FCM (topics + user targeting). Time-sensitive worship reminders stay locally computed (ADR-0003) for offline reliability; campaigns can also carry silent config-refresh pushes that update local schedules and templates.

## Consequences
- One preference model covers both delivery classes; server enforces preferences for remote sends, client enforces for local.
- Requires delivery/open analytics per campaign in the dashboard (feeds the Analytics module).
- Frequency-capping policy across campaign types is a product decision (OPEN_QUESTIONS) — uncapped admin power to notify is a churn risk.
