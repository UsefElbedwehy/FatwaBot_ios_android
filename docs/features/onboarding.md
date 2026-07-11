# Feature Spec: Onboarding & Permission Priming (M4)

> Value-first first-run flow: show what the app does before asking for anything, then prime each system permission with its own one-screen "why" immediately before the OS prompt — never a blanket permission wall at launch.

## Principles
- Zero sign-up to reach value (ADR-0004/Q3 already established this for the app at large — onboarding must not regress it). The flow ends at the Home screen fully usable anonymously; account creation is never part of onboarding.
- Every OS permission request is preceded by an in-app priming screen explaining *why*, shown only immediately before that specific system prompt — never batched, never shown for a permission the user hasn't reached the relevant feature for yet.
- Onboarding runs once per install (tracked locally, not server-side — no account exists yet to attach it to). Re-installs see it again; that's acceptable.
- Skippable at every step except the final "you're in" screen — a user who dismisses location/notification priming lands on Home with the manual-city fallback already built for M1, not a dead end.

## Flow (4 screens, iOS + Android identical structure)
1. **Welcome** — brand screen (mihrab-arch motif, per 06_DESIGN_REVIEW.md), one-line value statement, "Get started."
2. **What you'll find** — 3-card swipeable summary: Prayer times & Qibla (M1), Azkar/Tasbeeh/Awrad/Hadith (M2), Track your streaks (M3). No AI card yet — AI ships in M5, onboarding is not pre-announcing unshipped features.
3. **Location priming** — explains prayer-time/Qibla accuracy needs location; "Allow" triggers the OS prompt via the existing `LocationProviding` (iOS)/`SystemLocationProvider` (Android); "Not now" proceeds straight to Home with the M1 manual-city picker already wired as the fallback — this priming screen adds no new location code, it only sequences the existing permission request.
4. **Notification priming** — explains adhan/azkar reminders; "Allow" triggers the OS prompt via the existing notification scheduler wiring (M1 task 14); "Not now" proceeds to Home with notifications simply off, exactly like a user who denies the OS prompt directly today.

Both priming screens call the *same* underlying permission-request code paths M1 already built (`PrayerNotificationScheduler.requestAuthorization()`, `LocationProviding`) — onboarding is sequencing UI in front of existing calls, not new permission-handling logic.

## Local state
- `OnboardingCompletionStore` (mirrors the existing `WidgetSnapshotStore`/file-store pattern): a single boolean + timestamp, written on reaching screen 4's "Continue," read once at app launch to decide whether to show the flow before `RootTabView`/`RootScaffold`.
- No new backend endpoint — onboarding is 100% local UI sequencing over already-existing client and OS APIs.

## Accessibility (ties into M4's audit)
- Every onboarding screen is a standalone VoiceOver/TalkBack focus group with a clear heading; "Skip" and "Not now" always reachable without swiping through decorative content first.
- Respects Reduced Motion: card-swipe transitions become instant fades, not slides, when the OS setting is on.

## Tests
- Both platforms: `OnboardingCompletionStore` persists across relaunch; declining location/notification priming does not block reaching Home; onboarding is not re-shown after completion; re-triggering permission priming mid-flow never double-prompts the OS (a user who already granted the permission via a prior path — e.g. reinstalling with prior grant memory on Android — skips straight past that priming screen).
