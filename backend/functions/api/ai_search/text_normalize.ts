// Arabic text normalization shared by citation-verify and retrieval
// (docs/features/ai-search-m5.0-spec.md §Citation verification: "same
// normalizer retrieval uses"). Strips tashkeel (diacritics) and unifies
// alef/ya letter variants so a quote typed or OCR'd with different — but
// linguistically equivalent — marks still matches the source text.
//
// Written entirely with \u escapes (no literal combining-mark characters in
// source) — literal Arabic diacritics in a regex character class are easy
// to mis-copy into an unintended contiguous range, and \u escapes make the
// exact code points reviewable without relying on a font to render them.

// Tashkeel + Qur'anic annotation marks: FATHATAN..WAVY_HAMZA_BELOW
// (U+064B-U+065F), SUPERSCRIPT ALEF (U+0670), and the small Qur'anic
// annotation signs (U+06D6-U+06ED). Combining marks only, never base
// letters, so stripping them can't merge two different words.
//
// Deliberately NOT one contiguous U+064B-U+0670 range: that range also
// contains the Arabic-Indic digits U+0660-U+0669 and digit separators
// U+066A-U+066D — real content (ayah/hadith/page numbers), not diacritics.
const TASHKEEL_RE = /[ً-ٰٟۖ-ۭ]/g;

// Alef variants → bare alef (ا ا): MADDA ABOVE (آ آ), HAMZA ABOVE
// (أ أ), HAMZA BELOW (إ إ), WASLA (ٱ ٱ).
const ALEF_VARIANTS_RE = /[آأإٱ]/g;
const ALEF = "ا"; // ا

// Ya variants → bare ya (ي ي): ALEF MAKSURA (ى ى), YEH WITH HAMZA
// ABOVE (ئ ئ).
const YA_VARIANTS_RE = /[ىئ]/g;
const YA = "ي"; // ي

// TEH MARBUTA (ة ة) → HEH (ه ه). Matches the database's `fatwa.normalize_ar`
// (0047), which has folded these since the FTS rework. Until this side did
// too, the two halves of one search disagreed about what a word was: FTS
// matched «اللحيه» to «اللحية» while the verifier and the cache key did not —
// so «حلق اللحيه» and «ما حكم حلق اللحية؟» each paid a full run and stored
// separate answers. Users type either freely; OCR emits either freely.
const TEH_MARBUTA_RE = /ة/g;
const HEH = "ه"; // ه

export function normalizeArabic(text: string): string {
  return text
    .replace(TASHKEEL_RE, "")
    .replace(ALEF_VARIANTS_RE, ALEF)
    .replace(YA_VARIANTS_RE, YA)
    .replace(TEH_MARBUTA_RE, HEH)
    .replace(/\s+/g, " ")
    .trim();
}
