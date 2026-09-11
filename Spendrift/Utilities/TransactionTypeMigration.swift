//
//  TransactionTypeMigration.swift
//  Spendrift
//

import Foundation
import SwiftData

enum TransactionTypeMigration {
    static let didNormalizeNoneTypesKey = "didNormalizeNoneTransactionTypes"

    private static let legacyNoneRawValue = "none"

    /// Rewrites persisted `none` transaction and category types to `expense`.
    /// Idempotent; safe to call on every launch before queries run.
    static func normalizeNoneTypesIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didNormalizeNoneTypesKey) else { return }

        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        for transaction in transactions where transaction.transactionType.rawValue == legacyNoneRawValue {
            transaction.transactionType = .expense
        }

        let categories = (try? modelContext.fetch(FetchDescriptor<TransactionCategory>())) ?? []
        for category in categories where category.type.rawValue == legacyNoneRawValue {
            category.type = .expense
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: didNormalizeNoneTypesKey)
    }
}
