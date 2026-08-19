import ContentKit
import Foundation

/// Matching for the azkar browse screen.
///
/// Pulled out of the view because the interesting part is not the layout: Arabic
/// search is subtle enough to get wrong silently, and a filter that quietly
/// matches nothing looks identical to a category that is genuinely empty.
public enum AzkarSearch {
    /// Entries matching `query`, or all of them when it is blank.
    ///
    /// Matches against title, matn and source. Matn is included deliberately
    /// despite being the least pleasant field to match on: until the corpus is
    /// titled it is the *only* thing most entries can be found by, and a search
    /// that returns nothing for an untitled library reads as broken.
    public static func filter(_ items: [AzkarItem], query: String) -> [AzkarItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let needle = folded(trimmed)
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            [item.title, item.arabicText, item.source]
                .compactMap { $0 }
                .contains { folded($0).contains(needle) }
        }
    }

    /// Comparable form: diacritics stripped, case folded, and alif/ya variants
    /// unified.
    ///
    /// ## Why each part is load-bearing
    /// The corpus is fully vowelled, so "الحمد" typed by a user shares almost no
    /// characters with the stored "الْحَمْدُ" — every harakah is a codepoint that
    /// would have to be matched exactly. Diacritic folding alone fixes that.
    ///
    /// Alif and ya folding is the part that is easy to omit and hard to notice:
    /// `أ إ آ` and `ا` are distinct codepoints, as are `ى` and `ي`. A user
    /// typing "الاستيقاظ" against a stored "الإستيقاظ" gets nothing, and no
    /// amount of diacritic stripping helps because these are base letters. This
    /// mirrors the same FOLD table the backend's grading extractor uses, so the
    /// two sides of the app agree on what counts as the same word.
    static func folded(_ text: String) -> String {
        // Decompose first, then drop every combining mark. Foundation's
        // `.diacriticInsensitive` folding does NOT remove Arabic harakat — it is
        // built for Latin accents, and a fully vowelled matn survives it
        // unchanged. Relying on it made every Arabic query match nothing, which
        // is invisible: the screen shows "no results", not an error.
        let withoutMarks = String(
            text.decomposedStringWithCanonicalMapping.unicodeScalars.filter {
                !CharacterSet.nonBaseCharacters.contains($0)
            }
        )
        var out = ""
        out.reserveCapacity(withoutMarks.count)
        for character in withoutMarks.lowercased() {
            switch character {
            // Alif and ya variants are *base letters*, not marks, so stripping
            // diacritics does nothing for them. Hamza placement is exactly what
            // people leave off when typing, so this is the difference between a
            // search that works and one that only works for careful typists.
            case "أ", "إ", "آ", "ٱ", "ا": out.append("ا")
            case "ى", "ي", "ی": out.append("ي")
            case "ة", "ه": out.append("ه")
            default: out.append(character)
            }
        }
        return out
    }
}
