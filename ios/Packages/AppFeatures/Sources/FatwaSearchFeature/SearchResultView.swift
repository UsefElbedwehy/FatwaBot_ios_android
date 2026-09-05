import DesignSystemKit
import SwiftUI

/// The status colours the client specified: green = حلال, red = حرام,
/// blue = إباحة, orange = كراهة.
///
/// The API emits the full five-fold fiqh scale so nothing is lost server-side,
/// and the fold to four colours happens here, where it is a presentation
/// decision that can change without a deploy:
///
///   واجب, مستحب, حلال -> green   (all "do / may do", the permitted family)
///   مباح               -> blue
///   مكروه              -> orange
///   حرام               -> red
///
/// Folding واجب into green loses a real distinction — an obligation is not a
/// permission — and is worth revisiting with the client if he wants a fifth
/// colour. It is not a *wrong* colour, which is what matters: nothing that is
/// forbidden can ever show green.
extension Ruling {
    /// Deliberately not a brand token: these are semantic status colours the
    /// client named, and they must read the same in light and dark.
    var dotColor: Color? {
        switch self {
        case .wajib, .mustahabb, .halal: return Color(red: 0.18, green: 0.49, blue: 0.20)
        case .mubah: return Color(red: 0.08, green: 0.40, blue: 0.75)
        case .makruh: return Color(red: 0.90, green: 0.32, blue: 0.00)
        case .haram: return Color(red: 0.78, green: 0.16, blue: 0.16)
        // No colour at all — the question has no ruling to give, and a neutral
        // grey dot would still imply one had been assessed.
        case .none: return nil
        }
    }

    var labelKey: LocalizedStringKey? {
        switch self {
        case .wajib: return "fatwa_search.ruling.wajib"
        case .mustahabb: return "fatwa_search.ruling.mustahabb"
        case .halal: return "fatwa_search.ruling.halal"
        case .mubah: return "fatwa_search.ruling.mubah"
        case .makruh: return "fatwa_search.ruling.makruh"
        case .haram: return "fatwa_search.ruling.haram"
        case .none: return nil
        }
    }
}

private func resourceLabelKey(_ kind: String) -> LocalizedStringKey {
    switch kind {
    case "video": return "fatwa_search.resource.video"
    case "website": return "fatwa_search.resource.website"
    default: return "fatwa_search.resource.book"
    }
}

/// Renders the model's Markdown rather than printing it.
///
/// `Text(someString)` takes the `String` overload, which does **not** parse
/// Markdown — only the `LocalizedStringKey` one does — so answers arrived on
/// screen with literal `**...**`. `AttributedString(markdown:)` with
/// `.inlineOnlyPreservingWhitespace` keeps the model's line breaks, which it
/// uses to separate lines of evidence; the default option collapses them.
/// Unparseable input falls back to the raw text rather than being dropped:
/// losing a character from scripture is worse than showing an asterisk.
struct MarkdownText: View {
    let markdown: String

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }
}

/// The M5.1 result: a summary carrying the ruling, a card per scholar with its
/// evidence, availability, sources, and the disclaimer the reference ends on.
///
/// Degrades in both directions — a pre-M5.1 response has no summary and no
/// scholar cards, so the flat `answer` renders exactly as before; and a
/// structured response does not repeat `answer` underneath the cards.
struct SearchResultView: View {
    let response: SearchResponse
    let tokens: ColorTokens
    let onAskAgain: () -> Void
    let onContact: () -> Void

    private var renderedStructured: Bool {
        response.summary != nil || !response.scholarAnswers.isEmpty
            || (response.mode == FatwaSearchMode.hadith.rawValue && response.hadith != nil)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            if response.summary != nil { summaryCard }

            // Hadith mode only. The schema allows these fields in any mode and
            // the model volunteers them when a fatwa rests on a hadith, which
            // put a takhrij card inside a فتوى answer — reading as if the app
            // had answered the wrong question.
            if response.mode == FatwaSearchMode.hadith.rawValue, let hadith = response.hadith {
                hadithCard(hadith)
            }

            ForEach(response.scholarAnswers) { scholarCard($0) }

            if !renderedStructured {
                BrandCard(tokens) {
                    MarkdownText(markdown: response.answer)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }
            }

            if !response.resources.isEmpty { resourceRow }

            if !response.citations.isEmpty {
                BrandSectionHeader("fatwa_search.sources", systemImage: "book", tokens: tokens)
                ForEach(response.citations) { citation in
                    ArabicContentCard(
                        label: "\(citation.sourceTitle) — \(citation.scholar)",
                        badgeText: citation.pageNumber.map {
                            String(format: NSLocalizedString("fatwa_search.page_badge", comment: ""), $0)
                        },
                        arabic: citation.quotedText,
                        tokens: tokens
                    )
                }
            }

            Button(action: onAskAgain) {
                Text("fatwa_search.new_search")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color(hexToken: tokens.primary), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color(hexToken: tokens.onPrimary))

            disclaimerCard
        }
    }

    /// Filled maroon, as the reference draws it — the one block a reader who
    /// reads nothing else will read, so it carries the ruling.
    private var summaryCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                if let color = response.ruling.dotColor {
                    Circle().fill(color).frame(width: 14, height: 14)
                }
                // The ruling is always named in text beside the dot: colour
                // alone is invisible to a colour-blind or VoiceOver user, and
                // this colour carries a fatwa.
                if let labelKey = response.ruling.labelKey {
                    Text(labelKey).font(.subheadline.bold())
                        .foregroundStyle(Color(hexToken: tokens.onPrimary))
                }
                Text("fatwa_search.summary")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onPrimary).opacity(0.75))
            }
            MarkdownText(markdown: response.summary ?? "")
                .foregroundStyle(Color(hexToken: tokens.onPrimary))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(hexToken: tokens.primary), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scholarCard(_ answer: ScholarAnswer) -> some View {
        BrandCard(tokens) {
            VStack(alignment: .trailing, spacing: 10) {
                Text(answer.scholar)
                    .font(.headline.bold())
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                MarkdownText(markdown: answer.answer)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                if let evidence = answer.evidence {
                    labelledInset("fatwa_search.evidence", evidence)
                }
            }
        }
    }

    private func hadithCard(_ hadith: HadithVerdict) -> some View {
        BrandCard(tokens) {
            VStack(alignment: .trailing, spacing: 12) {
                labelledInset("fatwa_search.hadith.text", hadith.text)
                labelledInset("fatwa_search.hadith.grade", hadith.grade)
                if let source = hadith.source { labelledInset("fatwa_search.hadith.source", source) }
                if let verdicts = hadith.scholarVerdicts {
                    labelledInset("fatwa_search.hadith.verdicts", verdicts)
                }
            }
        }
    }

    /// The reference's inset sub-card: a label, a maroon rule down the leading
    /// edge, and the text.
    private func labelledInset(_ label: LocalizedStringKey, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hexToken: tokens.primary))
                .frame(width: 3)
            VStack(alignment: .trailing, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                MarkdownText(markdown: body)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Every kind is shown, including the unavailable ones — "غير متاح" is
    /// information; an omitted row leaves the reader wondering whether it was
    /// checked at all.
    private var resourceRow: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("fatwa_search.available_on")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(spacing: 8) {
                ForEach(response.resources) { resource in
                    // Built as concatenated `Text`, not a `Text(Text)` — the
                    // unavailable chip is two localized strings joined, and
                    // SwiftUI's `+` is how that composes.
                    Group {
                        if resource.available {
                            Text(resourceLabelKey(resource.kind))
                        } else {
                            Text(resourceLabelKey(resource.kind)) + Text(" · ")
                                + Text("fatwa_search.not_available")
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(
                        Color(hexToken: resource.available ? tokens.primary : tokens.onSurfaceSecondary)
                    )
                    .background(
                        Color(hexToken: resource.available ? tokens.primaryContainer : tokens.surfaceElevated),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
        }
    }

    private var disclaimerCard: some View {
        BrandCard(tokens) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    Text("fatwa_search.disclaimer")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Button(action: onContact) {
                    Text("fatwa_search.contact_us")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
