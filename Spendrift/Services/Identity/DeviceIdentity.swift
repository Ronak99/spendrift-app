//
//  DeviceIdentity.swift
//  Spendrift
//
//  Stable per-device UUID for cross-tool user reference. No auth: this id is
//  how Sentry, PostHog, and Supabase feedback refer to the same install.
//
//  Generated on first access, stored in Keychain (survives reinstall), and
//  independent of analytics or diagnostics opt-out.
//

import Foundation
import Security

enum DeviceIdentity {
    private static let service = "com.ronakpunase.Spendrift.identity"
    private static let account = "device_id"

    private static var cached: String?

    /// Stable UUID for this device install. Creates and persists on first access.
    static var current: String {
        if let cached { return cached }
        let value = readKeychain() ?? {
            let new = UUID().uuidString
            writeKeychain(new)
            return new
        }()
        cached = value
        return value
    }

    // MARK: - Keychain

    private static func readKeychain() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty else {
            return nil
        }
        return string
    }

    private static func writeKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        var query = baseQuery()
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            var updateQuery = baseQuery()
            let attributes = [kSecValueData as String: data]
            SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false
        ]
    }
}
