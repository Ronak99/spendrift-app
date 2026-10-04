//
//  Analytics.swift
//  Spendrift
//
//  Centralized analytics facade. Keeps PostHog out of feature code, enforces a
//  stable low-cardinality event taxonomy, and respects the user's opt-out.
//
//  No user accounts. Each install is one PostHog person, identified by the
//  Keychain `device_id`. `personProfiles` stays `.identifiedOnly`, so a profile
//  is created only when `identify` runs. A reinstall keeps that Keychain id;
//  PostHog aliases the new anonymous distinct id back to the same person.
//  `device_id` is the only person property, and the same value is registered as
//  an event super property so events can be grouped before the profile exists.
//
//  PostHog runs only in release builds, and only when a real API key and backend
//  URL are configured. Debug builds never start the SDK: there is no dev project,
//  and a fake key still makes the client poll remote config and feature flags
//  through the local `/ingest` proxy. Every call below is a no-op until
//  `bootstrap()` has set it up.
//

import Foundation
import PostHog

enum Analytics {
    enum Event: String {
        case appOpened = "app_opened"
        case screenViewed = "screen_viewed"
        case onboardingStepViewed = "onboarding_step_viewed"
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
        case feedbackSubmitted = "feedback_submitted"
        case backupCreated = "backup_created"
        case backupRestored = "backup_restored"
    }

    /// Property keys. Keep flat and free of PII — never send transaction amounts or notes.
    /// Category/account names (and account starting balance on create) are sent only on
    /// catalog events to learn which defaults to offer in future releases.
    enum Key {
        static let method = "method"
        static let type = "type"
        static let count = "count"
        static let tab = "tab"
        static let step = "step"
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
        static let path = "path"
        static let campaign = "campaign"
        static let notificationID = "notification_id"
        static let removedCount = "removed_count"
        static let keptCount = "kept_count"
        static let feature = "feature"
        static let context = "context"
        static let plan = "plan"
        static let remaining = "remaining"
        static let skippedToNotes = "skipped_to_notes"
        static let deviceID = "device_id"
    }

    private static let optOutDefaultsKey = "analyticsOptOut"
    private static let installDateKey = "analyticsInstallDate"
    private static let firstTransactionKey = "didFireFirstTransactionCreated"
    private static let placeholderAPIKey = "phc_REPLACE_ME"
    private static var didSetupPostHog = false

    // MARK: - Lifecycle

    static func bootstrap() {
        stampInstallDateIfNeeded()

        // Debug builds stay off PostHog. A non-placeholder key still initializes
        // the SDK, which then retries `/array/.../config` and `/flags` forever
        // when that key is rejected.
        #if DEBUG
        return
        #endif

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
        config.sessionReplayConfig.maskAllImages = false
        config.sessionReplayConfig.maskAllSandboxedViews = false
        // SwiftUI view hierarchies don't serialise into PostHog's wireframe format,
        // so capture screenshots instead.
        config.sessionReplayConfig.screenshotMode = true
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register([Key.deviceID: DeviceIdentity.current])
        didSetupPostHog = true

        if isOptedOut {
            PostHogSDK.shared.optOut()
        } else {
            identifyCurrentInstall()
        }
    }

    /// Links this install's PostHog person to the Keychain device id.
    /// Called on every launch and again on opt-in. The same id is idempotent, and
    /// a reinstall's new anonymous distinct id is aliased back to this person.
    /// Skipped while opted out so an opted-out launch does not create a profile.
    private static func identifyCurrentInstall() {
        let deviceID = DeviceIdentity.current
        PostHogSDK.shared.identify(deviceID, userProperties: [Key.deviceID: deviceID])
    }

    /// PostHog distinct id for this install. After `identify`, this is the Keychain
    /// device id. Nil until the SDK has been set up this launch.
    static var posthogDistinctId: String? {
        guard didSetupPostHog else { return nil }
        return PostHogSDK.shared.getDistinctId()
    }

    // MARK: - Capture

    static func capture(_ event: Event, _ properties: [String: Any] = [:]) {
        guard didSetupPostHog, !isOptedOut else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    /// Captures `app_opened`, attributing the open to a notification when the user
    /// tapped one on the way in. `source` is `"notification"` or `"direct"`; a
    /// notification-sourced open also carries `kind` (which notification),
    /// plus `notification_id` / `campaign` where the tap handler had them.
    ///
    /// Best effort by design: iOS gives no ordering guarantee between the tap
    /// callback and the first view appearing, so a cold start can still report
    /// `source=direct`. `notification_opened` is the authoritative per-notification
    /// event — this property is for splitting sessions, not for counting taps.
    static func captureAppOpened() {
        var properties: [String: Any] = [Key.daysSinceInstall: daysSinceInstall]

        if let open = NotificationOpenAttribution.current() {
            properties[Key.source] = "notification"
            properties[Key.kind] = open.kind
            if let notificationID = open.notificationID {
                properties[Key.notificationID] = notificationID
            }
            if let campaign = open.campaign, !campaign.isEmpty {
                properties[Key.campaign] = campaign
            }
        } else {
            properties[Key.source] = "direct"
        }

        capture(.appOpened, properties)
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
        AudienceTags.scheduleSync()

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstTransactionKey) else { return }
        defaults.set(true, forKey: firstTransactionKey)
        capture(.firstTransactionCreated, [Key.method: method])
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
            guard didSetupPostHog else { return }
            if newValue {
                PostHogSDK.shared.optOut()
            } else {
                PostHogSDK.shared.optIn()
                identifyCurrentInstall()
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
