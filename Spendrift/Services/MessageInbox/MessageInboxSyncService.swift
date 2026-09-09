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
    /// Messages left unparsed because the free monthly allowance ran out. The drain
    /// happens with no app on screen, so this is the only way the user finds out.
    let blockedCount: Int

    init(transactionIDs: [UUID], blockedCount: Int = 0) {
        self.id = UUID()
        self.transactionIDs = transactionIDs
        self.count = transactionIDs.count
        self.blockedCount = blockedCount
    }
}

enum MessageInboxSyncService {
    static let chunkSize = 40

    /// Sends `rows` to the backend, merging any results into `resultsByID`.
    ///
    /// When the backend rejects the payload outright (a 4xx that is not throttling or
    /// auth), the offending body cannot be identified from the response, so the batch
    /// is split in half and each half retried. Validation runs before the model call,
    /// so a rejected half costs no AI spend, and roughly log2(n) extra requests are
    /// enough to isolate the bad row while every good message still gets parsed.
    /// A single row that is still rejected on its own is handed back in `quarantined`.
    ///
    /// Returns false when the failure was transient or an auth problem -- those will
    /// hit every later chunk too, so the caller should stop rather than retry.
    @MainActor
    private static func parse(
        rows: [CapturedTransactionMessage],
        client: SpendriftBackendClient,
        categories: [TransactionCategory],
        resultsByID: inout [String: MessageParseResultItem],
        quarantined: inout [CapturedTransactionMessage]
    ) async -> Bool {
        guard !rows.isEmpty else { return true }

        let requestItems = rows.map { row in
            MessageParseRequestItem(
                id: row.id.uuidString,
                body: row.body,
                capturedAtIso: fallbackISOFormatter.string(from: row.capturedAt)
            )
        }

        do {
            let payload = try await client.parseTransactionMessages(
                messages: requestItems,
                categories: categories,
                clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                timezone: SpendriftBackendClient.makeTimezoneIdentifier()
            )
            for result in payload.results {
                resultsByID[result.id] = result
            }
            return true
        } catch {
            let disposition = (error as? SpendriftBackendError)?.disposition ?? .transient
            guard disposition == .rejectedPayload else {
                // Network trouble, throttling, 5xx or bad credentials: keep the rows
                // and let the next launch retry them untouched.
                for row in rows {
                    row.attemptCount += 1
                    row.lastAttemptAt = Date()
                }
                return false
            }

            guard rows.count > 1 else {
                rows[0].attemptCount += 1
                rows[0].lastAttemptAt = Date()
                quarantined.append(rows[0])
                return true
            }

            let mid = rows.count / 2
            let firstHalf = await parse(
                rows: Array(rows[..<mid]),
                client: client,
                categories: categories,
                resultsByID: &resultsByID,
                quarantined: &quarantined
            )
            let secondHalf = await parse(
                rows: Array(rows[mid...]),
                client: client,
                categories: categories,
                resultsByID: &resultsByID,
                quarantined: &quarantined
            )
            return firstHalf && secondHalf
        }
    }

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
        var pending: [CapturedTransactionMessage]
        do {
            pending = try inboxContext.fetch(descriptor)
        } catch {
            return nil
        }
        guard !pending.isEmpty else { return nil }

        // Free tier: spend only as many backend calls as the monthly allowance covers.
        // Anything over stays in the inbox untouched, so it drains next month or the
        // moment the user subscribes — nothing is thrown away.
        var blockedCount = 0
        if !ProEntitlementCache.isPro {
            let allowance = AIQuotaStore.remaining(.messageImport)
            if pending.count > allowance {
                blockedCount = pending.count - allowance
                pending = Array(pending.prefix(allowance))
            }
            if pending.isEmpty {
                // No modal here: this runs headless from a Shortcuts automation, so the
                // banner reports it on next open instead of ambushing the user.
                ProGate.reportBlocked(.messageImport, announce: false)
                return MessageInboxImportBanner(transactionIDs: [], blockedCount: blockedCount)
            }
        }

        let existingDescriptor = FetchDescriptor<Transaction>()
        let existing = (try? ledgerContext.fetch(existingDescriptor)) ?? []

        var createdIDs: [UUID] = []
        var createdCount = 0
        var parsedMessageCount = 0
        var rejectedCount = 0
        var skippedCount = 0

        let chunks = stride(from: 0, to: pending.count, by: chunkSize).map {
            Array(pending[$0..<min($0 + chunkSize, pending.count)])
        }

        var abortDrain = false

        for chunk in chunks {
            var resultsByID: [String: MessageParseResultItem] = [:]
            var quarantined: [CapturedTransactionMessage] = []

            let completed = await parse(
                rows: chunk,
                client: client,
                categories: categories,
                resultsByID: &resultsByID,
                quarantined: &quarantined
            )

            // Bodies the backend will never accept. Deleting them is what stops one
            // bad row from blocking the queue on every future launch.
            for row in quarantined {
                MessageInboxDebugLog.recordLedgerOutcome(
                    fingerprint: row.fingerprint,
                    capturedAt: row.capturedAt,
                    outcome: .rejected
                )
                inboxContext.delete(row)
            }
            if !quarantined.isEmpty {
                rejectedCount += quarantined.count
                Diagnostics.breadcrumb(
                    category: .error,
                    message: "message_inbox_body_quarantined",
                    data: [
                        Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue,
                        Diagnostics.Tag.stage: Diagnostics.Stage.parse.rawValue,
                        Diagnostics.Tag.count: String(quarantined.count),
                    ]
                )
            }

            // A transient or auth failure means later chunks would fail too, so stop
            // after banking whatever this chunk did return.
            if !completed {
                abortDrain = true
                Diagnostics.breadcrumb(
                    category: .error,
                    message: "message_inbox_parse_failed",
                    data: [
                        Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue,
                        Diagnostics.Tag.stage: Diagnostics.Stage.parse.rawValue,
                    ]
                )
            }

            // Credits track what the backend answered, not what became a transaction:
            // an SMS correctly identified as "not a transaction" still cost a call.
            parsedMessageCount += resultsByID.count

            let liveRows = chunk.filter { !quarantined.contains($0) }

            for row in liveRows {
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

            if abortDrain { break }
        }

        ProGate.recordUsage(.messageImport, count: parsedMessageCount)

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

        guard !createdIDs.isEmpty || blockedCount > 0 else { return nil }
        return MessageInboxImportBanner(transactionIDs: createdIDs, blockedCount: blockedCount)
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
