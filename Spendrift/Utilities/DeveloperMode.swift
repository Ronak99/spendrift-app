//
//  DeveloperMode.swift
//  Spendrift
//
//  Unlocks developer screens in production. Debug builds always treat this as on.
//  Release builds unlock with DEVELOPER_PASSWORD (ProdSecrets.xcconfig), entered
//  after tapping the Settings version label five times.
//

import Foundation

enum DeveloperMode {
    static let defaultsKey = "spendriftDeveloperModeEnabled"

    static let store: UserDefaults = UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard

    /// Debug builds always expose developer tools. Production requires the Settings passphrase.
    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        store.bool(forKey: defaultsKey)
        #endif
    }

    /// True when `text` matches `DEVELOPER_PASSWORD` from the build's secrets xcconfig.
    /// Always false when the password is not configured.
    static func isPassphrase(_ text: String) -> Bool {
        let password = AppSecrets.developerPassword
        guard !password.isEmpty else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == password
    }
}
