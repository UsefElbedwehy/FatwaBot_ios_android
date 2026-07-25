import Foundation

/// Canonical in-app destinations reachable from outside the app — today from
/// widgets and the Live Activity, tomorrow from push payloads or a website.
///
/// This lives in CoreKit so the app target, the widget extension and the Live
/// Activity extension all build their URLs from the SAME definition. A widget
/// that hardcodes `"fatwabot://prayer"` while the app parses `"prayer-times"`
/// fails silently — the tap just opens Home and nobody notices for weeks — so
/// the scheme, host and parsing are defined exactly once, here.
///
/// The scheme must stay in sync with `CFBundleURLSchemes` in ios/App/project.yml.
public enum DeepLink: String, CaseIterable, Sendable {
    case home
    case prayer
    case qibla
    case tasbeeh
    case azkar
    case dua
    case awrad
    case hadith
    case journey

    public static let scheme = "fatwabot"

    /// `fatwabot://prayer`
    public var url: URL {
        // Safe: every case is a lowercase ASCII host, so this always parses.
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    /// Parses an incoming URL, ignoring anything that isn't ours.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        // Accept both `fatwabot://prayer` (host) and `fatwabot:///prayer`
        // (empty host, path only) so a malformed link still lands correctly.
        let candidate = url.host?.lowercased()
            ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard let link = DeepLink(rawValue: candidate) else { return nil }
        self = link
    }
}
