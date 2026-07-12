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

## Remaining — two gated pieces

### 1. Backend sender (needs the Firebase service account)
The M3 campaign engine (`notifications.templates/campaigns/user_prefs/delivery_log`)
composes and audits campaigns, but the **actual FCM send is still stubbed**
(`functions/api/handlers/notifications.ts`). To send:
- Add an FCM HTTP v1 sender using the **Firebase service-account JSON** as a Supabase
  function secret (e.g. `FCM_SERVICE_ACCOUNT`), mint an OAuth token, POST to
  `https://fcm.googleapis.com/v1/projects/fatwabot-5f898/messages:send` per device token.
- ⚠️ The service-account key was surfaced in chat once — **rotate it**, then set the
  fresh one as the secret.

### 2. iOS client (gated on the Apple Developer Program)
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
