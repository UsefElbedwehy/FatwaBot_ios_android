import Foundation

/// Local-only favorite record (docs/features/dua.md — no backend sync in M2).
public struct FavoriteDua: Codable, Equatable, Sendable {
    public let duaId: String
    public let addedAt: Date

    public init(duaId: String, addedAt: Date) {
        self.duaId = duaId
        self.addedAt = addedAt
    }
}

public protocol DuaStoring: Sendable {
    func loadFavorites() -> [FavoriteDua]
    func saveFavorites(_ favorites: [FavoriteDua])
}

public struct FileDuaStore: DuaStoring {
    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("dua-favorites.json")
    }

    public func loadFavorites() -> [FavoriteDua] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([FavoriteDua].self, from: data)) ?? []
    }

    public func saveFavorites(_ favorites: [FavoriteDua]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(favorites) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Arabic-aware search normalization (docs/features/dua.md: "diacritic-insensitive
/// for Arabic — strip tashkeel before matching").
enum DuaSearch {
    private static let tashkeel = CharacterSet(charactersIn: "\u{0610}-\u{061A}\u{064B}-\u{065F}\u{0670}\u{06D6}-\u{06DC}\u{06DF}-\u{06E8}\u{06EA}-\u{06ED}")

    static func normalize(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { !tashkeel.contains($0) }))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
