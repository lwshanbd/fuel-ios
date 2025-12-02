import Foundation
import Security

/// Supported AI providers
enum AIProvider: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case chatgpt = "ChatGPT"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var keychainKey: String {
        switch self {
        case .claude: return "me.baodi.fuel.apikey.claude"
        case .chatgpt: return "me.baodi.fuel.apikey.chatgpt"
        }
    }

    var placeholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .chatgpt: return "sk-..."
        }
    }
}

/// Manages API keys securely using Keychain
final class APIKeyManager {
    static let shared = APIKeyManager()

    private init() {}

    // MARK: - Public Methods

    /// Check if an API key exists for a provider
    func hasAPIKey(for provider: AIProvider) -> Bool {
        return readFromKeychain(key: provider.keychainKey) != nil
    }

    /// Save an API key for a provider
    /// - Returns: true if save was successful
    @discardableResult
    func saveAPIKey(_ apiKey: String, for provider: AIProvider) -> Bool {
        guard !apiKey.isEmpty else {
            return deleteAPIKey(for: provider)
        }
        return saveToKeychain(key: provider.keychainKey, value: apiKey)
    }

    /// Retrieve an API key for a provider (for actual API calls)
    func getAPIKey(for provider: AIProvider) -> String? {
        return readFromKeychain(key: provider.keychainKey)
    }

    /// Delete an API key for a provider
    @discardableResult
    func deleteAPIKey(for provider: AIProvider) -> Bool {
        return deleteFromKeychain(key: provider.keychainKey)
    }

    /// Get masked version of API key for display (e.g., "sk-ant-...abc")
    func getMaskedAPIKey(for provider: AIProvider) -> String? {
        guard let key = readFromKeychain(key: provider.keychainKey), !key.isEmpty else {
            return nil
        }

        // Show first 7 chars and last 3 chars
        if key.count > 12 {
            let prefix = String(key.prefix(7))
            let suffix = String(key.suffix(3))
            return "\(prefix)...\(suffix)"
        } else {
            // For very short keys, just mask the middle
            return String(repeating: "•", count: key.count)
        }
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    @discardableResult
    private func deleteFromKeychain(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
