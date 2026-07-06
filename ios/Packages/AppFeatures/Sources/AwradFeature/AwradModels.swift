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

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: String,
        target: Int,
        unit: String,
        frequency: String,
        createdAt: Date,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.target = target
        self.unit = unit
        self.frequency = frequency
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    public var isActive: Bool { archivedAt == nil }
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
