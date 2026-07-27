# Security Posture

_Last reviewed: 2026-07-25._

This note records how FatwaBot protects data, so the posture is auditable and
decisions aren't re-litigated from memory. It reflects the code as of this date
(iOS SwiftUI app, Android Jetpack Compose app, Supabase-backed Deno edge-function
API). Update it when the posture changes.

## Transport security (TLS / SSL)

**All app ↔ backend traffic is encrypted in transit over HTTPS (TLS). This is
enforced, not just conventional.**

- The API base URL is HTTPS on both platforms — there is no plaintext `http://`
  endpoint anywhere:
  - iOS: `AppEnvironment.apiBaseURL` → `https://<project>.supabase.co/functions/v1/api`
    (`ios/App/Sources/AppContainer.swift`).
  - Android: Retrofit `baseUrl` → same HTTPS URL (`android/.../di/AppModule.kt`).
- **iOS** enforces Apple App Transport Security (ATS). There is **no**
  `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` exception in `Info.plist`
  or `project.yml`, so iOS refuses non-HTTPS and weak-TLS connections.
- **Android** relies on the platform default (cleartext blocked on API 28+).
  There is **no** `network_security_config.xml` and **no** `usesCleartextTraffic`
  override, so cleartext is disabled.
- TLS termination and certificate lifecycle (issuance + auto-rotation) are
  handled by Supabase's managed platform.

### Certificate pinning — deliberately NOT implemented

We do **not** pin the server certificate, and this is an intentional decision,
not an oversight.

- The backend is Supabase's **managed** endpoint; Supabase controls and rotates
  the TLS certificate on its own schedule. Pinning a leaf certificate would mean
  a routine rotation on their side could **break every already-installed app**
  until users update — an availability risk that, in practice, outweighs the
  MITM it would prevent.
- Standard TLS already protects against passive interception and ordinary MITM.
  Pinning only adds protection against a compromised device trust store (e.g. a
  corporate MITM proxy), which is out of scope for this app's threat model.
- If pinning is ever revisited, pin to the CA / public-key (SPKI) with **backup
  pins** and monitor Supabase's rotation — never pin a single leaf cert.

## Data at rest

| Data | iOS | Android |
| --- | --- | --- |
| Auth + refresh tokens | Keychain (`kSecClassGenericPassword`) | `EncryptedSharedPreferences` (Keystore-backed AES-256 GCM/SIV) |
| Worship history, activity queue, content caches, prefs, location cache | Plaintext JSON / `UserDefaults` in the app-group container | Plaintext `SharedPreferences (MODE_PRIVATE)` / files |

- Auth tokens are stored in the OS secure store on both platforms (not
  plaintext).
- Other local data (dhikr/worship history, cached content, notification prefs,
  cached prayer coordinates) is stored unencrypted inside the app's private
  sandbox / app-group container. On a non-jailbroken/non-rooted device the OS
  sandbox is the boundary; on a compromised device or an unencrypted backup this
  data is readable.
- Sensitivity is **moderate**: search queries and worship activity are personal,
  but the app stores no payment, health, or credential data.
- Known hardening opportunities (tracked, not yet done): iOS
  `FileProtectionType.completeFileProtection` on at-rest writes; encrypt the
  cached GPS coordinates on both platforms; switch the iOS Keychain item to
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

## Backend / API

- Custom stateless **HS256 JWTs** (issuer `fatwabot-api`, required claims
  checked); mobile and admin tokens are namespaced by audience.
- **Refresh tokens are stored only as SHA-256 hashes** — the raw token is never
  persisted server-side.
- Mobile clients **never talk to the database directly** — only to the edge
  function, which authenticates every request and reaches Postgres with the
  `service_role` key.
- Row-Level Security is **enabled** on all tables but there are **no per-user
  policies** yet: authorization currently lives entirely in the edge-function
  app logic ("closed by default", but no DB-layer defense-in-depth). Adding
  per-user RLS policies is a tracked improvement.
- No tokens, JWTs, or PII are logged by client code.

## Not implemented (by design or as future work)

- **Biometric app-open lock** (Face ID / fingerprint) — none. A product/UX
  decision, not required by the current threat model.
- **Certificate pinning** — none (see rationale above).
- **Per-user RLS policies** — future backend hardening.

## 🔴 Pre-launch gates (credential exposure)

Two credentials were pasted in plaintext during development and must be treated
as public. Both are **hard gates before the app reaches real users** — not
polish items.

### 1. Supabase personal access token (`sbp_fbbba32…`)
Account-scoped: it can administer every Supabase project on the account, not
just this one. Revoke at https://supabase.com/dashboard/account/tokens, then
`supabase login` again so the CLI keeps working. Revoking causes no downtime —
the deployed function and database authenticate with the project's own keys, not
this token.

### 2. Firebase service-account private key (project `fatwabot-5f898`)
**Deliberately deferred to project finalization (owner decision, 2026-07-27).**
Accepted knowingly: the app is pre-launch with no real users, and the key was
exposed in a chat rather than committed or published, so the practical risk today
is low. It stops being low the moment the app ships — anyone holding this key can
send push notifications as us and reach Firebase services with admin rights.

Rotation is **two consoles**, and generating a new key does NOT disable the old
one — that's the step that actually closes the exposure:
1. Firebase Console → Project settings → Service accounts → *Generate new private key*.
2. Google Cloud Console → IAM & Admin → Service Accounts → `firebase-adminsdk-…`
   → Keys → **delete the old key id**.
3. `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat <new>.json)"`, then delete the
   downloaded file. It belongs only in Supabase secrets, never in the repo.

Blocks: M4 #45 (beta / store listing) and any real-user distribution.
