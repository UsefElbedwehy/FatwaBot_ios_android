-- 0012: seed the gamification definitions the Journey tab renders.
--
-- `supabase db push` applies migrations but NEVER runs seed.sql, and seed.sql
-- never covered gamification anyway — so streak_defs / missions / badges were
-- empty in every environment. Activity events were being ingested correctly
-- (POST /v1/gamification/events -> accepted:1) but there were no definitions to
-- evaluate them against, so GET /v1/gamification/profile always returned
-- {streaks:[],missions:[],badges:[]} and Journey looked broken.
--
-- event_type values below are the ones both clients actually emit:
--   azkar_completed, tasbeeh_session_completed, wird_day_completed,
--   wird_ticked, hadith_entry_read
-- `published = true` is required for the API to serve them.
-- Idempotent: re-running is a no-op.

-- Streaks: one per worship category plus an overall streak (the "overall box"
-- from the product brief). Day boundary 04:00 local so a late-night session
-- still counts for the day it belongs to; one grace ("mercy") day.
insert into gamification.streak_defs
    (key, name_translations, event_types, required_daily_count, grace_allowance, enabled, published)
values
    ('overall',
     '{"ar":"التتابع العام","en":"Overall streak"}'::jsonb,
     array['azkar_completed','tasbeeh_session_completed','wird_day_completed','hadith_entry_read'],
     1, 1, true, true),
    ('azkar',
     '{"ar":"تتابع الأذكار","en":"Azkar streak"}'::jsonb,
     array['azkar_completed'], 1, 1, true, true),
    ('tasbeeh',
     '{"ar":"تتابع التسبيح","en":"Tasbeeh streak"}'::jsonb,
     array['tasbeeh_session_completed'], 1, 1, true, true),
    ('awrad',
     '{"ar":"تتابع الأوراد","en":"Awrad streak"}'::jsonb,
     array['wird_day_completed'], 1, 1, true, true),
    ('hadith',
     '{"ar":"تتابع الأحاديث","en":"Hadith streak"}'::jsonb,
     array['hadith_entry_read'], 1, 1, true, true)
on conflict (app_id, key) do nothing;

-- Daily/weekly missions.
insert into gamification.missions
    (key, name_translations, description_translations, event_type, target_count,
     progress_window, schedule, reward_translations, published)
values
    ('daily_azkar',
     '{"ar":"أذكار اليوم","en":"Today''s azkar"}'::jsonb,
     '{"ar":"أكمل مجموعة أذكار واحدة اليوم","en":"Complete one azkar set today"}'::jsonb,
     'azkar_completed', 1, 'daily', 'daily',
     '{"ar":"تقبل الله","en":"May Allah accept it"}'::jsonb, true),
    ('daily_tasbeeh',
     '{"ar":"تسبيح اليوم","en":"Today''s tasbeeh"}'::jsonb,
     '{"ar":"أكمل جولة تسبيح واحدة اليوم","en":"Complete one tasbeeh set today"}'::jsonb,
     'tasbeeh_session_completed', 1, 'daily', 'daily',
     '{"ar":"تقبل الله","en":"May Allah accept it"}'::jsonb, true),
    ('daily_wird',
     '{"ar":"ورد اليوم","en":"Today''s wird"}'::jsonb,
     '{"ar":"أتمم وردك اليومي","en":"Finish your daily wird"}'::jsonb,
     'wird_day_completed', 1, 'daily', 'daily',
     '{"ar":"تقبل الله","en":"May Allah accept it"}'::jsonb, true),
    ('weekly_hadith',
     '{"ar":"خمسة أحاديث هذا الأسبوع","en":"Five hadith this week"}'::jsonb,
     '{"ar":"اقرأ خمسة أحاديث خلال الأسبوع","en":"Read five hadith this week"}'::jsonb,
     'hadith_entry_read', 5, 'weekly', 'weekly',
     '{"ar":"زادك الله علماً","en":"May Allah increase you in knowledge"}'::jsonb, true)
on conflict (app_id, key) do nothing;

-- Lifetime milestone badges.
insert into gamification.badges
    (key, name_translations, description_translations, icon_ref, event_type,
     target_count, progress_window, published)
values
    ('azkar_7',
     '{"ar":"مداوم الأذكار","en":"Azkar keeper"}'::jsonb,
     '{"ar":"أكمل الأذكار سبع مرات","en":"Complete azkar seven times"}'::jsonb,
     'sparkles', 'azkar_completed', 7, 'lifetime', true),
    ('azkar_30',
     '{"ar":"ملازم الأذكار","en":"Azkar devotee"}'::jsonb,
     '{"ar":"أكمل الأذكار ثلاثين مرة","en":"Complete azkar thirty times"}'::jsonb,
     'star.fill', 'azkar_completed', 30, 'lifetime', true),
    ('tasbeeh_50',
     '{"ar":"كثير التسبيح","en":"Abundant in tasbeeh"}'::jsonb,
     '{"ar":"أكمل خمسين جولة تسبيح","en":"Complete fifty tasbeeh sets"}'::jsonb,
     'circle.hexagongrid.fill', 'tasbeeh_session_completed', 50, 'lifetime', true),
    ('wird_30',
     '{"ar":"صاحب الورد","en":"Wird companion"}'::jsonb,
     '{"ar":"أتمم وردك ثلاثين يوماً","en":"Finish your wird on thirty days"}'::jsonb,
     'book.closed.fill', 'wird_day_completed', 30, 'lifetime', true),
    ('hadith_50',
     '{"ar":"طالب الحديث","en":"Student of hadith"}'::jsonb,
     '{"ar":"اقرأ خمسين حديثاً","en":"Read fifty hadith"}'::jsonb,
     'text.book.closed.fill', 'hadith_entry_read', 50, 'lifetime', true)
on conflict (app_id, key) do nothing;
