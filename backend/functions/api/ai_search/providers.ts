// EmbeddingProvider + AnswerProvider (docs/features/ai-search-m5.0-spec.md
// §Provider interfaces). Dev-stub versions let retrieval math and
// citation-verification be tested with zero network calls — same pattern as
// FcmSender's test double elsewhere in this backend (fcm_sender.ts).
import Anthropic from "npm:@anthropic-ai/sdk@0.117.1";
import type { AnswerCitation, AnswerResult, FatwaMode, RetrievedChunk } from "../fatwa_types.ts";

export interface EmbeddingProvider {
  embed(texts: string[]): Promise<number[][]>;
  readonly dimensions: number;
  readonly id: string;
}

export interface AnswerProvider {
  answer(
    question: string,
    mode: FatwaMode,
    chunks: RetrievedChunk[],
    locale: string,
  ): Promise<AnswerResult>;
  readonly id: string;
}

// ---------------------------------------------------------------------------
// Dev stubs — deterministic, no network. Used until VOYAGE_API_KEY /
// ANTHROPIC_API_KEY are provisioned, and in every test.
// ---------------------------------------------------------------------------

/** FNV-1a — fast, deterministic, good-enough bit dispersion for a fake
 *  embedding (not semantically meaningful, just stable and non-degenerate). */
function fnv1a(text: string, seed: number): number {
  let hash = 0x811c9dc5 ^ seed;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

export class DevStubEmbeddingProvider implements EmbeddingProvider {
  readonly id = "dev-stub";
  constructor(readonly dimensions: number = 1024) {}

  embed(texts: string[]): Promise<number[][]> {
    return Promise.resolve(
      texts.map((text) => {
        const vec = new Array<number>(this.dimensions);
        for (let i = 0; i < this.dimensions; i++) {
          // Spread into [-1, 1]; deterministic per (text, dimension index).
          vec[i] = (fnv1a(text, i) / 0xffffffff) * 2 - 1;
        }
        return vec;
      }),
    );
  }
}

/** Fixed grounded-echo answerer: refuses on empty retrieval, otherwise
 *  quotes the top chunk verbatim so citation-verify's true-positive case is
 *  deterministic in tests. */
export class DevStubAnswerProvider implements AnswerProvider {
  readonly id = "dev-stub";

  answer(
    question: string,
    _mode: FatwaMode,
    chunks: RetrievedChunk[],
    _locale: string,
  ): Promise<AnswerResult> {
    if (chunks.length === 0) {
      return Promise.resolve({
        answer: "لم يتم العثور على مصدر موثوق للإجابة على هذا السؤال.",
        citations: [],
        refused: true,
        model: this.id,
      });
    }
    const top = chunks[0];
    const citation: AnswerCitation = {
      chunkId: top.chunkId,
      scholar: top.scholarName["ar"] ?? top.scholarName["en"] ?? "",
      sourceTitle: top.sourceTitle,
      quotedText: top.text,
      ...(top.pageNumber !== null ? { pageNumber: top.pageNumber } : {}),
      ...(top.videoTimestamp !== null ? { videoTimestamp: top.videoTimestamp } : {}),
    };
    return Promise.resolve({
      answer: `[dev-stub answer for: ${question}]\n\n${top.text}`,
      citations: [citation],
      refused: false,
      model: this.id,
    });
  }
}

// ---------------------------------------------------------------------------
// Real providers
// ---------------------------------------------------------------------------

/** Voyage AI's embeddings API — no official Deno/TS SDK, so this follows
 *  FcmSender's raw-fetch + injectable-fetch pattern for testability.
 *
 *  Two throttling defenses, not one:
 *  1. **Proactive pacing** (`requestsPerMinute`) — an account with no payment
 *     method on file is capped at 3 requests/minute (confirmed against the
 *     real API, not documentation). Retry-after-the-fact isn't enough on its
 *     own: every retry attempt is itself another request against that same
 *     budget, so a burst of calls (load_corpus.ts embedding book after book)
 *     can keep re-triggering 429 faster than backoff clears it. Tracked as a
 *     sliding 60s window of request timestamps; `embed()` waits for a free
 *     slot before ever sending, when a limit is configured. `undefined`
 *     (the default) means no proactive pacing — the live `/v1/search`
 *     endpoint sends one request per user query, not a tight bulk loop, so
 *     it has no reason to self-throttle.
 *  2. **Reactive retry** for whatever the pacing doesn't fully prevent (a
 *     genuine transient 5xx, or TPM rather than RPM pressure): `Retry-After`
 *     is honored when Voyage sends one; otherwise 429 backs off ~20s and
 *     5xx backs off exponentially from 1s. */
/** Carries the upstream provider's HTTP status so a failure can be reported as
 *  "the embedding service said 429" rather than an opaque 500. The status alone
 *  is safe to surface — it names no key and echoes no response body. */
export class UpstreamError extends Error {
  constructor(readonly provider: string, readonly status: number, message: string) {
    super(message);
    this.name = "UpstreamError";
  }
}

export class VoyageEmbeddingProvider implements EmbeddingProvider {
  readonly id: string;
  private readonly requestTimestamps: number[] = [];

  constructor(
    private readonly apiKey: string,
    private readonly deps: {
      model?: string;
      dimensions?: number;
      fetch?: typeof fetch;
      sleep?: (ms: number) => Promise<void>;
      maxRetries?: number;
      requestsPerMinute?: number;
      now?: () => number;
    } = {},
  ) {
    this.id = deps.model ?? "voyage-4";
    this.dimensions = deps.dimensions ?? 1024;
  }
  readonly dimensions: number;

  private get fetchFn() {
    return this.deps.fetch ?? fetch;
  }

  private get sleepFn() {
    return this.deps.sleep ?? ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  }

  private get nowFn() {
    return this.deps.now ?? Date.now;
  }

  private get maxRetries() {
    return this.deps.maxRetries ?? 8;
  }

  /** Blocks until sending another request would keep the trailing 60s window
   *  at or under `requestsPerMinute`, then records this send. A no-op when
   *  no limit is configured. */
  private async waitForRateLimitSlot(): Promise<void> {
    const limit = this.deps.requestsPerMinute;
    if (!limit) return;
    for (;;) {
      const now = this.nowFn();
      while (this.requestTimestamps.length > 0 && now - this.requestTimestamps[0] >= 60_000) {
        this.requestTimestamps.shift();
      }
      if (this.requestTimestamps.length < limit) {
        this.requestTimestamps.push(now);
        return;
      }
      await this.sleepFn(60_000 - (now - this.requestTimestamps[0]) + 250);
    }
  }

  async embed(texts: string[]): Promise<number[][]> {
    for (let attempt = 0;; attempt++) {
      await this.waitForRateLimitSlot();
      const res = await this.fetchFn("https://api.voyageai.com/v1/embeddings", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({ input: texts, model: this.id }),
      });
      if (res.ok) {
        const json = await res.json() as { data: { embedding: number[]; index: number }[] };
        return json.data
          .sort((a, b) => a.index - b.index)
          .map((d) => d.embedding);
      }

      const retryable = res.status === 429 || res.status >= 500;
      const body = await res.text();
      if (!retryable || attempt >= this.maxRetries) {
        throw new UpstreamError("voyage", res.status, `Voyage embeddings failed: ${res.status} ${body}`);
      }
      const retryAfterSeconds = Number(res.headers.get("retry-after"));
      const backoffMs = Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0
        ? retryAfterSeconds * 1000
        : res.status === 429
        ? 20_000
        : Math.min(30_000, 1000 * 2 ** attempt);
      await this.sleepFn(backoffMs);
    }
  }
}

/** Exported for tests: the citation locator fields are easy to regress (a
 *  `required` entry or a missing property silently forces the model to
 *  fabricate or drop a locator), and only a direct assertion catches that —
 *  a stubbed AnswerProvider bypasses the schema entirely. */
export const ANSWER_JSON_SCHEMA = {
  type: "object",
  properties: {
    answer: { type: "string" },
    refused: { type: "boolean" },
    citations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          chunkId: { type: "string" },
          scholar: { type: "string" },
          sourceTitle: { type: "string" },
          // Exactly one locator per citation, mirroring the DB's
          // `chunks_exactly_one_locator` constraint: a book chunk has a page,
          // a video chunk has a timestamp. BOTH are optional — `pageNumber`
          // used to be `required` with no `videoTimestamp` property at all,
          // which (with `additionalProperties: false`) meant a video-sourced
          // citation could not carry its timestamp *and* was forced to invent
          // a page number to satisfy the schema.
          pageNumber: { type: "integer" },
          videoTimestamp: { type: "integer" },
          quotedText: { type: "string" },
        },
        required: ["chunkId", "scholar", "sourceTitle", "quotedText"],
        additionalProperties: false,
      },
    },
  },
  required: ["answer", "refused", "citations"],
  additionalProperties: false,
} as const;

const MODE_INSTRUCTIONS: Record<FatwaMode, string> = {
  fatwa: "وضع «ابحث عن فتوى»: أجب بفتوى واحدة تعتمد فقط على المقاطع المسترجعة أدناه. " +
    "إن أجاب أكثر من عالِم في المقاطع، لخّص أقوالهم دون خلط أو تلفيق.",
  hadith: "وضع «استخراج الأحاديث»: تحقق من اللفظ الدقيق للحديث من المقاطع المسترجعة فقط. " +
    "إن لم يرد الحديث بهذا اللفظ بالضبط في المقاطع، ضع refused=true. إن وُجد في المقاطع لفظ صحيح مقارب، " +
    "اذكره في الإجابة، ويجب أن تضيف له استشهاداً حقيقياً في citations[] ينسخ لفظه حرفياً من مقطعه — أي ذكر " +
    "لأقرب لفظ دون استشهاد حقيقي يدعمه غير موثوق ولن يُقبل.",
  general: "وضع «سؤال ديني عام»: أجب إجابة واحدة مؤصَّلة بالدليل من المقاطع المسترجعة فقط.",
};

/** docs/features/ai-search-m5.0-spec.md §Non-negotiable: every claim must be
 *  traceable to a retrieved chunk. This system prompt states that as a hard
 *  rule, but the actual enforcement is citation_verify.ts checking every
 *  `quotedText` against the real chunk text — never trust the model alone. */
function buildSystemPrompt(mode: FatwaMode, locale: string): string {
  return [
    "أنت مساعد يجيب حصراً من نصوص مصدرها موثّق أُرفقت لك أدناه (مقاطع من كتب علماء معتمدين).",
    "لا تستخدم أي معرفة خاصة بك ولا أي مصدر خارج هذه المقاطع. إن لم تُجب المقاطع على السؤال، أعد refused=true وإجابة فارغة، ولا تخترع إجابة.",
    "كل استشهاد في citations[].quotedText يجب أن يكون نصاً حرفياً منسوخاً من المقطع (chunkId) الذي يشير إليه — لا إعادة صياغة.",
    "ولكل استشهاد موضعٌ واحد فقط: إن كان المقطع من كتاب فضع pageNumber برقم صفحته، وإن كان من مادة مرئية فضع videoTimestamp بدقيقته. لا تضع الحقلين معاً ولا تخمّن رقماً غير المذكور في المقطع.",
    MODE_INSTRUCTIONS[mode],
    `أجب بلغة: ${locale}.`,
  ].join("\n");
}

function buildUserPrompt(question: string, chunks: RetrievedChunk[]): string {
  const chunkBlocks = chunks.map((c, i) => {
    const scholar = c.scholarName["ar"] ?? c.scholarName["en"] ?? "";
    const loc = c.pageNumber !== null ? `صفحة ${c.pageNumber}` : `الدقيقة ${c.videoTimestamp}`;
    return `[مقطع ${
      i + 1
    }] chunkId=${c.chunkId} | العالم: ${scholar} | المصدر: ${c.sourceTitle} (${loc})\n${c.text}`;
  }).join("\n\n---\n\n");
  return `السؤال: ${question}\n\nالمقاطع المسترجعة:\n\n${chunkBlocks}`;
}

/** Default AnswerProvider per spec (§Decisions locked in): Claude Haiku 4.5,
 *  swappable to a stronger model per-query via the constructor. Uses the
 *  official Anthropic SDK (npm: specifier, same pattern as this codebase's
 *  `npm:jose@5` import) with structured outputs so the response is always
 *  valid JSON — no ad-hoc parsing/retry loop needed. */
export class ClaudeAnswerProvider implements AnswerProvider {
  readonly id: string;
  private readonly client: Anthropic;

  constructor(apiKey: string, deps: { model?: string; client?: Anthropic } = {}) {
    this.id = deps.model ?? "claude-haiku-4-5";
    this.client = deps.client ?? new Anthropic({ apiKey });
  }

  async answer(
    question: string,
    mode: FatwaMode,
    chunks: RetrievedChunk[],
    locale: string,
  ): Promise<AnswerResult> {
    if (chunks.length === 0) {
      return {
        answer: "",
        citations: [],
        refused: true,
        model: this.id,
      };
    }

    const response = await this.client.messages.create({
      model: this.id,
      max_tokens: 2048,
      system: buildSystemPrompt(mode, locale),
      messages: [{ role: "user", content: buildUserPrompt(question, chunks) }],
      output_config: { format: { type: "json_schema", schema: ANSWER_JSON_SCHEMA } },
    });

    if (response.stop_reason === "refusal") {
      return { answer: "", citations: [], refused: true, model: this.id };
    }

    const textBlock = response.content.find((b): b is Anthropic.TextBlock => b.type === "text");
    if (!textBlock) throw new Error(`AnswerProvider ${this.id}: no text block in response`);
    const parsed = JSON.parse(textBlock.text) as AnswerResult;
    return { ...parsed, model: this.id };
  }
}
