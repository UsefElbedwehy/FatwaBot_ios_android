# M0 Implementation Notes

> Running log of decisions and findings during Milestone 0. Date: 2026-07-04.

## Decisions made while building

1. **API gateway pathing.** Supabase serves functions at `/functions/v1/<name>`, so the client-visible base is `…/functions/v1/api` and our routes are the `/v1/...` suffix after the `/api/` mount. `apiPath()` handles both mounted and bare forms; caught by the first test run (the platform's own `/v1/` prefix shadowed ours).
2. **Handlers are pure over a repo interface.** Supabase imports live only in `supabase_repo.ts` + `index.ts`; tests run against `InMemoryConfigRepo` with zero runtime dependencies. Keep this pattern for every future domain (gamification, content, notifications).
3. **iOS project generation via XcodeGen.** `ios/App/project.yml` is the committed source of truth; the `.xcodeproj` is gitignored and regenerated (`xcodegen generate`). Removes project-file merge conflicts permanently.
4. **Factory DI deferred to M1.** With no use cases yet, registering nothing would be ceremony. The first feature (Prayer) introduces the Factory containers per ADR-0006.
5. **Theme parity contract.** `DesignSystemKit.DesignTokens.bundledDefault` (iOS) and `core/designsystem/DesignTokens.kt` (Android) must mirror `backend/supabase/seed.sql` theme values. A cross-platform parity check (script comparing all three) is a TODO for M1 CI.
6. **Android SDK/JDK provisioning.** Machine had neither; installed via Homebrew (`openjdk@21`, `android-commandlinetools`, `gradle` for wrapper bootstrap) + `sdkmanager platform-tools platforms;android-35 build-tools;35.0.0`. `android/local.properties` is machine-local (gitignored).

## Spike finding — high-latitude prayer rule (important)

Cross-validating adhan-js (reference) against adhan-swift over 140 city/date/method combinations: **perfect agreement (±90s) except when no explicit high-latitude rule is set at ≥48°N** — Paris with MWL defaults diverged by up to **2.8 hours** on June fajr between the two ports. With an explicit rule (`twilight_angle`), agreement is exact.

**Policy adopted:** `config.prayer_defaults.params.high_latitude_rule` is **mandatory** for countries with population centers ≥ ~48° latitude; the client calculator also applies a latitude-based recommended rule when config is silent (belt and braces — implement in M1 engine). The corpus encodes this and will catch regressions.

## Deviations from plan

- None architectural. Android compile verification pending first successful `gradlew build` (SDK freshly installed); kotlin/ksp/hilt version alignment may need a bump on first build.

## TODO carried into M1

- Config sync service on both clients (fetch → cache → overlay theme/strings/flags/home layout) with offline-first semantics.
- `/v1/auth/anonymous` + device registration endpoint + JWT middleware in the gateway.
- Token parity check script (seed.sql ↔ iOS ↔ Android) in CI.
- Spot-validate prayer corpus against official published timetables (Umm al-Qura, Egyptian General Authority, Diyanet) — corpus currently proves port-parity, not official-source accuracy.
- Dashboard admin auth (Supabase Auth roles via /admin/v1) — currently an unauthenticated read-only shell.
- iOS CI workflow: replace the per-package loop placeholder with explicit package + app-build jobs now that the layout is fixed.
