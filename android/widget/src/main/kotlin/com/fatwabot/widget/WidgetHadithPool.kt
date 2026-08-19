package com.fatwabot.widget

/**
 * A small curated pool of short, well-known hadith for the widgets. Bundled
 * statically (zero network, works on first launch); mirrors the iOS pool
 * entry-for-entry.
 *
 * Sourcing note: every entry is from **al-Arba'in al-Nawawiyya** or the two
 * Sahihs — classical, long out of copyright, and short enough to fit a widget
 * without truncation. Deliberately *not* drawn from the collections seeded as
 * `review_status = 'pending'` in migration 0025: those await scholar review, and
 * a home-screen widget is the last place unreviewed text should surface.
 */
data class WidgetHadith(val arabic: String, val translation: String, val source: String)

val widgetHadithPool: List<WidgetHadith> = listOf(
    WidgetHadith(
        "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى",
        "Actions are but by intentions, and every person shall have only what they intended.",
        "متفق عليه — النووية ١",
    ),
    WidgetHadith(
        "مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ",
        "Whoever believes in Allah and the Last Day, let them speak good or remain silent.",
        "متفق عليه — النووية ١٥",
    ),
    WidgetHadith(
        "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ",
        "None of you truly believes until he loves for his brother what he loves for himself.",
        "متفق عليه — النووية ١٣",
    ),
    WidgetHadith(
        "الدِّينُ النَّصِيحَةُ",
        "The religion is sincerity.",
        "رواه مسلم — النووية ٧",
    ),
    WidgetHadith(
        "اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ، وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا",
        "Fear Allah wherever you are, and follow a bad deed with a good one, it will erase it.",
        "رواه الترمذي — النووية ١٨",
    ),
    WidgetHadith(
        "مِنْ حُسْنِ إِسْلَامِ الْمَرْءِ تَرْكُهُ مَا لَا يَعْنِيهِ",
        "Part of a person's excellence in Islam is leaving what does not concern them.",
        "رواه الترمذي — النووية ١٢",
    ),
    WidgetHadith(
        "لَا ضَرَرَ وَلَا ضِرَارَ",
        "There should be neither harm nor reciprocating harm.",
        "رواه ابن ماجه — النووية ٣٢",
    ),
    WidgetHadith(
        "الطُّهُورُ شَطْرُ الإِيمَانِ",
        "Purity is half of faith.",
        "رواه مسلم — النووية ٢٣",
    ),
    WidgetHadith(
        "لَا تَغْضَبْ",
        "Do not become angry.",
        "رواه البخاري — النووية ١٦",
    ),
    WidgetHadith(
        "إِنَّ اللَّهَ كَتَبَ الإِحْسَانَ عَلَى كُلِّ شَيْءٍ",
        "Allah has prescribed excellence in all things.",
        "رواه مسلم — النووية ١٧",
    ),
    WidgetHadith(
        "الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ",
        "The Muslim is one from whose tongue and hand the Muslims are safe.",
        "متفق عليه",
    ),
    WidgetHadith(
        "تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ لَكَ صَدَقَةٌ",
        "Your smiling in your brother's face is charity for you.",
        "رواه الترمذي",
    ),
    WidgetHadith(
        "مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ",
        "Whoever treads a path seeking knowledge, Allah makes easy for them a path to Paradise.",
        "رواه مسلم",
    ),
    WidgetHadith(
        "خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ",
        "The best of you are those who learn the Qur'an and teach it.",
        "رواه البخاري",
    ),
    WidgetHadith(
        "الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ",
        "A good word is charity.",
        "متفق عليه",
    ),
    WidgetHadith(
        "ازْهَدْ فِي الدُّنْيَا يُحِبَّكَ اللَّهُ",
        "Detach yourself from the world and Allah will love you.",
        "رواه ابن ماجه — النووية ٣١",
    ),
)

/**
 * Deterministic per-slot pick, matching the iOS `widgetHadith(for:)` and the
 * du'a pool's approach: derived from the six-hour slot index so a reload does
 * not reshuffle what the user was part-way through reading.
 */
fun widgetHadith(nowMillis: Long = System.currentTimeMillis()): WidgetHadith {
    val slot = nowMillis / (6L * 60L * 60L * 1000L)
    val index = (slot % widgetHadithPool.size).toInt()
    return widgetHadithPool[if (index < 0) index + widgetHadithPool.size else index]
}
