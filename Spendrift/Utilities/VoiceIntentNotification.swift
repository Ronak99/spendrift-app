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
}
