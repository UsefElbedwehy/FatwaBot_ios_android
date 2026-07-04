# Changelog

All notable changes to this project are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/); milestone-based until first release.

## [Unreleased]

### 2026-07-04 — Planning phase
- Transcribed the foundation PDF into canonical [prompts/00_PROJECT_FOUNDATION.md](prompts/00_PROJECT_FOUNDATION.md).
- Added planning package: project analysis, architecture, architecture review, roadmap (M0–M7), design direction + Home screen spec, ADR-0001…0010 (all Proposed), open questions, future improvements, README.
- Flagged missing `design/` concept-demo assets and absent git initialization.
- **Gate:** awaiting stakeholder approval before Milestone 0 implementation.

### 2026-07-04 — Planning pass 2 (design review + configurability requirements)
- Reviewed the 22 concept screens added in `App Demo design/` → [docs/06_DESIGN_REVIEW.md](docs/06_DESIGN_REVIEW.md); adopted the FATWA BOT brand (maroon/cream, mihrab-arch motif) into the design direction.
- New modules from the designs: **Awrad (personal wird routines)** and **Hadith Collections (الأربعون learning)** — added to roadmap M2; rejected the demo's in-app secret-code admin panel.
- New ADRs for the backend-configurability philosophy: ADR-0011 (server-driven config, theme, strings, Home layout), ADR-0012 (leaderboards/streaks/missions as data), ADR-0013 (notification campaign engine), ADR-0014 (multi-locale content).
- Updated architecture (config platform §3a, schema domains, campaign engine, AI provider routing), roadmap (M0–M3 scope), open questions (Q1 resolved; new Q2b–Q2d).
- **Gate:** awaiting stakeholder approval of pass-2 updates before Milestone 0.

### 2026-07-04 — Final approval & implementation start
- Stakeholder approved architecture, roadmap, and documentation; all ADRs 0001–0014 marked **Accepted**.
- Final directives folded in: ADR-0015 (configurable-by-default + tenancy-ready schemas); Home spec rebalanced for the dual identity (AI assistant + daily companion — AI section above the fold, daily hadith/dua, featured content, quick actions/widget shortcuts sections added to the catalog); ADR-0008 extended (provider priority, fallback chains, sampling params, safety policies, cost metering); ADR-0013 extended (segmentation, delivery/open analytics, A/B-ready templates); ADR-0009 dashboard scope = operational control center; CMS block model (rich text, images, video, audio, PDF, markdown, sanitized HTML); analytics pipeline domain added.
- Repository initialized under git. **Milestone 0 implementation begins.**
