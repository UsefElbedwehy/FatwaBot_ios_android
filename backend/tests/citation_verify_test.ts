import { assert, assertEquals } from "jsr:@std/assert@1";
import { hadithFromChunk, repairQuote, verifyCitations } from "../functions/api/ai_search/citation_verify.ts";
import { normalizeArabic } from "../functions/api/ai_search/text_normalize.ts";
import { ANSWER_JSON_SCHEMA } from "../functions/api/ai_search/providers.ts";
import type { AnswerCitation, AnswerResult } from "../functions/api/fatwa_types.ts";

// --- ANSWER_JSON_SCHEMA citation locators ---
//
// Asserted directly, not through a stubbed AnswerProvider: the stubs return
// hand-built AnswerResults and never round-trip the schema, so a regression
// here would pass every other test in this file.

Deno.test("the citation schema carries BOTH locator fields", () => {
  const props = ANSWER_JSON_SCHEMA.properties.citations.items.properties;
  assertEquals("pageNumber" in props, true);
  assertEquals(
    "videoTimestamp" in props,
    true,
    "a video-sourced citation has no page; without this field, and with " +
      "additionalProperties:false, it cannot carry its locator at all",
  );
});

Deno.test("neither locator is required — exactly one applies per source kind", () => {
  const required: readonly string[] = ANSWER_JSON_SCHEMA.properties.citations.items.required;
  assertEquals(
    required.includes("pageNumber"),
    false,
    "a required pageNumber forces a video-sourced citation to invent one",
  );
  assertEquals(required.includes("videoTimestamp"), false);
  // The fields that identify and substantiate a citation stay mandatory.
  assertEquals(required.includes("chunkId"), true);
  assertEquals(required.includes("quotedText"), true);
});

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
  assertEquals(normalizeArabic("صفحة ٢٩"), "صفحه ٢٩");
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

Deno.test("a bare self-refusal with no citations passes through untouched, answer text kept", () => {
  const refused = answer({
    answer: "لم يرد الحديث بهذا اللفظ في المقاطع المتاحة.",
    citations: [],
    refused: true,
  });
  const result = verifyCitations(refused, new Map());
  assertEquals(result.refused, true);
  assertEquals(result.answer, "لم يرد الحديث بهذا اللفظ في المقاطع المتاحة.");
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 0);
});

Deno.test("a self-refused answer's citation is still verified — a real one survives (hadith 'closest match')", () => {
  const chunkText = "الوسط في الدين: أن لا يغلو الإنسان فيه. ولا يقصر فيه فينقص.";
  const result = verifyCitations(
    answer({
      answer: "لم يرد الحديث بهذا اللفظ، لكن أقرب لفظ صحيح هو ما يلي.",
      citations: [citation()],
      refused: true,
    }),
    new Map([["chunk-1", chunkText]]),
  );
  assertEquals(result.refused, true, "the model's own refusal (exact wording not found) is preserved");
  assertEquals(result.answer, "لم يرد الحديث بهذا اللفظ، لكن أقرب لفظ صحيح هو ما يلي.");
  assertEquals(result.citations.length, 1, "a real citation on a self-refusal must not be skipped");
});

Deno.test("a self-refused answer's fabricated citation is dropped and blanks the answer", () => {
  const result = verifyCitations(
    answer({
      answer: "أقرب لفظ صحيح هو ما يلي.",
      citations: [citation({ quotedText: "نص ملفّق لا وجود له" })],
      refused: true,
    }),
    new Map([["chunk-1", "نص المقطع الحقيقي المختلف تماماً"]]),
  );
  assertEquals(result.refused, true);
  assertEquals(
    result.answer,
    "",
    "an unverifiable 'closest match' must not reach the user as if it were real",
  );
  assertEquals(result.citations.length, 0);
  assertEquals(result.droppedCitations.length, 1);
});

// --- 0050: ة/ه folding and quote repair ---

Deno.test("normalizeArabic folds teh marbuta to heh, matching the database's normalize_ar", () => {
  // Until this matched 0047, FTS found «اللحيه» for «اللحية» while the verifier
  // and the cache key did not — one question, two cache rows, two full runs.
  assertEquals(normalizeArabic("حلق اللحية"), normalizeArabic("حلق اللحيه"));
});

const OCR_CHUNK =
  "الجواب: أما صبغ اللحية بالسواد فإنه محرعٌ؛ لأن النبي ﷺ يقول: «غيروا هذا الشيب واجتنبوا السواد» ثبت ذلك في صحيح مسلم.";

Deno.test("repairQuote recovers a quote the model 'corrected' past one OCR error", () => {
  // The model fixed «محرعٌ» to «محرم» — honest, and fatal to an exact match.
  const quote = "أما صبغ اللحية بالسواد فإنه محرم؛ لأن النبي ﷺ يقول: «غيروا هذا الشيب واجتنبوا السواد»";
  const fixed = repairQuote(quote, OCR_CHUNK);
  assert(fixed !== null);
  // The repaired quote is the *source's* words — what the user reads is the
  // text as it exists, glitch included, not the model's version of it. With
  // word-level tolerance the glitched word itself matches, so the whole quote
  // comes back rather than only the clean tail after it.
  assertEquals(fixed, "أما صبغ اللحية بالسواد فإنه محرعٌ؛ لأن النبي ﷺ يقول: «غيروا هذا الشيب واجتنبوا السواد»");
  assert(normalizeArabic(OCR_CHUNK).includes(normalizeArabic(fixed)), "and it verifies exactly");
});

Deno.test("repairQuote refuses a fabricated quote that merely shares a short phrase", () => {
  const fabricated = "قال الشيخ إن صبغ اللحية بالسواد جائز بلا كراهة عند جمهور العلماء المتأخرين والمعاصرين";
  assertEquals(repairQuote(fabricated, OCR_CHUNK), null, "three shared words are not evidence of copying");
});

Deno.test("repairQuote refuses a long invented quote wrapped around a short genuine one", () => {
  const genuine = "لأن النبي ﷺ يقول: «غيروا هذا الشيب واجتنبوا السواد»";
  const padding = Array(20).fill("كلمة").join(" ");
  assertEquals(
    repairQuote(`${padding} ${genuine} ${padding}`, OCR_CHUNK),
    null,
    "the run is under half the quote",
  );
});

Deno.test("verifyCitations repairs a near-miss citation instead of dropping it, and counts it", () => {
  const result = verifyCitations(
    answer({
      citations: [citation({
        quotedText: "أما صبغ اللحية بالسواد فإنه محرم؛ لأن النبي ﷺ يقول: «غيروا هذا الشيب واجتنبوا السواد»",
      })],
    }),
    new Map([["chunk-1", OCR_CHUNK]]),
  );
  assertEquals(result.refused, false);
  assertEquals(result.citations.length, 1);
  assertEquals(result.repairedCitations, 1);
  assertEquals(result.droppedCitations.length, 0);
  assert(normalizeArabic(OCR_CHUNK).includes(normalizeArabic(result.citations[0].quotedText)));
});

Deno.test("verifyCitations still refuses when the only citation cannot be repaired", () => {
  const result = verifyCitations(
    answer({ citations: [citation({ quotedText: "نص ملفّق لا يظهر في المصدر إطلاقاً بأي صورة من الصور" })] }),
    new Map([["chunk-1", OCR_CHUNK]]),
  );
  assertEquals(result.refused, true);
  assertEquals(result.repairedCitations, 0);
  assertEquals(result.droppedCitations.length, 1);
});

Deno.test("hadithFromChunk builds the takhrij card from a hadith entry's own lines", () => {
  const card = hadithFromChunk({
    chunkId: "h",
    documentId: "c",
    sourceId: "c",
    scholarId: "c",
    text: "إنما الأعمال بالنيات\n\nالدرجة: Sahih\nالمصدر: صحيح البخاري (رقم 1)",
    pageNumber: 1,
    videoTimestamp: null,
    sourceTitle: "صحيح البخاري",
    sourceCategory: "hadith",
    sourceKind: "book",
    sourceUrl: null,
    scholarName: { ar: "صحيح البخاري" },
    score: 1,
    ocrShattered: false,
  });
  assertEquals(card, { text: "إنما الأعمال بالنيات", grade: "Sahih", source: "صحيح البخاري (رقم 1)" });
});

Deno.test("hadithFromChunk returns null for a fatwa chunk that merely discusses a hadith", () => {
  const card = hadithFromChunk({
    chunkId: "f",
    documentId: "d",
    sourceId: "s",
    scholarId: "s",
    text: "شرح حديث إنما الأعمال بالنيات\n\nالدرجة: صحيح",
    pageNumber: 4,
    videoTimestamp: null,
    sourceTitle: "كتاب",
    sourceCategory: "الفتاوى واللقاءات",
    sourceKind: "book",
    sourceUrl: null,
    scholarName: { ar: "عالم" },
    score: 1,
    ocrShattered: false,
  });
  assertEquals(card, null);
});

Deno.test("repairQuote tolerates one scan error per word — the corpus has one every fifth word", () => {
  // Real pair from answers_log.dropped_citations: the model read the scan
  // correctly and wrote what it meant; the scan says خلق, عصي, امر, and «كيه»
  // where the print has ﷺ.
  const scan =
    "فمن خلق لحيته فقد عصي امر النبي كيه في قوله: «وفروا اللحي». ومن خلق لحيته فقد اتبع سبيل المجوس";
  const quote = "من حلق لحيته فقد عصى أمر النبي ومخالفة الفطرة التي فطر الله الناس عليها";
  const fixed = repairQuote(quote, scan);
  assertEquals(fixed, "خلق لحيته فقد عصي امر النبي", "six source words, shown as the scan has them");
});

Deno.test("repairQuote treats punctuation as invisible for matching but keeps it in the shown run", () => {
  const scan = "اجاببقوله: حلق اللحيه حرم؛ لانه معصيه لرسول الله كي فان النبي";
  const fixed = repairQuote("حلق اللحية حرام لأنه معصية لرسول الله وخروج عن هدي الرسل", scan);
  assertEquals(fixed, "حلق اللحيه حرم؛ لانه معصيه لرسول الله");
});

Deno.test("repairQuote does not let short function words fuzzy-bridge a run", () => {
  // من/في and على/عن are an edit apart and mean different things. If they
  // matched, this pair would share a six-word run; they do not, so the real
  // shared run is «كل حال بلا شك» — four words, under the floor.
  assertEquals(repairQuote("من الله على كل حال بلا شك", "في الله عن كل حال بلا شك"), null);
});
