import CoreKit
import Foundation

/// The endpoint catalog — one definition per OpenAPI operation.
public enum Endpoints {
    public static let config = Endpoint<AppConfig>(path: "v1/config")
    public static let theme = Endpoint<ServerTheme>(path: "v1/config/theme")
    public static let home = Endpoint<HomeLayout>(path: "v1/home")

    public static func strings(locale: String, sinceVersion: Int? = nil) -> Endpoint<StringPack> {
        var query: [URLQueryItem] = []
        if let sinceVersion {
            query.append(URLQueryItem(name: "since_version", value: String(sinceVersion)))
        }
        return Endpoint(path: "v1/config/strings/\(locale)", query: query)
    }

    public static func prayerDefaults(country: String) -> Endpoint<PrayerDefaults> {
        Endpoint(path: "v1/config/prayer-defaults", query: [URLQueryItem(name: "country", value: country)])
    }
}
