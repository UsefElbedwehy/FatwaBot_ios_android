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
 *  dropped exactly like a genuine substring mismatch.
 *
 *  Citations are checked even on an answer the model already self-refused
 *  (`result.refused === true`) — e.g. hadith mode citing the closest
 *  authentic wording while still refusing the exact quote asked for. An
 *  earlier version skipped verification whenever `refused` was already
 *  true, which meant a self-refusal's citations reached the user
 *  unverified — the one case citation-verify exists to prevent. */
export function verifyCitations(
  result: AnswerResult,
  chunkTextById: ReadonlyMap<string, string>,
): VerifiedAnswer {
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

  // Only force a hard refusal + blanked answer when there WERE citations and
  // every one of them was fabricated — the model's only supporting evidence
  // turned out to be fake, so nothing about the answer can be trusted. A
  // bare self-refusal with no citations at all (or one that already
  // verified) is left as-is, including whatever `answer` text the model
  // wrote — handlers/search.ts decides what to actually show for that.
  if (result.citations.length > 0 && verified.length === 0) {
    // Everything structured goes with the answer, not just `answer` itself.
    // The summary, the per-scholar cards and the hadith grading were all
    // written on the strength of citations that turned out to be fabricated —
    // keeping any of them would leave the fabrication on screen in a different
    // shape, and the ruling would still colour a status dot.
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
