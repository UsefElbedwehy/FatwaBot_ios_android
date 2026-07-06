import CoreKit
import Foundation
import Security

/// Real Keychain-backed token store (ADR-0004). One item, JSON-encoded, under
/// a fixed account/service pair — simplest thing that's still not plaintext
/// UserDefaults for a session credential.
public final class KeychainAuthTokenStore: AuthTokenStoring, @unchecked Sendable {
    private let service: String
    private let account = "fatwabot.auth-tokens"

    public init(service: String = "com.fatwabot.app") {
        self.service = service
    }

    public func load() -> AuthTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    public func save(_ tokens: AuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        var query = baseQuery()
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    public func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
