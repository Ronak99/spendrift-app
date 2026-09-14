//
//  NotificationManager.swift
//  Spendrift
//
//  Opt-in local notifications that nudge users to log their spending. No backend
//  or push entitlement required - everything is scheduled on-device via
//  UNUserNotificationCenter. Taps deep-link into the existing quick-add flows
//  through the registered `spendrift://` URL scheme.
//
//  Remote campaigns go through OneSignal. This type only owns on-device requests.
//

import Foundation
import UserNotifications

enum NotificationManager {
    /// AppStorage-mirrored defaults keys for the user's reminder preferences.
    enum Keys {
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
        static let dailyReminderMinute = "dailyReminderMinute"
        static let dailyReminderTimeInterval = "dailyReminderTimeInterval"
    }

    /// Default reminder time (evening) when the user first opts in.
    static let defaultHour = 18
    static let defaultMinute = 39

    static var defaultReminderDate: Date {
        Calendar.current.date(
            from: DateComponents(hour: defaultHour, minute: defaultMinute)
        ) ?? Date()
    }

    static var defaultReminderTimeInterval: Double {
        defaultReminderDate.timeIntervalSince1970
    }

    /// Stable identifiers so rescheduling is idempotent.
    private enum RequestID {
        static let typePrefix = "spendrift.reminder.type."
        static let voicePrefix = "spendrift.reminder.voice."
        static let monthlyStatement = "spendrift.reminder.statement.monthly"
        static let quotaRefill = "spendrift.quota.refill.monthly"
    }

    private static let typeWeekdays = [1, 2, 4, 6]   // Sun, Mon, Wed, Fri
    private static let voiceWeekdays = [3, 5, 7]     // Tue, Thu, Sat

    /// Deep-link destinations carried in each notification's `userInfo`.
    private enum DeepLink {
        static let key = "deeplink"
        static let createTransaction = "spendrift://createTransaction"
        static let voiceExpense = "spendrift://voiceExpense"
        static let importStatement = "spendrift://importStatement"
    }

    private static var reminderIdentifiers: [String] {
        typeWeekdays.map { RequestID.typePrefix + String($0) }
            + voiceWeekdays.map { RequestID.voicePrefix + String($0) }
            + [RequestID.monthlyStatement]
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

    /// Clears Spendrift spend reminders and, when `enabled`, reschedules the daily
    /// spend reminders (alternating type/voice across weekdays) plus the monthly
    /// bank-statement nudge, all at the user's chosen `hour`/`minute`.
    ///
    /// Only removes identifiers this function owns. A blanket
    /// `removeAllPendingNotificationRequests()` would also wipe the Pro trial
    /// reminder and the monthly quota-refill notification.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)

        guard enabled else { return }

        for weekday in typeWeekdays {
            scheduleWeekly(
                identifier: RequestID.typePrefix + String(weekday),
                weekday: weekday,
                hour: hour,
                minute: minute,
                title: "Log today's spending",
                body: "Tap to quickly add an expense before the day's done.",
                deeplink: DeepLink.createTransaction,
                kind: "type"
            )
        }

        for weekday in voiceWeekdays {
            scheduleWeekly(
                identifier: RequestID.voicePrefix + String(weekday),
                weekday: weekday,
                hour: hour,
                minute: minute,
                title: "Speak today's spending",
                body: "Tap and say what you spent - Spendrift handles the rest.",
                deeplink: DeepLink.voiceExpense,
                kind: "voice"
            )
        }

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
            title: "Your free AI credits are back",
            body: "Voice notes, receipts, and a bank statement parse just refilled for the month.",
            deeplink: nil,
            kind: "quota_refill",
            trigger: trigger
        )
    }

    private static func scheduleWeekly(
        identifier: String,
        weekday: Int,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        deeplink: String,
        kind: String
    ) {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        add(identifier: identifier, title: title, body: body, deeplink: deeplink, kind: kind, trigger: trigger)
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
        if let deeplink {
            content.userInfo = [DeepLink.key: deeplink]
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            Analytics.capture(.notificationScheduled, [Analytics.Key.kind: kind])
        }
    }
}
