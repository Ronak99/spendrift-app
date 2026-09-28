//
//  MessageInboxSyncService.swift
//  Spendrift
//
//  Drains the SMS inbox and forwarded emails on app launch: parse via backend AI,
//  insert ledger rows. SMS rows are deleted only after HTTP 200 from
//  parse-transactions, so a failed parse can still be retried on the next launch.
//  Emails stay on the server; a cursor records how far the import got.
//  Never logs message bodies.
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

/// One unit of work for the drain: a bank SMS captured on this device, or an
/// email forwarded to this device's expense address. Both go through the same
/// parse call, so one launch produces one banner.
private struct InboxDrainItem {
    enum Origin {
        case sms(CapturedTransactionMessage)
        case email(InboundEmailItem)
    }

    let origin: Origin
    let request: MessageParseRequestItem
    /// Ledger date for the transaction: SMS capture time, or the email's sent time.
    let capturedAt: Date

    var id: String { request.id }

    var smsRow: CapturedTransactionMessage? {
        if case let .sms(row) = origin { return row }
        return nil
    }

    var email: InboundEmailItem? {
        if case let .email(item) = origin { return item }
        return nil
    }

    var source: TransactionSource {
        switch origin {
        case .sms: .sms
        case .email: .email
        }
    }

    /// Key for the developer debug log; SMS rows already carry a body hash.
    var fingerprint: String {
        switch origin {
        case let .sms(row): row.fingerprint
        case let .email(item): "email:\(item.id)"
        }
    }

    /// Transient failures leave SMS rows in the inbox with a bumped attempt count.
    /// Emails need nothing: the cursor simply does not move past them.
    func recordAttempt() {
        guard let smsRow else { return }
        smsRow.attemptCount += 1
        smsRow.lastAttemptAt = Date()
    }
}

enum MessageInboxSyncService {
    static let chunkSize = 40

    /// Sends `items` to the backend, merging any results into `resultsByID`.
    ///
    /// When the backend rejects the payload outright (a 4xx that is not throttling or
    /// auth), the offending body cannot be identified from the response, so the batch
    /// is split in half and each half retried. Validation runs before the model call,
    /// so a rejected half costs no AI spend, and roughly log2(n) extra requests are
    /// enough to isolate the bad row while every good message still gets parsed.
    /// A single item that is still rejected on its own is handed back in `quarantined`.
    ///
    /// Returns false when the failure was transient or an auth problem -- those will
    /// hit every later chunk too, so the caller should stop rather than retry.
    @MainActor
    private static func parse(
        items: [InboxDrainItem],
        client: SpendriftBackendClient,
        categories: [TransactionCategory],
        resultsByID: inout [String: MessageParseResultItem],
        quarantined: inout [InboxDrainItem]
    ) async -> Bool {
        guard !items.isEmpty else { return true }

        do {
            let payload = try await client.parseTransactionMessages(
                messages: items.map(\.request),
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
                for item in items {
                    item.recordAttempt()
                }
                return false
            }

            guard items.count > 1 else {
                items[0].recordAttempt()
                quarantined.append(items[0])
                return true
            }

            let mid = items.count / 2
            let firstHalf = await parse(
                items: Array(items[..<mid]),
                client: client,
                categories: categories,
                resultsByID: &resultsByID,
                quarantined: &quarantined
            )
            let secondHalf = await parse(
                items: Array(items[mid...]),
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
        let smsRows: [CapturedTransactionMessage]
        do {
            smsRows = try inboxContext.fetch(descriptor)
        } catch {
            return nil
        }

        // Emails come oldest first from the server and go after the SMS so the
        // combined list stays in arrival order.
        let emails = await fetchEmails(client: client)
        var pending = smsRows.map(makeItem) + emails.map(makeItem)
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
        var createdBySource: [TransactionSource: Int] = [:]
        var parsedMessageCount = 0
        var rejectedCount = 0
        var skippedCount = 0
        var resolvedEmailIDs = Set<String>()

        /// The item reached a final outcome: SMS rows leave the inbox, emails become
        /// eligible for the cursor to move past them.
        func resolve(_ item: InboxDrainItem) {
            if let row = item.smsRow {
                inboxContext.delete(row)
            }
            if let email = item.email {
                resolvedEmailIDs.insert(email.id)
            }
        }

        let chunks = stride(from: 0, to: pending.count, by: chunkSize).map {
            Array(pending[$0..<min($0 + chunkSize, pending.count)])
        }

        var abortDrain = false

        for chunk in chunks {
            var resultsByID: [String: MessageParseResultItem] = [:]
            var quarantined: [InboxDrainItem] = []

            let completed = await parse(
                items: chunk,
                client: client,
                categories: categories,
                resultsByID: &resultsByID,
                quarantined: &quarantined
            )

            // Bodies the backend will never accept. Dropping them is what stops one
            // bad item from blocking the queue on every future launch.
            for item in quarantined {
                MessageInboxDebugLog.recordLedgerOutcome(
                    fingerprint: item.fingerprint,
                    capturedAt: item.capturedAt,
                    outcome: .rejected
                )
                resolve(item)
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
            // a message correctly identified as "not a transaction" still cost a call.
            parsedMessageCount += resultsByID.count

            let quarantinedIDs = Set(quarantined.map(\.id))
            let liveItems = chunk.filter { !quarantinedIDs.contains($0.id) }

            for item in liveItems {
                guard let result = resultsByID[item.id] else {
                    item.recordAttempt()
                    continue
                }

                let outcome = MessageTransactionCreator.createIfNeeded(
                    result: result,
                    capturedAt: item.capturedAt,
                    accounts: accounts,
                    categories: categories,
                    existingTransactions: existing + createdTransactions(
                        ids: createdIDs,
                        in: ledgerContext
                    ),
                    modelContext: ledgerContext,
                    source: item.source
                )

                switch outcome {
                case let .created(id):
                    createdIDs.append(id)
                    createdBySource[item.source, default: 0] += 1
                    resolve(item)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: item.fingerprint,
                        capturedAt: item.capturedAt,
                        outcome: .imported,
                        transactionID: id
                    )
                case .skippedDuplicate:
                    skippedCount += 1
                    resolve(item)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: item.fingerprint,
                        capturedAt: item.capturedAt,
                        outcome: .skippedDuplicate
                    )
                case .rejected:
                    rejectedCount += 1
                    resolve(item)
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: item.fingerprint,
                        capturedAt: item.capturedAt,
                        outcome: .rejected
                    )
                case .failed:
                    item.recordAttempt()
                    MessageInboxDebugLog.recordLedgerOutcome(
                        fingerprint: item.fingerprint,
                        capturedAt: item.capturedAt,
                        outcome: .failed
                    )
                }
            }

            try? inboxContext.save()
            try? ledgerContext.save()

            if abortDrain { break }
        }

        advanceEmailCursor(emails: emails, resolved: resolvedEmailIDs)

        ProGate.recordUsage(.messageImport, count: parsedMessageCount)

        for (source, count) in createdBySource where count > 0 {
            Analytics.captureTransactionCreated(
                method: source.rawValue,
                type: "mixed",
                count: count
            )
        }
        let createdCount = createdIDs.count
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

    // MARK: - Emails

    /// Emails newer than the cursor for this device's address. A failed fetch
    /// leaves the cursor alone and lets the SMS drain proceed on its own.
    @MainActor
    private static func fetchEmails(client: SpendriftBackendClient) async -> [InboundEmailItem] {
        do {
            let payload = try await client.fetchInboundEmails(
                tag: EmailInboxAddress.tag,
                since: EmailInboxSettings.lastReceivedAtIso
            )
            return payload.emails
        } catch {
            Diagnostics.breadcrumb(
                category: .error,
                message: "email_inbox_fetch_failed",
                data: [
                    Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue,
                    Diagnostics.Tag.errorDomain: (error as NSError).domain,
                    Diagnostics.Tag.errorCode: String((error as NSError).code),
                ]
            )
            return []
        }
    }

    /// Emails arrive oldest first. Move the cursor past every leading email that
    /// reached a final outcome; the first unresolved one (transient failure, no
    /// account yet) holds it so the next launch fetches from there again.
    private static func advanceEmailCursor(emails: [InboundEmailItem], resolved: Set<String>) {
        var cursor: String?
        for email in emails {
            guard resolved.contains(email.id) else { break }
            cursor = email.receivedAtIso
        }
        guard let cursor else { return }
        EmailInboxSettings.lastReceivedAtIso = cursor
        EmailInboxSettings.lastImportedAt = Date()
    }

    private static func makeItem(_ row: CapturedTransactionMessage) -> InboxDrainItem {
        InboxDrainItem(
            origin: .sms(row),
            request: MessageParseRequestItem(
                id: row.id.uuidString,
                body: row.body,
                capturedAtIso: fallbackISOFormatter.string(from: row.capturedAt)
            ),
            capturedAt: row.capturedAt
        )
    }

    private static func makeItem(_ email: InboundEmailItem) -> InboxDrainItem {
        // The email's own date is the purchase date; receipt time is the fallback.
        let capturedAt = parseServerDate(email.sentAtIso)
            ?? parseServerDate(email.receivedAtIso)
            ?? Date()
        return InboxDrainItem(
            origin: .email(email),
            request: MessageParseRequestItem(
                id: "email-\(email.id)",
                body: email.bodyText,
                capturedAtIso: fallbackISOFormatter.string(from: capturedAt),
                source: "email",
                subject: email.subject
            ),
            capturedAt: capturedAt
        )
    }

    private static let serverDateFormatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]
        return [fractional, whole]
    }()

    private static func parseServerDate(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        for formatter in serverDateFormatters {
            if let date = formatter.date(from: iso) { return date }
        }
        return nil
    }

    // MARK: - Undo

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
