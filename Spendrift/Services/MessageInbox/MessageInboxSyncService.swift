//
//  MessageInboxSyncService.swift
//  Spendrift
//
//  Drains the SMS inbox on app launch: parse via backend AI, insert ledger rows.
//  Inbox rows are deleted only after HTTP 200 from parse-transactions, so a
//  failed parse can still be retried on the next launch. Never logs message bodies.
//

import Foundation
import SwiftData

struct MessageInboxImportBanner: Identifiable, Equatable {
    let id: UUID
    let transactionIDs: [UUID]
    let count: Int

    init(transactionIDs: [UUID]) {
        self.id = UUID()
        self.transactionIDs = transactionIDs
        self.count = transactionIDs.count
    }
}

enum MessageInboxSyncService {
    static let chunkSize = 40

    private static let fallbackISOFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    @MainActor
    static func syncIfNeeded(
        ledgerContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) async -> MessageInboxImportBanner? {
        guard VoiceTransactionCreator.resolvePrimaryAccount(from: accounts) != nil else { return nil }
        guard let client = try? SpendriftBackendClient() else { return nil }

        await mergeFallbackIntoInbox()

        let inboxContainer: ModelContainer
        do {
            inboxContainer = try MessageInboxSwiftData.makeModelContainer()
        } catch {
            Diagnostics.breadcrumb(
                category: .error,
                message: "message_inbox_open_failed",
                data: [Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue]
            )
            return nil
        }

        let inboxContext = ModelContext(inboxContainer)
        let descriptor = FetchDescriptor<CapturedTransactionMessage>(
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )
        let pending: [CapturedTransactionMessage]
        do {
            pending = try inboxContext.fetch(descriptor)
        } catch {
            return nil
        }
        guard !pending.isEmpty else { return nil }

        let existingDescriptor = FetchDescriptor<Transaction>()
        let existing = (try? ledgerContext.fetch(existingDescriptor)) ?? []

        var createdIDs: [UUID] = []
        var createdCount = 0
        var rejectedCount = 0
        var skippedCount = 0

        let chunks = stride(from: 0, to: pending.count, by: chunkSize).map {
            Array(pending[$0..<min($0 + chunkSize, pending.count)])
        }

        for chunk in chunks {
            let requestItems = chunk.map { row in
                MessageParseRequestItem(
                    id: row.id.uuidString,
                    body: String(row.body.prefix(1000)),
                    capturedAtIso: fallbackISOFormatter.string(from: row.capturedAt)
                )
            }

            let payload: MessageParsePayload
            do {
                payload = try await client.parseTransactionMessages(
                    messages: requestItems,
                    categories: categories,
                    clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                    timezone: SpendriftBackendClient.makeTimezoneIdentifier()
                )
            } catch {
                // Keep every row. Inbox messages are only removed after HTTP 200
                // so a failed parse can still be retried on the next launch.
                for row in chunk {
                    row.attemptCount += 1
                    row.lastAttemptAt = Date()
                }
                try? inboxContext.save()
                Diagnostics.breadcrumb(
                    category: .error,
                    message: "message_inbox_parse_failed",
                    data: [
                        Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue,
                        Diagnostics.Tag.stage: Diagnostics.Stage.parse.rawValue,
                    ]
                )
                break
            }

            let resultsByID = Dictionary(uniqueKeysWithValues: payload.results.map { ($0.id, $0) })

            for row in chunk {
                let key = row.id.uuidString
                guard let result = resultsByID[key] else {
                    row.attemptCount += 1
                    row.lastAttemptAt = Date()
                    continue
                }

                let outcome = MessageTransactionCreator.createIfNeeded(
                    result: result,
                    capturedAt: row.capturedAt,
                    accounts: accounts,
                    categories: categories,
                    existingTransactions: existing + createdTransactions(
                        ids: createdIDs,
                        in: ledgerContext
                    ),
                    modelContext: ledgerContext
                )

                switch outcome {
                case let .created(id):
                    createdIDs.append(id)
                    createdCount += 1
                    inboxContext.delete(row)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: row.fingerprint,
                        capturedAt: row.capturedAt,
                        outcome: .imported,
                        transactionID: id
                    )
                case .skippedDuplicate:
                    skippedCount += 1
                    inboxContext.delete(row)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: row.fingerprint,
                        capturedAt: row.capturedAt,
                        outcome: .skippedDuplicate
                    )
                case .rejected:
                    rejectedCount += 1
                    inboxContext.delete(row)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: row.fingerprint,
                        capturedAt: row.capturedAt,
                        outcome: .rejected
                    )
                case .failed:
                    row.attemptCount += 1
                    row.lastAttemptAt = Date()
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: row.fingerprint,
                        capturedAt: row.capturedAt,
                        outcome: .failed
                    )
                }
            }

            try? inboxContext.save()
            try? ledgerContext.save()
        }

        if createdCount > 0 {
            Analytics.captureTransactionCreated(
                method: "sms",
                type: "mixed",
                count: createdCount
            )
        }
        Analytics.capture(
            .messageInboxSynced,
            [
                Analytics.Key.count: createdCount,
                Analytics.Key.removedCount: rejectedCount + skippedCount,
                Analytics.Key.keptCount: skippedCount,
            ]
        )

        guard !createdIDs.isEmpty else { return nil }
        return MessageInboxImportBanner(transactionIDs: createdIDs)
    }

    @MainActor
    static func undoImport(
        transactionIDs: [UUID],
        modelContext: ModelContext
    ) {
        guard !transactionIDs.isEmpty else { return }
        let idSet = Set(transactionIDs)
        let descriptor = FetchDescriptor<Transaction>()
        guard let all = try? modelContext.fetch(descriptor) else { return }
        for txn in all where idSet.contains(txn.id) {
            deleteFromLedger(txn, in: modelContext)
        }
        // Save after SwiftUI has dropped the deleted models. Immediate save
        // detaches backing data while the list still reads `transactionType`.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            try? modelContext.save()
        }
    }

    /// Unlinks relationships and resolves stored attributes before delete.
    /// SwiftData fatals if a view later reads an unfaulted attribute (commonly
    /// `transactionType`) on backing data that has already left the context.
    @MainActor
    private static func deleteFromLedger(_ txn: Transaction, in modelContext: ModelContext) {
        _ = txn.notes
        _ = txn.amount
        _ = txn.date
        _ = txn.transactionType
        _ = txn.source
        txn.category = nil
        txn.account = nil
        modelContext.delete(txn)
    }

    @MainActor
    private static func mergeFallbackIntoInbox() async {
        let fallbackItems = MessageInboxFallback.consumeAll()
        guard !fallbackItems.isEmpty else { return }
        guard let container = try? MessageInboxSwiftData.makeModelContainer() else {
            // Re-queue if inbox still unavailable.
            for item in fallbackItems {
                MessageInboxFallback.enqueue(
                    body: item.body,
                    fingerprint: item.fingerprint,
                    capturedAt: item.capturedAt
                )
            }
            return
        }
        let context = ModelContext(container)
        for item in fallbackItems {
            let fingerprint = item.fingerprint
            let windowStart = item.capturedAt.addingTimeInterval(-5 * 60)
            let descriptor = FetchDescriptor<CapturedTransactionMessage>(
                predicate: #Predicate<CapturedTransactionMessage> {
                    $0.fingerprint == fingerprint && $0.capturedAt >= windowStart
                }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                continue
            }
            context.insert(
                CapturedTransactionMessage(
                    id: item.id,
                    body: item.body,
                    capturedAt: item.capturedAt,
                    fingerprint: item.fingerprint
                )
            )
        }
        try? context.save()
    }

    @MainActor
    private static func createdTransactions(ids: [UUID], in context: ModelContext) -> [Transaction] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<Transaction>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { idSet.contains($0.id) }
    }
}
