//
//  MessageTransactionCreatorTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct MessageTransactionCreatorTests {
    @MainActor
    @Test
    func nearDuplicateDetectsSameAmountDayAccountType() throws {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let account = Account(name: "Savings", balance: 100, isPrimary: true)
        context.insert(account)

        let existing = Transaction(
            notes: "SWIGGY",
            amount: 450,
            date: Date(),
            transactionType: .expense,
            account: account,
            source: TransactionSource.manual.rawValue
        )
        context.insert(existing)
        try context.save()

        let isDup = MessageTransactionCreator.isNearDuplicate(
            amount: 450,
            date: Date(),
            type: .expense,
            account: account,
            existing: [existing]
        )
        #expect(isDup)

        let notDup = MessageTransactionCreator.isNearDuplicate(
            amount: 451,
            date: Date(),
            type: .expense,
            account: account,
            existing: [existing]
        )
        #expect(!notDup)
    }

    @MainActor
    @Test
    func createsUncategorizedSMSTransaction() throws {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let account = Account(name: "Savings", balance: 100, isPrimary: true)
        context.insert(account)
        try context.save()

        let result = MessageParseResultItem(
            id: UUID().uuidString,
            status: "success",
            transaction: MessageTransactionData(
                notes: "SWIGGY",
                amount: 220,
                date: "2026-08-24T10:00:00",
                transactionType: "expense",
                category: nil
            ),
            reason: nil
        )

        let outcome = MessageTransactionCreator.createIfNeeded(
            result: result,
            capturedAt: Date(),
            accounts: [account],
            categories: [],
            existingTransactions: [],
            modelContext: context
        )

        guard case let .created(id) = outcome else {
            Issue.record("Expected created transaction")
            return
        }
        try context.save()
        let rows = try context.fetch(FetchDescriptor<Transaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.id == id)
        #expect(rows.first?.source == TransactionSource.sms.rawValue)
        #expect(rows.first?.category == nil)
    }
}
