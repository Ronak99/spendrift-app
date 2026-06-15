//
//  Analytics.swift
//  Spendrift
//
//  Centralized analytics facade. Keeps PostHog out of feature code, enforces a
//  stable low-cardinality event taxonomy, and respects the user's opt-out.
//
//  No authentication: PostHog's iOS SDK persists an anonymous `distinct_id`, so
//  funnels and retention work per-device. We never call `identify()`.
//

import Foundation
import PostHog

enum Analytics {
    enum Event: String {
        case appOpened = "app_opened"
        case screenViewed = "screen_viewed"
        case onboardingCompleted = "onboarding_completed"
        case transactionCreated = "transaction_created"
        case firstTransactionCreated = "first_transaction_created"
        case voiceCaptureFailed = "voice_capture_failed"
        case pdfImportFailed = "pdf_import_failed"
        case shortcutUsed = "shortcut_used"
        case widgetTapped = "widget_tapped"
        case categoryCreated = "category_created"
        case categoryDeleted = "category_deleted"
        case accountCreated = "account_created"
        case accountDeleted = "account_deleted"
    }

    /// Property keys. Keep flat and free of PII — never send transaction amounts or notes.
    /// Category/account names (and account starting balance on create) are sent only on
    /// catalog events to learn which defaults to offer in future releases.
    enum Key {
        static let method = "method"
        static let type = "type"
        static let count = "count"
        static let tab = "tab"
        static let kind = "kind"
        static let reason = "reason"
        static let version = "version"
        static let daysSinceInstall = "days_since_install"
        static let name = "name"
        static let initialBalance = "initial_balance"
    }

    private static let optOutDefaultsKey = "analyticsOptOut"
    private static let installDateKey = "analyticsInstallDate"
    private static let firstTransactionKey = "didFireFirstTransactionCreated"
    private static let placeholderAPIKey = "phc_REPLACE_ME"

    // MARK: - Lifecycle

    static func bootstrap() {
        stampInstallDateIfNeeded()

        let apiKey = AppSecrets.posthogAPIKey
        // A missing or placeholder key means analytics isn't configured for this build.
        guard !apiKey.isEmpty, apiKey != placeholderAPIKey else { return }

        // Ingestion is proxied through the backend's /ingest route; without a
        // backend URL there is nowhere to send analytics.
        guard let host = AppSecrets.posthogHost else { return }

        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.personProfiles = .identifiedOnly
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.sessionReplay = false
        #if DEBUG
        config.debug = true
        config.flushAt = 1
        #endif
        PostHogSDK.shared.setup(config)

        if isOptedOut {
            PostHogSDK.shared.optOut()
        }
    }

    // MARK: - Capture

    static func capture(_ event: Event, _ properties: [String: Any] = [:]) {
        guard !isOptedOut else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    /// Captures `transaction_created` and, on the very first transaction ever,
    /// the one-shot `first_transaction_created` activation event.
    /// `method` is one of "manual" / "voice" / "pdf"; `count` covers batch imports.
    static func captureTransactionCreated(method: String, type: String, count: Int = 1) {
        capture(.transactionCreated, [Key.method: method, Key.type: type, Key.count: count])

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstTransactionKey) else { return }
        defaults.set(true, forKey: firstTransactionKey)
        capture(.firstTransactionCreated, [Key.method: method])
    }

    // MARK: - Opt-out

    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optOutDefaultsKey)
            if newValue {
                PostHogSDK.shared.optOut()
            } else {
                PostHogSDK.shared.optIn()
            }
        }
    }

    // MARK: - Install date

    /// Whole days since first launch, used for retention cohorting on `app_opened`.
    static var daysSinceInstall: Int {
        stampInstallDateIfNeeded()
        guard let installDate = UserDefaults.standard.object(forKey: installDateKey) as? Date else {
            return 0
        }
        return max(0, Int(Date().timeIntervalSince(installDate) / 86_400))
    }

    private static func stampInstallDateIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: installDateKey) == nil else { return }
        defaults.set(Date(), forKey: installDateKey)
    }
}
