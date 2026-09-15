//
//  AudienceTags.swift
//  Spendrift
//
//  Compact OneSignal Data Tags (`sd_*`) used to build dashboard segments.
//  PostHog remains the source of truth for what happened; these tags are a
//  current-state snapshot for targeting. No PII: no notes, amounts, names,
//  or emails.
//
//  OneSignal writes happen only from the main app after bootstrap. App Intents
//  and the widget write App Group flags here so the next foreground sync
//  uploads them.
//

import Foundation
import OneSignalFramework
import SwiftData
import UIKit

enum AudienceTags {
    /// OneSignal tag keys. Keep in lockstep with `Spendrift/docs/ONESIGNAL_CAMPAIGNS.md`.
    enum Tag {
        static let onboardingDone = "sd_onboarding_done"
        static let hasTransaction = "sd_has_transaction"
        static let txCountBucket = "sd_tx_count_bucket"
        static let usedManual = "sd_used_manual"
        static let usedVoice = "sd_used_voice"
        static let usedSMS = "sd_used_sms"
        static let usedPDF = "sd_used_pdf"
        static let usedReceipt = "sd_used_receipt"
        static let usedTypedShortcut = "sd_used_typed_shortcut"
        static let seenExplore = "sd_seen_explore"
        static let exploreShortcutAdded = "sd_explore_shortcut_added"
        static let seenAnalytics = "sd_seen_analytics"
        static let plan = "sd_plan"
        static let trialEndsOn = "sd_trial_ends_on"
        static let quotaVoice = "sd_quota_voice"
        static let quotaSMS = "sd_quota_sms"
        static let quotaReceipt = "sd_quota_receipt"
        static let quotaPDF = "sd_quota_pdf"
        static let quotaExhaustedAny = "sd_quota_exhausted_any"
        static let hitQuotaVoice = "sd_hit_quota_voice"
        static let quotaHits30d = "sd_quota_hits_30d"
        static let notifStatus = "sd_notif_status"
        static let lastActiveOn = "sd_last_active_on"
        static let daysSinceInstall = "sd_days_since_install"
        static let appVersion = "sd_app_version"
        static let iosVersion = "sd_ios_version"
        static let locale = "sd_locale"
    }

    /// App Group keys shared with the widget copy of `ShortcutQuickAmountTransaction`.
    enum StoreKey {
        static let lastSent = "audience.lastSentTags"
        static let seenExplore = "audience.seenExplore"
        static let exploreShortcutAdded = "audience.exploreShortcutAdded"
        static let seenAnalytics = "audience.seenAnalytics"
        static let hasTransaction = "audience.hasTransaction"
        static let usedTypedShortcut = "audience.usedTypedShortcut"
        static let txCount = "audience.txCount"
        static let quotaHitTimestamps = "audience.quotaHitTimestamps"
        static let hitQuotaVoicePeriod = "audience.hitQuotaVoicePeriod"
    }

    static let onboardingVersionKey = "spendriftOnboardingVersion"
    static let debounceNanoseconds: UInt64 = 1_000_000_000
    static let quotaHitWindow: TimeInterval = 30 * 24 * 60 * 60
    static let quotaHitCap = 99

    /// Test seam. Production resolves to the App Group suite.
    static var defaultsOverride: UserDefaults?

    private static var suite: UserDefaults {
        defaultsOverride ?? UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    private static var pendingSync: Task<Void, Never>?
    private static var cachedLedgerContainer: ModelContainer?

    // MARK: - Snapshot input

    struct LedgerSnapshot: Equatable {
        var transactionCount: Int = 0
        var usedManual: Bool = false
        var usedVoice: Bool = false
        var usedSMS: Bool = false
        var usedPDF: Bool = false
        var usedReceipt: Bool = false
        var usedTypedShortcut: Bool = false
    }

    struct SnapshotInput: Equatable {
        var onboardingDone: Bool
        var ledger: LedgerSnapshot
        var seenExplore: Bool
        var exploreShortcutAdded: Bool
        var seenAnalytics: Bool
        /// `free` / `trial` / `pro` / `lapsed`. Nil omits `sd_plan` (StoreKit unknown).
        var plan: String?
        var trialEndsAt: Date?
        var isPro: Bool
        var quotaVoice: Int
        var quotaSMS: Int
        var quotaReceipt: Int
        var quotaPDF: Int
        var hitQuotaVoice: Bool
        var quotaHitTimestamps: [Date]
        var notifStatus: String
        var now: Date
        var daysSinceInstall: Int
        var appVersion: String
        var iosVersion: String
        var locale: String
    }

    struct TagDiff: Equatable {
        var add: [String: String]
        var remove: [String]
    }

    // MARK: - Snapshot

    /// Pure mapping from local state to OneSignal string tags. No SDK calls.
    static func snapshot(_ input: SnapshotInput) -> [String: String] {
        var tags: [String: String] = [
            Tag.onboardingDone: boolString(input.onboardingDone),
            Tag.hasTransaction: boolString(input.ledger.transactionCount > 0),
            Tag.txCountBucket: txCountBucket(input.ledger.transactionCount),
            Tag.usedManual: boolString(input.ledger.usedManual),
            Tag.usedVoice: boolString(input.ledger.usedVoice),
            Tag.usedSMS: boolString(input.ledger.usedSMS),
            Tag.usedPDF: boolString(input.ledger.usedPDF),
            Tag.usedReceipt: boolString(input.ledger.usedReceipt),
            Tag.usedTypedShortcut: boolString(input.ledger.usedTypedShortcut),
            Tag.seenExplore: boolString(input.seenExplore),
            Tag.exploreShortcutAdded: boolString(input.exploreShortcutAdded),
            Tag.seenAnalytics: boolString(input.seenAnalytics),
            Tag.quotaVoice: String(input.quotaVoice),
            Tag.quotaSMS: String(input.quotaSMS),
            Tag.quotaReceipt: String(input.quotaReceipt),
            Tag.quotaPDF: String(input.quotaPDF),
            Tag.quotaExhaustedAny: boolString(quotaExhaustedAny(input)),
            Tag.hitQuotaVoice: boolString(input.hitQuotaVoice),
            Tag.quotaHits30d: String(quotaHitCount(timestamps: input.quotaHitTimestamps, now: input.now)),
            Tag.notifStatus: input.notifStatus,
            Tag.lastActiveOn: dayString(input.now),
            Tag.daysSinceInstall: String(max(0, input.daysSinceInstall)),
            Tag.appVersion: input.appVersion,
            Tag.iosVersion: input.iosVersion,
            Tag.locale: input.locale,
        ]

        if let plan = input.plan {
            tags[Tag.plan] = plan
        }
        if let trialEndsAt = input.trialEndsAt, input.plan == "trial" {
            tags[Tag.trialEndsOn] = dayString(trialEndsAt)
        }
        return tags
    }

    static func txCountBucket(_ count: Int) -> String {
        switch count {
        case ...0: "0"
        case 1: "1"
        case 2...5: "2_5"
        case 6...20: "6_20"
        default: "21_plus"
        }
    }

    static func boolString(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func quotaHitCount(timestamps: [Date], now: Date) -> Int {
        min(quotaHitCap, pruneQuotaHits(timestamps, now: now).count)
    }

    static func pruneQuotaHits(_ timestamps: [Date], now: Date) -> [Date] {
        let cutoff = now.addingTimeInterval(-quotaHitWindow)
        return timestamps.filter { $0 >= cutoff }
    }

    static func isHitQuotaVoiceSticky(storedPeriod: String?, currentPeriod: String) -> Bool {
        guard let storedPeriod, !storedPeriod.isEmpty else { return false }
        return storedPeriod == currentPeriod
    }

    static func diff(current: [String: String], last: [String: String]) -> TagDiff {
        var add: [String: String] = [:]
        for (key, value) in current where last[key] != value {
            add[key] = value
        }
        let remove = last.keys.filter { current[$0] == nil }.sorted()
        return TagDiff(add: add, remove: remove)
    }

    // MARK: - Sync

    /// Immediate upload. Used from launch / foreground / permission grant.
    @MainActor
    static func sync() async {
        guard shouldTalkToOneSignal else { return }
        pendingSync?.cancel()
        pendingSync = nil

        let status = await NotificationManager.authorizationStatus()
        let tags = snapshot(liveInput(permissionStatus: NotificationManager.permissionStatusName(status)))
        apply(tags)
    }

    /// Coalesces bursty writes (SMS drain, batch import) into one upload.
    static func scheduleSync() {
        guard shouldTalkToOneSignal else { return }
        pendingSync?.cancel()
        pendingSync = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            pendingSync = nil
            await sync()
        }
    }

    // MARK: - Local flags (App Group)

    static func markSeenExplore() {
        guard !suite.bool(forKey: StoreKey.seenExplore) else { return }
        suite.set(true, forKey: StoreKey.seenExplore)
        scheduleSync()
    }

    static func markExploreShortcutAdded() {
        guard !suite.bool(forKey: StoreKey.exploreShortcutAdded) else { return }
        suite.set(true, forKey: StoreKey.exploreShortcutAdded)
        scheduleSync()
    }

    static func markSeenAnalytics() {
        guard !suite.bool(forKey: StoreKey.seenAnalytics) else { return }
        suite.set(true, forKey: StoreKey.seenAnalytics)
        scheduleSync()
    }

    /// Called from the main-app typed-shortcut intent. Does not talk to OneSignal.
    static func recordTypedShortcutSuccess() {
        recordTypedShortcutSuccess(in: suite)
    }

    /// Shared with the widget target via identical App Group keys.
    static func recordTypedShortcutSuccess(in defaults: UserDefaults) {
        defaults.set(true, forKey: StoreKey.hasTransaction)
        defaults.set(true, forKey: StoreKey.usedTypedShortcut)
        defaults.set(defaults.integer(forKey: StoreKey.txCount) + 1, forKey: StoreKey.txCount)
    }

    static func recordQuotaHit(feature: ProFeature, now: Date = Date()) {
        var timestamps = storedQuotaHitTimestamps()
        timestamps.append(now)
        timestamps = pruneQuotaHits(timestamps, now: now)
        storeQuotaHitTimestamps(timestamps)

        if feature == .voice {
            suite.set(AIQuotaStore.period(for: now), forKey: StoreKey.hitQuotaVoicePeriod)
        }
        scheduleSync()
    }

    // MARK: - Live gather

    @MainActor
    static func liveInput(permissionStatus: String, now: Date = Date()) -> SnapshotInput {
        let entitlement = ProEntitlement.shared
        let plan: String?
        let isPro: Bool
        var trialEndsAt: Date?
        switch entitlement.status {
        case .unknown:
            plan = nil
            isPro = ProEntitlementCache.isPro
        case .free:
            plan = "free"
            isPro = false
        case .trial(let endsAt):
            plan = "trial"
            isPro = true
            trialEndsAt = endsAt
        case .subscribed:
            plan = "pro"
            isPro = true
        case .lapsed:
            plan = "lapsed"
            isPro = false
        }

        let currentPeriod = AIQuotaStore.period(for: now)
        let storedVoicePeriod = suite.string(forKey: StoreKey.hitQuotaVoicePeriod)
        if !isHitQuotaVoiceSticky(storedPeriod: storedVoicePeriod, currentPeriod: currentPeriod) {
            suite.removeObject(forKey: StoreKey.hitQuotaVoicePeriod)
        }

        return SnapshotInput(
            onboardingDone: UserDefaults.standard.integer(forKey: onboardingVersionKey)
                >= OnboardingCarouselView.currentVersion,
            ledger: loadLedgerSnapshot(),
            seenExplore: suite.bool(forKey: StoreKey.seenExplore),
            exploreShortcutAdded: suite.bool(forKey: StoreKey.exploreShortcutAdded),
            seenAnalytics: suite.bool(forKey: StoreKey.seenAnalytics),
            plan: plan,
            trialEndsAt: trialEndsAt,
            isPro: isPro,
            quotaVoice: AIQuotaStore.remaining(.voice, now: now),
            quotaSMS: AIQuotaStore.remaining(.messageImport, now: now),
            quotaReceipt: AIQuotaStore.remaining(.receiptScan, now: now),
            quotaPDF: AIQuotaStore.remaining(.statementImport, now: now),
            hitQuotaVoice: isHitQuotaVoiceSticky(
                storedPeriod: suite.string(forKey: StoreKey.hitQuotaVoicePeriod),
                currentPeriod: currentPeriod
            ),
            quotaHitTimestamps: pruneAndPersistQuotaHits(now: now),
            notifStatus: permissionStatus,
            now: now,
            daysSinceInstall: Analytics.daysSinceInstall,
            appVersion: AppInfo.marketingVersion,
            iosVersion: UIDevice.current.systemVersion,
            locale: Locale.current.identifier
        )
    }

    // MARK: - Private

    private static var shouldTalkToOneSignal: Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return false }
        return PushNotifications.isConfigured
    }

    private static func quotaExhaustedAny(_ input: SnapshotInput) -> Bool {
        guard !input.isPro else { return false }
        return input.quotaVoice == 0
            || input.quotaSMS == 0
            || input.quotaReceipt == 0
            || input.quotaPDF == 0
    }

    private static func apply(_ tags: [String: String]) {
        let last = storedLastSent()
        let change = diff(current: tags, last: last)
        guard !change.add.isEmpty || !change.remove.isEmpty else { return }

        if !change.add.isEmpty {
            OneSignal.User.addTags(change.add)
        }
        if !change.remove.isEmpty {
            OneSignal.User.removeTags(change.remove)
        }
        storeLastSent(tags)
    }

    private static func loadLedgerSnapshot() -> LedgerSnapshot {
        do {
            let context = try ledgerContext()
            let count = try context.fetchCount(FetchDescriptor<Transaction>())
            var snapshot = LedgerSnapshot(
                transactionCount: count,
                usedManual: exists(.manual, in: context),
                usedVoice: exists(.voice, in: context),
                usedSMS: exists(.sms, in: context),
                usedPDF: exists(.pdf, in: context),
                usedReceipt: exists(.receipt, in: context),
                usedTypedShortcut: exists(.shortcut, in: context)
            )
            // Typed-shortcut intents save the row and a flag. Trust SwiftData when
            // the fetch works; OR the flag so a flush race cannot drop the source.
            if suite.bool(forKey: StoreKey.usedTypedShortcut) {
                snapshot.usedTypedShortcut = true
            }
            suite.set(snapshot.transactionCount > 0, forKey: StoreKey.hasTransaction)
            suite.set(snapshot.usedTypedShortcut, forKey: StoreKey.usedTypedShortcut)
            suite.set(snapshot.transactionCount, forKey: StoreKey.txCount)
            return snapshot
        } catch {
            Diagnostics.log(
                "Audience tag ledger fetch failed",
                level: .warning,
                tags: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.notifications.rawValue,
                    Diagnostics.Tag.stage: Diagnostics.Stage.bootstrap.rawValue,
                    Diagnostics.Tag.errorDomain: (error as NSError).domain,
                    Diagnostics.Tag.errorCode: String((error as NSError).code),
                ]
            )
            let cachedCount = suite.integer(forKey: StoreKey.txCount)
            let cachedHas = suite.bool(forKey: StoreKey.hasTransaction)
            return LedgerSnapshot(
                transactionCount: max(cachedCount, cachedHas ? 1 : 0),
                usedTypedShortcut: suite.bool(forKey: StoreKey.usedTypedShortcut)
            )
        }
    }

    private static func exists(_ source: TransactionSource, in context: ModelContext) -> Bool {
        let raw = source.rawValue
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.source == raw
            }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }

    private static func ledgerContext() throws -> ModelContext {
        if let cachedLedgerContainer {
            return ModelContext(cachedLedgerContainer)
        }
        let container = try IntentSwiftData.makeModelContainer()
        cachedLedgerContainer = container
        return ModelContext(container)
    }

    private static func storedLastSent() -> [String: String] {
        guard let data = suite.data(forKey: StoreKey.lastSent),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func storeLastSent(_ tags: [String: String]) {
        if let data = try? JSONEncoder().encode(tags) {
            suite.set(data, forKey: StoreKey.lastSent)
        }
    }

    private static func storedQuotaHitTimestamps() -> [Date] {
        guard let data = suite.data(forKey: StoreKey.quotaHitTimestamps),
              let values = try? JSONDecoder().decode([TimeInterval].self, from: data)
        else { return [] }
        return values.map { Date(timeIntervalSince1970: $0) }
    }

    private static func storeQuotaHitTimestamps(_ dates: [Date]) {
        let values = dates.map { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(values) {
            suite.set(data, forKey: StoreKey.quotaHitTimestamps)
        }
    }

    private static func pruneAndPersistQuotaHits(now: Date) -> [Date] {
        let pruned = pruneQuotaHits(storedQuotaHitTimestamps(), now: now)
        storeQuotaHitTimestamps(pruned)
        return pruned
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
