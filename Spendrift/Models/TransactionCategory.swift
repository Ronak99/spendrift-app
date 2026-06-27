//
//  TransactionCategory.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData
 
@Model
final class TransactionCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: TransactionType
    var createdOn: Date
    var icon: CategoryIcon
    /// Updated whenever a transaction is saved with this category (manual or shortcut).
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?
    
    init(id: UUID = UUID(), name: String, type: TransactionType, createdOn: Date = Date(), icon: CategoryIcon = .unknown) {
        self.id = id
        self.name = name
        self.type = type
        self.createdOn = createdOn
        self.icon = icon
        self.transactions = []
    }
}

extension TransactionCategory {
    /// Curated default set seeded on first launch. Kept intentionally short so users
    /// add their own instead of cleaning up a long list (see RON-82).
    static func defaultCategories() -> [TransactionCategory] {
        universalCore() + localeAdditions(for: Locale.current)
    }

    /// Compact set of categories that apply regardless of region.
    private static func universalCore() -> [TransactionCategory] {
        [
            // Income
            TransactionCategory(name: "Salary", type: .income, icon: .salary),
            TransactionCategory(name: "Other Income", type: .income, icon: .sale),
            // Expense
            TransactionCategory(name: "Food", type: .expense, icon: .food),
            TransactionCategory(name: "Groceries", type: .expense, icon: .groceries),
            TransactionCategory(name: "Transport", type: .expense, icon: .transportation),
            TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills),
            TransactionCategory(name: "Rent", type: .expense, icon: .rent),
            TransactionCategory(name: "Shopping", type: .expense, icon: .shopping),
            TransactionCategory(name: "Health", type: .expense, icon: .health),
            TransactionCategory(name: "Miscellaneous", type: .expense, icon: .miscellaneous)
        ]
    }

    /// Region-specific extras layered on top of the universal core.
    /// v1 ships a single curated set, so this returns no additions; region-specific
    /// categories can be slotted in here later without touching the seed call sites.
    private static func localeAdditions(for locale: Locale) -> [TransactionCategory] {
        []
    }
}

extension Array where Element == TransactionCategory {
    /// Most recently used first; never-used at the end, preserving alphabetical order from `@Query(sort: \.name)`.
    func sortedByLastUsage() -> [TransactionCategory] {
        sorted { a, b in
            switch (a.lastUsedAt, b.lastUsedAt) {
            case let (aDate?, bDate?): return aDate > bDate
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return false
            }
        }
    }
}
