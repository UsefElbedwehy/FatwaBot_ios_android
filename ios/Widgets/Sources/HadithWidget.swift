import CoreKit
import SwiftUI
import WidgetKit

/// A small curated pool of short, well-known hadith for the widgets.
///
/// Bundled statically for the same reason as `widgetDuaPool`: a widget must
/// render on first launch with zero network and no shared-container read. The
/// full, reviewable library lives in the app and comes from the backend.
///
/// Sourcing note: every entry here is from **al-Arba'in al-Nawawiyya** or the
/// two Sahihs — classical, long out of copyright, and short enough to fit a
/// widget without truncation. Deliberately *not* drawn from the pending
/// collections seeded in migration 0025: those are awaiting scholar review, and
/// a widget is the last place unreviewed text should surface.
struct WidgetHadith: Identifiable {
    let id: Int
    let arabic: String
    let translation: String
    let source: String
}

let widgetHadithPool: [WidgetHadith] = [
    .init(id: 0, arabic: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى",
          translation: "Actions are but by intentions, and every person shall have only what they intended.",
          source: "متفق عليه — النووية ١"),
    .init(id: 1, arabic: "مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ",
          translation: "Whoever believes in Allah and the Last Day, let them speak good or remain silent.",
          source: "متفق عليه — النووية ١٥"),
    .init(id: 2, arabic: "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ",
          translation: "None of you truly believes until he loves for his brother what he loves for himself.",
          source: "متفق عليه — النووية ١٣"),
    .init(id: 3, arabic: "الدِّينُ النَّصِيحَةُ",
          translation: "The religion is sincerity.",
          source: "رواه مسلم — النووية ٧"),
    .init(id: 4, arabic: "اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ، وَأَتْبِعِ السَّيِّئَةَ الْحَسَنَةَ تَمْحُهَا",
          translation: "Fear Allah wherever you are, and follow a bad deed with a good one, it will erase it.",
          source: "رواه الترمذي — النووية ١٨"),
    .init(id: 5, arabic: "مِنْ حُسْنِ إِسْلَامِ الْمَرْءِ تَرْكُهُ مَا لَا يَعْنِيهِ",
          translation: "Part of a person's excellence in Islam is leaving what does not concern them.",
          source: "رواه الترمذي — النووية ١٢"),
    .init(id: 6, arabic: "لَا ضَرَرَ وَلَا ضِرَارَ",
          translation: "There should be neither harm nor reciprocating harm.",
          source: "رواه ابن ماجه — النووية ٣٢"),
    .init(id: 7, arabic: "الطُّهُورُ شَطْرُ الإِيمَانِ",
          translation: "Purity is half of faith.",
          source: "رواه مسلم — النووية ٢٣"),
    .init(id: 8, arabic: "لَا تَغْضَبْ",
          translation: "Do not become angry.",
          source: "رواه البخاري — النووية ١٦"),
    .init(id: 9, arabic: "إِنَّ اللَّهَ كَتَبَ الإِحْسَانَ عَلَى كُلِّ شَيْءٍ",
          translation: "Allah has prescribed excellence in all things.",
          source: "رواه مسلم — النووية ١٧"),
    .init(id: 10, arabic: "الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ",
          translation: "The Muslim is one from whose tongue and hand the Muslims are safe.",
          source: "متفق عليه"),
    .init(id: 11, arabic: "تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ لَكَ صَدَقَةٌ",
          translation: "Your smiling in your brother's face is charity for you.",
          source: "رواه الترمذي"),
    .init(id: 12, arabic: "مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ",
          translation: "Whoever treads a path seeking knowledge, Allah makes easy for them a path to Paradise.",
          source: "رواه مسلم"),
    .init(id: 13, arabic: "خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ",
          translation: "The best of you are those who learn the Qur'an and teach it.",
          source: "رواه البخاري"),
    .init(id: 14, arabic: "الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ",
          translation: "A good word is charity.",
          source: "متفق عليه"),
    .init(id: 15, arabic: "ازْهَدْ فِي الدُّنْيَا يُحِبَّكَ اللَّهُ",
          translation: "Detach yourself from the world and Allah will love you.",
          source: "رواه ابن ماجه — النووية ٣١"),
]

/// Deterministic per-slot pick, matching the du'a widget's approach: derived
/// from the slot index so every timeline entry for the same instant resolves to
/// the same hadith, and so a reload does not reshuffle what the user was
/// mid-way through reading.
func widgetHadith(for date: Date) -> WidgetHadith {
    let slot = Int(date.timeIntervalSince1970 / (6 * 3600))
    return widgetHadithPool[abs(slot) % widgetHadithPool.count]
}

struct HadithEntry: TimelineEntry {
    let date: Date
    let hadith: WidgetHadith
}

struct HadithTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HadithEntry {
        HadithEntry(date: Date(), hadith: widgetHadithPool[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (HadithEntry) -> Void) {
        completion(HadithEntry(date: Date(), hadith: widgetHadith(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HadithEntry>) -> Void) {
        let now = Date()
        // Six hours: long enough that a hadith is still there when the user comes
        // back to finish it, short enough to feel alive across a day.
        let step: TimeInterval = 6 * 3600
        let entries = (0..<4).map { i -> HadithEntry in
            let date = now.addingTimeInterval(step * Double(i))
            return HadithEntry(date: date, hadith: widgetHadith(for: date))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(step * 4))))
    }
}

struct HadithWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HadithWidget", provider: HadithTimelineProvider()) { entry in
            HadithWidgetView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.hadith.url)
        }
        .configurationDisplayName(Text("widget.hadith.name"))
        .description(Text("widget.hadith.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct HadithWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HadithEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed.fill")
                    .font(.caption)
                    .foregroundStyle(brandPrimary)
                Text("widget.hadith.title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandPrimary)
                Spacer()
            }
            Text(entry.hadith.arabic)
                .font(family == .systemLarge ? .title3.weight(.semibold) : .callout.weight(.medium))
                .foregroundStyle(brandInk)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .minimumScaleFactor(0.6)
                .lineLimit(family == .systemLarge ? 5 : 3)
            if family == .systemLarge {
                Text(entry.hadith.translation)
                    .font(.footnote)
                    .foregroundStyle(brandMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Text(entry.hadith.source)
                .font(.caption2)
                .foregroundStyle(brandMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
