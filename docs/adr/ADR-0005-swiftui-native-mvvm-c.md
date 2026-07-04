# ADR-0005: MVVM-C in a SwiftUI-native dialect (typed routers over NavigationStack)

- **Status:** Accepted 2026-07-04 (**amends** the foundation's literal "Coordinator Pattern")
- **Date:** 2026-07-04

## Context
Classic Coordinators wrap UIKit's imperative navigation. On iOS 17+ SwiftUI, recreating them verbatim fights `NavigationStack`, deep linking, and state restoration.

## Decision
Keep the coordinator *responsibilities* — views never navigate themselves; flow logic is centralized and testable — implemented as:
- Typed route enums per feature (`PrayerRoute`, `AzkarRoute`, …).
- Per-flow router objects owning `NavigationPath`/sheet/full-screen state, composed by an app-level coordinator that also handles deep links (widget taps, notifications).
- ViewModels emit navigation *events*; routers translate them to path mutations.

Android mirrors this with per-feature Navigation-Compose graphs composed in `:app`; ViewModels emit navigation events, never call navigation APIs.

## Consequences
Deep links (widget → prayer screen, notification → azkar session) are first-class from M1. Flow logic is unit-testable without UI. Satisfies the foundation's MVVM-C intent in the platform's idiom.
