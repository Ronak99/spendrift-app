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

    /// Posted when the host app is opened via `spendrift://importReceipt` (Share Extension handoff).
    static let receiptShareImportTriggered = Notification.Name("Spendrift.receiptShareImportTriggered")

    /// Posted when the already-selected Home tab is tapped again, so the home screen can
    /// collapse the analytics view back to the transactions list (see `TransactionsView`).
    static let homeTabReselected = Notification.Name("Spendrift.homeTabReselected")
}
