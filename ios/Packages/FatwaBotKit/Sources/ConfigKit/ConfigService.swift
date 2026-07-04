import CoreKit
import Foundation
import NetworkingKit

/// Config sync per docs/features/config-sync.md. Offline-first: `current` is
/// always readable (cache → empty snapshot whose consumers fall back to bundled
/// values); `refresh` updates layers independently and persists validated results.
public actor ConfigService {
    private let store: ConfigStoring
    private let client: APIClientProtocol
    private let now: @Sendable () -> Date
    private(set) public var current: ConfigSnapshot

    public init(
        store: ConfigStoring,
        client: APIClientProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.client = client
        self.now = now
        self.current = store.load() ?? ConfigSnapshot()
    }

    /// Fetches all layers concurrently. Per-layer failures are silent (spec):
    /// the failed layer keeps its cached value. Returns the layers that changed.
    @discardableResult
    public func refresh(locales: [String]) async -> Set<ConfigLayer> {
        async let configResult = try? client.get(Endpoints.config)
        async let themeResult = try? client.get(Endpoints.theme)
        async let layoutResult = try? client.get(Endpoints.home)

        var packs: [String: StringPack] = [:]
        for locale in locales {
            let since = current.stringPacks[locale]?.version
            if let pack = try? await client.get(Endpoints.strings(locale: locale, sinceVersion: since)) {
                packs[locale] = pack
            }
        }

        var changed: Set<ConfigLayer> = []
        var next = current

        if let config = await configResult, config != next.appConfig {
            next.appConfig = config
            changed.insert(.appConfig)
        }
        if let theme = await themeResult, theme != next.theme {
            next.theme = theme
            changed.insert(.theme)
        }
        if let layout = await layoutResult, layout != next.homeLayout {
            next.homeLayout = layout
            changed.insert(.homeLayout)
        }
        for (locale, pack) in packs where pack != next.stringPacks[locale] {
            next.stringPacks[locale] = pack
            changed.insert(.strings)
        }

        if let country = countryCode(of: next), country != "*" || next.prayerDefaults == nil {
            if let defaults = try? await client.get(Endpoints.prayerDefaults(country: country)),
               defaults != next.prayerDefaults {
                next.prayerDefaults = defaults
                changed.insert(.prayerDefaults)
            }
        }

        if !changed.isEmpty || next.fetchedAt == nil {
            next.fetchedAt = now()
            current = next
            store.save(next)
        }
        return changed
    }

    /// Server pack overlay → nil (caller falls back to bundled Localizable, then key).
    public func string(_ key: String, locale: String) -> String? {
        current.stringPacks[locale]?.strings[key]
    }

    /// Flag gating: unknown flag = false; disabled = false; min_app_version gate
    /// honored (percentage rollout lands with identity bucketing in M3).
    public func isEnabled(_ flag: String, appVersion: String) -> Bool {
        guard let entry = current.appConfig?.flags[flag], entry.enabled else { return false }
        if let minimum = entry.rollout?.minAppVersion {
            return SemVer.isVersion(appVersion, atLeast: minimum)
        }
        return true
    }

    public func staleness() -> TimeInterval? {
        current.fetchedAt.map { now().timeIntervalSince($0) }
    }

    private func countryCode(of snapshot: ConfigSnapshot) -> String? {
        // M1: country comes from device region; injected later with location work.
        Locale.current.region?.identifier ?? "*"
    }
}
