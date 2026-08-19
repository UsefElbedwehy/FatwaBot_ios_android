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
 *  FcmSender's raw-fetch + injectable-fetch pattern for testability. */
export class VoyageEmbeddingProvider implements EmbeddingProvider {
  readonly id: string;
  constructor(
    private readonly apiKey: string,
    private readonly deps: { model?: string; dimensions?: number; fetch?: typeof fetch } = {},
  ) {
    this.id = deps.model ?? "voyage-4";
    this.dimensions = deps.dimensions ?? 1024;
  }
  readonly dimensions: number;

  private get fetchFn() {
    return this.deps.fetch ?? fetch;
  }

  async embed(texts: string[]): Promise<number[][]> {
    const res = await this.fetchFn("https://api.voyageai.com/v1/embeddings", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({ input: texts, model: this.id }),
    });
    if (!res.ok) throw new Error(`Voyage embeddings failed: ${res.status} ${await res.text()}`);
    const json = await res.json() as { data: { embedding: number[]; index: number }[] };
    return json.data
      .sort((a, b) => a.index - b.index)
      .map((d) => d.embedding);
  }
}

const ANSWER_JSON_SCHEMA = {
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
          pageNumber: { type: "integer" },
          quotedText: { type: "string" },
        },
        required: ["chunkId", "scholar", "sourceTitle", "pageNumber", "quotedText"],
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
    "إن لم يرد الحديث بهذا اللفظ بالضبط في المقاطع، صرّح بذلك (refused=true) واذكر أقرب لفظ صحيح موجود إن وُجد.",
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
