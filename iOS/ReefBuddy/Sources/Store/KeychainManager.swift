import Foundation
import Security

/// Secure storage using iOS Keychain
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.reefbuddy.app"

    private init() {}

    // MARK: - Public Methods

    /// Save string to Keychain
    func saveString(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, for: key)
    }

    /// Load string from Keychain
    func loadString(for key: String) -> String? {
        guard let data = load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Save data to Keychain
    func save(_ data: Data, for key: String) -> Bool {
        // Delete existing item first
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load data from Keychain
    func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess ? result as? Data : nil
    }

    /// Delete item from Keychain
    func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Check if key exists in Keychain
    func exists(for key: String) -> Bool {
        return load(for: key) != nil
    }
}