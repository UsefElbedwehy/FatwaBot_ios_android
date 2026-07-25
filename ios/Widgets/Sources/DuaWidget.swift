import CoreKit
import SwiftUI
import WidgetKit

// A small curated pool of short, authentic supplications for the widgets —
// Qur'anic verses and sound (sahih) prophetic du'as, chosen to fit a widget.
// Bundled statically so the widget needs zero network and works on first launch
// (the full library lives in the app). Arabic matn is public domain.
struct WidgetDua: Identifiable {
    let id: Int
    let arabic: String
    let translation: String
    let source: String
}

let widgetDuaPool: [WidgetDua] = [
    .init(id: 0, arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
          translation: "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.",
          source: "البقرة: 201"),
    .init(id: 1, arabic: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
          translation: "My Lord, expand for me my chest and ease for me my task.",
          source: "طه: 25-26"),
    .init(id: 2, arabic: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
          translation: "Allah is sufficient for us, and He is the best disposer of affairs.",
          source: "آل عمران: 173"),
    .init(id: 3, arabic: "لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
          translation: "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.",
          source: "الأنبياء: 87"),
    .init(id: 4, arabic: "رَبِّ زِدْنِي عِلْمًا",
          translation: "My Lord, increase me in knowledge.",
          source: "طه: 114"),
    .init(id: 5, arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى",
          translation: "O Allah, I ask You for guidance, piety, chastity and self-sufficiency.",
          source: "رواه مسلم"),
    .init(id: 6, arabic: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ",
          translation: "O Allah, help me to remember You, to thank You, and to worship You well.",
          source: "رواه أبو داود"),
    .init(id: 7, arabic: "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا",
          translation: "Our Lord, grant us comfort of the eyes from our spouses and offspring, and make us an example for the righteous.",
          source: "الفرقان: 74"),
    .init(id: 8, arabic: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ",
          translation: "O Allah, I seek refuge in You from anxiety and grief.",
          source: "رواه البخاري"),
    .init(id: 9, arabic: "رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ",
          translation: "Our Lord, forgive me and my parents and the believers the Day the account is established.",
          source: "إبراهيم: 41"),
    .init(id: 10, arabic: "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ",
          translation: "O Turner of hearts, make my heart firm upon Your religion.",
          source: "رواه الترمذي"),
    .init(id: 11, arabic: "رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ",
          translation: "Our Lord, accept this from us. Indeed, You are the Hearing, the Knowing.",
          source: "البقرة: 127"),
    .init(id: 12, arabic: "اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ",
          translation: "O Allah, forgive me all of my sins, the small and the great.",
          source: "رواه مسلم"),
    .init(id: 13, arabic: "رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِنْ ذُرِّيَّتِي رَبَّنَا وَتَقَبَّلْ دُعَاءِ",
          translation: "My Lord, make me an establisher of prayer, and from my descendants. Our Lord, accept my supplication.",
          source: "إبراهيم: 40"),
    .init(id: 14, arabic: "رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا",
          translation: "Our Lord, do not impose blame upon us if we forget or make a mistake.",
          source: "البقرة: 286"),
]

// Short, complete adhkar for the lock-screen / Notification Center families,
// where only ~2 lines are legible at a readable size. Kept as its OWN pool
// rather than clipping `widgetDuaPool` — truncating a Qur'anic verse mid-āyah
// to fit a widget would change its meaning, which we won't do.
// NOTE: like all shipped religious content, this list should be proofread by a
// scholar before release (see the content review process).
let widgetShortDhikrPool: [WidgetDua] = [
    .init(id: 100, arabic: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
          translation: "Glory be to Allah, and praise be to Him.", source: "متفق عليه"),
    .init(id: 101, arabic: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ",
          translation: "I seek Allah's forgiveness and turn to Him in repentance.", source: "رواه البخاري"),
    .init(id: 102, arabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
          translation: "There is no power nor strength except with Allah.", source: "متفق عليه"),
    .init(id: 103, arabic: "رَبِّ زِدْنِي عِلْمًا",
          translation: "My Lord, increase me in knowledge.", source: "طه: 114"),
    .init(id: 104, arabic: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
          translation: "Allah is sufficient for us, and He is the best disposer of affairs.", source: "آل عمران: 173"),
    .init(id: 105, arabic: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ",
          translation: "O Allah, help me to remember You.", source: "رواه أبو داود"),
    .init(id: 106, arabic: "رَبِّ اشْرَحْ لِي صَدْرِي",
          translation: "My Lord, expand for me my chest.", source: "طه: 25"),
    .init(id: 107, arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ",
          translation: "O Allah, I ask You for well-being.", source: "رواه الترمذي"),
    .init(id: 108, arabic: "سُبْحَانَ اللَّهِ الْعَظِيمِ",
          translation: "Glory be to Allah, the Most Great.", source: "متفق عليه"),
    .init(id: 109, arabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
          translation: "O Allah, send blessings upon Muhammad.", source: "متفق عليه"),
    .init(id: 110, arabic: "رَبَّنَا تَقَبَّلْ مِنَّا",
          translation: "Our Lord, accept this from us.", source: "البقرة: 127"),
    .init(id: 111, arabic: "اللَّهُمَّ اغْفِرْ لِي",
          translation: "O Allah, forgive me.", source: "متفق عليه"),
]

/// Rotates through the pool in ~3-hour slots so the du'a refreshes through the
/// day (deterministic, so the timeline is stable without waking the app).
func widgetDua(for date: Date) -> WidgetDua {
    let slot = Int(date.timeIntervalSince1970 / (3 * 3600))
    let index = ((slot % widgetDuaPool.count) + widgetDuaPool.count) % widgetDuaPool.count
    return widgetDuaPool[index]
}

/// Lock-screen rotation — hourly, so a glance at the phone usually shows
/// something new (the home-screen widget's 3h cadence feels static there).
func widgetShortDhikr(for date: Date) -> WidgetDua {
    let slot = Int(date.timeIntervalSince1970 / 3600)
    let count = widgetShortDhikrPool.count
    return widgetShortDhikrPool[((slot % count) + count) % count]
}

struct DuaEntry: TimelineEntry {
    let date: Date
    let dua: WidgetDua
}

struct DuaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuaEntry {
        DuaEntry(date: Date(), dua: widgetDuaPool[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (DuaEntry) -> Void) {
        completion(DuaEntry(date: Date(), dua: widgetDua(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DuaEntry>) -> Void) {
        let now = Date()
        let step: TimeInterval = 3 * 3600
        // One entry per slot over the next 24h; reload after that.
        var entries: [DuaEntry] = []
        for i in 0..<8 {
            let date = now.addingTimeInterval(step * Double(i))
            entries.append(DuaEntry(date: date, dua: widgetDua(for: date)))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(step * 8))))
    }
}

/// Separate provider for the accessory families: hourly cadence over the short
/// adhkar pool.
struct ShortDhikrTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuaEntry {
        DuaEntry(date: Date(), dua: widgetShortDhikrPool[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (DuaEntry) -> Void) {
        completion(DuaEntry(date: Date(), dua: widgetShortDhikr(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DuaEntry>) -> Void) {
        let now = Date()
        let step: TimeInterval = 3600
        let entries = (0..<12).map { i -> DuaEntry in
            let date = now.addingTimeInterval(step * Double(i))
            return DuaEntry(date: date, dua: widgetShortDhikr(for: date))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(step * 12))))
    }
}

// MARK: - Home-screen Du'a widget (medium + large)

struct RandomDuaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RandomDuaWidget", provider: DuaTimelineProvider()) { entry in
            DuaWidgetView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
                .widgetURL(DeepLink.dua.url)
        }
        .configurationDisplayName(Text("widget.dua.name"))
        .description(Text("widget.dua.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DuaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DuaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 6) {
            HStack(spacing: 6) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.caption)
                    .foregroundStyle(brandPrimary)
                Text("widget.dua.title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandPrimary)
                Spacer()
            }
            Text(entry.dua.arabic)
                .font(family == .systemLarge ? .title3.weight(.semibold) : .callout.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .minimumScaleFactor(0.6)
                .lineLimit(family == .systemLarge ? 5 : 3)
            if family == .systemLarge {
                Text(entry.dua.translation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Text(entry.dua.source)
                .font(.caption2)
                .foregroundStyle(brandPrimary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock Screen / Notification Center du'a (accessoryRectangular)

struct DuaAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DuaAccessoryWidget", provider: ShortDhikrTimelineProvider()) { entry in
            DuaAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(DeepLink.dua.url)
        }
        .configurationDisplayName(Text("widget.dua.name"))
        .description(Text("widget.dua.desc"))
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

/// The dhikr gets the WHOLE widget — no header row, no icon. On the lock screen
/// vertical space is the scarcest resource, and a static "Du'a" caption costs a
/// third of it while telling the user nothing they can't see. Rendering the
/// Arabic as large as it will fit is what makes this legible at a glance.
struct DuaAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DuaEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.dua.arabic)
        default:
            Text(entry.dua.arabic)
                .font(.system(.headline, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .widgetAccentable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
