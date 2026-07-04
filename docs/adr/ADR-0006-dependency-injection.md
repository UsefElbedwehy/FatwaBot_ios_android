# ADR-0006: Dependency injection — Factory (iOS), Hilt (Android)

- **Status:** Accepted 2026-07-04 (interprets the foundation's "Factory Dependency Injection" per platform)
- **Date:** 2026-07-04

## Context
Factory (hmlongco/Factory) is an iOS-ecosystem library. Android has no idiomatic equivalent; hand-rolled factory containers there would be a liability.

## Decision
- iOS: **Factory** — container-based, compile-safe registrations in each module's composition file; test overrides via container scopes.
- Android: **Hilt** — compile-time DI, per-module bindings, test replacement via `@TestInstallIn`.

## Rationale
Same intent on both platforms (compile-time-safe container DI with easy test doubles), each in its ecosystem's standard tool. Repository interfaces live in domain modules, so DI wiring stays at the edges.

## Consequences
DI registration is part of each feature module's public surface; no service locators in feature code; ViewModels receive use cases, not repositories.
