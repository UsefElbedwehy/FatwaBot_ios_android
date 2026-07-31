-- 0028: publish بلوغ المرام and العمدة في الأحكام (owner decision, 2026-07-31).
--
-- 0025 seeded both as `review_status = 'pending'`, behind the content review
-- gate added in 0014 (`not published or review_status = 'approved'`). The owner
-- has approved them for release without a per-entry scholarly pass.
--
-- Recorded here rather than done by hand in the dashboard so the decision is
-- versioned, reviewable, and reproducible in every environment — and so it is
-- obvious later *that* the gate was bypassed for these two collections, rather
-- than someone inferring the entries were individually reviewed.
--
-- Deliberately scoped to these two slugs. It does NOT approve pending content
-- generally, and it does NOT restore the six Kutub al-Sittah that 0025
-- unpublished — those 34,083 entries stay preserved and unpublished.
--
-- Both works are classical and long out of copyright:
--   بلوغ المرام — الحافظ ابن حجر العسقلاني (d. 852 AH)
--   العمدة في الأحكام — الحافظ عبد الغني المقدسي (d. 600 AH)
--
-- Idempotent: re-running is a no-op.

update content.hadith_entries e
set review_status = 'approved',
    published = true
from content.hadith_collections c
where e.collection_id = c.id
  and e.app_id = c.app_id
  and c.slug in ('bulugh_almaram', 'umdat_alahkam')
  and (e.review_status is distinct from 'approved' or e.published is not true);

-- The collections themselves were already published by 0025; this only matters
-- if one was toggled off in between.
update content.hadith_collections
set published = true
where slug in ('bulugh_almaram', 'umdat_alahkam')
  and published is not true;
