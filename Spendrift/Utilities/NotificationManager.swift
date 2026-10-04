//
//  NotificationManager.swift
//  Spendrift
//
//  Opt-in local notifications. No backend or push entitlement required -
//  everything is scheduled on-device via UNUserNotificationCenter. Taps deep-link
//  into the existing flows through the registered `spendrift://` URL scheme.
//
//  Daily "log today's spending" reminders are no longer scheduled. `cancelDailySpendReminders`
//  clears any that an older build already queued.
//
//  Remote campaigns go through OneSignal. This type only owns on-device requests.
//

import Foundation
import UserNotifications

enum NotificationManager {
    /// AppStorage-mirrored defaults keys for the user's reminder preferences.
    enum Keys {
        static let dailyReminderHour = "dailyReminderHour"
        static let dailyReminderMinute = "dailyReminderMinute"
    }

    /// Clock time used by the monthly statement reminder.
    static let defaultHour = 18
    static let defaultMinute = 39

    /// Stable identifiers so rescheduling is idempotent.
    private enum RequestID {
        static let typePrefix = "spendrift.reminder.type."
        static let voicePrefix = "spendrift.reminder.voice."
        static let monthlyStatement = "spendrift.reminder.statement.monthly"
        static let quotaRefill = "spendrift.quota.refill.monthly"
    }

    private static let typeWeekdays = [1, 2, 4, 6]   // Sun, Mon, Wed, Fri
    private static let voiceWeekdays = [3, 5, 7]     // Tue, Thu, Sat

    /// Keys stamped into a scheduled notification's `userInfo`. `kind` is what lets
    /// a tap name the notification that fired it rather than inferring it from the
    /// deep link, which several requests don't carry at all.
    enum UserInfoKey {
        static let deeplink = "deeplink"
        static let kind = "kind"
    }

    /// Deep-link destinations carried in each notification's `userInfo`.
    private enum DeepLink {
        static let importStatement = "spendrift://importStatement"
    }

    private static var dailySpendReminderIdentifiers: [String] {
        typeWeekdays.map { RequestID.typePrefix + String($0) }
            + voiceWeekdays.map { RequestID.voicePrefix + String($0) }
    }

    private static var reminderIdentifiers: [String] {
        dailySpendReminderIdentifiers + [RequestID.monthlyStatement]
    }

    // MARK: - Tap attribution

    /// The deep link a tapped notification should open, if it carries one.
    static func deeplink(userInfo: [AnyHashable: Any]) -> URL? {
        guard let link = userInfo[UserInfoKey.deeplink] as? String else { return nil }
        return URL(string: link)
    }

    /// Names the notification that was tapped. Requests scheduled by a build older
    /// than the `kind` stamp are still pending on device, so fall back to the deep
    /// link's host and then to `unknown` rather than dropping the open entirely.
    static func openKind(userInfo: [AnyHashable: Any]) -> String {
        if let kind = userInfo[UserInfoKey.kind] as? String, !kind.isEmpty {
            return kind
        }
        if let host = deeplink(userInfo: userInfo)?.host, !host.isEmpty {
            return host
        }
        return "unknown"
    }

    // MARK: - Permission

    /// Requests notification authorization and reports the outcome to analytics.
    /// Returns whether permission is granted.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        Analytics.capture(.notificationPermissionRequested)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        Analytics.capture(.notificationPermissionGranted, [Analytics.Key.granted: granted])
        return granted
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func permissionStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not_determined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "not_determined"
        }
    }

    static func isPermissionGranted(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    // MARK: - Scheduling

    /// Drops the retired daily spend reminders ("Log today's spending" /
    /// "Speak today's spending"), including any already sitting in Notification Center.
    /// Safe to call on every launch.
    static func cancelDailySpendReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: dailySpendReminderIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: dailySpendReminderIdentifiers)
    }

    /// Clears Spendrift spend reminders and, when `enabled`, reschedules the monthly
    /// bank-statement nudge at the user's chosen `hour`/`minute`.
    ///
    /// Daily spend nags are always removed and never put back.
    ///
    /// Only removes identifiers this function owns. A blanket
    /// `removeAllPendingNotificationRequests()` would also wipe the Pro trial
    /// reminder and the monthly quota-refill notification.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: dailySpendReminderIdentifiers)

        guard enabled else { return }

        scheduleMonthlyStatement(hour: hour, minute: minute)
    }

    /// Schedules a repeating 1st-of-month refill ping for free-tier users who have
    /// notification permission. Subscribers have no quota to refill.
    static func refreshQuotaRefillReminder() {
        Task {
            let granted = isPermissionGranted(await authorizationStatus())
            guard granted, !ProEntitlementCache.isPro else {
                cancelQuotaRefill()
                return
            }
            scheduleQuotaRefill()
        }
    }

    static func cancelQuotaRefill() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [RequestID.quotaRefill])
    }

    private static func scheduleQuotaRefill() {
        var components = DateComponents()
        components.day = 1
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        add(
            identifier: RequestID.quotaRefill,
            title: "Premium Refilled",
            body: "Your 10 voice notes are ready for the month. Let's track!",
            deeplink: nil,
            kind: "quota_refill",
            trigger: trigger
        )
    }

    private static func scheduleMonthlyStatement(hour: Int, minute: Int) {
        // Second day of every month - early enough that the prior month is fully
        // settled, prompting a statement upload for a complete summary.
        var components = DateComponents()
        components.day = 2
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        add(
            identifier: RequestID.monthlyStatement,
            title: "Get last month's full picture",
            body: "Upload your bank statement to capture every transaction from the month.",
            deeplink: DeepLink.importStatement,
            kind: "statement",
            trigger: trigger
        )
    }

    private static func add(
        identifier: String,
        title: String,
        body: String,
        deeplink: String?,
        kind: String,
        trigger: UNNotificationTrigger
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var userInfo: [AnyHashable: Any] = [UserInfoKey.kind: kind]
        if let deeplink {
            userInfo[UserInfoKey.deeplink] = deeplink
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            Analytics.capture(.notificationScheduled, [Analytics.Key.kind: kind])
        }
    }
}
