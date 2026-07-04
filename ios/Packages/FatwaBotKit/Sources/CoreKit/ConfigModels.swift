import Foundation

// Server contract models — mirror backend/openapi/api.v1.yaml.

public struct AppConfig: Codable, Equatable, Sendable {
    public struct Flag: Codable, Equatable, Sendable {
        public struct Rollout: Codable, Equatable, Sendable {
            public let minAppVersion: String?

            enum CodingKeys: String, CodingKey {
                case minAppVersion = "min_app_version"
            }

            public init(minAppVersion: String? = nil) { self.minAppVersion = minAppVersion }
        }

        public let enabled: Bool
        public let rollout: Rollout?

        public init(enabled: Bool, rollout: Rollout? = nil) {
            self.enabled = enabled
            self.rollout = rollout
        }
    }

    public let config: [String: JSONValue]
    public let flags: [String: Flag]
    public let locales: [LocaleInfo]

    public init(config: [String: JSONValue], flags: [String: Flag], locales: [LocaleInfo]) {
        self.config = config
        self.flags = flags
        self.locales = locales
    }

    public func isEnabled(_ flag: String) -> Bool {
        flags[flag]?.enabled ?? false
    }
}

public struct LocaleInfo: Codable, Equatable, Sendable {

    public init(locale: String, displayName: String, direction: String, digits: String) {
        self.locale = locale
        self.displayName = displayName
        self.direction = direction
        self.digits = digits
    }
    public let locale: String
    public let displayName: String
    public let direction: String
    public let digits: String

    enum CodingKeys: String, CodingKey {
        case locale
        case displayName = "display_name"
        case direction
        case digits
    }
}

public struct ServerTheme: Codable, Equatable, Sendable {

    public init(version: Int, tokens: [String: JSONValue]) {
        self.version = version
        self.tokens = tokens
    }
    public let version: Int
    public let tokens: [String: JSONValue]
}

public struct StringPack: Codable, Equatable, Sendable {

    public init(locale: String, version: Int, strings: [String: String]) {
        self.locale = locale
        self.version = version
        self.strings = strings
    }
    public let locale: String
    public let version: Int
    public let strings: [String: String]
}

public struct HomeLayout: Codable, Equatable, Sendable {
    public struct Section: Codable, Equatable, Sendable {
        public init(id: String, type: String, props: [String: JSONValue]) {
            self.id = id
            self.type = type
            self.props = props
        }
        public let id: String
        public let type: String
        public let props: [String: JSONValue]
    }

    public let version: Int
    public let sections: [Section]

    public init(version: Int, sections: [Section]) {
        self.version = version
        self.sections = sections
    }

    /// ADR-0011 forward compatibility: unknown section types are skipped, never fatal.
    public func renderableSections(supported: Set<String>) -> [Section] {
        sections.filter { supported.contains($0.type) }
    }
}

public struct PrayerDefaults: Codable, Equatable, Sendable {

    public init(countryCode: String, method: String, params: [String: JSONValue]) {
        self.countryCode = countryCode
        self.method = method
        self.params = params
    }
    public let countryCode: String
    public let method: String
    public let params: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case method
        case params
    }
}
