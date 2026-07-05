//
//  CategoryCatalogServiceTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct CategoryCatalogServiceTests {
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
    func startFreshKeepsDefaultsWithTransactions() throws {
        let context = try makeInMemoryContext()
        let account = Account(name: "Primary", balance: 100, icon: .bankAccountOne, isPrimary: true)
        let salary = TransactionCategory(name: "Salary", type: .income, icon: .salary, isDefault: true)
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food, isDefault: true)
        let baby = TransactionCategory(name: "Baby", type: .expense, icon: .baby, isDefault: true)
        context.insert(account)
        context.insert(salary)
        context.insert(food)
        context.insert(baby)

        let transaction = Transaction(
            notes: "Formula",
            amount: 500,
            date: Date(),
            transactionType: .expense,
            category: baby,
            account: account
        )
        context.insert(transaction)
        try context.save()

        try CategoryCatalogService.applyStartFresh(modelContext: context, source: .onboarding)

        let names = Set(try context.fetch(FetchDescriptor<TransactionCategory>()).map(\.name))
        #expect(names.contains("Baby"))
        #expect(names.contains("Salary"))
        #expect(names.contains("Food"))
        #expect(names.contains("Transport"))
        #expect(names.contains("Miscellaneous"))
        #expect(!names.contains("Groceries"))
    }

    @Test
    func resetToSuggestedAddsMissingCuratedCategories() throws {
        let context = try makeInMemoryContext()
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food, isDefault: true)
        context.insert(food)
        try context.save()

        try CategoryCatalogService.resetToSuggestedCategories(modelContext: context, source: .manual)

        let names = Set(try context.fetch(FetchDescriptor<TransactionCategory>()).map(\.name))
        #expect(names.contains("Food"))
        #expect(names.contains("Groceries"))
        #expect(names.contains("Rent"))
    }
}
