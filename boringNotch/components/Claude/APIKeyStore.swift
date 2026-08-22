//
//  APIKeyStore.swift
//  boringNotch
//
//  Stores the Anthropic API key in the login Keychain (not UserDefaults) so it
//  isn't baked into shared app preferences. `APIKeyStore.shared` is an
//  observable wrapper the UI binds to.
//

import Foundation
import Security

enum Keychain {
    private static let service = "com.theboringteam.boringnotch"
    private static let account = "anthropicAPIKey"

    static func read() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    static func save(_ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            SecItemDelete(base as CFDictionary)
            return
        }
        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

@MainActor
final class APIKeyStore: ObservableObject {
    static let shared = APIKeyStore()

    @Published var apiKey: String {
        didSet {
            guard apiKey != oldValue else { return }
            Keychain.save(apiKey)
        }
    }

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() { apiKey = Keychain.read() }
}
