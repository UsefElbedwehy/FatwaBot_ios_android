import Foundation

/// Generic per-collection-per-locale cache (docs/features/content-pipeline.md:
/// "one JSON file per collection per locale ... so a large hadith collection
/// doesn't invalidate azkar on refresh"). Falls back to the bundled seed
/// (Resources/*.json, ContentKit's SPM bundle) when no cache exists yet.
public struct ContentFileStore: Sendable {
    private let directory: URL
    private let bundle: Bundle

    public init(directory: URL, bundle: Bundle? = nil) {
        self.directory = directory
        self.bundle = bundle ?? .module
    }

    /// Cache → bundled seed → nil. Never throws; callers treat nil as "show empty state".
    public func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        if let cached = decode(type, from: cacheURL(for: key)) {
            return cached
        }
        guard let seedURL = bundle.url(forResource: key, withExtension: "json") else { return nil }
        return decode(type, from: seedURL)
    }

    public func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: cacheURL(for: key), options: .atomic)
    }

    private func cacheURL(for key: String) -> URL {
        directory.appendingPathComponent("content-\(key).json")
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
