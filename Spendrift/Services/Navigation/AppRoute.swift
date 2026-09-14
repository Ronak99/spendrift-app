//
//  AppRoute.swift
//  Spendrift
//
//  Page paths carried in remote push payloads. Keep this allowlist in lockstep
//  with `APP_PUSH_PATHS` on the backend; an unknown path is ignored rather than
//  guessed at.
//

import Foundation

enum AppRoute: String, CaseIterable, Hashable {
    case feedback = "/feedback"
    case explore = "/explore"

    /// Tolerates a missing leading slash, mixed case, surrounding whitespace, a
    /// trailing slash, and a query string. Returns nil for anything else.
    init?(path: String) {
        var trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query = trimmed.firstIndex(of: "?") {
            trimmed = String(trimmed[..<query])
        }
        if trimmed.hasPrefix("/") == false {
            trimmed = "/" + trimmed
        }
        if trimmed.count > 1, trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        self.init(rawValue: trimmed.lowercased())
    }

    var settingsDestination: AppRouter.SettingsDestination {
        switch self {
        case .feedback: .feedback
        case .explore: .explore
        }
    }
}
