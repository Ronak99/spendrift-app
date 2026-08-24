//
//  CapturedTransactionMessage.swift
//  Spendrift
//
//  Inbox row for bank SMS captured by Shortcuts while the app is closed.
//  Lives in SpendriftMessages.sqlite (no CloudKit), not the main ledger.
//

import Foundation
import SwiftData

@Model
final class CapturedTransactionMessage {
    var id: UUID = UUID()
    var body: String = ""
    var sender: String = ""
    var capturedAt: Date = Date()
    /// SHA-256 of the normalized body, used for short-window dedupe.
    var fingerprint: String = ""
    var attemptCount: Int = 0
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        body: String,
        sender: String = "",
        capturedAt: Date = Date(),
        fingerprint: String,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.body = body
        self.sender = sender
        self.capturedAt = capturedAt
        self.fingerprint = fingerprint
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
    }
}
