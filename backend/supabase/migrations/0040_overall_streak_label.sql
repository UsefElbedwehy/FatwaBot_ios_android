-- 0040: client direction — append the English "(streak)" hint to the overall
-- streak's Arabic name, so the Journey tab's streak card reads
-- "التتابع العام (streak)" rather than the bare Arabic phrase alone.
-- Idempotent: only touches rows that don't already carry the suffix.

update gamification.streak_defs
set name_translations = jsonb_set(
    name_translations, '{ar}', to_jsonb('التتابع العام (streak)'::text)
)
where app_id = public.primary_app_id()
  and key = 'overall'
  and name_translations->>'ar' = 'التتابع العام';
