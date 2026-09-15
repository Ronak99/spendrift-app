//
//  ProGate.swift
//  Spendrift
//
//  The single decision point for "may this AI call happen, and should we pitch Pro
//  afterwards?". Feature code asks `evaluate` before spending a backend call and
//  calls `recordSuccess` after one lands.
//
//  Deliberately free of SwiftUI and of actor isolation: voice runs from an App
//  Intent and SMS drains from a Shortcuts automation, so both entry points must be
//  able to reach this from a background process.
//

import Foundation

extension Notification.Name {
    /// Posted after the first successful use of a `ProFeature`, so the root view can
    /// surface the celebration paywall. `userInfo[ProGate.featureUserInfoKey]` holds
    /// the feature's raw value.
    static let proMomentReached = Notification.Name("Spendrift.proMomentReached")

    /// Posted when a feature was refused because its free monthly quota is spent.
    /// Same `userInfo` shape as `proMomentReached`.
    static let proQuotaExhausted = Notification.Name("Spendrift.proQuotaExhausted")

    /// The notification opt-in alert appeared / went away. The paywall listens so it
    /// can queue behind the alert instead of swallowing it.
    static let reminderOptInShown = Notification.Name("Spendrift.reminderOptInShown")
    static let reminderOptInDismissed = Notification.Name("Spendrift.reminderOptInDismissed")
}

enum ProGate {
    static let featureUserInfoKey = "feature"

    enum Decision: Equatable {
        /// Subscriber — no counting, no pitching.
        case unlimited
        /// Free tier with credits left this month.
        case allowed(remaining: Int)
        /// Free tier, quota exhausted. Caller must not spend a backend call.
        case blocked(ProFeature)

        var isAllowed: Bool {
            if case .blocked = self { return false }
            return true
        }
    }

    /// Test seam — see `AIQuotaStore.defaultsOverride`.
    static var defaultsOverride: UserDefaults?

    private static var suite: UserDefaults {
        defaultsOverride ?? UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    private static func pitchedKey(_ feature: ProFeature) -> String {
        "didShowProMoment.\(feature.rawValue)"
    }

    // MARK: - Gate

    static func evaluate(_ feature: ProFeature) -> Decision {
        guard !ProEntitlementCache.isPro else { return .unlimited }
        let remaining = AIQuotaStore.remaining(feature)
        return remaining > 0 ? .allowed(remaining: remaining) : .blocked(feature)
    }

    static func isAllowed(_ feature: ProFeature) -> Bool {
        evaluate(feature).isAllowed
    }

    // MARK: - Success

    /// Records backend calls that actually returned. Quota tracks spend, so this is
    /// keyed to "the AI answered", not to "the user got a perfect transaction" — a
    /// parse that lands in the manual-review sheet still cost money. Calls that fail
    /// outright never reach here, so a bad recording or an unreadable PDF is free.
    ///
    /// `count` covers batch results: a statement or an SMS drain is one call per row.
    static func recordUsage(_ feature: ProFeature, count: Int = 1) {
        guard !ProEntitlementCache.isPro else { return }
        AIQuotaStore.consume(feature, count: count)
    }

    /// Broadcasts the celebration paywall on the first user-visible win for this
    /// feature — a transaction actually created, not merely parsed. Fires at most once
    /// per feature, ever.
    ///
    /// Not used for SMS import: that drains headlessly from a Shortcuts automation, so
    /// its pitch rides on `MessageInboxImportBannerView` instead of a modal.
    static func announceMomentIfNeeded(_ feature: ProFeature) {
        guard !ProEntitlementCache.isPro, shouldPitch(feature) else { return }
        markPitched(feature)
        NotificationCenter.default.post(
            name: .proMomentReached,
            object: nil,
            userInfo: [featureUserInfoKey: feature.rawValue]
        )
    }

    /// Convenience for flows where the call and the win are the same moment.
    static func recordSuccess(_ feature: ProFeature, count: Int = 1) {
        recordUsage(feature, count: count)
        announceMomentIfNeeded(feature)
    }

    /// Call when a feature is refused. Records the block and asks the UI to surface
    /// the quota paywall.
    ///
    /// SMS import is deliberately excluded from the broadcast: it drains from a
    /// Shortcuts automation with no app in the foreground, so a modal would either be
    /// lost or ambush the user later. `MessageInboxImportBannerView` reports that case
    /// in place.
    static func reportBlocked(_ feature: ProFeature, announce: Bool = true) {
        Analytics.capturePro(.proFeatureBlocked, [
            Analytics.Key.feature: feature.rawValue
        ])
        Analytics.capturePro(.quotaExhausted, [
            Analytics.Key.feature: feature.rawValue
        ])
        AudienceTags.recordQuotaHit(feature: feature)
        guard announce else { return }
        NotificationCenter.default.post(
            name: .proQuotaExhausted,
            object: nil,
            userInfo: [featureUserInfoKey: feature.rawValue]
        )
    }

    // MARK: - Pitch bookkeeping

    /// One celebration per feature, ever — at most four in the app's lifetime.
    static func shouldPitch(_ feature: ProFeature) -> Bool {
        !suite.bool(forKey: pitchedKey(feature))
    }

    static func markPitched(_ feature: ProFeature) {
        suite.set(true, forKey: pitchedKey(feature))
    }

    /// Test and developer-menu affordance.
    static func resetPitches() {
        for feature in ProFeature.allCases {
            suite.removeObject(forKey: pitchedKey(feature))
        }
    }
}
