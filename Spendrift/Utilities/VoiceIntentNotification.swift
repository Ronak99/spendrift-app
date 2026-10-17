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

    /// Posted by the `spendrift://createTransaction` quick action so the Home shell can
    /// open the create sheet wherever it is.
    static let createTransactionRequested = Notification.Name("Spendrift.createTransactionRequested")

    /// Posted when a push or widget route resolves to Settings, so the Home shell can
    /// present it over whatever pane is visible.
    static let settingsRequested = Notification.Name("Spendrift.settingsRequested")

    /// Posted by the `spendrift://importStatement` quick action, once the Pro gate passed.
    static let statementImportRequested = Notification.Name("Spendrift.statementImportRequested")
}
