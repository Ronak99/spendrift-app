//
//  TransactionTypeMigrationTests.swift
//  SpendriftTests
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct TransactionTypeMigrationTests {
    @Test
    func resolvedMapsLegacyNoneToExpense() {
        #expect(TransactionType.resolved(from: "none") == .expense)
        #expect(TransactionType.resolved(from: "expense") == .expense)
        #expect(TransactionType.resolved(from: "income") == .income)
        #expect(TransactionType.resolved(from: "unknown") == .expense)
        #expect(TransactionType.resolved(from: nil) == .expense)
    }

    @Test
    func categoryTypeMapsFromTransactionType() {
        #expect(CategoryType(transactionType: .expense) == .expense)
        #expect(CategoryType(transactionType: .income) == .income)
    }

    @MainActor
    @Test
    func migrationIsIdempotentOnEmptyStore() throws {
        UserDefaults.standard.removeObject(forKey: TransactionTypeMigration.didNormalizeNoneTypesKey)

        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: context)
        TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: context)

        #expect(UserDefaults.standard.bool(forKey: TransactionTypeMigration.didNormalizeNoneTypesKey))
    }
}
