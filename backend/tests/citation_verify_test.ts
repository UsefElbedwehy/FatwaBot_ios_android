import { assertEquals } from "jsr:@std/assert@1";
import { verifyCitations } from "../functions/api/ai_search/citation_verify.ts";
import { normalizeArabic } from "../functions/api/ai_search/text_normalize.ts";
import type { AnswerCitation, AnswerResult } from "../functions/api/fatwa_types.ts";

function citation(over: Partial<AnswerCitation> = {}): AnswerCitation {
  return {
    chunkId: "chunk-1",
    scholar: "ابن عثيمين",
    sourceTitle: "فتاوى أركان الإسلام",
    pageNumber: 25,
    quotedText: "الوسط في الدين: أن لا يغلو الإنسان فيه.",
    ...over,
  };
}

function answer(over: Partial<AnswerResult> = {}): AnswerResult {
  return {
    answer: "الوسط في الدين هو الاعتدال.",
    citations: [citation()],
    refused: false,
    model: "claude-haiku-4-5",
    ...over,
  };
}

// --- normalizeArabic ---

Deno.test("normalizeArabic strips tashkeel but preserves Arabic-Indic digits", () => {
  assertEquals(normalizeArabic("بِسْمِ اللَّهِ"), "بسم الله");
  assertEquals(normalizeArabic("صفحة ٢٩"), "صفحة ٢٩");
});

Deno.test("normalizeArabic unifies alef and ya variants", () => {
  assertEquals(normalizeArabic("أحمد"), normalizeArabic("احمد"));
  assertEquals(normalizeArabic("إبراهيم"), normalizeArabic("ابراهيم"));
  assertEquals(normalizeArabic("مستوى"), normalizeArabic("مستوي"));
});

// --- verifyCitations ---

Deno.test("a citation whose quotedText is an exact substring of its chunk verifies", () => {
  const chunkText = "الوسط في الدين: أن لا يغلو الإنسان فيه. ولا يقصر فيه فينقص.";
  const result = verifyCitations(
    answer(),
    new Map([["chunk-1", chunkText]]),
  );
  assertEquals(result.refused, false);
  assertEquals(result.citations.length, 1);
  assertEquals(result.droppedCitations.length, 0);
});

Deno.test("a citation still verifies when the quote and chunk differ only by tashkeel", () => {
  const chunkText = "الوَسَطُ فِي الدِّينِ: أَنْ لَا يَغْلُوَ الْإِنْسَانُ فِيهِ.";
  const result = verifyCitations(
    answer({ citations: [citation({ quotedText: "الوسط في الدين: أن لا يغلو الإنسان فيه." })] }),
    new Map([["chunk-1", chunkText]]),
  );
  assertEquals(result.refused, false);
  assertEquals(result.citations.length, 1);
});

Deno.test("a fabricated quote not present in the chunk is dropped", () => {
  const chunkText = "نص مختلف تماماً لا علاقة له بالاستشهاد.";
  const result = verifyCitations(
    answer(),
    new Map([["chunk-1", chunkText]]),
  );
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 1);
});

Deno.test("a citation pointing at a chunk id outside the retrieved set is dropped", () => {
  const result = verifyCitations(
    answer({ citations: [citation({ chunkId: "chunk-does-not-exist" })] }),
    new Map([["chunk-1", "نص المقطع الحقيقي"]]),
  );
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 1);
});

Deno.test("an empty quotedText never verifies, even against a chunk with real text", () => {
  const result = verifyCitations(
    answer({ citations: [citation({ quotedText: "   " })] }),
    new Map([["chunk-1", "أي نص هنا سيحتوي على سلسلة فارغة"]]),
  );
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 1);
});

Deno.test("when every citation fails, the whole answer flips to a refusal", () => {
  const result = verifyCitations(
    answer({ citations: [citation({ quotedText: "نص لا وجود له" })] }),
    new Map([["chunk-1", "نص المقطع الحقيقي المختلف تماماً"]]),
  );
  assertEquals(result.refused, true);
  assertEquals(result.answer, "");
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 1, "the failed citation is still surfaced for QA");
});

Deno.test("a mix of a valid and a fabricated citation keeps only the valid one, no refusal flip", () => {
  const result = verifyCitations(
    answer({
      citations: [
        citation({ chunkId: "chunk-1" }),
        citation({ chunkId: "chunk-2", quotedText: "استشهاد ملفّق غير موجود" }),
      ],
    }),
    new Map([
      ["chunk-1", "الوسط في الدين: أن لا يغلو الإنسان فيه. ولا يقصر فيه فينقص."],
      ["chunk-2", "نص حقيقي مختلف تماماً عن الاستشهاد المزعوم"],
    ]),
  );
  assertEquals(result.refused, false);
  assertEquals(result.citations.length, 1);
  assertEquals(result.citations[0].chunkId, "chunk-1");
  assertEquals(result.droppedCitations.length, 1);
});

Deno.test("an already-refused answer passes through untouched", () => {
  const refused = answer({ answer: "", citations: [], refused: true });
  const result = verifyCitations(refused, new Map());
  assertEquals(result.refused, true);
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 0);
});
