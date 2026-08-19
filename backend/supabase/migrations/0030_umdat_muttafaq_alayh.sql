-- 0030: stamp "متفق عليه" across العمدة في الأحكام (owner decision, 2026-08-01),
-- and clear two false positives left by the 0029 extractor.
--
-- ## Why a stamp is defensible here
-- العمدة carries no per-hadith takhrij because the work is *defined* as hadith
-- agreed upon by البخاري and مسلم — عبد الغني المقدسي states the criterion in his
-- introduction, so repeating it on every entry would be redundant in print.
-- Recording it per row is what lets the app display and filter on it.
--
-- Unlike 0029, this value is **authored, not extracted** — "متفق عليه" appears
-- nowhere in these entries' matn. That is the whole reason it is a separate
-- migration with its own note rather than more rows in 0029.
--
-- ## What is deliberately NOT stamped
-- Five entries carry an explicit attribution of their own, and every one of them
-- contradicts the blanket rule. Overwriting them would turn a redundancy into a
-- factual error:
--
--   187  أخرجه أبو داود        — not in either Sahih
--   198  أخرجه مسلم بتمامه     — Muslim only
--   340  أخرجه الجماعة         — all seven, wider than the two
--   397  أخرجه مسلم            — Muslim only
--   398  أخرجه البخاري         — Bukhari only
--
-- They keep what the text itself says. 409 of 414 entries are stamped.
--
-- ## The two cleared entries
-- 0029's extractor misfired twice, both in العمدة, and both are now rejected by
-- guards in scripts/extract_hadith_grading.ts (with tests):
--
--   173  "أُخْرِجُهُ »"  — أخرجه is Abu Sa'id's verb inside the matn, and the clause
--        closes a quote it never opened. Cleared, then stamped like its peers.
--   191  "رَوَاهُ: أَبُو هُرَيْرَةَ، وَعَائِشَةُ، وَأَنَسُ بْنُ مَالِكٍ" — those are the companions who
--        narrated it, not collectors. Cleared, then stamped like its peers.
--
-- Idempotent: re-running changes nothing.

-- 1. Clear the two misfires so they fall through to the stamp below.
update content.hadith_entries e
set grading = ''
from content.hadith_collections c
where e.collection_id = c.id
  and e.app_id = c.app_id
  and c.slug = 'umdat_alahkam'
  and e.number in (173, 191)
  and e.grading <> '';

-- 2. Stamp the collection's defining criterion on every entry that does not
--    state its own attribution.
update content.hadith_entries e
set grading = 'مُتَّفَقٌ عَلَيْهِ.'
from content.hadith_collections c
where e.collection_id = c.id
  and e.app_id = c.app_id
  and c.slug = 'umdat_alahkam'
  and coalesce(e.grading, '') = '';
