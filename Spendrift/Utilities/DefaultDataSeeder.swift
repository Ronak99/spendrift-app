//
//  DefaultDataSeeder.swift
//  Spendrift
//
//  Single source of truth for seeding a brand-new user's starter data.
//

import Foundation
import SwiftData

/// Unifies seeding of the default account and default categories so it happens
/// in exactly one place: the moment the user starts onboarding.
///
/// When the local store has no accounts or categories yet, inserts the starter
/// "Savings" account and curated default categories immediately so every
/// `@Query`-backed view has data right away.
enum DefaultDataSeeder {
    /// Default starter account values.
    private static let defaultAccountName = "Savings"
    private static let defaultAccountBalance: Double = 100

    /// Seeds default account and categories when the local store is empty.
    /// Idempotent and safe to call repeatedly.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        Diagnostics.breadcrumb(
            category: .feature,
            message: "default_data_seed_started",
            feature: .seeding,
            stage: .bootstrap
        )

        // Bring legacy rows up to date regardless of whether we seed (idempotent,
        // guarded by their own UserDefaults flags).
        TransactionTypeMigration.normalizeNoneTypesIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillIsDefaultIfNeeded(modelContext: modelContext)
        DefaultCategoryMigration.backfillSortOrderIfNeeded(modelContext: modelContext)

        let needsAccount = !hasAny(Account.self, in: modelContext)
        let needsCategories = !hasAny(TransactionCategory.self, in: modelContext)

        guard needsAccount || needsCategories else {
            Diagnostics.breadcrumb(
                category: .feature,
                message: "default_data_seed_skipped",
                feature: .seeding,
                stage: .reconcile
            )
            return
        }

        if needsAccount {
            seedDefaultAccount(in: modelContext)
        }
        if needsCategories {
            seedDefaultCategories(in: modelContext)
        }

        Diagnostics.breadcrumb(
            category: .feature,
            message: "default_data_seed_completed",
            feature: .seeding,
            stage: .reconcile
        )
    }

    private static func seedDefaultAccount(in modelContext: ModelContext) {
        let account = Account(
            name: defaultAccountName,
            balance: defaultAccountBalance,
            icon: .savings,
            isPrimary: true
        )
        modelContext.insert(account)
        try? modelContext.save()
    }

    private static func seedDefaultCategories(in modelContext: ModelContext) {
        let categories = TransactionCategory.defaultCategories()
        for category in categories {
            modelContext.insert(category)
        }
        try? modelContext.save()
    }

    private static func hasAny<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
