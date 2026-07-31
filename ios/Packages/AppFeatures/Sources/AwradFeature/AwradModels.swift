import Foundation

/// A user-created wird instance (docs/features/awrad.md). `wird_templates` from
/// the backend (ContentKit) supply the guided-creation starting points; the
/// instance itself is fully local in M2 (server sync arrives with accounts, M3+).
public struct Wird: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var type: String
    public var target: Int
    public var unit: String
    public var frequency: String
    public let createdAt: Date
    public var archivedAt: Date?
    /// One of the four always-present slots (`FixedWirdSlot`). Persisted rather
    /// than derived so the marker survives a store round-trip on its own, and
    /// so a future slot whose id changed still reads back as fixed.
    /// Fixed wirds can be ticked and retargeted, never archived or removed.
    public let isFixed: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: String,
        target: Int,
        unit: String,
        frequency: String,
        createdAt: Date,
        archivedAt: Date? = nil,
        isFixed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.target = target
        self.unit = unit
        self.frequency = frequency
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.isFixed = isFixed
    }

    public var isActive: Bool { archivedAt == nil }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, type, target, unit, frequency, createdAt, archivedAt, isFixed
    }

    /// Hand-written for the same reason `NotificationPreferences` is: records on
    /// disk were written by a build that had no `isFixed`, and synthesized
    /// decoding throws on a missing key. One throw fails the whole array decode
    /// and `FileWirdStore` would hand back `[]` — every wird the user ever made,
    /// silently gone. Every field therefore has a fallback.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        self.id = id
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "custom"
        target = try c.decodeIfPresent(Int.self, forKey: .target) ?? 1
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? "times"
        frequency = try c.decodeIfPresent(String.self, forKey: .frequency) ?? "daily"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        // Falling back to the id keeps a seeded slot protected even if the flag
        // is missing — an old record can only be missing it, never contradict it.
        isFixed = try c.decodeIfPresent(Bool.self, forKey: .isFixed) ?? (FixedWirdSlot(wirdId: id) != nil)
    }
}

/// One wird's tally for one local calendar day (`dateKey` = "yyyy-MM-dd").
public struct WirdDailyProgress: Codable, Equatable, Sendable {
    public let wirdId: String
    public let dateKey: String
    public var count: Int

    public init(wirdId: String, dateKey: String, count: Int) {
        self.wirdId = wirdId
        self.dateKey = dateKey
        self.count = count
    }
}

/// Recorded when all active wirds meet their target on a given day (the
/// concept demo's "أتممت وردي اليوم" moment) — one record per day, idempotent.
public struct WirdDayCompletionRecord: Codable, Equatable, Sendable {
    public let dateKey: String
    public let completedAt: Date

    public init(dateKey: String, completedAt: Date) {
        self.dateKey = dateKey
        self.completedAt = completedAt
    }
}

/// Lifetime aggregation mirroring the concept demo's four-stat row
/// (docs/06_DESIGN_REVIEW.md): total dhikr count, completed days, Qur'an
/// pages, salawat count.
public struct WirdStats: Equatable, Sendable {
    public let totalDhikrCount: Int
    public let completedDaysCount: Int
    public let quranPagesCount: Int
    public let salawatCount: Int

    static let quranUnit = "pages"
    static let salawatType = "salawat"

    public static func compute(
        wirds: [Wird],
        progress: [WirdDailyProgress],
        dayCompletions: [WirdDayCompletionRecord]
    ) -> WirdStats {
        let wirdsById = Dictionary(uniqueKeysWithValues: wirds.map { ($0.id, $0) })
        var totalDhikr = 0
        var quranPages = 0
        var salawat = 0
        for entry in progress {
            guard let wird = wirdsById[entry.wirdId] else { continue }
            if wird.unit == quranUnit {
                quranPages += entry.count
            } else {
                totalDhikr += entry.count
            }
            if wird.type == salawatType {
                salawat += entry.count
            }
        }
        return WirdStats(
            totalDhikrCount: totalDhikr,
            completedDaysCount: dayCompletions.count,
            quranPagesCount: quranPages,
            salawatCount: salawat
        )
    }
}

public protocol WirdStoring: Sendable {
    func loadWirds() -> [Wird]
    func saveWirds(_ wirds: [Wird])
    func loadProgress() -> [WirdDailyProgress]
    func saveProgress(_ progress: [WirdDailyProgress])
    func loadDayCompletions() -> [WirdDayCompletionRecord]
    func recordDayCompletion(_ record: WirdDayCompletionRecord)
}

public struct FileWirdStore: WirdStoring {
    private let wirdsURL: URL
    private let progressURL: URL
    private let completionsURL: URL

    public init(directory: URL) {
        wirdsURL = directory.appendingPathComponent("awrad-wirds.json")
        progressURL = directory.appendingPathComponent("awrad-progress.json")
        completionsURL = directory.appendingPathComponent("awrad-day-completions.json")
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    public func loadWirds() -> [Wird] { load([Wird].self, from: wirdsURL) ?? [] }
    public func saveWirds(_ wirds: [Wird]) { save(wirds, to: wirdsURL) }
    public func loadProgress() -> [WirdDailyProgress] { load([WirdDailyProgress].self, from: progressURL) ?? [] }
    public func saveProgress(_ progress: [WirdDailyProgress]) { save(progress, to: progressURL) }
    public func loadDayCompletions() -> [WirdDayCompletionRecord] {
        load([WirdDayCompletionRecord].self, from: completionsURL) ?? []
    }

    public func recordDayCompletion(_ record: WirdDayCompletionRecord) {
        var all = loadDayCompletions()
        all.append(record)
        save(all, to: completionsURL)
    }
}
