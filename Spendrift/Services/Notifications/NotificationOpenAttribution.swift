//
//  NotificationOpenAttribution.swift
//  Spendrift
//
//  Remembers the notification the user just tapped so the `app_opened` that
//  follows can say the session came from a notification, and which one.
//
//  The tap itself is already logged as `notification_opened` by whichever layer
//  handled it (AppDelegate for local requests, PushNotifications for OneSignal).
//  This type exists only to carry that fact a few milliseconds forward into the
//  launch path, which has no other way of knowing why it was woken.
//

import Foundation

enum NotificationOpenAttribution {
    struct Record: Equatable {
        /// Which notification: the scheduled `kind` for local requests
        /// (`type`, `voice`, `statement`, `quota_refill`, `trial_ending`) or
        /// `push` for a remote campaign.
        let kind: String
        /// The local `UNNotificationRequest` identifier, when there is one.
        let notificationID: String?
        /// The OneSignal campaign name, when there is one.
        let campaign: String?
        let recordedAt: Date
    }

    /// How long a tap stays attributable. iOS does not hand the tap to us and
    /// bring the scene to `.active` in a guaranteed order, so the read side
    /// cannot simply consume the record — a cold start fires `app_opened` twice
    /// (`onAppear` and `scenePhase == .active`) and both should be attributed.
    /// `clear()` on backgrounding is what actually bounds the lifetime; this
    /// window is the backstop for a launch that never reaches `.background`.
    static let window: TimeInterval = 10

    private static var pending: Record?

    /// Called from the notification tap handlers, before the app reaches `.active`.
    static func record(
        kind: String,
        notificationID: String? = nil,
        campaign: String? = nil,
        now: Date = Date()
    ) {
        pending = Record(
            kind: kind,
            notificationID: notificationID,
            campaign: campaign,
            recordedAt: now
        )
    }

    /// The tap responsible for this activation, if it is still recent. Reading
    /// does not clear: a single activation can capture `app_opened` more than once.
    static func current(now: Date = Date()) -> Record? {
        guard let pending, now.timeIntervalSince(pending.recordedAt) <= window else { return nil }
        return pending
    }

    /// Drops the record. Called when the app backgrounds, so the next launch is
    /// not credited to a notification the user tapped during the previous one.
    static func clear() {
        pending = nil
    }
}
