import Foundation

/// Bundled dhikr presets (docs/features/tasbeeh.md). A backend-driven list is
/// a natural future extension (mirrors wird_templates); not required for M2.
public struct DhikrPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let arabicText: String

    public init(id: String, arabicText: String) {
        self.id = id
        self.arabicText = arabicText
    }

    /// Sentinel selection meaning "let the user type custom text".
    public static let custom = DhikrPreset(id: "custom", arabicText: "")

    public static let bundled: [DhikrPreset] = [
        DhikrPreset(id: "subhanallah", arabicText: "سبحان الله"),
        DhikrPreset(id: "alhamdulillah", arabicText: "الحمد لله"),
        DhikrPreset(id: "allahu_akbar", arabicText: "الله أكبر"),
        DhikrPreset(id: "la_ilaha_illallah", arabicText: "لا إله إلا الله"),
        DhikrPreset(id: "subhanallahi_wabihamdihi", arabicText: "سبحان الله وبحمده"),
        DhikrPreset(id: "astaghfirullah", arabicText: "أستغفر الله"),
    ]

    public static let commonTargets = [33, 99, 100, 1000]
}

/// A completed counting set, persisted to history.
public struct TasbeehHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let presetId: String?
    public let customText: String?
    public let target: Int
    public let actualCount: Int
    public let completedAt: Date

    public init(
        id: UUID = UUID(),
        presetId: String?,
        customText: String?,
        target: Int,
        actualCount: Int,
        completedAt: Date
    ) {
        self.id = id
        self.presetId = presetId
        self.customText = customText
        self.target = target
        self.actualCount = actualCount
        self.completedAt = completedAt
    }
}

public struct TasbeehStats: Equatable, Sendable {
    public let totalCount: Int
    public let setsCompleted: Int

    public init(totalCount: Int, setsCompleted: Int) {
        self.totalCount = totalCount
        self.setsCompleted = setsCompleted
    }

    public static func from(history: [TasbeehHistoryEntry]) -> TasbeehStats {
        TasbeehStats(
            totalCount: history.reduce(0) { $0 + $1.actualCount },
            setsCompleted: history.count
        )
    }
}

/// Persistence boundary for history (mirrors ConfigKit.ConfigStoring).
public protocol TasbeehHistoryStoring: Sendable {
    func load() -> [TasbeehHistoryEntry]
    func save(_ history: [TasbeehHistoryEntry])
}

public struct FileTasbeehHistoryStore: TasbeehHistoryStoring {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("tasbeeh-history.json")
    }

    public func load() -> [TasbeehHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TasbeehHistoryEntry].self, from: data)) ?? []
    }

    public func save(_ history: [TasbeehHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
