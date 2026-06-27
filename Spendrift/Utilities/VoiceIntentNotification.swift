//
//  VoiceIntentNotification.swift
//  Spendrift
//
//  Created by Cursor on 28/03/26.
//

import Foundation

extension Notification.Name {
    /// Posted when `VoiceExpenseIntent` (or related shortcuts) run so the UI can react while already foregrounded.
    static let voiceExpenseIntentTriggered = Notification.Name("Spendrift.voiceExpenseIntentTriggered")

    /// Posted the first time a transaction is ever created, so the UI can offer a
    /// contextual notification opt-in (see `NotificationManager`).
    static let firstTransactionCreated = Notification.Name("Spendrift.firstTransactionCreated")
}
