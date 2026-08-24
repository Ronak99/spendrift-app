//
//  MessageInboxSyncServiceTests.swift
//  SpendriftTests
//
//  Undo must delete SMS-imported rows without tripping SwiftData's
//  "backing data was detached without resolving attribute faults" crash.
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct MessageInboxSyncServiceTests {
    @MainActor
    @Test
    func undoImportDeletesRowsWhenAttributesAreStillFaults() async throws {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let writeContext = ModelContext(container)
        let account = Account(name: "Savings", balance: 1_000, isPrimary: true)
        writeContext.insert(account)
        let transaction = Transaction(
            notes: "SWIGGY",
            amount: 220,
            date: Date(),
            transactionType: .expense,
            account: account,
            source: TransactionSource.sms.rawValue
        )
        writeContext.insert(transaction)
        let id = transaction.id
        try writeContext.save()

        // A fresh context loads attribute faults. SwiftUI `@Query` keeps these
        // instances alive across undo, then reads `transactionType` on re-render.
        let undoContext = ModelContext(container)
        let held = try undoContext.fetch(FetchDescriptor<Transaction>())
        #expect(held.count == 1)
        #expect(held[0].isPersisted)

        MessageInboxSyncService.undoImport(transactionIDs: [id], modelContext: undoContext)

        let pendingDelete = try undoContext.fetch(FetchDescriptor<Transaction>())
        #expect(pendingDelete.filter(\.isPersisted).isEmpty)

        try await Task.sleep(for: .milliseconds(500))

        let remaining = try undoContext.fetch(FetchDescriptor<Transaction>())
        #expect(remaining.isEmpty)

        let accounts = try undoContext.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts.first?.currentBalance == 1_000)
    }
}
