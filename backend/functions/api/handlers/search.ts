// POST /v1/search (docs/features/ai-search-m5.0-spec.md §Answer contract).
// question + mode → hybrid retrieve → AnswerProvider → citation-verify →
// log to fatwa.answers_log + the existing per-user search history →
// { answer, citations[], refused, mode }. A refusal is a normal 200
// response (refused=true, localized message, empty citations), not an
// error — the error path is reserved for the AI stack not being configured
// at all (503) or a genuine failure.
import { verifyAccessToken } from "../auth/jwt.ts";
import { apiError, json } from "../http.ts";
import { resolveRequired } from "../locale_resolve.ts";
import type { AppContext } from "../types.ts";
import type { FatwaMode, FatwaSearchRepo, RetrievedChunk } from "../fatwa_types.ts";
import { UpstreamError } from "../ai_search/providers.ts";
import type { AnswerProvider, EmbeddingProvider } from "../ai_search/providers.ts";
import { hybridRetrieve, RetrievalError } from "../ai_search/retrieval.ts";
import type { AnswerCacheRepo } from "../ai_search/answer_cache.ts";
import { questionHash } from "../ai_search/embedding_cache.ts";
import { verifyCitations } from "../ai_search/citation_verify.ts";
import type { SearchHistoryRepo, SearchSource } from "../search_types.ts";

export interface SearchDeps {
  fatwaSearch: FatwaSearchRepo;
  /** Both undefined until VOYAGE_API_KEY / ANTHROPIC_API_KEY are configured
   *  — mirrors the FCM sender's optional-until-configured pattern
   *  (fcm_sender.ts), so this endpoint 503s rather than silently answering
   *  from a meaningless dev-stub embedding/echo in production. */
  embeddingProvider?: EmbeddingProvider;
  answerProvider?: AnswerProvider;
  searchHistory: SearchHistoryRepo;
  /** Optional: without it every search runs the full pipeline, which is the
   *  pre-0046 behaviour and still correct, only slower. */
  answerCache?: AnswerCacheRepo;
  jwtSecret: string;
}

const VALID_MODES: FatwaMode[] = ["fatwa", "hadith", "general"];

function isValidMode(value: unknown): value is FatwaMode {
  return typeof value === "string" && (VALID_MODES as string[]).includes(value);
}

const MODE_TO_HISTORY_SOURCE: Record<FatwaMode, SearchSource> = {
  fatwa: "ai_fatwa",
  hadith: "ai_hadith",
  general: "ai_question",
};

const REFUSAL_MESSAGE: Record<string, string> = {
  ar: "لم نجد في مصادرنا الموثوقة ما يجيب عن هذا السؤال.",
  en: "We couldn't find a vetted source that answers this question.",
};

async function requireUser(req: Request, jwtSecret: string): Promise<string | Response> {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return apiError(401, "unauthorized", "Valid bearer token required");
  const claims = await verifyAccessToken(header.slice("Bearer ".length), jwtSecret);
  if (!claims) return apiError(401, "unauthorized", "Valid bearer token required");
  return claims.sub;
}

/** What the answer is also available as, derived from the *verified* citations
 *  rather than asked of the model.
 *
 *  The reference design shows an availability badge per scholar card. A model
 *  asked "is this on YouTube?" will happily say yes, so the only trustworthy
 *  source is the `kind`/`url` on the sources those citations actually came from
 *  (0048). Every source is a book today, so `video` and `website` will report
 *  `available: false` until such sources are ingested — which is the honest
 *  answer, not a gap.
 */
function deriveResources(
  citations: readonly { chunkId: string }[],
  chunks: readonly RetrievedChunk[],
): { kind: string; available: boolean; url: string | null }[] {
  const byChunk = new Map(chunks.map((c) => [c.chunkId, c]));
  const found = new Map<string, string | null>();
  for (const citation of citations) {
    const chunk = byChunk.get(citation.chunkId);
    if (!chunk) continue;
    // First url wins, but a later citation with a url beats an earlier one
    // without: a kind is "available" if any cited source of that kind exists,
    // and a link is better than none.
    const existing = found.get(chunk.sourceKind);
    if (existing === undefined || (existing === null && chunk.sourceUrl !== null)) {
      found.set(chunk.sourceKind, chunk.sourceUrl);
    }
  }
  // Always report all three, so the UI can render "غير متاح" rather than
  // silently omitting a row and leaving the user unsure whether it was checked.
  return ["book", "video", "website"].map((kind) => ({
    kind,
    available: found.has(kind),
    url: found.get(kind) ?? null,
  }));
}

/** POST /v1/search */
export async function handleSearch(
  ctx: AppContext,
  deps: SearchDeps,
  req: Request,
  body: unknown,
): Promise<Response> {
  const userOrError = await requireUser(req, deps.jwtSecret);
  if (userOrError instanceof Response) return userOrError;
  const userId = userOrError;

  const b = (body as Record<string, unknown> | null) ?? {};
  if (!isValidMode(b.mode)) {
    return apiError(400, "invalid_mode", `mode must be one of ${VALID_MODES.join(", ")}`);
  }
  if (typeof b.question !== "string" || b.question.trim().length === 0) {
    return apiError(400, "invalid_question", "question must be a non-empty string");
  }
  const mode = b.mode;
  const question = b.question.trim();

  if (!deps.embeddingProvider || !deps.answerProvider) {
    return apiError(503, "ai_unavailable", "AI search is not configured yet");
  }

  // A repeat costs one indexed lookup instead of ~15s (0046). Read before
  // anything expensive, and fail open — a cache that is down must make search
  // slow, never broken.
  const hash = await questionHash(question);
  const answerModelId = deps.answerProvider.id;
  if (deps.answerCache) {
    try {
      const hit = await deps.answerCache.get(ctx, hash, mode, answerModelId);
      if (hit) {
        // History still records the ask: a cached answer is still the user
        // asking, and their history would otherwise have holes in it exactly
        // where they repeated themselves.
        try {
          await deps.searchHistory.record(ctx, userId, MODE_TO_HISTORY_SOURCE[mode], question, ctx.locale);
        } catch (err) {
          console.error("search_logging_failed", err instanceof Error ? err.stack ?? err.message : err);
        }
        return json(hit, 200, { "server-timing": "cache;dur=0" });
      }
    } catch (err) {
      console.warn("answer_cache_read_failed", err instanceof Error ? err.message : err);
    }
  }

  // Each stage reports its own failure code. Previously any throw anywhere in
  // here fell through to the router's blanket `internal_error`, so a 500 said
  // only "something broke" — indistinguishable between the embedding call, the
  // SQL search functions, and the answer model, and diagnosable only by someone
  // with dashboard access to the stack trace. The codes carry no internal
  // detail; the stack still goes to the log, not to the client.
  const timings: { embedMs?: number; searchMs?: number } = {};
  let answerMs = 0;
  let chunks;
  try {
    chunks = await hybridRetrieve(ctx, deps.fatwaSearch, deps.embeddingProvider, question, {}, timings);
  } catch (err) {
    console.error("search_retrieval_failed", err instanceof Error ? err.stack ?? err.message : err);
    const stage = err instanceof RetrievalError ? err.stage : "unknown";
    const cause = err instanceof RetrievalError ? err.reason : err;
    // The upstream HTTP status, when there is one. Naming it turns an opaque
    // 502 into an actionable one — a 429 is a quota problem on the provider
    // account, a 401 a bad key, a 404 a wrong model id. No key and no response
    // body is echoed, only the number.
    // Postgres/PostgREST error codes are equally actionable and equally safe:
    // 42883 / PGRST202 mean the function isn't there (an unapplied migration),
    // 42501 means it is but the API role can't call it, 42704 a missing type or
    // extension. Only the code travels — never the message, which can quote the
    // caller's own text back.
    const pgCode = typeof (cause as { code?: unknown })?.code === "string"
      ? ` (pg ${(cause as { code: string }).code})`
      : "";
    const upstream = cause instanceof UpstreamError ? ` (${cause.provider} ${cause.status})` : pgCode;
    const which = err instanceof RetrievalError && err.failedSearches.length > 0
      ? ` [${err.failedSearches.join(",")}]`
      : "";
    return apiError(
      502,
      stage === "embedding" ? "embedding_failed" : "retrieval_failed",
      `Could not search the sources${upstream}${which}`,
    );
  }

  let raw;
  const answerStart = performance.now();
  try {
    raw = await deps.answerProvider.answer(question, mode, chunks, ctx.locale);
    answerMs = Math.round(performance.now() - answerStart);
  } catch (err) {
    console.error("search_answer_failed", err instanceof Error ? err.stack ?? err.message : err);
    return apiError(502, "answer_failed", "Could not generate an answer");
  }

  const chunkTextById = new Map(chunks.map((c) => [c.chunkId, c.text]));
  const verified = verifyCitations(raw, chunkTextById);

  // A refusal still carries useful text sometimes — hadith mode is asked to
  // name the closest authentic wording even while refusing the exact quote.
  // Only fall back to the generic localized message when there's genuinely
  // nothing else to show (the common case, and always true when
  // citation-verify blanked the answer for fabricated evidence).
  const answer = verified.refused && verified.answer.trim().length === 0
    ? resolveRequired(REFUSAL_MESSAGE, ctx.locale)
    : verified.answer;

  // Bookkeeping, not the product. A failed audit-log or history write used to
  // throw away an answer that had already been retrieved, generated and
  // verified — the user paid for the whole pipeline and got a 500 because a
  // side-table insert failed. Log it and hand over the answer.
  try {
    await deps.fatwaSearch.logAnswer(ctx, {
      userId,
      mode,
      question,
      retrievedChunkIds: chunks.map((c) => c.chunkId),
      citations: verified.citations,
      answer,
      refused: verified.refused,
      model: verified.model,
    });
    await deps.searchHistory.record(ctx, userId, MODE_TO_HISTORY_SOURCE[mode], question, ctx.locale);
  } catch (err) {
    console.error("search_logging_failed", err instanceof Error ? err.stack ?? err.message : err);
  }

  const responseBody = {
    answer,
    // Structured fields for the M5.1 result card. All optional: a refusal has
    // no ruling and no scholar cards, and hadith fields exist only in that
    // mode. `answer` stays populated so a client built against the old shape
    // still renders something.
    summary: verified.summary ?? null,
    ruling: verified.ruling ?? "none",
    scholar_answers: (verified.scholarAnswers ?? []).map((a) => ({
      scholar: a.scholar,
      answer: a.answer,
      evidence: a.evidence ?? null,
    })),
    hadith: verified.hadith
      ? {
        text: verified.hadith.text,
        grade: verified.hadith.grade,
        source: verified.hadith.source ?? null,
        scholar_verdicts: verified.hadith.scholarVerdicts ?? null,
      }
      : null,
    resources: deriveResources(verified.citations, chunks),
    citations: verified.citations.map((c) => ({
      chunk_id: c.chunkId,
      scholar: c.scholar,
      source_title: c.sourceTitle,
      page_number: c.pageNumber ?? null,
      video_timestamp: c.videoTimestamp ?? null,
      quoted_text: c.quotedText,
    })),
    refused: verified.refused,
    mode,
  };

  // Written after the answer is assembled, and a failure here costs the user
  // nothing — they already have their answer.
  //
  // Refusals are deliberately NOT cached. A refusal is far more often a
  // transient symptom than a stable fact about the corpus — a truncated
  // generation, a model hiccup, a retrieval leg that timed out — and caching
  // one freezes that accident in place for the whole corpus generation. This
  // was not hypothetical: a truncated response cached "لم نجد" for a question
  // the corpus answers well, and every later ask served the accident in under
  // a second. The cost of not caching them is that a genuinely unanswerable
  // question re-runs, which is the cheaper mistake.
  if (deps.answerCache && !verified.refused) {
    try {
      await deps.answerCache.put(ctx, hash, mode, answerModelId, responseBody);
    } catch (err) {
      console.warn("answer_cache_write_failed", err instanceof Error ? err.message : err);
    }
  }

  // Standard `Server-Timing`, so where a slow search spent its time is visible
  // from the client instead of only in logs someone has to have access to read.
  return json(
    responseBody,
    200,
    {
      "server-timing": [
        `embed;dur=${timings.embedMs ?? 0}`,
        `search;dur=${timings.searchMs ?? 0}`,
        `answer;dur=${answerMs}`,
      ].join(", "),
    },
  );
}
