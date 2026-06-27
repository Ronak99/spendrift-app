//
//  DefaultCategoryMigration.swift
//  Spendrift
//

import Foundation
import SwiftData

enum DefaultCategoryMigration {
    static let didBackfillIsDefaultKey = "didBackfillCategoryIsDefault"
    static let didBackfillSortOrderKey = "didBackfillCategorySortOrder"

    /// Marks existing rows that match any shipped bundled catalog name as `isDefault`.
    static func backfillIsDefaultIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didBackfillIsDefaultKey) else { return }

        let bundled = TransactionCategory.bundledDefaultSignatures()
        let categories = (try? modelContext.fetch(FetchDescriptor<TransactionCategory>())) ?? []

        for category in categories where !category.isDefault {
            if bundled.contains(category.catalogSignature) {
                category.isDefault = true
            }
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: didBackfillIsDefaultKey)
    }

    /// Assigns `sortOrder` from current alphabetical position for rows that still use the default (0).
    static func backfillSortOrderIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didBackfillSortOrderKey) else { return }

        let descriptor = FetchDescriptor<TransactionCategory>(
            sortBy: [SortDescriptor(\.name)]
        )
        let categories = (try? modelContext.fetch(descriptor)) ?? []
        let income = categories.filter { $0.type == .income }
        let expense = categories.filter { $0.type == .expense }

        for (index, category) in income.enumerated() where category.sortOrder == 0 && income.count > 1 {
            category.sortOrder = index
        }
        for (index, category) in expense.enumerated() where category.sortOrder == 0 && expense.count > 1 {
            category.sortOrder = index
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: didBackfillSortOrderKey)
    }
}
