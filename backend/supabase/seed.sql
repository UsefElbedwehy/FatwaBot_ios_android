-- Seed: default configuration so /v1/config* endpoints serve real data from day one.
-- Values mirror the bundled client defaults (ADR-0011: bundled defaults are offline fallbacks).

insert into config.locales (locale, display_name, direction, digits, enabled, sort_order) values
    ('ar', 'العربية', 'rtl', 'eastern', true, 0),
    ('en', 'English', 'ltr', 'western', true, 1)
on conflict do nothing;

insert into config.feature_flags (key, enabled, description) values
    ('module.prayer',        true,  'Prayer times module'),
    ('module.qibla',         true,  'Qibla compass'),
    ('module.azkar',         true,  'Azkar & Duas'),
    ('module.tasbeeh',       true,  'Digital tasbeeh'),
    ('module.awrad',         true,  'Personal wird routines'),
    ('module.hadith',        true,  'Hadith collections'),
    ('module.gamification',  false, 'Streaks/missions (enables in M3)'),
    ('module.leaderboard',   false, 'Leaderboards (enables in M3)'),
    ('module.ai_ask',        false, 'AI Ask section (enables in M5)'),
    ('home.announcements',   false, 'Announcement/featured content slot')
on conflict do nothing;

insert into config.themes (version, tokens, published) values (1, '{
  "product_name": "Fatwa Bot",
  "light": {
    "color.primary": "#7A2A2A",
    "color.primary_container": "#F3E4E1",
    "color.accent": "#B8860B",
    "color.surface": "#FAF3EC",
    "color.surface_elevated": "#FFFFFF",
    "color.on_surface": "#2B1B17",
    "color.on_surface_secondary": "#6E5A54",
    "color.on_primary": "#FFFFFF",
    "color.outline": "#E3D5CC"
  },
  "dark": {
    "color.primary": "#D08770",
    "color.primary_container": "#3A2422",
    "color.accent": "#D4A73F",
    "color.surface": "#171210",
    "color.surface_elevated": "#221A17",
    "color.on_surface": "#F1E7E0",
    "color.on_surface_secondary": "#B5A398",
    "color.on_primary": "#2B1B17",
    "color.outline": "#463832"
  },
  "shape": {"radius.card": 18, "radius.control": 12},
  "assets": {}
}'::jsonb, true)
on conflict do nothing;

insert into config.home_layouts (platform, version, sections, published) values ('all', 1, '[
  {"id": "header",       "type": "ambient_header",  "props": {}},
  {"id": "prayer",       "type": "prayer_hero",     "props": {"show_timeline": true}},
  {"id": "ask",          "type": "ask_ai",          "props": {"state": "coming_soon", "intents": ["fatwa", "hadith", "general"]}},
  {"id": "today",        "type": "actions_row",     "props": {"show_progress": true}},
  {"id": "streak",       "type": "streak_strip",    "props": {}},
  {"id": "daily_hadith", "type": "content_card",    "props": {"slot": "daily_hadith"}},
  {"id": "daily_dua",    "type": "content_card",    "props": {"slot": "daily_dua"}},
  {"id": "featured",     "type": "announcement",    "props": {"slot": "featured"}},
  {"id": "quick",        "type": "quick_actions",   "props": {"actions": ["qibla", "tasbeeh", "azkar", "history"], "show_widget_hint": true}}
]'::jsonb, true)
on conflict do nothing;

insert into config.prayer_defaults (country_code, method, params) values
    ('*',  'mwl',          '{"madhab": "shafi"}'),
    ('SA', 'umm_al_qura',  '{"madhab": "shafi"}'),
    ('EG', 'egyptian',     '{"madhab": "shafi"}'),
    ('US', 'isna',         '{"madhab": "shafi"}'),
    ('PK', 'karachi',      '{"madhab": "hanafi"}'),
    ('TR', 'turkey',       '{"madhab": "hanafi"}'),
    ('AE', 'dubai',        '{"madhab": "shafi"}')
on conflict do nothing;

insert into config.remote_config (key, value, description) values
    ('hijri.default_offset_days', '0', 'Default Hijri date adjustment'),
    ('notifications.campaign_daily_cap', '2', 'Max campaign (non-worship) notifications per user per day'),
    ('leaderboard.display_name_policy', '"pseudonymous_default"', 'ADR-0007 guardrail')
on conflict do nothing;

insert into config.string_packs (locale, version, strings, published) values
('ar', 1, '{
  "home.greeting.morning": "صباح الخير",
  "home.greeting.evening": "مساء الخير",
  "home.ask.placeholder": "ما حكم...؟",
  "home.ask.trust_line": "البحث عن الإجابة على ضوء منهج أهل السنة والجماعة",
  "home.ask.intent.fatwa": "ابحث عن فتوى",
  "home.ask.intent.hadith": "استخراج الأحاديث",
  "home.ask.intent.general": "سؤال ديني عام",
  "home.ask.coming_soon": "قريباً إن شاء الله",
  "tabs.home": "الرئيسية",
  "tabs.worship": "العبادة",
  "tabs.journey": "المسيرة",
  "tabs.settings": "الإعدادات"
}'::jsonb, true),
('en', 1, '{
  "home.greeting.morning": "Good morning",
  "home.greeting.evening": "Good evening",
  "home.ask.placeholder": "Ask a question…",
  "home.ask.trust_line": "Answers grounded in the methodology of Ahl al-Sunnah wal-Jama’ah",
  "home.ask.intent.fatwa": "Find a fatwa",
  "home.ask.intent.hadith": "Hadith lookup",
  "home.ask.intent.general": "General question",
  "home.ask.coming_soon": "Coming soon, in shaa Allah",
  "tabs.home": "Home",
  "tabs.worship": "Worship",
  "tabs.journey": "Journey",
  "tabs.settings": "Settings"
}'::jsonb, true)
on conflict do nothing;

-- ============================================================================
-- Content domain seed (M2+). Azkar, duas, and the hadith collections are seeded
-- by migrations (0013 azkar/dua; 0015-0021 hadith) with proper provenance and
-- review state, so they are NOT duplicated here — that also keeps this seed
-- compatible with the 0014 publish-requires-approval constraint. Only the wird
-- templates (no review gate) are seeded below for local dev.
-- ============================================================================

do $$
begin
    -- Wird templates (guided creation options, per the Awrad feature)
    insert into content.wird_templates (name_translations, description_translations, type, default_target, default_unit, default_frequency, sort_order, published) values
    ('{"ar": "الصلاة على النبي ﷺ", "en": "Sending Blessings on the Prophet"}'::jsonb,
     '{"ar": "وِرد يومي من الصلاة على النبي صلى الله عليه وسلم", "en": "A daily wird of sending blessings upon the Prophet"}'::jsonb,
     'salawat', 100, 'times', 'daily', 0, true),
    ('{"ar": "تلاوة القرآن الكريم", "en": "Quran Recitation"}'::jsonb,
     '{"ar": "وِرد يومي من قراءة القرآن الكريم", "en": "A daily wird of Quran reading"}'::jsonb,
     'quran_reading', 5, 'pages', 'daily', 1, true),
    ('{"ar": "الاستغفار", "en": "Seeking Forgiveness"}'::jsonb,
     '{"ar": "وِرد يومي من الاستغفار", "en": "A daily wird of seeking Allah''s forgiveness"}'::jsonb,
     'istighfar', 100, 'times', 'daily', 2, true);
end $$;

-- Bootstrap dev admin (docs/features/admin-dashboard-v1.md). DEV-ONLY credentials —
-- rotate the password (or delete this row) before any non-local deployment.
insert into admin.admin_users (email, password_hash) values
    ('admin@fatwabot.dev', crypt('change-me-dev-only', gen_salt('bf')))
on conflict (app_id, email) do nothing;
