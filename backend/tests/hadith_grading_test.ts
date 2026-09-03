import { assertEquals } from "jsr:@std/assert";
import { extractGrading, normalizeWithMap } from "../scripts/extract_hadith_grading.ts";

Deno.test("normalizeWithMap indices address the original string", () => {
  const text = "أَخْرَجَهُ";
  const { normalized, map } = normalizeWithMap(text);
  assertEquals(normalized, "اخرجه");
  // Every mapped index must point at the character that produced it.
  assertEquals(map.length, normalized.length);
  assertEquals(text[map[0]], "أ");
});

Deno.test("extracts a takhrij that shares the matn's sentence", () => {
  // The common shape: no period before the attribution.
  const matn = "قَالَ رَسُولُ اللَّهِ - ﷺ - فِي الْبَحْرِ: «هُوَ الطَّهُورُ مَاؤُهُ» أَخْرَجَهُ الْأَرْبَعَةُ، وَصَحَّحَهُ ابْنُ خُزَيْمَةَ.";
  assertEquals(
    extractGrading(matn),
    "أَخْرَجَهُ الْأَرْبَعَةُ، وَصَحَّحَهُ ابْنُ خُزَيْمَةَ.",
  );
});

Deno.test("extracts a bare متفق عليه", () => {
  // Regression: an earlier pattern wrote `ما?`, which is "م then optional ا" —
  // it required متفق عليهما and silently missed every plain متفق عليه, i.e. the
  // single most common grading in the corpus.
  const matn = "«تَسَحَّرُوا فَإِنَّ فِي السَّحُورِ بَرَكَةً» مُتَّفَقٌ عَلَيْهِ.";
  assertEquals(extractGrading(matn), "مُتَّفَقٌ عَلَيْهِ.");
});

Deno.test("keeps a verdict sentence that follows the attribution", () => {
  const matn = "«...» مُتَّفَقٌ عَلَيْهِ. وَاللَّفْظُ لِمُسْلِمٍ.";
  assertEquals(extractGrading(matn), "مُتَّفَقٌ عَلَيْهِ. وَاللَّفْظُ لِمُسْلِمٍ.");
});

Deno.test("stops before ibn Hajr's commentary", () => {
  const matn = "«وَلْيَضَعْ يَدَيْهِ قَبْلَ رُكْبَتَيْهِ» أَخْرَجَهُ الثَّلَاثَةُ. وَهُوَ أَقْوَى مِنْ حَدِيثِ وَائِلٍ.";
  assertEquals(extractGrading(matn), "أَخْرَجَهُ الثَّلَاثَةُ.");
});

Deno.test("anchors on the last attribution, not a mid-text one", () => {
  const matn = "وَرَوَاهُ فُلَانٌ فِي أَثْنَاءِ الْحَدِيثِ. ثُمَّ الْمَتْنُ. رَوَاهُ مُسْلِمٌ.";
  assertEquals(extractGrading(matn), "رَوَاهُ مُسْلِمٌ.");
});

Deno.test("returns empty when there is no takhrij at all", () => {
  // العمدة entries end at the matn — the work is defined as agreed-upon hadith,
  // so it never repeats an attribution per entry. Nothing to extract.
  const matn = "قَالَ رَسُولُ اللَّهِ ﷺ: «وَيْلٌ لِلْأَعْقَابِ مِنَ النَّارِ».";
  assertEquals(extractGrading(matn), "");
});

Deno.test("never returns text absent from the matn", () => {
  const matn = "«...» رَوَاهُ أَبُو دَاوُدَ وَضَعَّفَهُ.";
  const grading = extractGrading(matn);
  assertEquals(matn.includes(grading), true);
});

Deno.test("rejects a verb inside the matn mistaken for an attribution", () => {
  // العمدة 173: أخرجه here is Abu Sa'id's verb, and the clause ends on a closing
  // quote it never opened — the tell that the anchor landed inside the matn.
  const matn = "قَالَ أَبُو سَعِيدٍ: أَمَّا أَنَا؛ فَلَا أَزَالُ أُخْرِجُهُ كَمَا كُنْتُ أُخْرِجُهُ ».";
  assertEquals(extractGrading(matn), "");
});

Deno.test("keeps a takhrij that legitimately quotes an alternate wording", () => {
  // Same character, balanced — this one is real and must survive.
  const matn = "«...» أَخْرَجَهُ مُسْلِمٌ، وَفِي لَفْظٍ لَهُ: «فَلْيُرِقْهُ».";
  assertEquals(
    extractGrading(matn),
    "أَخْرَجَهُ مُسْلِمٌ، وَفِي لَفْظٍ لَهُ: «فَلْيُرِقْهُ».",
  );
});

Deno.test("rejects an isnad note listing companions rather than collectors", () => {
  const matn = "«...» رَوَاهُ: أَبُو هُرَيْرَةَ، وَعَائِشَةُ، وَأَنَسُ بْنُ مَالِكٍ ﵃.";
  assertEquals(extractGrading(matn), "");
});

Deno.test("keeps a takhrij whose collector is followed by a colon", () => {
  const matn = "«...» رَوَاهُ الْبَيْهَقِيُّ: عَنْ عَلِيٍّ - ﵁ - مِنْ قَوْلِهِ.";
  assertEquals(extractGrading(matn), "رَوَاهُ الْبَيْهَقِيُّ: عَنْ عَلِيٍّ - ﵁ - مِنْ قَوْلِهِ.");
});
