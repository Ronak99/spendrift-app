//
//  MessageInboxDebugLog.swift
//  Spendrift
//
//  Capture history for Log Transaction Message.
//  Survives inbox drain so you can confirm the intent stored a body.
//

import Foundation
import SwiftData

enum MessageInboxDebugLog {
    static let pauseDrainKey = "messageInboxDebugPauseDrain"
    private static let entriesKey = "messageInboxDebugLog"
    private static let maxEntries = 200

    enum Outcome: String, Codable {
        case inserted
        case duplicate
        case fallback
        /// OTP / verification message: never stored, so never uploaded.
        case skippedOTP
    }

    enum LedgerOutcome: String, Codable {
        case imported
        case skippedDuplicate
        case rejected
        case failed
    }

    struct Entry: Codable, Identifiable, Equatable {
        let id: UUID
        let body: String
        let fingerprint: String
        let capturedAt: Date
        let outcome: Outcome
        /// Set when parse-transactions drain handles this body.
        var ledgerOutcome: LedgerOutcome?
        var transactionID: UUID?
    }

    struct PendingRow: Identifiable, Equatable {
        let id: UUID
        let body: String
        let capturedAt: Date
        let fingerprint: String
        let attemptCount: Int
        let lastAttemptAt: Date?
    }

    private static var suite: UserDefaults {
        UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    /// When true, launch drain is skipped so pending SwiftData rows stay visible.
    static var isDrainPaused: Bool {
        get { suite.bool(forKey: pauseDrainKey) }
        set { suite.set(newValue, forKey: pauseDrainKey) }
    }

    static func append(
        body: String,
        fingerprint: String,
        capturedAt: Date,
        outcome: Outcome
    ) {
        guard DeveloperMode.isEnabled else { return }
        var items = all()
        items.insert(
            Entry(
                id: UUID(),
                body: body,
                fingerprint: fingerprint,
                capturedAt: capturedAt,
                outcome: outcome,
                ledgerOutcome: nil,
                transactionID: nil
            ),
            at: 0
        )
        if items.count > maxEntries {
            items = Array(items.prefix(maxEntries))
        }
        save(items)
    }

    static func all() -> [Entry] {
        guard let data = suite.data(forKey: entriesKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    static func clear() {
        suite.removeObject(forKey: entriesKey)
    }

    /// Records whether drain turned this SMS body into a ledger row.
    /// Matches by fingerprint so duplicate captures of the same string share the result.
    static func recordLedgerOutcome(
        fingerprint: String,
        capturedAt: Date,
        outcome: LedgerOutcome,
        transactionID: UUID? = nil
    ) {
        guard DeveloperMode.isEnabled else { return }
        var items = all()
        var changed = false
        for index in items.indices where items[index].fingerprint == fingerprint {
            let sameCapture = abs(items[index].capturedAt.timeIntervalSince(capturedAt)) < 2
            let shouldUpdate = sameCapture || items[index].ledgerOutcome == nil || outcome == .imported
            guard shouldUpdate else { continue }
            items[index].ledgerOutcome = outcome
            if let transactionID {
                items[index].transactionID = transactionID
            }
            changed = true
        }
        if changed {
            save(items)
        }
    }

    @MainActor
    static func fetchPendingInbox() -> [PendingRow] {
        guard let container = try? MessageInboxSwiftData.makeModelContainer() else {
            return []
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedTransactionMessage>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { row in
            PendingRow(
                id: row.id,
                body: row.body,
                capturedAt: row.capturedAt,
                fingerprint: row.fingerprint,
                attemptCount: row.attemptCount,
                lastAttemptAt: row.lastAttemptAt
            )
        }
    }

    @MainActor
    static func deletePending(id: UUID) {
        guard let container = try? MessageInboxSwiftData.makeModelContainer() else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedTransactionMessage>()
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows where row.id == id {
            context.delete(row)
        }
        try? context.save()
    }

    static var storePathDescription: String {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IntentSwiftData.appGroupID
        ) {
            return groupURL.appendingPathComponent(MessageInboxSwiftData.storeFileName).path
        }
        return "App Group unavailable; using the default SwiftData container"
    }

    private static func save(_ items: [Entry]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        suite.set(data, forKey: entriesKey)
    }
}
