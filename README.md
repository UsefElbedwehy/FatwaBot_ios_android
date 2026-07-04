# Fatwa Bot Platform

An AI-powered **Islamic Companion Platform**: iOS (SwiftUI), Android (Jetpack Compose), a versioned REST backend over Supabase, and a web Admin Dashboard. Worship tools (Prayer, Qibla, Azkar, Dua, Tasbeeh, streaks/challenges) are first-class; AI features (fatwa search, hadith extraction, general questions) follow with citation-mandatory answers from curated sources.

> **Current status: planning phase complete — awaiting stakeholder approval before implementation (Milestone 0).**

## Source of truth

[prompts/00_PROJECT_FOUNDATION.md](prompts/00_PROJECT_FOUNDATION.md) — the product foundation (transcribed from the original PDF in the repo root).

## Documentation map

| Document | Purpose |
|---|---|
| [docs/01_PROJECT_ANALYSIS.md](docs/01_PROJECT_ANALYSIS.md) | Repo state, domain analysis, risks |
| [docs/02_ARCHITECTURE.md](docs/02_ARCHITECTURE.md) | System, mobile, backend, notification, widget, AI architecture |
| [docs/03_ARCHITECTURE_REVIEW.md](docs/03_ARCHITECTURE_REVIEW.md) | Challenged decisions: amendments & endorsements |
| [docs/04_ROADMAP.md](docs/04_ROADMAP.md) | Milestones M0–M7 with exit criteria |
| [docs/05_DESIGN_DIRECTION.md](docs/05_DESIGN_DIRECTION.md) | Design system + Home screen redesign spec |
| [docs/06_DESIGN_REVIEW.md](docs/06_DESIGN_REVIEW.md) | Screen-by-screen review of the concept demos (`App Demo design/`) |
| [docs/adr/](docs/adr/README.md) | Architecture Decision Records (all Proposed) |
| [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md) | Decisions needing stakeholder input |
| [docs/FUTURE_IMPROVEMENTS.md](docs/FUTURE_IMPROVEMENTS.md) | Parked ideas |
| [CHANGELOG.md](CHANGELOG.md) | Change history |

## Planned repository layout

See [docs/02_ARCHITECTURE.md §2](docs/02_ARCHITECTURE.md): `backend/` (Supabase migrations, edge functions, OpenAPI), `ios/`, `android/`, `dashboard/` (Next.js), `content/` (seed worship content), `docs/`, `prompts/`, `design/` (reference designs — currently missing, see OPEN_QUESTIONS Q1).

## Known gaps at planning time

- Repository is not yet under git; initialization is scheduled for Milestone 0.
- Credentials (Supabase, Firebase, store accounts) required before M0 exit — see OPEN_QUESTIONS Q8.
