# M5.0 Build Spec — AI Fatwa Search over the Ibn Uthaymeen corpus

Status: **spec / in progress**. Revises the original "text (web) sources" M5.0 slice
after the actual M5 corpus arrived: **312 scanned PDF books by Ibn Uthaymeen رحمه الله,
159,421 pages, 3.3 GB**, organized into 12 categories (عقيدة، فقه, حديث، تفسير، فتاوى
ولقاءات، خطب، سيرة، ...). See [ai-search.md](ai-search.md) for the product vision +
non-negotiables, which this still follows exactly.

## What changed from the original M5.0 slice, and why

The original spec assumed clean web text. The real corpus is **scanned page images with
zero embedded text** (verified: `pdftotext` returns nothing on every sampled book — these
are photographed/scanned pages, not digital-native PDFs). So M5.0 now has an OCR stage the
old spec didn't need, and the source `kind` is `book`, not `web` — the schema already
anticipated this (`kind check in ('web','video','book')`), so no schema redesign, just a
different ingestion path filling it.

Two other changes driven by the real data:
- **Multi-scholar schema from day 1**, even though today's corpus is one scholar. The
  reference app (client-provided screenshots) shows fatwa answers as one card per scholar
  under a synthesized "خلاصة الأقوال" — that shape only works if `scholars` was never
  singular to begin with. Adding a second scholar later is new rows, not a migration.
- **Three answer *modes*, not one.** ابحث عن فتوى / استخراج الأحاديث / سؤال ديني عام share
  one retrieval+answer machine but differ in retrieval weighting, output shape, and prompt
  — see §Modes below.

## Non-negotiable, restated for this corpus
Every answer must be traceable to a specific **page** in a specific **book** by this
corpus's scholar — never the model's own knowledge, never a source outside `fatwa.chunks`.
Enforced in code (§Citation verification), not just prompted.

## ⚖️ Still the gate, not a blocker to building
`fatwa.sources.license_status` defaults every ingested book to **`pending`**, and
retrieval only ever reads `license_status='granted'` rows (already enforced in SQL per the
original spec). That means: **the whole pipeline can be built and the pilot can run
end-to-end right now**, with real answers visible only to admin/QA (a debug flag bypasses
the filter in non-prod), and *nothing* serves to real users until you explicitly flip
sources to `granted`. Confirm the redistribution basis for this corpus before that flip —
it's a switch, not a rebuild.

## Pipeline (offline ingestion, once per book — NOT at request time)
```
PDF (scanned)
  → 1. RENDER      pdftoppm, one PNG per page (150dpi — proven sufficient, see pilot)
  → 2. OCR         vision model reads each page image → Markdown, preserving tashkeel,
                    ﷺ/ﷻ glyphs, question/answer structure; embeds a page-break marker
  → 3. ASSEMBLE    per-book Markdown = concatenated pages, in fatwa.documents.original_text
  → 4. CHUNK       split on paragraph/question boundaries (~400–700 tokens, ~15% overlap),
                    each chunk keeps the page number(s) it came from — never split a page
                    marker out of a chunk
  → 5. EMBED       EmbeddingProvider.embed(chunk[]) → fatwa.chunks.embedding
  → 6. INDEX       tsvector (Arabic FTS) + trigram (pg_trgm, for the "extract this hadith
                    from partial/misremembered wording" mode) + vector, all on fatwa.chunks
Query time (unchanged shape from the original spec, mode changes retrieval weighting):
  question → embed → hybrid retrieve (vector + FTS + trigram, RRF) → AnswerProvider →
  citation-verify → response, logged to fatwa.answers_log
```

OCR runs **once per book, offline** — never in the request path. A page that's already
been OCR'd is never re-processed (idempotent by `(source_id, page_number)`).

## OCR: what "AI OCR" means here, and the pilot that grounds this plan
Modern OCR *is* a vision model reading the page image and writing text — the same
technology as the model writing this spec, just run as a batch job instead of a
conversation. Confirmed directly against this corpus, not assumed: I rendered real pages
from `العقيدة/شرح ثلاثة الأصول` and `الفتاوى واللقاءات/فتاوى أركان الإسلام` and
transcribed them by reading the page images — full tashkeel, ﷺ/ﷻ symbols, and
question/answer structure all came through correctly. Scan quality across the sample is
high. Pilot artifacts are in `backend/scripts/ai_ingest/pilot_output/` (§Pilot below).

**Provider for the real 159k-page batch is not chosen yet** — that needs a decision + an
API key, since transcribing at this volume conversationally doesn't scale. Candidates,
same trade-off the original spec flagged for embeddings/LLM:
- **Gemini 2.5 Flash / Pro** (vision) — cheapest at this volume, strong Arabic OCR track record.
- **Mistral OCR** — purpose-built OCR API, competitive prices, native Markdown output.
- **Claude** (via the same `ANTHROPIC_API_KEY` the answer LLM uses) — highest quality bar,
  costs more at 159k pages; reasonable choice for a second-opinion pass on low-confidence pages.

Recommendation: pilot **Gemini 2.5 Flash and Mistral OCR** side-by-side on the same
5-book sample the manual pilot used, compare against the manual transcription as ground
truth, pick on quality-per-dollar. Rough all-in cost at this volume either way:
**$150–$400 one-time.** Needs an API key from you to run — nothing else blocks it.

## Modes
All three share retrieval + citation-verification; they differ in weighting and prompt.

| Mode | Retrieval weighting | Answer shape |
|---|---|---|
| **ابحث عن فتوى** | favors `فتاوى واللقاءات` sources | one card **per scholar** that answered + a synthesized "خلاصة الأقوال" — matches the reference app exactly |
| **استخراج الأحاديث** | trigram-heavy (matches *approximate/misremembered* wording) + existing hadith DB | authentic wording + grading + source, or explicit "لا يوجد حديث بهذا اللفظ" + closest real matches — matches the reference app's behavior on a hadith that doesn't exist as quoted |
| **سؤال ديني عام** | whole-corpus, vector-heavy | one grounded answer + evidence + citation |

## Data model — migration `0011_fatwa_schema.sql`
Extends the original spec's schema (unchanged tables/columns keep their shape):
- `fatwa.scholars` — unchanged.
- `fatwa.sources` — `kind='book'` rows: `url` is **nullable** (books have no URL; store the
  original filename in a new `origin_path text null`, useful for re-ingestion/audit), add
  `category text null` (عقيدة/فقه/حديث/... — powers the فتوى-mode weighting above and an
  admin filter), add `total_pages int null`.
- `fatwa.documents` — `original_text` for a book is the **full OCR'd Markdown for that
  book**, with an inline marker `<!-- page:N -->` before each page's content. One row per
  book (312 rows), not per page — keeps the table small; page granularity lives in chunks.
- `fatwa.chunks` — add `page_number int null` (alongside the existing `video_timestamp
  int null` for future video sources — exactly one of the two is set per chunk). Add a
  `pg_trgm` GIN index on `text` for mode 2's approximate-wording search, alongside the
  existing `tsv`/`embedding` indexes.
- `fatwa.answers_log` — add `mode text check in ('fatwa','hadith','general')`.
- RLS/extension guards: unchanged from the original spec (`create extension if not
  exists pg_trgm;` added alongside the existing `vector` guard).

## Citation verification (new — the enforcement half of "no fabrication")
Before an `AnswerProvider` result reaches the user, the backend verifies **every**
`citations[].quotedText` is a **substring match** (normalized: strip tashkeel, unify
alef/ya variants — same normalizer retrieval uses) of the `fatwa.chunks.text` for that
`chunkId`. A citation that fails verification drops that claim and, if it was the answer's
only support, flips the response to a refusal rather than shipping an unverifiable claim.
This is what makes "the AI can only reference this data" a property of the code, not a
prompt instruction the model could ignore.

## YouTube captions (documented, not built this pass — no video sources in this corpus yet)
When a video source is added: pull the existing caption track (not full audio
transcription — that stays M5.1's harder/costlier case for un-captioned video), run the
same AI-cleanup pass OCR gets (fixing auto-caption punctuation/errors), store with
`video_timestamp` instead of `page_number`. Answer citations for these are marked as
"معالَج من التفريغ الآلي" rather than presented as verbatim-book quotes, and the app's
"مشاهدة" action opens the source video at that timestamp.

## Everything else — provider interfaces, chunking mechanics, retrieval (RRF), the
`/v1/search` contract, app wiring, and the test plan — is **unchanged from the original
spec** below; only the ingestion source and the three-mode split are new.

### Decisions locked in (unchanged)
| Concern | Decision | Rationale |
|---|---|---|
| Vector store | **pgvector in the existing Supabase** | No new infra; RLS-protected; already live |
| Embeddings | **Voyage `voyage-4`** (1024‑dim), `voyage-4-lite` budget option | Anthropic-recommended, strong Arabic; 200M free tokens |
| Answer LLM | **Behind `AnswerProvider` interface; default Claude Haiku 4.5** | Cheapest single-provider option with strong Arabic + grounding/refusal; Sonnet 5 swappable per-query |
| Retrieval | **Hybrid**: pgvector cosine + Postgres FTS + pg_trgm, Reciprocal Rank Fusion | Vector catches paraphrase; FTS catches exact terms; trigram catches misremembered hadith wording |
| Build strategy | Providers behind interfaces + **dev-stub**; flip to real keys at go-live | Whole machine built + tested with zero external cost |

### Provider interfaces (`backend/functions/api/ai_search/providers.ts`)
```ts
export interface EmbeddingProvider {
  embed(texts: string[]): Promise<number[][]>;
  readonly dimensions: number;
  readonly id: string; // "voyage-4" | "dev-stub"
}
export interface AnswerCitation { chunkId: string; scholar: string; sourceTitle: string; pageNumber?: number; videoTimestamp?: number; quotedText: string; }
export interface AnswerResult { answer: string; citations: AnswerCitation[]; refused: boolean; model: string; }
export interface AnswerProvider {
  answer(question: string, mode: "fatwa" | "hadith" | "general", chunks: RetrievedChunk[], locale: string): Promise<AnswerResult>;
  readonly id: string;
}
```
Dev-stub versions of both (deterministic hash-vector embedder; fixed grounded-echo
answerer that refuses on empty retrieval) let the whole endpoint, retrieval math, and
citation-verification path be tested with zero network calls — same pattern as
`FcmSender`'s test double elsewhere in this backend.

### Chunking (`ai_search/chunking.ts`, pure + tested)
Split on paragraph/question boundaries, ~400–700 tokens, ~15% overlap, never mid-sentence;
tracks exact offsets **and** the page marker(s) spanned, so a chunk that straddles a page
break still cites correctly (cite the page the majority of the chunk's text is on).

### Retrieval (`ai_search/retrieval.ts`)
Embed the question → vector top-k (~20) ∥ FTS top-k ∥ trigram top-k (mode 2 only,
similarity threshold tuned in the pilot) → RRF merge → top-N (~6-8) → answer layer. Only
`license_status='granted'` + `active` rows, enforced in SQL.

### Answer contract (`handlers/search.ts`, `POST /v1/search`)
`{ question, mode }` → retrieve → `AnswerProvider.answer` → **citation-verify** → log to
`answers_log` + existing search history → `{ answer, citations[], refused, mode }`.
Refusal is a success (`refused=true`, localized "no vetted source" message, empty
citations), not an error. `503 ai_unavailable` pre-keys, mirroring the FCM pattern.

### App wiring (both platforms)
Home "Ask" → **three entry points** matching the reference app (سؤال ديني عام / استخراج
الأحاديث / ابحث عن فتوى) → mode-appropriate answer screen. **Loading state**: the app
logo with a rotating dhikr line (سبحان الله / الحمد لله / الله أكبر / لا إله إلا الله) —
covers LLM latency without a bare spinner, per your reference. Citations are tappable;
book citations show page number (deep-linking to an in-app reader is a later nice-to-have,
not M5.0 — v1 just shows the quote + page number + book title). Records to search history.

### Tests
`chunking_test.ts` (boundaries, overlap, page-marker integrity), `retrieval_test.ts` (RRF,
trigram fusion, license/active filter), `citation_verify_test.ts` (**new** — catches a
fabricated/mismatched quote, catches a correct one), `search_test.ts` (endpoint incl. all
3 modes, refusal, auth, 503), `voyage_provider_test.ts`. Target: keep the suite green
(currently 105+); add ~18–22 tests.

## What's yours (gates for go-live, not for building)
1. **Copyright/redistribution basis for this corpus** — confirm before flipping any
   `license_status` to `granted`. Everything up to that flip is buildable and testable now.
2. **OCR batch provider + API key** (Gemini 2.5 Flash vs. Mistral OCR — pilot both, ~$150–400 one-time).
3. **Embedding + answer-LLM keys** — `VOYAGE_API_KEY`, `ANTHROPIC_API_KEY` (Supabase secrets).
4. Whichever provider you pick for OCR, its key too.

## Build order
1. **OCR pilot** — automated (not manual) side-by-side on the 5-book sample once a
   provider key is available; compare to the manual transcription; pick a provider.
2. `0011_fatwa_schema.sql` (scholars/sources/documents/chunks/answers_log + pg_trgm).
3. Ingestion script: render → OCR (chosen provider) → assemble → chunk → embed → load.
   Run across the full corpus (offline, hours not minutes at 159k pages — batched/resumable).
4. `chunking.ts` + `citation-verify` + tests.
5. `providers.ts` (dev-stub + real Voyage/Claude) + `retrieval.ts` (incl. trigram) + tests.
6. `handlers/search.ts` (3 modes) + route + tests; wire real providers in `index.ts`.
7. App: iOS + Android, 3 entry points → answer screens, dhikr loading state.
8. `deno test` green, deploy, CHANGELOG + memory. **Sources stay `pending` until you flip
   the copyright gate.**
