# ADR-0011: Server-driven configuration & Home layout (config platform)

- **Status:** Accepted 2026-07-04
- **Date:** 2026-07-04

## Context
Product requirement: the platform must be highly configurable — branding, themes, typography, texts, onboarding, Home layout, categories, providers, defaults — changeable from the Admin Dashboard without store releases, and extensible with minimal mobile changes.

## Decision
A layered **config platform**, all admin-managed, all versioned, all cached offline with shipped defaults:

1. **Remote Config (`/v1/config`)** — feature flags, module registry (which modules are enabled per platform/version/locale/country), provider selections, prayer-calculation defaults, notification defaults, gamification parameters, supported languages/countries/regions. Flat typed keys + JSON values, each with min-app-version gating.
2. **Theme & Branding (`/v1/config/theme`)** — design *tokens as data*: color palettes (light/dark), type-scale parameters, radius/spacing multipliers, logo/artwork URLs, in-app product name string. Apps ship the token *schema* and default values; the server overrides values, never structure.
3. **String packs (`/v1/config/strings/{locale}`)** — versioned localized text bundles (UI copy, onboarding slides, help texts, legal). Delta-downloaded by version; bundled seed per release. New locales activate server-side.
4. **Home layout (`/v1/home`)** — an ordered list of **typed sections** (e.g. `prayer_hero`, `actions_row`, `streak_strip`, `ask_ai`, `announcement`, `content_carousel`), each with a props payload. Apps ship a native **section catalog**; the server composes order, visibility, and props. Unknown section types are skipped silently (forward compatibility: new arrangements — and new sections shipped in app updates — without churn).

**Honest limits (cannot be server-driven, by OS design):** the app name under the icon, the app icon (except pre-shipped iOS alternate icons), the true launch/splash screen (build artifact; we ship a neutral branded launch that hands off to a themed splash overlay), widget *types* (extension code), store listings, and new native capabilities. Everything else in the requirement list is covered by layers 1–4 or by content APIs (ADR-0014).

## Consequences
- Config fetch is non-blocking: apps render from cached/bundled config instantly and apply updates on next launch (or immediately where safe).
- Every config payload carries `version` + `min_app_version`; the dashboard gets validation + preview + staged rollout (percentage/country) + instant kill-switch.
- Discipline required: the section catalog stays *native and finite* — we are not building HTML-style server-driven UI; premium feel and offline behavior stay intact.
