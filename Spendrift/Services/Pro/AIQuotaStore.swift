//
//  AIQuotaStore.swift
//  Spendrift
//
//  Per-feature monthly counters for the free tier.
//
//  Storage is the App Group suite, not `UserDefaults.standard`: voice capture runs
//  from `VoiceExpenseIntent` and SMS capture runs from a Shortcuts automation, both
//  in processes other than the host app. A counter in `.standard` would be invisible
//  to them and the quota would silently never apply.
//
//  Counters are incremented only after a *successful* parse, so a failed voice note
//  or an unreadable PDF never costs the user a credit.
//
//  Bonus credits (the notification opt-in reward) live beside the monthly counters
//  and are not cleared on month rollover.
//

import Foundation

enum AIQuotaStore {
    private static let periodKey = "aiQuota.period"
    private static let rewardGrantedKey = "aiQuota.notificationRewardGranted"

    /// Test seam. Production always resolves to the shared App Group suite; tests
    /// point this at a throwaway suite so they never disturb real usage counts.
    static var defaultsOverride: UserDefaults?

    private static var suite: UserDefaults {
        defaultsOverride ?? UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    private static func usageKey(_ feature: ProFeature) -> String {
        "aiQuota.\(feature.rawValue)"
    }

    private static func bonusKey(_ feature: ProFeature) -> String {
        "aiQuota.bonus.\(feature.rawValue)"
    }

    // MARK: - Period

    /// Calendar-month bucket, e.g. "2026-09". Uses the user's current calendar so the
    /// reset lines up with the month boundary they see in the app's month navigator.
    static func period(for date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    /// First instant of next month - the moment quotas refill.
    static func nextResetDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        return calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? date
    }

    /// Zeroes every monthly counter when the stored period is stale. Bonus credits
    /// are a one-time reward and are left alone. Called on each read and write, so
    /// a month rollover is picked up without any scheduled work.
    private static func rolloverIfNeeded(now: Date = Date()) {
        let current = period(for: now)
        guard suite.string(forKey: periodKey) != current else { return }
        for feature in ProFeature.allCases {
            suite.removeObject(forKey: usageKey(feature))
        }
        suite.set(current, forKey: periodKey)
    }

    // MARK: - Read

    static func used(_ feature: ProFeature, now: Date = Date()) -> Int {
        rolloverIfNeeded(now: now)
        return suite.integer(forKey: usageKey(feature))
    }

    static func bonus(_ feature: ProFeature) -> Int {
        max(0, suite.integer(forKey: bonusKey(feature)))
    }

    static func remaining(_ feature: ProFeature, now: Date = Date()) -> Int {
        max(0, feature.monthlyFreeQuota - used(feature, now: now)) + bonus(feature)
    }

    static func hasQuota(_ feature: ProFeature, now: Date = Date()) -> Bool {
        remaining(feature, now: now) > 0
    }

    static var didGrantNotificationReward: Bool {
        suite.bool(forKey: rewardGrantedKey)
    }

    // MARK: - Write

    /// Records `count` successful uses. Spends the free monthly allowance first
    /// and only drains bonus credits on overflow, so the reward lasts as long as
    /// possible. A batch import that overshoots remaining credits (monthly plus
    /// bonus) cannot push stored usage past the monthly quota.
    static func consume(_ feature: ProFeature, count: Int = 1, now: Date = Date()) {
        guard count > 0 else { return }
        rolloverIfNeeded(now: now)

        let monthlyUsed = suite.integer(forKey: usageKey(feature))
        let freeRemaining = max(0, feature.monthlyFreeQuota - monthlyUsed)
        let fromFree = min(count, freeRemaining)
        let overflow = count - fromFree

        suite.set(monthlyUsed + fromFree, forKey: usageKey(feature))
        if overflow > 0 {
            let leftoverBonus = max(0, bonus(feature) - overflow)
            suite.set(leftoverBonus, forKey: bonusKey(feature))
        }
        AudienceTags.scheduleSync()
    }

    /// Grants one extra month of the free-tier credits for voice, receipts, and
    /// statements. Idempotent within an install; reinstall re-grants by design.
    @discardableResult
    static func grantNotificationRewardIfNeeded() -> Bool {
        guard !didGrantNotificationReward else { return false }
        for feature in ProFeature.allCases {
            let extra = feature.notificationRewardBonus
            guard extra > 0 else { continue }
            suite.set(bonus(feature) + extra, forKey: bonusKey(feature))
        }
        suite.set(true, forKey: rewardGrantedKey)
        return true
    }

    /// Test and developer-menu affordance.
    static func resetAll() {
        for feature in ProFeature.allCases {
            suite.removeObject(forKey: usageKey(feature))
            suite.removeObject(forKey: bonusKey(feature))
        }
        suite.set(period(), forKey: periodKey)
        suite.removeObject(forKey: rewardGrantedKey)
    }
}
