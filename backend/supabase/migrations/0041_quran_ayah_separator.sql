-- 0041: client direction — standalone Qur'an passages (Al-Ikhlas, Al-Falaq,
-- An-Nas, morning + evening azkar) should separate ayat with the Qur'anic
-- end-of-ayah mark (۝) rather than an ordinary Arabic comma. Scoped to these
-- three Qur'an-only items; every other azkar/dua/hadith entry keeps its
-- ordinary commas.
--
-- Matched by (category slug, sort_order) rather than by the Arabic text
-- itself: a hand-typed Arabic literal is one canonically-equivalent but
-- byte-different combining-mark order away from silently matching zero rows
-- (found the hard way — an earlier version of this migration did exactly
-- that against the live DB). Position is a stable, ASCII-only identifier for
-- the same six rows the seed JSON (content/seed/azkar.ar.json) assigns them.
--
-- Idempotent: the `like '%، %'` guard means only rows still holding the old
-- comma form are touched, so re-running db push after this has applied once
-- is a no-op.

update content.azkar_items ai
set arabic_text = replace(ai.arabic_text, '، ', ' ۝ '),
    version = ai.version + 1,
    updated_at = now()
from content.azkar_categories ac
join (
    values ('morning', 2), ('morning', 3), ('morning', 4),
           ('evening', 3), ('evening', 4), ('evening', 5)
) as target(slug, sort_order) on ac.slug = target.slug
where ai.category_id = ac.id
  and ai.sort_order = target.sort_order
  and ac.app_id = public.primary_app_id()
  and ai.arabic_text like '%، %';
