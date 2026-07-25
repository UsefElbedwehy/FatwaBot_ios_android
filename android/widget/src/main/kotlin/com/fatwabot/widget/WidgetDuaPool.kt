package com.fatwabot.widget

/**
 * A small curated pool of short, authentic supplications for the widgets —
 * Qur'anic verses and sound prophetic du'as chosen to fit a widget. Bundled
 * statically (zero network, works on first launch); mirrors the iOS pool. The
 * full library lives in the app. Arabic matn is public domain.
 */
data class WidgetDua(val arabic: String, val translation: String, val source: String)

val widgetDuaPool: List<WidgetDua> = listOf(
    WidgetDua(
        "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
        "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.",
        "البقرة: 201",
    ),
    WidgetDua(
        "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
        "My Lord, expand for me my chest and ease for me my task.",
        "طه: 25-26",
    ),
    WidgetDua(
        "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
        "Allah is sufficient for us, and He is the best disposer of affairs.",
        "آل عمران: 173",
    ),
    WidgetDua(
        "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
        "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.",
        "الأنبياء: 87",
    ),
    WidgetDua(
        "رَبِّ زِدْنِي عِلْمًا",
        "My Lord, increase me in knowledge.",
        "طه: 114",
    ),
    WidgetDua(
        "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى",
        "O Allah, I ask You for guidance, piety, chastity and self-sufficiency.",
        "رواه مسلم",
    ),
    WidgetDua(
        "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ",
        "O Allah, help me to remember You, to thank You, and to worship You well.",
        "رواه أبو داود",
    ),
    WidgetDua(
        "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا",
        "Our Lord, grant us comfort of the eyes from our spouses and offspring, and make us an example for the righteous.",
        "الفرقان: 74",
    ),
    WidgetDua(
        "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ",
        "O Allah, I seek refuge in You from anxiety and grief.",
        "رواه البخاري",
    ),
    WidgetDua(
        "رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ",
        "Our Lord, forgive me and my parents and the believers the Day the account is established.",
        "إبراهيم: 41",
    ),
    WidgetDua(
        "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ",
        "O Turner of hearts, make my heart firm upon Your religion.",
        "رواه الترمذي",
    ),
    WidgetDua(
        "رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ",
        "Our Lord, accept this from us. Indeed, You are the Hearing, the Knowing.",
        "البقرة: 127",
    ),
    WidgetDua(
        "اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ",
        "O Allah, forgive me all of my sins, the small and the great.",
        "رواه مسلم",
    ),
    WidgetDua(
        "رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِنْ ذُرِّيَّتِي رَبَّنَا وَتَقَبَّلْ دُعَاءِ",
        "My Lord, make me an establisher of prayer, and from my descendants. Our Lord, accept my supplication.",
        "إبراهيم: 40",
    ),
    WidgetDua(
        "رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا",
        "Our Lord, do not impose blame upon us if we forget or make a mistake.",
        "البقرة: 286",
    ),
)

/**
 * A separate pool of *short, complete* adhkar for constrained surfaces (the 2x2
 * du'a widget). Kept apart from [widgetDuaPool] on purpose: clipping a long
 * Qur'anic verse to make it fit would change its meaning, so we never truncate —
 * we pick something that is already whole at that length. Mirrors the iOS
 * `widgetShortDhikrPool`.
 */
val widgetShortDhikrPool: List<WidgetDua> = listOf(
    WidgetDua(
        "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
        "Glory be to Allah, and praise be to Him.",
        "متفق عليه",
    ),
    WidgetDua(
        "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ",
        "I seek Allah's forgiveness and turn to Him in repentance.",
        "رواه البخاري",
    ),
    WidgetDua(
        "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
        "There is no might nor power except with Allah.",
        "متفق عليه",
    ),
    WidgetDua(
        "رَبِّ زِدْنِي عِلْمًا",
        "My Lord, increase me in knowledge.",
        "طه: 114",
    ),
    WidgetDua(
        "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
        "Allah is sufficient for us, and He is the best disposer of affairs.",
        "آل عمران: 173",
    ),
    WidgetDua(
        "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ",
        "O Allah, help me to remember You.",
        "رواه أبو داود",
    ),
    WidgetDua(
        "رَبِّ اشْرَحْ لِي صَدْرِي",
        "My Lord, expand for me my chest.",
        "طه: 25",
    ),
    WidgetDua(
        "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ",
        "O Allah, I ask You for well-being.",
        "رواه الترمذي",
    ),
    WidgetDua(
        "سُبْحَانَ اللَّهِ الْعَظِيمِ",
        "Glory be to Allah, the Most Great.",
        "متفق عليه",
    ),
    WidgetDua(
        "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
        "O Allah, send blessings upon Muhammad.",
        "متفق عليه",
    ),
    WidgetDua(
        "رَبَّنَا تَقَبَّلْ مِنَّا",
        "Our Lord, accept this from us.",
        "البقرة: 127",
    ),
    WidgetDua(
        "اللَّهُمَّ اغْفِرْ لِي",
        "O Allah, forgive me.",
        "متفق عليه",
    ),
)

/** Deterministic ~3-hour rotation so the du'a refreshes through the day. */
fun widgetDua(nowMillis: Long = System.currentTimeMillis()): WidgetDua =
    rotate(widgetDuaPool, nowMillis, 3L * 3600L * 1000L)

/**
 * Hourly rotation for the short pool — the small surface is glanced at far more
 * often than it is read, so it should usually have something new on it.
 */
fun widgetShortDhikr(nowMillis: Long = System.currentTimeMillis()): WidgetDua =
    rotate(widgetShortDhikrPool, nowMillis, 3600L * 1000L)

private fun rotate(pool: List<WidgetDua>, nowMillis: Long, slotMillis: Long): WidgetDua {
    val slot = nowMillis / slotMillis
    val index = ((slot % pool.size) + pool.size) % pool.size
    return pool[index.toInt()]
}

private val ARABIC_DIACRITICS = ('ً'..'ْ').toSet() + setOf('ٰ', 'ـ')

/**
 * Length of the Arabic text ignoring tashkeel and tatweel. Glance/RemoteViews has
 * no auto-shrinking text, so the dhikr's rendered width has to be estimated up
 * front to pick a point size — and counting raw `String.length` would badly
 * over-count fully vocalised text (every fatha is a char but takes no width).
 */
internal fun arabicVisualLength(text: String): Int = text.count { it !in ARABIC_DIACRITICS }
