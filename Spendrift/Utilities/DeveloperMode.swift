//
//  DeveloperMode.swift
//  Spendrift
//
//  Unlocks developer screens in production. Debug builds always treat this as on.
//

import Foundation

enum DeveloperMode {
    static let defaultsKey = "spendriftDeveloperModeEnabled"
    static let passphrase = "developer"

    static let store: UserDefaults = UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard

    /// Debug builds always expose developer tools. Production requires the Settings passphrase.
    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        store.bool(forKey: defaultsKey)
        #endif
    }

    static func isPassphrase(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == passphrase
    }
}
