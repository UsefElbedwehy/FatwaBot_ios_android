import DesignSystemKit
import SwiftUI
import UIKit

/// The contact channels shown in Settings — email, WhatsApp and social links.
///
/// Server-driven (ADR-0011, string-pack keys `contact.email`,
/// `contact.whatsapp`, `contact.instagram`, `contact.x`) so an operator can
/// change an address, or switch a channel off, from the dashboard without a
/// release. A field is `nil` when the server supplied nothing or supplied a
/// blank value; nothing is bundled as a fallback on purpose — a made-up
/// address shipped in the binary is worse than no row at all.
struct ContactLinks {
    var email: String?
    var whatsapp: String?
    var instagram: String?
    var x: String?

    /// True when no channel is configured — the whole section is then hidden.
    var isEmpty: Bool {
        email == nil && whatsapp == nil && instagram == nil && x == nil
    }
}

/// Turns an operator-supplied value into the URL that opens the right app.
/// Accepts either a full URL (pasted out of a browser) or the bare handle /
/// address / phone number the dashboard field asks for, because both are what
/// people actually type. Anything that yields no usable URL disables its row
/// rather than opening something wrong.
enum ContactChannel {
    case email, whatsapp, instagram, x

    func url(for value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") || lowered.hasPrefix("mailto:") {
            return URL(string: trimmed)
        }
        switch self {
        case .email:
            return URL(string: "mailto:\(trimmed)")
        case .whatsapp:
            // wa.me wants digits only — operators write "+20 100 123 4567".
            let digits = trimmed.filter(\.isNumber)
            return digits.isEmpty ? nil : URL(string: "https://wa.me/\(digits)")
        case .instagram:
            return URL(string: "https://instagram.com/\(handle(trimmed))")
        case .x:
            return URL(string: "https://x.com/\(handle(trimmed))")
        }
    }

    private func handle(_ value: String) -> String {
        value.hasPrefix("@") ? String(value.dropFirst()) : value
    }
}

/// "التواصل" — one row per configured channel, following the same section
/// conventions as the rest of Settings (branded header + a single card).
struct ContactSection: View {
    let links: ContactLinks
    let tokens: ColorTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader("settings.contact_section", systemImage: "bubble.left.and.bubble.right.fill", tokens: tokens)
            VStack(spacing: 0) {
                // Declaration order == on-screen order; each row disappears with
                // its value, and the dividers follow.
                let rows: [(LocalizedStringKey, String, ContactChannel, String)] = [
                    ("settings.contact.email", "envelope.fill", .email, links.email ?? ""),
                    ("settings.contact.whatsapp", "phone.fill", .whatsapp, links.whatsapp ?? ""),
                    ("settings.contact.instagram", "camera.fill", .instagram, links.instagram ?? ""),
                    ("settings.contact.x", "at", .x, links.x ?? ""),
                ].filter { !$0.3.isEmpty }

                ForEach(Array(rows.enumerated()), id: \.offset) { index, entry in
                    row(entry.0, systemImage: entry.1, value: entry.3, url: entry.2.url(for: entry.3))
                    if index < rows.count - 1 { Divider().opacity(0.3) }
                }
            }
            .brandCard(tokens)
        }
    }

    private func row(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        value: String,
        url: URL?
    ) -> some View {
        Button {
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleKey)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    // The address itself, so it's obvious where the row leads —
                    // forced LTR because handles and numbers are latin runs that
                    // read backwards when the paragraph is Arabic.
                    Text(verbatim: value)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(Text(verbatim: value))
    }
}
