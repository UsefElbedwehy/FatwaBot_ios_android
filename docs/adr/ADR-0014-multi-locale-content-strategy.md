# ADR-0014: Multi-locale content strategy (Arabic-first, 16+ language ambition)

- **Status:** Accepted 2026-07-04
- **Date:** 2026-07-04

## Context
The concept demo's language picker lists 16+ languages (Urdu, Hindi, Bengali, Nepali, Sinhala, Malay, Indonesian, Turkish, Somali, French, Swahili, Filipino, Hausa…). Retrofitting multi-locale content is expensive; supporting it structurally from day one is cheap.

## Decision
1. **Every content entity is multi-locale by schema**: azkar, duas, hadith collections + benefit notes, wird templates, mission/badge copy, notification templates, announcements, onboarding slides — stored as `{field}_translations: {locale: value}` with **Arabic as the canonical source** and per-locale publishing state (a locale ships only when its translation is reviewed).
2. **Supported languages are backend-driven** (ADR-0011 remote config): the picker lists what the server enables; adding a language = enabling it + publishing translated string packs and content — no app release. Script metadata per locale (direction, font stack, Eastern/Western digits) travels with the config.
3. **Apps ship font support pragmatically**: Arabic + Latin fonts bundled; other scripts (Devanagari, Bengali, Sinhala…) use platform system fonts — no 40 MB font payloads.
4. **Launch scope is a product decision** (OPEN_QUESTIONS Q7): recommendation remains Arabic + English at launch with the pipeline proven by translating one additional locale end-to-end in beta.
5. Religious-content translations require **reviewed human translation** (dashboard workflow states: machine-draft → human review → published). AI-assisted drafts allowed; never auto-published.

## Consequences
Content tables carry translation maps from M2 onward; the dashboard CMS gets locale tabs + review states; string-pack tooling (export/import for translators) is part of the dashboard content module. UI copy and worship content scale to new markets without mobile releases.
