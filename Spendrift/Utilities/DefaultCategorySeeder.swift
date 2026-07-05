//
//  DefaultCategorySeeder.swift
//  Spendrift
//
//  Created by Cursor on 27/06/26.
//

import Foundation
import SwiftData

enum DefaultCategorySeeder {
    private static let hasSeededDefaultCategoriesKey = "hasSeededDefaultCategories"

    /// Seeds default categories only once per iCloud account.
    /// - Important: This uses iCloud KVS to prevent duplicate seeding after reinstall
    ///   while CloudKit is still downloading existing categories.
    static func seedIfNeeded(modelContext: ModelContext) {
        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

        let descriptor = FetchDescriptor<TransactionCategory>()
        let existingCategories = (try? modelContext.fetch(descriptor)) ?? []

        // If categories already exist (legacy installs or CloudKit download completed),
        // mark as seeded to avoid any future duplicate inserts.
        guard existingCategories.isEmpty else {
            return
        }

        for category in TransactionCategory.defaultCategories() {
            modelContext.insert(category)
        }

        do {
            try modelContext.save()
        } catch {
            // Save failures should not mark the seed flag.
        }
    }
}
