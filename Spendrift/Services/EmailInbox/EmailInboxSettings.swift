//
//  EmailInboxSettings.swift
//  Spendrift
//
//  Import cursor for forwarded emails. The backend keeps every email, so the app
//  remembers the `receivedAtIso` of the last one it finished with and asks only
//  for newer ones next launch.
//

import Foundation

enum EmailInboxSettings {
    static let lastReceivedAtIsoKey = "emailInboxLastReceivedAtIso"
    static let lastImportedAtKey = "emailInboxLastImportedAt"

    private static var suite: UserDefaults {
        UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    /// Server timestamp of the newest email that reached a final outcome.
    static var lastReceivedAtIso: String? {
        get { suite.string(forKey: lastReceivedAtIsoKey) }
        set {
            if let newValue {
                suite.set(newValue, forKey: lastReceivedAtIsoKey)
            } else {
                suite.removeObject(forKey: lastReceivedAtIsoKey)
            }
        }
    }

    /// When the app last finished importing at least one email. Health signal for Settings.
    static var lastImportedAt: Date? {
        get {
            let interval = suite.double(forKey: lastImportedAtKey)
            guard interval > 0 else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let newValue {
                suite.set(newValue.timeIntervalSince1970, forKey: lastImportedAtKey)
            } else {
                suite.removeObject(forKey: lastImportedAtKey)
            }
        }
    }
}
