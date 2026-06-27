//
//  NotificationManager.swift
//  Spendrift
//
//  Opt-in local notifications that nudge users to log their spending. No backend
//  or push entitlement required — everything is scheduled on-device via
//  UNUserNotificationCenter. Taps deep-link into the existing quick-add flows
//  through the registered `spendrift://` URL scheme.
//

import Foundation
import UserNotifications

enum NotificationManager {
    /// AppStorage-mirrored defaults keys for the user's reminder preferences.
    enum Keys {
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
        static let dailyReminderMinute = "dailyReminderMinute"
    }

    /// Default reminder time (evening) when the user first opts in.
    static let defaultHour = 20
    static let defaultMinute = 0

    /// Stable identifiers so rescheduling is idempotent.
    private enum RequestID {
        static let typePrefix = "spendrift.reminder.type."
        static let voicePrefix = "spendrift.reminder.voice."
        static let monthlyStatement = "spendrift.reminder.statement.monthly"
    }

    /// Deep-link destinations carried in each notification's `userInfo`.
    private enum DeepLink {
        static let key = "deeplink"
        static let createTransaction = "spendrift://createTransaction"
        static let voiceExpense = "spendrift://voiceExpense"
        static let importStatement = "spendrift://importStatement"
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

    // MARK: - Scheduling

    /// Clears all Spendrift reminders and, when `enabled`, reschedules the daily
    /// spend reminders (alternating type/voice across weekdays) plus the monthly
    /// bank-statement nudge, all at the user's chosen `hour`/`minute`.
    static func reschedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard enabled else { return }

        // Type-expense reminder on Sun/Mon/Wed/Fri; voice-expense on Tue/Thu/Sat.
        // Alternating keeps both required flavors in rotation without firing two
        // notifications on the same day.
        let typeWeekdays = [1, 2, 4, 6]   // Sun, Mon, Wed, Fri
        let voiceWeekdays = [3, 5, 7]     // Tue, Thu, Sat

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
                body: "Tap and say what you spent — Spendrift handles the rest.",
                deeplink: DeepLink.voiceExpense,
                kind: "voice"
            )
        }

        scheduleMonthlyStatement(hour: hour, minute: minute)
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
        // Second day of every month — early enough that the prior month is fully
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
        deeplink: String,
        kind: String,
        trigger: UNNotificationTrigger
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [DeepLink.key: deeplink]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            Analytics.capture(.notificationScheduled, [Analytics.Key.kind: kind])
        }
    }
}
