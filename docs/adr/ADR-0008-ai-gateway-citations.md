# ADR-0008: Server-side AI gateway with provider abstraction and citation-mandatory answers

- **Status:** Accepted 2026-07-04 (endorses foundation; fixes interfaces now, implementation deferred to M5–M6)
- **Date:** 2026-07-04

## Context
The foundation requires trusted sources, references on every answer, and replaceable providers. AI ships after the مزايا section, but Home design and Search History depend on its shape.

## Decision
- All AI runs server-side behind `AIGateway` (interface) with provider adapters (Anthropic, OpenAI, Google Gemini, Azure OpenAI, local/self-hosted); mobile apps never hold provider keys and **never know which provider served a request**.
- Dashboard-controlled (versioned config): provider registry, **provider priority + fallback chain**, per-feature model selection, temperature, max tokens, prompt/system-prompt templates, knowledge bases, fatwa/scholar source registries, per-feature availability, and safety policies (refusal boundaries, moderation thresholds). Token consumption and cost are metered per request and surfaced in dashboard AI-usage/cost monitoring.
- Retrieval-augmented answers over an **admin-curated knowledge base** (fatwa sources, hadith collections; pgvector) with source-tier ranking controlled from the dashboard.
- Response contract fixed now: `answer + citations[] + confidence + refusal`. Fatwa-class questions **without adequate sources return a structured refusal** with scholar-referral messaging — never an uncited answer.
- Endpoints: `/v1/ai/fatwa-search`, `/v1/ai/hadith-extract`, `/v1/ai/question` (streaming). Queries feed the Search History module.
- Rate limiting, abuse moderation, and an expert-reviewed evaluation set gate launch.

## Consequences
Home's "Ask" section and Search History are built against this contract before any AI exists (feature-flag hidden). Provider swap is a server-side adapter change.
