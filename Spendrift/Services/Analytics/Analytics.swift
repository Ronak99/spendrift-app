//
//  Analytics.swift
//  Spendrift
//
//  Centralized analytics facade. Keeps PostHog out of feature code, enforces a
//  stable low-cardinality event taxonomy, and respects the user's opt-out.
//
//  No authentication: PostHog's iOS SDK persists an anonymous `distinct_id`, so
//  funnels and retention work per-device. We never call `identify()`.
//  A stable `device_id` super property (Keychain-backed) joins events to Sentry
//  and Supabase feedback without creating identified person profiles.
//
//  PostHog is production-only (App Store and TestFlight). Debug, Simulator,
//  and Xcode/Ad Hoc installs never initialize the SDK, so session replay,
//  lifecycle autocapture, and product events cannot leak into Spendrift-Prod
//  from local sessions.
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
        case voiceCaptureRetried = "voice_capture_retried"
        case pdfImportFailed = "pdf_import_failed"
        case receiptScanFailed = "receipt_scan_failed"
        case shortcutUsed = "shortcut_used"
        case widgetTapped = "widget_tapped"
        case categoryCreated = "category_created"
        case categoryDeleted = "category_deleted"
        case accountCreated = "account_created"
        case accountDeleted = "account_deleted"
        case notificationPermissionRequested = "notification_permission_requested"
        case notificationPermissionGranted = "notification_permission_granted"
        case notificationScheduled = "notification_scheduled"
        case notificationOpened = "notification_opened"
        case messageInboxSynced = "message_inbox_synced"

        // Spendrift Pro
        case paywallViewed = "paywall_viewed"
        case paywallDismissed = "paywall_dismissed"
        case purchaseStarted = "purchase_started"
        case trialStarted = "trial_started"
        case purchaseCompleted = "purchase_completed"
        case purchaseFailed = "purchase_failed"
        case restoreCompleted = "restore_completed"
        case quotaExhausted = "quota_exhausted"
        case proFeatureBlocked = "pro_feature_blocked"
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
        static let source = "source"
        static let isRetry = "is_retry"
        static let version = "version"
        static let daysSinceInstall = "days_since_install"
        static let name = "name"
        static let isDefault = "is_default"
        static let initialBalance = "initial_balance"
        static let granted = "granted"
        static let removedCount = "removed_count"
        static let keptCount = "kept_count"
        static let feature = "feature"
        static let context = "context"
        static let plan = "plan"
        static let remaining = "remaining"
    }

    private static let optOutDefaultsKey = "analyticsOptOut"
    private static let installDateKey = "analyticsInstallDate"
    private static let firstTransactionKey = "didFireFirstTransactionCreated"
    private static let placeholderAPIKey = "phc_REPLACE_ME"

    /// False unless this binary was distributed by Apple (App Store or TestFlight).
    /// Debug, Simulator, and Xcode/Ad Hoc installs never construct the SDK.
    private static var isPostHogEnabled: Bool {
        #if DEBUG
        false
        #elseif targetEnvironment(simulator)
        false
        #else
        isAppStoreOrTestFlightDistribution
        #endif
    }

    /// App Store binaries ship without an embedded provisioning profile.
    /// TestFlight binaries include `beta-reports-active`. Development, Ad Hoc,
    /// and Enterprise profiles do not.
    private static var isAppStoreOrTestFlightDistribution: Bool {
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return true
        }
        guard let contents = try? String(contentsOfFile: profilePath, encoding: .isoLatin1) else {
            return false
        }
        return contents.contains("<key>beta-reports-active</key>")
    }

    // MARK: - Lifecycle

    static func bootstrap() {
        stampInstallDateIfNeeded()
        guard isPostHogEnabled else { return }

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

        // Session replay: screenshot the real UI so we can see where flows stall
        // or break, including amounts, labels, and other on-screen text.
        // Password fields stay masked by the SDK. Images and sandboxed system
        // views (photo/contact pickers) stay masked. Replay honours the same
        // opt-out as event capture below.
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = false
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.maskAllSandboxedViews = true
        // SwiftUI view hierarchies don't serialise into PostHog's wireframe format,
        // so capture screenshots instead.
        config.sessionReplayConfig.screenshotMode = true
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(["device_id": DeviceIdentity.current])

        if isOptedOut {
            PostHogSDK.shared.optOut()
        }
    }

    // MARK: - Capture

    static func capture(_ event: Event, _ properties: [String: Any] = [:]) {
        guard isPostHogEnabled, !isOptedOut else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    /// Captures `transaction_created` and, on the very first transaction ever,
    /// the one-shot `first_transaction_created` activation event.
    /// `method` is one of "manual" / "voice" / "pdf"; `count` covers batch imports.
    /// `isRetry` flags transactions that landed only after a voice retry, so retry
    /// success rate = `transaction_created`(is_retry) / `voice_capture_retried`.
    static func captureTransactionCreated(method: String, type: String, count: Int = 1, isRetry: Bool = false) {
        capture(.transactionCreated, [
            Key.method: method,
            Key.type: type,
            Key.count: count,
            Key.isRetry: isRetry
        ])

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstTransactionKey) else { return }
        defaults.set(true, forKey: firstTransactionKey)
        capture(.firstTransactionCreated, [Key.method: method])

        // Surface the contextual notification opt-in prompt (after first transaction,
        // never at cold start). UI lives in the view layer, so just broadcast.
        NotificationCenter.default.post(name: .firstTransactionCreated, object: nil)
    }

    /// Captures a Spendrift Pro event with `days_since_install` attached, so paywall
    /// funnels can be split by cohort without every call site remembering to add it.
    /// Never pass amounts or notes — the no-PII rule above applies here too.
    static func capturePro(_ event: Event, _ properties: [String: Any] = [:]) {
        var enriched = properties
        enriched[Key.daysSinceInstall] = daysSinceInstall
        capture(event, enriched)
    }

    // MARK: - Opt-out

    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optOutDefaultsKey)
            guard isPostHogEnabled else { return }
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
