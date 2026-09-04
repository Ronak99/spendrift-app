//
//  DefaultCategorySeederTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

@Suite(.serialized)
struct DefaultCategorySeederTests {
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
    func seedsCuratedDefaultsOnEmptyStore() throws {
        let context = try makeInMemoryContext()
        DefaultCategorySeeder.seedIfNeeded(modelContext: context)

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        #expect(categories.count == 10)
        #expect(categories.allSatisfy { $0.isDefault })
        #expect(categories.contains { $0.name == "Groceries" && $0.type == .expense })
        #expect(categories.contains { $0.name == "Other Income" && $0.type == .income })
    }

    @Test
    func backfillMarksLegacyBundledNamesAsDefault() throws {
        UserDefaults.standard.removeObject(forKey: DefaultCategoryMigration.didBackfillIsDefaultKey)

        let context = try makeInMemoryContext()
        let legacy = TransactionCategory(name: "Dividend", type: .income, icon: .dividend)
        context.insert(legacy)
        try context.save()

        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: context)

        #expect(legacy.isDefault)
    }
}
