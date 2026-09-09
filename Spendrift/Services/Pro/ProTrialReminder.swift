//
//  ProTrialReminder.swift
//  Spendrift
//
//  A single local notification two days before the 7-day trial converts.
//
//  This exists as much for trust as for revenue: a surprise charge is the fastest
//  route to a one-star review, and Spendrift has no rating cushion to absorb those.
//  Reminding people also measurably improves trial retention rather than hurting it.
//
//  The copy carries a recap of what Pro actually did during the trial, so the
//  reminder reads as evidence rather than as a billing warning. Local notifications
//  cannot compute anything at fire time, so `refresh` is called while the app is
//  open to re-stamp the request with an up-to-date count.
//

import Foundation
import UserNotifications

enum ProTrialReminder {
    private static let requestID = "spendrift.pro.trialEnding"
    /// Days before expiry that the reminder fires. Two leaves a full day to decide.
    private static let leadDays = 2

    /// Schedules (or re-schedules) the reminder. Idempotent — the stable identifier
    /// means repeated calls replace rather than stack.
    static func scheduleIfNeeded(trialEndsAt: Date?, aiTransactionCount: Int = 0) {
        guard let trialEndsAt else { return }

        let calendar = Calendar.current
        guard let fireDate = calendar.date(byAdding: .day, value: -leadDays, to: trialEndsAt),
              fireDate > Date() else {
            // Trial is already inside the lead window (or over); a notification now
            // would be noise rather than notice.
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your Pro trial ends in \(leadDays) days"
        content.body = body(aiTransactionCount: aiTransactionCount)
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            Analytics.capture(.notificationScheduled, [Analytics.Key.kind: "trial_ending"])
        }
    }

    /// Re-stamps the pending reminder with a fresh usage count. Safe to call often.
    static func refresh(trialEndsAt: Date?, aiTransactionCount: Int) {
        guard trialEndsAt != nil else {
            cancel()
            return
        }
        scheduleIfNeeded(trialEndsAt: trialEndsAt, aiTransactionCount: aiTransactionCount)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestID])
    }

    private static func body(aiTransactionCount: Int) -> String {
        guard aiTransactionCount > 0 else {
            return "Voice capture, SMS import, statement import and receipt scan stay unlimited if you keep Pro."
        }
        let noun = aiTransactionCount == 1 ? "transaction" : "transactions"
        return "Spendrift Pro logged \(aiTransactionCount) \(noun) for you so far. Keep it to stay unlimited."
    }
}
