//
//  CategoryTypeChangeTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

@MainActor
struct CategoryTypeChangeTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @discardableResult
    private func insertTransaction(
        _ context: ModelContext,
        category: TransactionCategory,
        type: TransactionType
    ) -> Transaction {
        let transaction = Transaction(
            notes: "Test",
            amount: 10,
            transactionType: type,
            category: category
        )
        context.insert(transaction)
        return transaction
    }

    @Test
    func transactionTypeMapsFromCategoryType() {
        #expect(TransactionType(categoryType: .expense) == .expense)
        #expect(TransactionType(categoryType: .income) == .income)
    }

    @Test
    func expenseToIncomeRetypesEveryTransaction() throws {
        let context = try makeContext()
        let category = TransactionCategory(name: "Freelance", type: .expense)
        context.insert(category)
        let first = insertTransaction(context, category: category, type: .expense)
        let second = insertTransaction(context, category: category, type: .expense)
        try context.save()

        let retyped = category.applyType(.income)

        #expect(retyped == 2)
        #expect(category.type == .income)
        #expect(first.transactionType == .income)
        #expect(second.transactionType == .income)
    }

    @Test
    func incomeToExpenseRetypesEveryTransaction() throws {
        let context = try makeContext()
        let category = TransactionCategory(name: "Refunds", type: .income)
        context.insert(category)
        let transaction = insertTransaction(context, category: category, type: .income)
        try context.save()

        let retyped = category.applyType(.expense)

        #expect(retyped == 1)
        #expect(category.type == .expense)
        #expect(transaction.transactionType == .expense)
    }

    @Test
    func unchangedTypeLeavesTransactionsAlone() throws {
        let context = try makeContext()
        let category = TransactionCategory(name: "Food", type: .expense)
        context.insert(category)
        // A transaction that drifted out of sync stays untouched when the type does not change.
        let drifted = insertTransaction(context, category: category, type: .income)
        try context.save()

        let retyped = category.applyType(.expense)

        #expect(retyped == 0)
        #expect(category.type == .expense)
        #expect(drifted.transactionType == .income)
    }

    @Test
    func changeAppliesToOnlyItsOwnTransactions() throws {
        let context = try makeContext()
        let flipped = TransactionCategory(name: "Sale", type: .expense)
        let untouched = TransactionCategory(name: "Rent", type: .expense)
        context.insert(flipped)
        context.insert(untouched)
        let mine = insertTransaction(context, category: flipped, type: .expense)
        let theirs = insertTransaction(context, category: untouched, type: .expense)
        try context.save()

        flipped.applyType(.income)

        #expect(mine.transactionType == .income)
        #expect(theirs.transactionType == .expense)
        #expect(untouched.type == .expense)
    }

    @Test
    func categoryWithoutTransactionsStillSwitchesType() throws {
        let context = try makeContext()
        let category = TransactionCategory(name: "Dividend", type: .expense)
        context.insert(category)
        try context.save()

        let retyped = category.applyType(.income)

        #expect(retyped == 0)
        #expect(category.type == .income)
    }
}
