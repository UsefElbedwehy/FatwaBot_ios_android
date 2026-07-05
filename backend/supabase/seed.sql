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
-- Content domain seed (M2, docs/features/content-pipeline.md).
-- Texts are drawn from widely published, centuries-old public sources
-- (Hisnul Muslim-style morning/evening azkar; Sahih al-Bukhari/Muslim hadith;
-- Nawawi's 40). English translations here are unreviewed drafts for
-- development — production content goes through the dashboard's
-- draft->review->publish workflow (ADR-0014) before real users see it.
-- ============================================================================

do $$
declare
    cat_morning uuid;
    cat_evening uuid;
    cat_after_prayer uuid;
    dua_cat_quran uuid;
    dua_cat_daily uuid;
    hadith_col_nawawi uuid;
begin
    insert into content.azkar_categories (slug, name_translations, sort_order, published)
    values ('morning', '{"ar": "أذكار الصباح", "en": "Morning Azkar"}'::jsonb, 0, true)
    returning id into cat_morning;

    insert into content.azkar_categories (slug, name_translations, sort_order, published)
    values ('evening', '{"ar": "أذكار المساء", "en": "Evening Azkar"}'::jsonb, 1, true)
    returning id into cat_evening;

    insert into content.azkar_categories (slug, name_translations, sort_order, published)
    values ('after_prayer', '{"ar": "أذكار بعد الصلاة", "en": "After-Prayer Azkar"}'::jsonb, 2, true)
    returning id into cat_after_prayer;

    -- Morning azkar
    insert into content.azkar_items (category_id, sort_order, arabic_text, translation_translations, repeat_count, source, published) values
    (cat_morning, 0,
     'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
     '{"en": "We have reached the morning and at this very time unto Allah belongs all sovereignty, and all praise is for Allah. None has the right to be worshipped except Allah, alone, without partner."}'::jsonb,
     1, 'رواه مسلم', true),
    (cat_morning, 1,
     'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
     '{"en": "O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection."}'::jsonb,
     1, 'رواه الترمذي', true),
    (cat_morning, 2,
     'سَيِّدُ الاِسْتِغْفَارِ: اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ',
     '{"en": "The master of seeking forgiveness: O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me and I acknowledge my sin, so forgive me, for none forgives sins except You."}'::jsonb,
     1, 'رواه البخاري', true),
    (cat_morning, 3, 'حَسْبِيَ اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
     '{"en": "Allah is sufficient for me. None has the right to be worshipped except Him. Upon Him I rely, and He is the Lord of the mighty Throne."}'::jsonb,
     7, 'رواه أبو داود', true),
    (cat_morning, 4, 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
     '{"en": "Glory is to Allah and praise is to Him."}'::jsonb,
     100, 'رواه مسلم', true);

    -- Evening azkar (mirrors morning with أمسينا)
    insert into content.azkar_items (category_id, sort_order, arabic_text, translation_translations, repeat_count, source, published) values
    (cat_evening, 0,
     'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
     '{"en": "We have reached the evening and at this very time unto Allah belongs all sovereignty, and all praise is for Allah. None has the right to be worshipped except Allah, alone, without partner."}'::jsonb,
     1, 'رواه مسلم', true),
    (cat_evening, 1,
     'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
     '{"en": "O Allah, by You we enter the evening and by You we enter the morning, by You we live and by You we die, and to You is the return."}'::jsonb,
     1, 'رواه الترمذي', true),
    (cat_evening, 2,
     'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
     '{"en": "I seek refuge in the perfect words of Allah from the evil of what He has created."}'::jsonb,
     3, 'رواه مسلم', true);

    -- After-prayer azkar
    insert into content.azkar_items (category_id, sort_order, arabic_text, translation_translations, repeat_count, source, published) values
    (cat_after_prayer, 0, 'أَسْتَغْفِرُ اللَّهَ',
     '{"en": "I seek the forgiveness of Allah."}'::jsonb, 3, 'رواه مسلم', true),
    (cat_after_prayer, 1,
     'اللَّهُمَّ أَنْتَ السَّلاَمُ وَمِنْكَ السَّلاَمُ، تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ',
     '{"en": "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor."}'::jsonb,
     1, 'رواه مسلم', true),
    (cat_after_prayer, 2, 'سُبْحَانَ اللَّهِ',
     '{"en": "Glory is to Allah."}'::jsonb, 33, 'رواه البخاري ومسلم', true),
    (cat_after_prayer, 3, 'الْحَمْدُ لِلَّهِ',
     '{"en": "Praise is to Allah."}'::jsonb, 33, 'رواه البخاري ومسلم', true),
    (cat_after_prayer, 4, 'اللَّهُ أَكْبَرُ',
     '{"en": "Allah is the Greatest."}'::jsonb, 33, 'رواه البخاري ومسلم', true),
    (cat_after_prayer, 5,
     'لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
     '{"en": "None has the right to be worshipped except Allah, alone, without partner. His is the dominion and His is the praise, and He is over all things omnipotent."}'::jsonb,
     1, 'رواه البخاري ومسلم', true);

    -- Dua categories + duas
    insert into content.dua_categories (slug, name_translations, sort_order, published)
    values ('quran', '{"ar": "أدعية قرآنية", "en": "Quranic Duas"}'::jsonb, 0, true)
    returning id into dua_cat_quran;

    insert into content.dua_categories (slug, name_translations, sort_order, published)
    values ('daily', '{"ar": "أدعية يومية", "en": "Daily Occasions"}'::jsonb, 1, true)
    returning id into dua_cat_daily;

    insert into content.duas (category_id, sort_order, title_translations, arabic_text, translation_translations, source, published) values
    (dua_cat_quran, 0,
     '{"ar": "ربنا آتنا في الدنيا حسنة", "en": "Our Lord, Give Us Good"}'::jsonb,
     'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
     '{"en": "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire."}'::jsonb,
     'سورة البقرة: 201', true),
    (dua_cat_quran, 1,
     '{"ar": "رب اشرح لي صدري", "en": "My Lord, Expand for Me My Chest"}'::jsonb,
     'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
     '{"en": "My Lord, expand for me my chest and ease for me my task."}'::jsonb,
     'سورة طه: 25-26', true),
    (dua_cat_daily, 0,
     '{"ar": "دعاء الاستخارة", "en": "Dua of Istikhara"}'::jsonb,
     'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ',
     '{"en": "O Allah, I seek Your guidance by virtue of Your knowledge, and I seek ability by virtue of Your power, and I ask You of Your great bounty."}'::jsonb,
     'رواه البخاري', true),
    (dua_cat_daily, 1,
     '{"ar": "دعاء عند الكرب", "en": "Dua at Times of Distress"}'::jsonb,
     'لاَ إِلَهَ إِلاَّ اللَّهُ الْعَظِيمُ الْحَلِيمُ، لاَ إِلَهَ إِلاَّ اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ',
     '{"en": "None has the right to be worshipped except Allah, the Mighty, the Forbearing. None has the right to be worshipped except Allah, Lord of the mighty Throne."}'::jsonb,
     'رواه البخاري ومسلم', true);

    -- Hadith collection: Nawawi's 40 (seeded subset; remaining entries via CMS)
    insert into content.hadith_collections (slug, name_translations, description_translations, sort_order, published)
    values ('nawawi40', '{"ar": "الأربعون النووية", "en": "The Forty Hadith of an-Nawawi"}'::jsonb,
            '{"ar": "أربعون حديثاً جامعة لأصول الدين اختارها الإمام النووي", "en": "Forty hadith on the foundations of the faith, compiled by Imam an-Nawawi"}'::jsonb,
            0, true)
    returning id into hadith_col_nawawi;

    insert into content.hadith_entries (collection_id, number, arabic_text, translation_translations, grading, benefit_note_translations, source, published) values
    (hadith_col_nawawi, 1,
     'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى، فَمَنْ كَانَتْ هِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ فَهِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ، وَمَنْ كَانَتْ هِجْرَتُهُ لِدُنْيَا يُصِيبُهَا أَوِ امْرَأَةٍ يَنْكِحُهَا فَهِجْرَتُهُ إِلَى مَا هَاجَرَ إِلَيْهِ',
     '{"en": "Actions are but by intentions, and every man shall have only that which he intended. Thus, he whose migration was for Allah and His Messenger, his migration was for Allah and His Messenger; and he whose migration was to achieve some worldly benefit or to take some woman in marriage, his migration was for that for which he migrated."}'::jsonb,
     'متفق عليه',
     '{"ar": "الأعمال لا تُقبل ولا يُثاب عليها إلا بالنية الخالصة لله، وكل امرئ يُجازى على حسب نيته، فالنية هي روح العبادة.", "en": "Deeds are not accepted or rewarded except with sincere intention for Allah alone; every person is judged by their intention, which is the spirit of worship."}'::jsonb,
     'رواه البخاري ومسلم', true),
    (hadith_col_nawawi, 3,
     'بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَإِقَامِ الصَّلاَةِ، وَإِيتَاءِ الزَّكَاةِ، وَحَجِّ الْبَيْتِ، وَصَوْمِ رَمَضَانَ',
     '{"en": "Islam is built upon five pillars: testifying that there is no god but Allah and that Muhammad is the Messenger of Allah, establishing prayer, paying zakah, making pilgrimage to the House, and fasting Ramadan."}'::jsonb,
     'متفق عليه',
     '{"ar": "هذه الأركان الخمسة هي أساس الإسلام العملي، ومن حافظ عليها فقد أقام دينه.", "en": "These five pillars are the practical foundation of Islam; whoever upholds them has established their faith."}'::jsonb,
     'رواه البخاري ومسلم', true),
    (hadith_col_nawawi, 13,
     'لاَ يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
     '{"en": "None of you truly believes until he loves for his brother what he loves for himself."}'::jsonb,
     'متفق عليه',
     '{"ar": "هذا الحديث أصل عظيم في الأخوة الإيمانية، ويدعو إلى نزع الأثرة والحسد من القلب.", "en": "A great principle of brotherhood in faith, calling one to remove selfishness and envy from the heart."}'::jsonb,
     'رواه البخاري ومسلم', true);

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
