# Feature Spec — AI Fatwa Search (M5, the core)

Status: **design**. This is the product's reason to exist and its largest build.
Nothing here is implemented yet; it defines the architecture and the decisions needed.

## Goal
Answer a user's religious question with **source-accurate** fatwas from **vetted,
named scholars** — where the quoted text matches the original source *exactly* (the two
failures the stakeholder saw in other apps: text not matching the source, and text not
matching the video).

## Non-negotiables
1. **Exact quotes + correct citation.** Every answer shows the scholar, the source
   (page/URL/video + timestamp), and text that is verbatim from that source.
2. **Vetted scholars only.** Restricted to the approved source list
   (docs/PRODUCT_REQUIREMENTS_2026-07.md) — no open-web answers.
3. **No fabrication.** If no vetted source answers the question, say so — never invent.
4. **On-device stays offline-first for prayer/worship;** AI search is online-only (it
   needs the server + models) and degrades gracefully when offline.

## Pipeline (server-side, Supabase + workers)
```
Source (site / YouTube)
  → 1. INGEST      pull text, or download audio
  → 2. TRANSCRIBE  audio/video → accurate Arabic transcript (with timestamps)
  → 3. NORMALIZE   clean, attribute (scholar, source URL, date), keep original text
  → 4. CHUNK       split into passages, preserve exact spans + citations
  → 5. EMBED       vector embeddings per chunk → pgvector table in Supabase
  → 6. INDEX       keyword + vector (hybrid) index
Query time:
  user question
  → 7. RETRIEVE    hybrid search (vector + keyword) over vetted chunks
  → 8. ANSWER      LLM composes an answer that QUOTES retrieved chunks verbatim,
                   with citations; refuses if retrieval is empty/weak
  → 9. RECORD      into search history (already built) for the Journey tab
```

## Data model (new `fatwa` schema, Supabase)
- `fatwa.scholars` — id, name (ar/en), site_url, youtube_url, active.
- `fatwa.sources` — id, scholar_id, kind (`web`|`video`|`book`), url, title, published_at,
  license_status (`granted`|`pending`|`unknown`), ingested_at.
- `fatwa.documents` — id, source_id, original_text, transcript (nullable), lang.
- `fatwa.chunks` — id, document_id, text (verbatim span), start/end offsets,
  video_timestamp (nullable), embedding `vector(N)`, tsv (keyword index).
- `fatwa.answers_log` — question, retrieved_chunk_ids, model, answer, citations, created_at
  (for QA + abuse monitoring).
All admin-managed via the existing `/admin/v1` CRUD pattern; served read-only to the app
via a new `/v1/search` endpoint.

## Decisions needed from you (blockers before build)
1. **⚖️ Copyright / permission (must resolve first).** Republishing scholars' fatwas and
   transcribing their videos needs the rights holders' permission, or a clear fair-use
   basis. "Trusted & authoritative" should also mean "used with permission." Which sources
   have you cleared? (Some, e.g. Ibn Baz / Ibn Uthaymeen official sites, publish for free
   redistribution; others may not.) We ingest **only cleared sources**.
2. **Transcription engine.** For Arabic audio→text with timestamps: options are OpenAI
   Whisper (self-host, free compute cost only) vs. a hosted API (Google/Azure/ElevenLabs).
   Arabic religious speech (classical, tajweed) needs a strong model — Whisper large-v3 is
   the usual choice. Cost scales with hours of audio.
3. **Embeddings + LLM.** Arabic-strong models: embeddings (e.g. multilingual-e5, OpenAI
   text-embedding-3, Cohere) and the answer LLM (must be strong in Arabic + good at "quote
   only from context"). Hosted API vs. self-host — cost & privacy trade-off.
4. **Vector store.** Recommend **pgvector inside your existing Supabase** (no new
   infra, RLS-protected) unless volume demands a dedicated vector DB later.
5. **Cost ceiling.** Transcription + embeddings are one-time per source; answering is
   per-query LLM cost. We'll want a per-user rate limit + cache.

## Phasing
- **M5.0** — schema + admin ingestion for **web (text) sources only** (no transcription
  yet): pull, chunk, embed, hybrid retrieval, cited answers. Proves the whole loop cheaply
  on the sites that are already text.
- **M5.1** — **transcription pipeline** for YouTube/audio sources (the harder, costlier
  half), with timestamped citations.
- **M5.2** — quality: answer-refusal tuning, abuse/rate limiting, feedback loop, caching.

## App side (both platforms)
The Home "Ask" section already exists (currently `coming_soon`). M5 wires it to
`/v1/search`: query box → answer screen showing the answer, the scholar, and a tappable
citation (opens the source / jumps to the video timestamp). Recorded to search history.

## What I need to start M5.0
- Your **copyright decision** (which sources are cleared) — the gate.
- Your pick on **transcription + LLM/embedding provider** (I can recommend a default:
  Whisper large-v3 for transcription, pgvector + a strong Arabic-capable hosted LLM for
  retrieval/answering — but the cost is yours to approve).
Once those are set, M5.0 (text sources) can start immediately since Supabase is now live.
