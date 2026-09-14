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

    static var posthogAPIKey: String {
        (Bundle.main.infoDictionary?["SpendriftPostHogAPIKey"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Analytics ingestion is proxied through the backend's `/ingest` route, so
    /// the PostHog host is derived from `backendBaseURL` rather than configured
    /// separately. Returns nil when the backend URL is missing.
    static var posthogHost: String? {
        guard let base = backendBaseURL else { return nil }
        return base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/ingest"
    }

    static var sentryDSN: String {
        (Bundle.main.infoDictionary?["SpendriftSentryDSN"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Production Sentry envelopes are tunneled through `/ingest` (same first-party
    /// proxy as PostHog) so App Store builds never talk to ingest.sentry.io.
    /// Returns nil when the backend URL is missing.
    static var sentryTunnelURL: URL? {
        guard let base = backendBaseURL else { return nil }
        let trimmed = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed + "/ingest")
    }

    static var oneSignalAppID: String {
        (Bundle.main.infoDictionary?["SpendriftOneSignalAppID"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
