// Citation verification (docs/features/ai-search-m5.0-spec.md §Citation
// verification) — the enforcement half of "no fabrication". Every
// AnswerProvider citation's quotedText must be a normalized substring of the
// real fatwa.chunks.text it claims to quote. This is checked here, in code,
// not left to the model to have followed the prompt — a citation that fails
// is dropped, and if it was the answer's only support, the whole response
// flips to a refusal rather than shipping an unverifiable claim.
import type { AnswerResult } from "../fatwa_types.ts";
import { normalizeArabic } from "./text_normalize.ts";

export interface VerifiedAnswer extends AnswerResult {
  /** Citations the model produced that failed verification (missing chunk,
   *  or quotedText not actually found in that chunk's text) — surfaced for
   *  logging/QA, never shown to the user. */
  droppedCitations: AnswerResult["citations"];
}

/** `chunkTextById` must contain only the chunks actually retrieved for this
 *  query — a citation pointing at a chunkId absent from the map (the model
 *  inventing an id, or referencing a chunk outside its own context) is
 *  dropped exactly like a genuine substring mismatch. */
export function verifyCitations(
  result: AnswerResult,
  chunkTextById: ReadonlyMap<string, string>,
): VerifiedAnswer {
  if (result.refused) {
    return { ...result, droppedCitations: [] };
  }

  const verified: AnswerResult["citations"] = [];
  const dropped: AnswerResult["citations"] = [];
  for (const citation of result.citations) {
    const chunkText = chunkTextById.get(citation.chunkId);
    const normalizedQuote = normalizeArabic(citation.quotedText);
    // An empty (or whitespace-only) quote is a substring of everything —
    // guard it explicitly so it can never "verify" without actually quoting.
    const isVerified = chunkText !== undefined && normalizedQuote.length > 0 &&
      normalizeArabic(chunkText).includes(normalizedQuote);
    (isVerified ? verified : dropped).push(citation);
  }

  if (verified.length === 0) {
    return {
      answer: "",
      citations: [],
      refused: true,
      model: result.model,
      droppedCitations: dropped,
    };
  }

  return { ...result, citations: verified, droppedCitations: dropped };
}
