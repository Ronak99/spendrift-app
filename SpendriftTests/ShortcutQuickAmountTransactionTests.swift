//
//  ShortcutQuickAmountTransactionTests.swift
//  MyMoneyTests
//
//  Created by Cursor on 30/03/26.
//

import Foundation
import SwiftData
import Testing
@testable import MyMoney

struct ShortcutQuickAmountTransactionTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self,
            Account.self,
            TransactionCategory.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test
    func createInsertsExpenseOnPrimaryUncategorized() throws {
        let context = try makeInMemoryContext()
        let primary = Account(name: "Primary", balance: 0, icon: .unknown, isPrimary: true)
        let other = Account(name: "Other", balance: 0, icon: .unknown, isPrimary: false)
        context.insert(primary)
        context.insert(other)

        let tx = try ShortcutQuickAmountTransaction.create(
            amount: 42.5,
            notes: "Coffee",
            category: nil,
            modelContext: context,
            accounts: [other, primary]
        )

        #expect(tx.amount == 42.5)
        #expect(tx.notes == "Coffee")
        #expect(tx.transactionType == .expense)
        #expect(tx.category == nil)
        #expect(tx.account?.id == primary.id)

        let fetched = try context.fetch(FetchDescriptor<Transaction>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == tx.id)
    }

    @Test
    func createAssignsExpenseCategoryWhenProvided() throws {
        let context = try makeInMemoryContext()
        let primary = Account(name: "Primary", balance: 0, icon: .unknown, isPrimary: true)
        context.insert(primary)
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food)
        context.insert(food)

        let tx = try ShortcutQuickAmountTransaction.create(
            amount: 25,
            notes: "Lunch",
            category: food,
            modelContext: context,
            accounts: [primary]
        )

        #expect(tx.category?.id == food.id)
        #expect(tx.transactionType == .expense)
    }

    @Test
    func createRejectsNonPositiveAmount() throws {
        let context = try makeInMemoryContext()
        let primary = Account(name: "Primary", balance: 0, icon: .unknown, isPrimary: true)
        context.insert(primary)

        #expect(throws: ShortcutQuickAmountTransaction.Failure.self) {
            try ShortcutQuickAmountTransaction.create(
                amount: 0,
                notes: "",
                category: nil,
                modelContext: context,
                accounts: [primary]
            )
        }

        #expect(throws: ShortcutQuickAmountTransaction.Failure.self) {
            try ShortcutQuickAmountTransaction.create(
                amount: -10,
                notes: "",
                category: nil,
                modelContext: context,
                accounts: [primary]
            )
        }
    }

    @Test
    func createRequiresPrimaryAccount() throws {
        let context = try makeInMemoryContext()
        let nonPrimary = Account(name: "Savings", balance: 0, icon: .unknown, isPrimary: false)
        context.insert(nonPrimary)

        #expect(throws: ShortcutQuickAmountTransaction.Failure.self) {
            try ShortcutQuickAmountTransaction.create(
                amount: 99,
                notes: "",
                category: nil,
                modelContext: context,
                accounts: [nonPrimary]
            )
        }
    }
}
