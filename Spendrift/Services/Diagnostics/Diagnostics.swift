//
//  Diagnostics.swift
//  Spendrift
//
//  Centralized diagnostics facade. Keeps Sentry out of feature code, enforces a
//  stable low-cardinality tag taxonomy, and respects the user's opt-out.
//
//  Complements Analytics (PostHog): PostHog counts product behavior and failure
//  rates; Diagnostics captures crashes, breadcrumbs, and technical errors.
//  Do not mirror every Analytics.capture call here.
//

import Foundation
import Sentry

enum Diagnostics {
    /// Breadcrumb categories for grouping the verbose trail before a crash.
    enum Category: String {
        case navigation
        case feature
        case lifecycle
        case error
    }

    /// Structured tag keys. Keep flat and free of PII.
    enum Tag {
        static let feature = "feature"
        static let stage = "stage"
        static let method = "method"
        static let reason = "reason"
        static let source = "source"
        static let route = "route"
        static let errorDomain = "error_domain"
        static let errorCode = "error_code"
        static let tab = "tab"
    }

    /// Low-cardinality subsystem identifiers.
    enum Feature: String {
        case voice
        case pdf
        case receipt
        case manual
        case cloudkit
        case seeding
        case notifications
        case app
    }

    /// Pipeline step within a feature flow.
    enum Stage: String {
        case bootstrap
        case capture
        case transcribe
        case parse
        case persist
        case upload
        case reconcile
    }

    enum Level {
        case info
        case warning
        case error
    }

    private static let optOutDefaultsKey = "diagnosticsOptOut"
    private static let placeholderDSN = "https://REPLACE_ME@o0.ingest.sentry.io/0"

    // MARK: - Lifecycle

    static func bootstrap() {
        guard !isOptedOut else { return }

        let cloudDSN = AppSecrets.sentryDSN
        guard !cloudDSN.isEmpty, cloudDSN != placeholderDSN else { return }
        guard let backendBaseURL = AppSecrets.backendBaseURL else { return }
        guard let clientDSN = Self.clientDSN(cloudDSN: cloudDSN, backendBaseURL: backendBaseURL) else {
            return
        }

        SentrySDK.start { options in
            // DSN host points at our backend; SDK POSTs to /api/{projectId}/envelope/
            // and the backend forwards to Sentry cloud (no URLProtocol needed).
            options.dsn = clientDSN
            options.enableCaptureFailedRequests = false
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version) (\(build))"
            }
            #if DEBUG
            options.environment = "development"
            options.debug = true
            options.tracesSampleRate = 1.0
            #else
            options.environment = "production"
            options.tracesSampleRate = 0.1
            #endif
            options.beforeSend = { event in
                scrubRequestHeaders(in: event)
                return event
            }
        }
    }

    // MARK: - Breadcrumbs

    /// Cheap verbose trail for reconstructing context before a crash or error.
    static func breadcrumb(
        category: Category,
        message: String,
        feature: Feature? = nil,
        stage: Stage? = nil,
        data: [String: String] = [:]
    ) {
        guard !isOptedOut else { return }

        var merged = data
        if let feature { merged[Tag.feature] = feature.rawValue }
        if let stage { merged[Tag.stage] = stage.rawValue }

        let crumb = Breadcrumb(level: .info, category: category.rawValue)
        crumb.message = message
        crumb.data = merged
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - Messages

    /// Handled anomalies and degraded paths that do not throw.
    static func log(_ message: String, level: Level = .info, tags: [String: String] = [:]) {
        guard !isOptedOut else { return }

        SentrySDK.capture(message: message) { scope in
            scope.setLevel(sentryLevel(for: level))
            apply(tags: tags, to: scope)
        }
    }

    // MARK: - Errors

    /// Unexpected thrown errors and infrastructure failures.
    static func capture(_ error: Error, tags: [String: String] = [:]) {
        guard !isOptedOut else { return }

        SentrySDK.capture(error: error) { scope in
            apply(tags: tags, to: scope)
            let nsError = error as NSError
            scope.setTag(value: nsError.domain, key: Tag.errorDomain)
            scope.setTag(value: String(nsError.code), key: Tag.errorCode)
        }
    }

    // MARK: - Opt-out

    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: optOutDefaultsKey) }
    }

    // MARK: - Private

    private static func sentryLevel(for level: Level) -> SentryLevel {
        switch level {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }

    private static func apply(tags: [String: String], to scope: Scope) {
        for (key, value) in tags {
            scope.setTag(value: value, key: key)
        }
    }

    private static func scrubRequestHeaders(in event: Event) {
        event.request?.headers?.removeValue(forKey: "Authorization")
        event.request?.headers?.removeValue(forKey: "authorization")
    }

    /// Rewrites the cloud DSN host to the backend so the SDK sends envelopes to
    /// `{backend}/api/{projectId}/envelope/` instead of Sentry directly.
    private static func clientDSN(cloudDSN: String, backendBaseURL: URL) -> String? {
        guard let cloud = URLComponents(string: cloudDSN.trimmingCharacters(in: .whitespacesAndNewlines)),
              let publicKey = cloud.user,
              !publicKey.isEmpty else {
            return nil
        }

        let projectId = cloud.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !projectId.isEmpty else { return nil }

        guard var components = URLComponents(url: backendBaseURL, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return nil
        }

        let hostWithPort: String
        if let port = components.port,
           (components.scheme == "http" && port != 80)
            || (components.scheme == "https" && port != 443) {
            hostWithPort = "\(host):\(port)"
        } else {
            hostWithPort = host
        }

        let scheme = components.scheme ?? "https"
        return "\(scheme)://\(publicKey)@\(hostWithPort)/\(projectId)"
    }
}
