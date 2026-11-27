import Foundation
import Security

/// Guarda la sesión (JWT y usuario) en Keychain. Nunca en UserDefaults.
final class KeychainManager {
    nonisolated static let shared = KeychainManager()

    private let service = Bundle.main.bundleIdentifier ?? "com.juancamacho.Yonke-App"

    private enum Account {
        static let token = "auth.token"
        static let user = "auth.user"
    }

    private init() {}

    // MARK: - Session

    func saveToken(_ token: String) -> Bool {
        save(Data(token.utf8), account: Account.token)
    }

    func readToken() -> String? {
        guard let data = read(account: Account.token) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveUser(_ user: AuthUser) -> Bool {
        guard let data = try? JSONEncoder().encode(user) else { return false }
        return save(data, account: Account.user)
    }

    func readUser() -> AuthUser? {
        guard let data = read(account: Account.user) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    func clearSession() {
        delete(account: Account.token)
        delete(account: Account.user)
    }

    // MARK: - Generic

    @discardableResult
    func save(_ data: Data, account: String) -> Bool {
        delete(account: account)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
