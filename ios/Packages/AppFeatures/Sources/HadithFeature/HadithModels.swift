import Foundation

/// Local reading progress for one collection (docs/features/hadith-collections.md).
/// `readNumbers` is a set — re-reading an entry never double counts.
public struct HadithProgress: Codable, Equatable, Sendable {
    public var readNumbers: Set<Int>
    public var lastReadNumber: Int?

    public init(readNumbers: Set<Int> = [], lastReadNumber: Int? = nil) {
        self.readNumbers = readNumbers
        self.lastReadNumber = lastReadNumber
    }
}

public protocol HadithStoring: Sendable {
    func loadProgress() -> [String: HadithProgress]
    func saveProgress(_ progress: [String: HadithProgress])
}

public struct FileHadithStore: HadithStoring {
    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("hadith-progress.json")
    }

    public func loadProgress() -> [String: HadithProgress] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: HadithProgress].self, from: data)) ?? [:]
    }

    public func saveProgress(_ progress: [String: HadithProgress]) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
