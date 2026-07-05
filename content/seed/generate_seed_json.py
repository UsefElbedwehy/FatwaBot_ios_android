#!/usr/bin/env python3
"""Generates the bundled client seed JSON files from one source of truth.

These mirror exactly what GET /v1/content/{collection}?locale={locale} returns
(server-resolved plain strings, not translation maps) so the client's cache
format and the bundled-fallback format are identical — one decode path.

Content matches backend/supabase/seed.sql. IDs here are fixed placeholders
(the real backend generates its own UUIDs on seed) — see
docs/notes/M2_IMPLEMENTATION_NOTES.md for the known first-sync ID
reconciliation limitation this implies.

Regenerate: python3 generate_seed_json.py
"""
import json
import os

def uid(n):
    return f"00000000-0000-4000-a000-{n:012d}"

AZKAR = {
    "version": 1,
    "categories": [
        {
            "id": uid(1), "slug": "morning", "sortOrder": 0,
            "name": {"ar": "أذكار الصباح", "en": "Morning Azkar"},
            "items": [
                {"id": uid(101), "sortOrder": 0, "repeatCount": 1, "source": "رواه مسلم",
                 "arabicText": "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
                 "transliteration": None,
                 "translation": {"en": "We have reached the morning and at this very time unto Allah belongs all sovereignty, and all praise is for Allah. None has the right to be worshipped except Allah, alone, without partner."},
                 "virtueNote": None},
                {"id": uid(102), "sortOrder": 1, "repeatCount": 1, "source": "رواه الترمذي",
                 "arabicText": "اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ",
                 "transliteration": None,
                 "translation": {"en": "O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection."},
                 "virtueNote": None},
                {"id": uid(103), "sortOrder": 2, "repeatCount": 1, "source": "رواه البخاري",
                 "arabicText": "سَيِّدُ الاِسْتِغْفَارِ: اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ",
                 "transliteration": None,
                 "translation": {"en": "The master of seeking forgiveness: O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant... forgive me, for none forgives sins except You."},
                 "virtueNote": None},
                {"id": uid(104), "sortOrder": 3, "repeatCount": 7, "source": "رواه أبو داود",
                 "arabicText": "حَسْبِيَ اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ",
                 "transliteration": None,
                 "translation": {"en": "Allah is sufficient for me. None has the right to be worshipped except Him. Upon Him I rely, and He is the Lord of the mighty Throne."},
                 "virtueNote": None},
                {"id": uid(105), "sortOrder": 4, "repeatCount": 100, "source": "رواه مسلم",
                 "arabicText": "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
                 "transliteration": None,
                 "translation": {"en": "Glory is to Allah and praise is to Him."},
                 "virtueNote": None},
            ],
        },
        {
            "id": uid(2), "slug": "evening", "sortOrder": 1,
            "name": {"ar": "أذكار المساء", "en": "Evening Azkar"},
            "items": [
                {"id": uid(201), "sortOrder": 0, "repeatCount": 1, "source": "رواه مسلم",
                 "arabicText": "أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
                 "transliteration": None,
                 "translation": {"en": "We have reached the evening and at this very time unto Allah belongs all sovereignty, and all praise is for Allah. None has the right to be worshipped except Allah, alone, without partner."},
                 "virtueNote": None},
                {"id": uid(202), "sortOrder": 1, "repeatCount": 1, "source": "رواه الترمذي",
                 "arabicText": "اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ",
                 "transliteration": None,
                 "translation": {"en": "O Allah, by You we enter the evening and by You we enter the morning, by You we live and by You we die, and to You is the return."},
                 "virtueNote": None},
                {"id": uid(203), "sortOrder": 2, "repeatCount": 3, "source": "رواه مسلم",
                 "arabicText": "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",
                 "transliteration": None,
                 "translation": {"en": "I seek refuge in the perfect words of Allah from the evil of what He has created."},
                 "virtueNote": None},
            ],
        },
        {
            "id": uid(3), "slug": "after_prayer", "sortOrder": 2,
            "name": {"ar": "أذكار بعد الصلاة", "en": "After-Prayer Azkar"},
            "items": [
                {"id": uid(301), "sortOrder": 0, "repeatCount": 3, "source": "رواه مسلم",
                 "arabicText": "أَسْتَغْفِرُ اللَّهَ", "transliteration": None,
                 "translation": {"en": "I seek the forgiveness of Allah."}, "virtueNote": None},
                {"id": uid(302), "sortOrder": 1, "repeatCount": 1, "source": "رواه مسلم",
                 "arabicText": "اللَّهُمَّ أَنْتَ السَّلاَمُ وَمِنْكَ السَّلاَمُ، تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ",
                 "transliteration": None,
                 "translation": {"en": "O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of majesty and honor."},
                 "virtueNote": None},
                {"id": uid(303), "sortOrder": 2, "repeatCount": 33, "source": "رواه البخاري ومسلم",
                 "arabicText": "سُبْحَانَ اللَّهِ", "transliteration": None,
                 "translation": {"en": "Glory is to Allah."}, "virtueNote": None},
                {"id": uid(304), "sortOrder": 3, "repeatCount": 33, "source": "رواه البخاري ومسلم",
                 "arabicText": "الْحَمْدُ لِلَّهِ", "transliteration": None,
                 "translation": {"en": "Praise is to Allah."}, "virtueNote": None},
                {"id": uid(305), "sortOrder": 4, "repeatCount": 33, "source": "رواه البخاري ومسلم",
                 "arabicText": "اللَّهُ أَكْبَرُ", "transliteration": None,
                 "translation": {"en": "Allah is the Greatest."}, "virtueNote": None},
                {"id": uid(306), "sortOrder": 5, "repeatCount": 1, "source": "رواه البخاري ومسلم",
                 "arabicText": "لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
                 "transliteration": None,
                 "translation": {"en": "None has the right to be worshipped except Allah, alone, without partner. His is the dominion and His is the praise, and He is over all things omnipotent."},
                 "virtueNote": None},
            ],
        },
    ],
}

DUAS = {
    "version": 1,
    "categories": [
        {
            "id": uid(10), "slug": "quran", "sortOrder": 0,
            "name": {"ar": "أدعية قرآنية", "en": "Quranic Duas"},
            "duas": [
                {"id": uid(1001), "sortOrder": 0, "source": "سورة البقرة: 201",
                 "title": {"ar": "ربنا آتنا في الدنيا حسنة", "en": "Our Lord, Give Us Good"},
                 "arabicText": "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
                 "transliteration": None,
                 "translation": {"en": "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire."}},
                {"id": uid(1002), "sortOrder": 1, "source": "سورة طه: 25-26",
                 "title": {"ar": "رب اشرح لي صدري", "en": "My Lord, Expand for Me My Chest"},
                 "arabicText": "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
                 "transliteration": None,
                 "translation": {"en": "My Lord, expand for me my chest and ease for me my task."}},
            ],
        },
        {
            "id": uid(11), "slug": "daily", "sortOrder": 1,
            "name": {"ar": "أدعية يومية", "en": "Daily Occasions"},
            "duas": [
                {"id": uid(1101), "sortOrder": 0, "source": "رواه البخاري",
                 "title": {"ar": "دعاء الاستخارة", "en": "Dua of Istikhara"},
                 "arabicText": "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ",
                 "transliteration": None,
                 "translation": {"en": "O Allah, I seek Your guidance by virtue of Your knowledge, and I seek ability by virtue of Your power, and I ask You of Your great bounty."}},
                {"id": uid(1102), "sortOrder": 1, "source": "رواه البخاري ومسلم",
                 "title": {"ar": "دعاء عند الكرب", "en": "Dua at Times of Distress"},
                 "arabicText": "لاَ إِلَهَ إِلاَّ اللَّهُ الْعَظِيمُ الْحَلِيمُ، لاَ إِلَهَ إِلاَّ اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ",
                 "transliteration": None,
                 "translation": {"en": "None has the right to be worshipped except Allah, the Mighty, the Forbearing. None has the right to be worshipped except Allah, Lord of the mighty Throne."}},
            ],
        },
    ],
}

HADITH_COLLECTION_SLUG = "nawawi40"
HADITH_DETAIL = {
    "version": 1,
    "slug": HADITH_COLLECTION_SLUG,
    "name": {"ar": "الأربعون النووية", "en": "The Forty Hadith of an-Nawawi"},
    "description": {
        "ar": "أربعون حديثاً جامعة لأصول الدين اختارها الإمام النووي",
        "en": "Forty hadith on the foundations of the faith, compiled by Imam an-Nawawi",
    },
    "entries": [
        {"id": uid(2001), "number": 1, "grading": "متفق عليه", "source": "رواه البخاري ومسلم",
         "arabicText": "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى، فَمَنْ كَانَتْ هِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ فَهِجْرَتُهُ إِلَى اللَّهِ وَرَسُولِهِ، وَمَنْ كَانَتْ هِجْرَتُهُ لِدُنْيَا يُصِيبُهَا أَوِ امْرَأَةٍ يَنْكِحُهَا فَهِجْرَتُهُ إِلَى مَا هَاجَرَ إِلَيْهِ",
         "translation": {"en": "Actions are but by intentions, and every man shall have only that which he intended. Thus, he whose migration was for Allah and His Messenger, his migration was for Allah and His Messenger; and he whose migration was to achieve some worldly benefit or to take some woman in marriage, his migration was for that for which he migrated."},
         "benefitNote": {"ar": "الأعمال لا تُقبل ولا يُثاب عليها إلا بالنية الخالصة لله، وكل امرئ يُجازى على حسب نيته، فالنية هي روح العبادة.",
                          "en": "Deeds are not accepted or rewarded except with sincere intention for Allah alone; every person is judged by their intention, which is the spirit of worship."}},
        {"id": uid(2002), "number": 3, "grading": "متفق عليه", "source": "رواه البخاري ومسلم",
         "arabicText": "بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَإِقَامِ الصَّلاَةِ، وَإِيتَاءِ الزَّكَاةِ، وَحَجِّ الْبَيْتِ، وَصَوْمِ رَمَضَانَ",
         "translation": {"en": "Islam is built upon five pillars: testifying that there is no god but Allah and that Muhammad is the Messenger of Allah, establishing prayer, paying zakah, making pilgrimage to the House, and fasting Ramadan."},
         "benefitNote": {"ar": "هذه الأركان الخمسة هي أساس الإسلام العملي، ومن حافظ عليها فقد أقام دينه.",
                          "en": "These five pillars are the practical foundation of Islam; whoever upholds them has established their faith."}},
        {"id": uid(2003), "number": 13, "grading": "متفق عليه", "source": "رواه البخاري ومسلم",
         "arabicText": "لاَ يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ",
         "translation": {"en": "None of you truly believes until he loves for his brother what he loves for himself."},
         "benefitNote": {"ar": "هذا الحديث أصل عظيم في الأخوة الإيمانية، ويدعو إلى نزع الأثرة والحسد من القلب.",
                          "en": "A great principle of brotherhood in faith, calling one to remove selfishness and envy from the heart."}},
    ],
}

HADITH_SUMMARIES = {
    "collections": [
        {"id": uid(2000), "slug": HADITH_COLLECTION_SLUG,
         "name": HADITH_DETAIL["name"], "description": HADITH_DETAIL["description"],
         "entryCount": len(HADITH_DETAIL["entries"])},
    ],
}

WIRD_TEMPLATES = {
    "version": 1,
    "templates": [
        {"id": uid(3001), "type": "salawat", "defaultTarget": 100, "defaultUnit": "times", "defaultFrequency": "daily",
         "name": {"ar": "الصلاة على النبي ﷺ", "en": "Sending Blessings on the Prophet"},
         "description": {"ar": "وِرد يومي من الصلاة على النبي صلى الله عليه وسلم", "en": "A daily wird of sending blessings upon the Prophet"}},
        {"id": uid(3002), "type": "quran_reading", "defaultTarget": 5, "defaultUnit": "pages", "defaultFrequency": "daily",
         "name": {"ar": "تلاوة القرآن الكريم", "en": "Quran Recitation"},
         "description": {"ar": "وِرد يومي من قراءة القرآن الكريم", "en": "A daily wird of Quran reading"}},
        {"id": uid(3003), "type": "istighfar", "defaultTarget": 100, "defaultUnit": "times", "defaultFrequency": "daily",
         "name": {"ar": "الاستغفار", "en": "Seeking Forgiveness"},
         "description": {"ar": "وِرد يومي من الاستغفار", "en": "A daily wird of seeking Allah's forgiveness"}},
    ],
}


def resolve(value, locale):
    """Mirrors backend locale_resolve.ts: dict -> resolved string; None stays None."""
    if value is None:
        return None
    if isinstance(value, dict):
        return value.get(locale) or value.get("ar")
    return value


def resolve_optional(value, locale):
    if value is None:
        return None
    if isinstance(value, dict):
        result = value.get(locale)
        return result if result else None
    return value


def localize_azkar(locale):
    return {
        "version": AZKAR["version"],
        "categories": [
            {
                "id": c["id"], "slug": c["slug"], "sortOrder": c["sortOrder"],
                "name": resolve(c["name"], locale),
                "items": [
                    {
                        "id": i["id"], "sortOrder": i["sortOrder"], "arabicText": i["arabicText"],
                        "transliteration": resolve_optional(i["transliteration"], locale),
                        "translation": resolve_optional(i["translation"], locale),
                        "virtueNote": resolve_optional(i["virtueNote"], locale),
                        "source": i["source"], "repeatCount": i["repeatCount"],
                    } for i in c["items"]
                ],
            } for c in AZKAR["categories"]
        ],
    }


def localize_duas(locale):
    return {
        "version": DUAS["version"],
        "categories": [
            {
                "id": c["id"], "slug": c["slug"], "sortOrder": c["sortOrder"],
                "name": resolve(c["name"], locale),
                "duas": [
                    {
                        "id": d["id"], "sortOrder": d["sortOrder"],
                        "title": resolve(d["title"], locale), "arabicText": d["arabicText"],
                        "transliteration": resolve_optional(d["transliteration"], locale),
                        "translation": resolve_optional(d["translation"], locale),
                        "source": d["source"],
                    } for d in c["duas"]
                ],
            } for c in DUAS["categories"]
        ],
    }


def localize_hadith_detail(locale):
    return {
        "version": HADITH_DETAIL["version"], "slug": HADITH_DETAIL["slug"],
        "name": resolve(HADITH_DETAIL["name"], locale),
        "description": resolve(HADITH_DETAIL["description"], locale),
        "entries": [
            {
                "id": e["id"], "number": e["number"], "arabicText": e["arabicText"],
                "translation": resolve_optional(e["translation"], locale),
                "grading": e["grading"],
                "benefitNote": resolve_optional(e["benefitNote"], locale),
                "source": e["source"],
            } for e in HADITH_DETAIL["entries"]
        ],
    }


def localize_hadith_summaries(locale):
    return {
        "collections": [
            {
                "id": c["id"], "slug": c["slug"],
                "name": resolve(c["name"], locale), "description": resolve(c["description"], locale),
                "entryCount": c["entryCount"],
            } for c in HADITH_SUMMARIES["collections"]
        ],
    }


def localize_wird_templates(locale):
    return {
        "version": WIRD_TEMPLATES["version"],
        "templates": [
            {
                "id": t["id"], "type": t["type"], "defaultTarget": t["defaultTarget"],
                "defaultUnit": t["defaultUnit"], "defaultFrequency": t["defaultFrequency"],
                "name": resolve(t["name"], locale), "description": resolve(t["description"], locale),
            } for t in WIRD_TEMPLATES["templates"]
        ],
    }


def write(name, data):
    path = os.path.join(os.path.dirname(__file__), name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {name}")


for locale in ("ar", "en"):
    write(f"azkar.{locale}.json", localize_azkar(locale))
    write(f"duas.{locale}.json", localize_duas(locale))
    write(f"hadith-{HADITH_COLLECTION_SLUG}.{locale}.json", localize_hadith_detail(locale))
    write(f"hadith-collections.{locale}.json", localize_hadith_summaries(locale))
    write(f"wird-templates.{locale}.json", localize_wird_templates(locale))
