//
//  VoiceCaptureHints.swift
//  Spendrift
//
//  Example phrases shown while voice recording. Copy and locale coverage come from
//  the PostHog remote config flag `voice_capture_hints`.
//

import Foundation

enum VoiceCaptureHints {
    static let remoteConfigFlagKey = "voice_capture_hints"

    /// BCP 47-style identifier from Language & Region (e.g. `en_IN`). Matches PostHog `locales` keys.
    static var currentLocaleIdentifier: String {
        Locale.current.identifier
    }

    /// Scripts for `localeIdentifier`, or empty when the locale is absent or PostHog is unavailable.
    static func scripts(for localeIdentifier: String, payload: [String: Any]?) -> [String] {
        guard let payload else { return [] }
        return Self.parseScripts(from: payload, localeIdentifier: localeIdentifier)
    }

    static func scriptsForCurrentLocale() -> [String] {
        let payload = Analytics.remoteConfigPayload(forKey: remoteConfigFlagKey)
        return scripts(for: currentLocaleIdentifier, payload: payload)
    }

    static func randomScript(for localeIdentifier: String = currentLocaleIdentifier) -> String? {
        scripts(for: localeIdentifier, payload: Analytics.remoteConfigPayload(forKey: remoteConfigFlagKey))
            .randomElement()
    }

    // MARK: - Parsing

    static func parseScripts(from payload: [String: Any], localeIdentifier: String) -> [String] {
        guard let locales = payload["locales"] as? [String: Any] else { return [] }
        guard let localeEntry = locales[localeIdentifier] as? [String: Any] else { return [] }
        guard let scripts = localeEntry["scripts"] as? [Any] else { return [] }
        return scripts.compactMap { element in
            guard let line = element as? String else { return nil }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}
