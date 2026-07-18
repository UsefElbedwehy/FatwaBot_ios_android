# M5.0 Build Spec — AI Fatwa Search (text-source RAG)

Status: **spec / awaiting approval**. Implementation-level plan for the first slice of
M5 (see the design doc [ai-search.md](ai-search.md) for the product vision + non‑negotiables).
This spec is what we build against once approved; nothing here is coded yet.

## Scope of M5.0 (what this slice does, and does NOT)
**Does:** the entire RAG machine for **text (web) sources only** — schema, admin
ingestion + chunking, embeddings, hybrid retrieval, a grounded/cited answer endpoint,
the Home "Ask" wiring, and full tests — all behind **pluggable provider interfaces** with
a **dev-stub**, so it is built and tested before any API key, cost, or copyright clearance.

**Does NOT (deferred):** audio/video transcription (M5.1), answer-quality tuning + abuse
limits (M5.2). No real provider keys are needed to build or test M5.0.

## Decisions locked in
| Concern | Decision | Rationale |
|---|---|---|
| Vector store | **pgvector in the existing Supabase** | No new infra; RLS-protected; already live |
| Embeddings | **Voyage `voyage-4`** (1024‑dim), `voyage-4-lite` budget option | Anthropic-recommended, strong Arabic; 200M free tokens; supersedes voyage‑3 at same price |
| Answer LLM | **Behind `AnswerProvider` interface; default Claude Haiku 4.5** (cheapest ~0.6¢/Q) | Cheapest single-provider option with strong Arabic + grounding/refusal. Sonnet 5 swappable per-query for hard questions. |
| Retrieval | **Hybrid**: pgvector cosine + Postgres full‑text (`tsvector`), Reciprocal Rank Fusion | Vector catches paraphrase; keyword catches exact terms/names |
| Build strategy | Providers behind interfaces + **dev-stub**; flip to real keys at go-live | Whole machine built + tested with zero external cost |

## Architecture (M5.0 subset of the full pipeline)
```
ADMIN (ingest, text sources only)
  paste/URL text → clean → CHUNK (verbatim spans + offsets)
    → EmbeddingProvider.embed(chunk[]) → store row + vector in fatwa.chunks

USER (ask)
  POST /v1/search {question}
    → EmbeddingProvider.embed(question)
    → hybrid retrieve top-K vetted chunks (vector + keyword, RRF)
    → AnswerProvider.answer(question, chunks) → grounded answer + citations,
      or refusal if retrieval is empty/weak
    → record to search history (existing) + fatwa.answers_log
```

## Data model — migration `0011_fatwa_schema.sql`
New `fatwa` schema (mirrors [ai-search.md](ai-search.md) §Data model, with concrete types):
- `fatwa.scholars` — `id`, `name_translations jsonb`, `site_url`, `youtube_url`, `active bool`.
- `fatwa.sources` — `id`, `scholar_id fk`, `kind text check in ('web','video','book')`,
  `url`, `title`, `published_at`, `license_status text check in ('granted','pending','unknown')`,
  `ingested_at`.
- `fatwa.documents` — `id`, `source_id fk`, `original_text text`, `transcript text null`, `lang text`.
- `fatwa.chunks` — `id`, `document_id fk`, `text text` (verbatim span), `start_offset int`,
  `end_offset int`, `video_timestamp int null`, `embedding vector(1024)`, `tsv tsvector`,
  `ordinal int`.
- `fatwa.answers_log` — `id`, `question`, `retrieved_chunk_ids uuid[]`, `model text`,
  `answer text`, `citations jsonb`, `refused bool`, `created_at`.
- Indexes: `ivfflat`/`hnsw` on `chunks.embedding` (cosine), GIN on `chunks.tsv`.
- **RLS**: app (anon/bearer) gets **read-only** on `chunks/documents/sources/scholars`
  filtered to `license_status='granted'` + `active`; writes are service-role/admin only.
- `create extension if not exists vector;` guarded at top.

## Provider interfaces (the pluggable seam)
`backend/functions/api/ai_search/providers.ts`:
```ts
export interface EmbeddingProvider {
  /** Returns one 1024-dim vector per input, order-preserving. */
  embed(texts: string[]): Promise<number[][]>;
  readonly dimensions: number;
  readonly id: string; // "voyage-4" | "dev-stub"
}
export interface AnswerCitation { chunkId: string; scholar: string; sourceUrl: string; quotedText: string; }
export interface AnswerResult { answer: string; citations: AnswerCitation[]; refused: boolean; model: string; }
export interface AnswerProvider {
  /** MUST ground answer only in `chunks`; MUST refuse (refused=true) if they don't answer. */
  answer(question: string, chunks: RetrievedChunk[], locale: string): Promise<AnswerResult>;
  readonly id: string; // "claude-sonnet-5" | "dev-stub"
}
```
- **Dev-stub `EmbeddingProvider`**: deterministic hash→vector (stable, no network) so
  retrieval math is testable end-to-end.
- **Dev-stub `AnswerProvider`**: returns a fixed grounded answer echoing the top chunk +
  its citation, and `refused=true` when `chunks` is empty. Lets us test the full endpoint,
  refusal path, and logging with zero cost.
- **Real `VoyageEmbeddingProvider`**: POST `api.voyageai.com/v1/embeddings`, `model=voyage-4`,
  `VOYAGE_API_KEY` secret; `fetch` injectable (mirrors `FcmSender` test pattern).
- **Real `ClaudeAnswerProvider`**: Anthropic SDK / HTTP v1 messages, default `claude-haiku-4-5`
  (model configurable per-query so hard questions can escalate to `claude-sonnet-5`),
  `ANTHROPIC_API_KEY` secret, adaptive thinking off (deterministic), a strict system prompt
  that forbids using anything outside the passages and mandates the refusal sentinel.
  `index.ts` builds real providers when both secrets are present; otherwise dev-stub.

## Chunking (`ai_search/chunking.ts`, pure + tested)
- Split `original_text` into passages of ~400–700 tokens on sentence/paragraph boundaries,
  ~15% overlap, **never splitting mid-sentence**.
- Each chunk keeps exact `start_offset`/`end_offset` into the source text → citations can
  quote **verbatim** and (later) deep-link. Pure function, golden-corpus tested.

## Retrieval (`ai_search/retrieval.ts`)
- Embed the question → pgvector `ORDER BY embedding <=> $q LIMIT k_vec` (k≈20).
- Parallel keyword: `ts_rank(tsv, plainto_tsquery('arabic', $q))` top‑k.
- **Reciprocal Rank Fusion** merge → top‑N (N≈6) passed to the answer layer.
- Only `license_status='granted'` + `active` rows (enforced in SQL, not just RLS).

## Answer contract (`handlers/search.ts`, route `POST /v1/search`)
- Request: `{ "question": string (1..1000 chars) }`, bearer-auth (existing middleware).
- Behavior: retrieve → `AnswerProvider.answer` → log to `answers_log` + search history.
- Response `200`: `{ answer, citations:[{scholar, source_url, quoted_text, timestamp?}], refused }`.
- **Refusal is a success, not an error**: `refused=true`, `answer` = the "no vetted source
  answers this" message (localized), empty citations.
- `503 ai_unavailable` when no real `AnswerProvider`/`EmbeddingProvider` is configured
  (mirrors the FCM `503 push_unavailable` pattern) — so the endpoint ships safely pre-keys.
- Per-user rate limit + response cache: **M5.2** (documented, not built here).

## App wiring (both platforms)
- Home "Ask" section (currently `coming_soon`) → query box → **Answer screen**:
  the answer, the scholar name, and tappable citations (open source URL). Video-timestamp
  deep-links wait for M5.1. Records to the existing search history (Journey tab).
- iOS (SwiftUI) + Android (Compose) parity, using existing `AuthenticatedApiClient`.

## Tests
- `chunking_test.ts` — boundaries, overlap, offset integrity (golden corpus).
- `retrieval_test.ts` — RRF ordering, keyword+vector fusion, license/active filter (in-memory + stub embeddings).
- `search_test.ts` — endpoint: grounded answer, **refusal on empty retrieval**, auth required,
  `503` when providers absent, answers_log written.
- `voyage_provider_test.ts` — request shape + response parse with fake `fetch`.
- Target: keep the suite green (currently 105); add ~12–15 tests.

## What's yours (gates for go‑live, NOT for building M5.0)
1. **Copyright/permission** — which scholar sources are cleared to ingest + republish. We
   ingest only `license_status='granted'`.
2. **Provider keys** — `VOYAGE_API_KEY` + the answer-LLM key (Anthropic), set as Supabase
   secrets. Until then the endpoint returns `503` and everything runs on the dev-stub.
3. **Answer-LLM pick — DECIDED: Claude Haiku 4.5** (cheapest single-provider). Swappable
   per-query; hard questions can escalate to Sonnet 5 later with no rebuild.

## Build order (once approved)
1. `0011_fatwa_schema.sql` + repos (admin CRUD for scholars/sources/documents; read for chunks).
2. `chunking.ts` + tests.
3. `providers.ts` + dev-stub + `retrieval.ts` + tests.
4. `handlers/search.ts` + route + `search_test.ts`; wire optional real providers in `index.ts`.
5. Real `VoyageEmbeddingProvider` + `ClaudeAnswerProvider` (behind the secrets) + provider test.
6. App: iOS + Android Ask → Answer screen.
7. `deno test` green, deploy, CHANGELOG + memory.
```
```
