import CoreKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The repeat marker on a content card — "٣ مرات" rather than a bare "×3".
///
/// Arabic does not pluralise like English. Writing `"\(count) مرة"` produces
/// "3 مرة", which is simply wrong; the noun changes form with the count:
///
///   1        مرة       singular
///   2        مرتان     dual — Arabic has a distinct dual, not just sing/plural
///   3…10     مرات      plural
///   11+      مرة       reverts to the singular after ten
///
/// That last rule is the one that surprises people: ١٠٠ مرة, not ١٠٠ مرات. It
/// matters here because 33 and 100 are common counts in the corpus.
public enum RepeatCountLabel {

    /// The marker for `count`, or `nil` when there is nothing worth showing.
    ///
    /// A count of one returns `nil` deliberately: every dhikr is said at least
    /// once, so "١ مرة" on most cards is noise that pushes the matn down. The
    /// marker earns its place only when the count is a genuine instruction.
    public static func text(_ count: Int, locale: Locale = .current) -> String? {
        guard count > 1 else { return nil }
        guard locale.identifier.hasPrefix("ar") else { return "×\(count)" }

        let noun: String
        switch count {
        case 2: return "مرتان" // The dual carries the count itself — no numeral.
        case 3...10: noun = "مرات"
        default: noun = "مرة"
        }
        return "\(count) \(noun)"
    }
}

/// One passage of Arabic scripture presented for reading: a short label, an
/// optional repeat marker, the text itself, and a copy affordance.
///
/// ## Why this is shared rather than written per feature
/// Azkar, Du'a and Hadith had three different presentations of the same thing —
/// a card list, a row-plus-detail-page, and a one-at-a-time reader with
/// prev/next. Each had grown its own subtitle, translation block, source line
/// and note card, so the same dua looked like different content depending on
/// which screen you reached it from, and every card carried more apparatus than
/// scripture.
///
/// The owner's direction was explicit: show the passage, not the apparatus. One
/// component is the only way that stays true — a translation block added back to
/// "just" the hadith screen is how the drift started the first time.
///
/// ## What is deliberately absent
/// No translation, transliteration, takhrij chain, virtue note or benefit note.
/// None of it is deleted from the API or the database; it is simply not on this
/// surface. Bringing any of it back is a product decision, not a styling one.
public struct ArabicContentCard<Accessory: View>: View {

    /// Short heading — a dhikr title, a dua title, a hadith's collection name.
    ///
    /// Must be short. This is the reference design's "صحيح البخاري" slot, not
    /// somewhere to put a takhrij paragraph; the azkar corpus stores a 90–400
    /// character isnad chain in its `source` field and passing that here would
    /// reproduce exactly the wall of text this component exists to remove.
    private let label: String?

    /// Short marker in the corner opposite the label, already formatted.
    ///
    /// Azkar puts a repeat instruction here (see ``RepeatCountLabel``); Hadith
    /// puts the entry number. Deliberately a pre-formatted `String` rather than
    /// an `Int` — the two callers need different words around the number, and
    /// Arabic pluralisation is not something a view should be deciding.
    private let badgeText: String?

    /// The passage. Rendered with honorifics expanded, so ﷺ reads as it should
    /// on devices without the ligature.
    private let arabic: String

    private let tokens: ColorTokens

    /// Optional control alongside the copy button — Du'a hangs its favourite
    /// toggle here.
    ///
    /// This exists so that removing a feature's bespoke detail page does not
    /// silently remove the feature: the dua favourite used to live in that
    /// page's toolbar, and a card list with nowhere to put it would have dropped
    /// a persisted, user-facing capability as a side effect of a styling change.
    private let accessory: Accessory

    public init(
        label: String? = nil,
        badgeText: String? = nil,
        arabic: String,
        tokens: ColorTokens,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.label = label
        self.badgeText = badgeText
        self.arabic = arabic
        self.tokens = tokens
        self.accessory = accessory()
    }

    /// Trimmed label, or nil when it is absent or blank. A whitespace-only title
    /// would otherwise draw a header band and a rule above nothing.
    private var trimmedLabel: String? {
        guard let label else { return nil }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var displayText: String { arabic.expandingArabicHonorifics }

    public var body: some View {
        BrandCard(tokens, padding: 18) {
            VStack(alignment: .trailing, spacing: 12) {
                if trimmedLabel != nil || badgeText != nil {
                    header
                    Divider().overlay(Color(hexToken: tokens.outline))
                }

                Text(displayText)
                    .font(.title3.weight(.medium))
                    .lineSpacing(8)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                copyButton
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(trimmedLabel ?? displayText))
    }

    /// Label on the leading edge, repeat marker on the trailing one. Under RTL
    /// SwiftUI mirrors this automatically, putting the label at the right and the
    /// marker at the left — which is the reference layout.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let trimmedLabel {
                Text(trimmedLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            if let badgeText {
                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color(hexToken: tokens.primaryContainer))
                    )
            }
        }
    }

    private var copyButton: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            accessory
            Button {
                #if canImport(UIKit)
                // What was on screen, not what was stored: the reader saw
                // expanded honorifics, and pasting a ligature they never saw
                // into an app that renders it as ▯ would be a surprise.
                UIPasteboard.general.string = displayText
                #endif
            } label: {
                Label("content.copy", systemImage: "doc.on.doc")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color(hexToken: tokens.primary).opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
