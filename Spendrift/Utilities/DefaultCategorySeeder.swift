//
//  DefaultCategorySeeder.swift
//  Spendrift
//
//  Created by Cursor on 27/06/26.
//

import Foundation
import SwiftData

enum DefaultCategorySeeder {
    /// Seeds default categories when the local store has no categories yet.
    /// Used by UI tests that skip onboarding; production seeding uses `DefaultDataSeeder`.
    static func seedIfNeeded(modelContext: ModelContext) {
        TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

        let descriptor = FetchDescriptor<TransactionCategory>()
        let existingCategories = (try? modelContext.fetch(descriptor)) ?? []

        guard existingCategories.isEmpty else {
            return
        }

        for category in TransactionCategory.defaultCategories() {
            modelContext.insert(category)
        }

        try? modelContext.save()
    }
}
