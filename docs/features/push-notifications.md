# Push Notifications (FCM) — status & wiring

Two independent notification systems exist (see also docs/WORSHIP_TAB_DATA_MODEL.md §5):
- **Prayer reminders** — 100% **local**, on-device, work today, no server. (Adhan,
  pre-adhan, iqama, last-third — the notification suite.)
- **Campaign / marketing push** — server-driven via **FCM**. This doc covers that.

## What's built now
- **Backend token endpoint**: `PATCH /v1/me/push-token` `{ "push_token": "…" | null }`
  → stores the FCM token on the user's device row (`identity.devices.push_token`).
  Authenticated (bearer). Tested; deployed to the live function.
- **Android client — fully wired & building**:
  - Firebase BOM + `firebase-messaging`, `google-services` plugin, `google-services.json`.
  - `FatwaBotMessagingService` (`@AndroidEntryPoint`): `onNewToken` registers with the
    backend; `onMessageReceived` posts a notification (foreground) on the `general` channel.
  - `PushTokenRegistrar` → `AuthenticatedApiClient.patchRaw("/v1/me/push-token", …)`.
  - `MainActivity` fetches the token on launch and registers it.
  - `ic_notification` (white mihrab-arch silhouette) as the default FCM notification icon.
  → **Android push works end-to-end once the backend sender is wired (below).**

## Backend sender — BUILT (deployed)
- `fcm_sender.ts` — **FCM HTTP v1 sender**: mints a Google OAuth access token from the
  service account (RS256 JWT via `jose` → token endpoint, cached ~1h) and POSTs to
  `https://fcm.googleapis.com/v1/projects/{project}/messages:send`. Detects dead tokens
  (404 / UNREGISTERED) so the caller can clear them. `fetch`/`now` injectable → unit-tested.
- `notification_dispatch.ts` — pure `dispatchCampaign`: per recipient, checks the user's
  per-type **preference**, enforces the **daily cap** (`notification_engine`), sends, and
  writes the **delivery_log** (sent/capped/failed); clears tokens FCM reports dead.
- `handlers/send_campaign.ts` + route **`POST /admin/v1/campaigns/{key}/send`** (admin
  auth): loads the campaign → template (locale-picked) → notification-type default →
  push audience (`identity.listPushTargets`) → dispatch. Returns `{recipients, sent,
  capped, failed, skipped}`.
- Wired in `index.ts`: `FcmSender` is constructed from the **`FCM_SERVICE_ACCOUNT`**
  secret; if the secret is absent, the endpoint returns `503 push_unavailable`.
- Tests: `tests/push_test.ts` (sender token-mint + payload + unregistered; dispatch
  opted-out/cap/dead-token). Full suite 105 green. Deployed to the live function.

### Remaining to actually fire a push
1. **Rotate** the Firebase service-account key (it was surfaced in chat once), then set it:
   `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat rotated-service-account.json)"`.
2. Have at least one device with a registered token (Android registers automatically).
3. Author a **campaign** + **template** in the dashboard, then
   `POST /admin/v1/campaigns/{key}/send`.

### iOS client (gated on the Apple Developer Program)
**Deliberately not added yet.** iOS push cannot function without APNs, which requires:
- The **Apple Developer Program** (paid) → an **APNs auth key (.p8)** uploaded to Firebase,
  and the **Push Notifications** capability + `aps-environment` entitlement on a real
  provisioning profile.
- Push does **not** work on the iOS Simulator at all.

Because the whole path is blocked until that account exists, we did **not** add the heavy
`firebase-ios-sdk` SPM dependency yet (it would bloat every build and be untestable). When
Apple Developer is ready, the iOS wiring is small and mechanical:
1. Add `firebase-ios-sdk` (product `FirebaseMessaging`) to `ios/App/project.yml` packages.
2. `FirebaseApp.configure()` in `FatwaBotApp.init`; add the Push Notifications capability +
   `aps-environment` entitlement; `UIApplication.registerForRemoteNotifications()`.
3. Set `Messaging.messaging().delegate`; on `didReceiveRegistrationToken`, call the existing
   authenticated client → `PATCH /v1/me/push-token` (mirror of `PushTokenRegistrar`).
The backend endpoint + contract are already in place, so iOS is a drop-in when unblocked.
