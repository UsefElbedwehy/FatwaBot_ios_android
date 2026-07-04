# ADR-0010: Monorepo with mirrored feature-first modularization

- **Status:** Accepted 2026-07-04 (endorses foundation)
- **Date:** 2026-07-04

## Context
Four deliverables (iOS, Android, backend, dashboard) share contracts, content, and documentation and are built by one team.

## Decision
Single repository, layout per [02_ARCHITECTURE.md §2](../02_ARCHITECTURE.md). Feature-first modules on both mobile platforms with an enforced dependency rule:

```
app → feature/* → core/* (domain, network, persistence, common) and designsystem
feature → feature is forbidden; cross-feature flows compose at app level.
```

- iOS: features and core as SPM packages; App target is the composition root.
- Android: Gradle convention plugins enforce module structure and the dependency rule.
- Shared truth: `backend/openapi/*.yaml` (API contract), `content/` (seed content), `docs/features/*.md` (single-source feature specs implemented on both platforms).

## Consequences
Atomic cross-platform changes (API + both clients in one PR); CI paths-filtered per platform. Module boundaries make the "extend for years" goal enforceable rather than aspirational.
