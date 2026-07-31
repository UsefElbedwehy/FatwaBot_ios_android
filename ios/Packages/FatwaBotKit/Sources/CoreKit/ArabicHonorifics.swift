import Foundation

/// Expands Arabic honorific ligatures that most shipped fonts cannot draw.
///
/// ## Why this is not a font problem to fix with a font
/// The بلوغ المرام corpus uses two generations of ligature. `ﷺ` (U+FDFA) dates
/// from Unicode 1.1 and every Arabic font on iOS and Android draws it. The
/// honorifics in the U+FD40–FD4F block were added in **Unicode 14 (2021)**, and
/// the system Arabic fonts on shipping devices predate them — so 1,176
/// occurrences across بلوغ المرام alone rendered as ▯ boxes.
///
/// Bundling a font with that coverage would mean shipping several MB, picking a
/// licence, and still leaving older OS versions and every *widget* — which uses
/// system fonts — broken. Expanding the ligature to the words it stands for
/// renders correctly in every font, on every OS version, at every size, forever.
/// The meaning is identical: these codepoints exist purely as a typographic
/// contraction of the phrase.
///
/// Expansions are taken from each codepoint's own Unicode name (e.g. U+FD41
/// ARABIC LIGATURE RADI ALLAAHU ANH → رضي الله عنه), not from judgement — these
/// are religious honorifics and an invented expansion would be a meaning error.
///
/// `ﷺ` and `ﷻ` are deliberately left alone: they render, and the ligature is the
/// form readers expect.
public enum ArabicHonorifics {
    /// U+FD40–FD4F and U+FDFD/U+FDFF, keyed by scalar.
    static let expansions: [Character: String] = [
        "\u{FD40}": "رحمه الله",              // RAHIMAHU ALLAAH
        "\u{FD41}": "رضي الله عنه",           // RADI ALLAAHU ANH
        "\u{FD42}": "رضي الله عنها",          // RADI ALLAAHU ANHAA
        "\u{FD43}": "رضي الله عنهم",          // RADI ALLAAHU ANHUM
        "\u{FD44}": "رضي الله عنهما",         // RADI ALLAAHU ANHUMAA
        "\u{FD45}": "رضي الله عنهن",          // RADI ALLAAHU ANHUNNA
        "\u{FD46}": "صلى الله عليه وآله",     // SALLALLAAHU ALAYHI WA-AALIH
        "\u{FD47}": "عليه السلام",            // ALAYHI AS-SALAAM
        "\u{FD48}": "عليهم السلام",           // ALAYHIM AS-SALAAM
        "\u{FD49}": "عليهما السلام",          // ALAYHIMAA AS-SALAAM
        "\u{FD4A}": "عليه الصلاة والسلام",    // ALAYHI AS-SALAATU WAS-SALAAM
        "\u{FD4B}": "قدس سره",                // QUDDISA SIRRAH
        "\u{FD4C}": "صلى الله عليه وآله وسلم", // SALLALLAHU ALAYHI WAAALIHEE WA-SALLAM
        "\u{FD4D}": "عليها السلام",           // ALAYHAA AS-SALAAM
        "\u{FD4E}": "تبارك وتعالى",           // TABAARAKA WA-TAAALAA
        "\u{FD4F}": "رحمهم الله",             // RAHIMAHUM ALLAAH
        "\u{FDFF}": "عز وجل",                 // AZZA WA JALL
    ]

    /// Returns `text` with unrenderable honorific ligatures expanded.
    ///
    /// A no-op for text containing none, which is the overwhelming majority of
    /// strings the app draws.
    public static func expanded(_ text: String) -> String {
        guard text.contains(where: { expansions[$0] != nil }) else { return text }
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            if let expansion = expansions[character] {
                // The source writes the ligature tight against the preceding
                // word ("أَبِي أَيُّوبَ﵁"); the expansion is words, so it needs the
                // space the glyph implied.
                if let last = out.last, !last.isWhitespace { out.append(" ") }
                out.append(expansion)
            } else {
                out.append(character)
            }
        }
        return out
    }
}

public extension String {
    /// Display form of Arabic content: honorific ligatures expanded to the words
    /// they stand for, so they render in fonts that lack the Unicode 14 glyphs.
    var expandingArabicHonorifics: String { ArabicHonorifics.expanded(self) }
}
