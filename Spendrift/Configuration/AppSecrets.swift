//
//  AppSecrets.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

enum AppSecrets {
    static var backendBaseURL: URL? {
        guard let raw = Bundle.main.infoDictionary?["SpendriftBackendBaseURL"] as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static var backendClientToken: String {
        Bundle.main.infoDictionary?["SpendriftBackendClientToken"] as? String ?? ""
    }
}
