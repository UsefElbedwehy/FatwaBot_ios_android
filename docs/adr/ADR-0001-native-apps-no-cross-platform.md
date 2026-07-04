# ADR-0001: Native SwiftUI + Jetpack Compose; no cross-platform framework

- **Status:** Accepted 2026-07-04 (endorses foundation)
- **Date:** 2026-07-04

## Context
Two native apps duplicate feature work. KMP could share the domain layer; Flutter/RN could share everything.

## Decision
Fully native per the foundation: SwiftUI (iOS 17+) and Jetpack Compose. No KMP for now.

## Rationale
The product's differentiators are exactly the things cross-platform is worst at: widgets (WidgetKit/Glance), sensor-heavy Qibla, reliable local notifications, platform-premium feel, Live Activities later. The hardest shared logic (prayer calculation) already exists as mature native libraries on both platforms. KMP adds toolchain complexity and hiring constraints for modest savings.

## Consequences
Feature work is specified once (`docs/features/`) and implemented twice; parity enforced via shared OpenAPI DTOs, mirrored module layout, same analytics events. Revisit KMP only if domain-logic drift becomes a recurring bug source.
