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
//  Every free user gets the full monthly allowance from the first month this store
//  sees them. Notification permission does not change the quota.
//

import Foundation

enum AIQuotaStore {
    private static let periodKey = "aiQuota.period"

    /// Test seam. Production always resolves to the shared App Group suite; tests
    /// point this at a throwaway suite so they never disturb real usage counts.
    static var defaultsOverride: UserDefaults?

    private static var suite: UserDefaults {
        defaultsOverride ?? UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    private static func usageKey(_ feature: ProFeature) -> String {
        "aiQuota.\(feature.rawValue)"
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

    /// Zeroes every monthly counter when the stored period is stale. Called on each
    /// read and write, so a month rollover is picked up without any scheduled work.
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

    /// Free uses available this month. The full allowance is there from the first
    /// launch; permission never gates it.
    static func monthlyAllowance(_ feature: ProFeature, now: Date = Date()) -> Int {
        rolloverIfNeeded(now: now)
        return feature.monthlyFreeQuota
    }

    static func remaining(_ feature: ProFeature, now: Date = Date()) -> Int {
        max(0, monthlyAllowance(feature, now: now) - used(feature, now: now))
    }

    static func hasQuota(_ feature: ProFeature, now: Date = Date()) -> Bool {
        remaining(feature, now: now) > 0
    }

    // MARK: - Write

    /// Records `count` successful uses. A batch import that overshoots the remaining
    /// credits cannot push stored usage past this month's allowance.
    static func consume(_ feature: ProFeature, count: Int = 1, now: Date = Date()) {
        guard count > 0 else { return }
        rolloverIfNeeded(now: now)

        let monthlyUsed = suite.integer(forKey: usageKey(feature))
        let allowance = monthlyAllowance(feature, now: now)
        suite.set(min(allowance, monthlyUsed + count), forKey: usageKey(feature))
        AudienceTags.scheduleSync()
    }

    /// Test and developer-menu affordance.
    static func resetAll() {
        for feature in ProFeature.allCases {
            suite.removeObject(forKey: usageKey(feature))
        }
        suite.set(period(), forKey: periodKey)
    }
}
