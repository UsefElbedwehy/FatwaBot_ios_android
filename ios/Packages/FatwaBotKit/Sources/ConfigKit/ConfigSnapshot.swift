import CoreKit
import Foundation

/// The persisted result of config sync (docs/features/config-sync.md).
/// Layers are independent: a failed/malformed layer never blocks the others.
public struct ConfigSnapshot: Codable, Equatable, Sendable {
    public var appConfig: AppConfig?
    public var theme: ServerTheme?
    public var stringPacks: [String: StringPack] // keyed by locale
    public var homeLayout: HomeLayout?
    public var prayerDefaults: PrayerDefaults?
    public var fetchedAt: Date?

    public init(
        appConfig: AppConfig? = nil,
        theme: ServerTheme? = nil,
        stringPacks: [String: StringPack] = [:],
        homeLayout: HomeLayout? = nil,
        prayerDefaults: PrayerDefaults? = nil,
        fetchedAt: Date? = nil
    ) {
        self.appConfig = appConfig
        self.theme = theme
        self.stringPacks = stringPacks
        self.homeLayout = homeLayout
        self.prayerDefaults = prayerDefaults
        self.fetchedAt = fetchedAt
    }
}

public enum ConfigLayer: String, CaseIterable, Sendable {
    case appConfig, theme, strings, homeLayout, prayerDefaults
}

/// Persistence boundary. FileConfigStore in production (app-group container so
/// widgets share the snapshot); InMemoryConfigStore in tests.
public protocol ConfigStoring: Sendable {
    func load() -> ConfigSnapshot?
    func save(_ snapshot: ConfigSnapshot)
}

public struct FileConfigStore: ConfigStoring {
    private let fileURL: URL

    /// - Parameter directory: e.g. the app-group container's Application Support dir.
    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("config-snapshot.json")
    }

    public func load() -> ConfigSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder().decode(ConfigSnapshot.self, from: data)
    }

    public func save(_ snapshot: ConfigSnapshot) {
        guard let data = try? encoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Atomic write: a crash mid-save must never corrupt the snapshot.
        try? data.write(to: fileURL, options: .atomic)
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
