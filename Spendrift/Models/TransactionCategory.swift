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
    var id: UUID = UUID()
    var name: String = ""
    var type: TransactionType = TransactionType.expense
    var createdOn: Date = Date()
    var icon: CategoryIcon = CategoryIcon.unknown
    /// True for categories seeded from the bundled catalog (defaults or migration).
    var isDefault: Bool = false
    /// Custom display order in the Categories tab (lower = higher in list).
    var sortOrder: Int = 0
    /// Updated whenever a transaction is saved with this category (manual or shortcut).
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?

    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        createdOn: Date = Date(),
        icon: CategoryIcon = .unknown,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdOn = createdOn
        self.icon = icon
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.transactions = []
    }
}

extension TransactionCategory {
    /// Curated default set seeded on first launch (RON-82).
    static func defaultCategories() -> [TransactionCategory] {
        universalCore() + localeAdditions(for: Locale.current)
    }

    /// Ultra-minimal set for "start fresh" onboarding (RON-83).
    static func minimalCore() -> [TransactionCategory] {
        [
            TransactionCategory(name: "Salary", type: .income, icon: .salary, isDefault: true, sortOrder: 0),
            TransactionCategory(name: "Food", type: .expense, icon: .food, isDefault: true, sortOrder: 0),
            TransactionCategory(name: "Transport", type: .expense, icon: .transportation, isDefault: true, sortOrder: 1),
            TransactionCategory(name: "Miscellaneous", type: .expense, icon: .miscellaneous, isDefault: true, sortOrder: 2)
        ]
    }

    /// Compact set of categories that apply regardless of region.
    private static func universalCore() -> [TransactionCategory] {
        [
            TransactionCategory(name: "Salary", type: .income, icon: .salary, isDefault: true, sortOrder: 0),
            TransactionCategory(name: "Other Income", type: .income, icon: .sale, isDefault: true, sortOrder: 1),
            TransactionCategory(name: "Food", type: .expense, icon: .food, isDefault: true, sortOrder: 0),
            TransactionCategory(name: "Groceries", type: .expense, icon: .groceries, isDefault: true, sortOrder: 1),
            TransactionCategory(name: "Transport", type: .expense, icon: .transportation, isDefault: true, sortOrder: 2),
            TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills, isDefault: true, sortOrder: 3),
            TransactionCategory(name: "Rent", type: .expense, icon: .rent, isDefault: true, sortOrder: 4),
            TransactionCategory(name: "Shopping", type: .expense, icon: .shopping, isDefault: true, sortOrder: 5),
            TransactionCategory(name: "Health", type: .expense, icon: .health, isDefault: true, sortOrder: 6),
            TransactionCategory(name: "Miscellaneous", type: .expense, icon: .miscellaneous, isDefault: true, sortOrder: 7)
        ]
    }

    /// Region-specific extras layered on top of the universal core.
    private static func localeAdditions(for locale: Locale) -> [TransactionCategory] {
        []
    }

    /// All bundled catalog names ever shipped — used to backfill `isDefault` on upgrades.
    static func bundledDefaultSignatures() -> Set<String> {
        var signatures = Set<String>()
        for category in defaultCategories() + legacyDefaultCategories() {
            signatures.insert(category.catalogSignature)
        }
        return signatures
    }

    var catalogSignature: String {
        Self.signature(name: name, type: type)
    }

    static func signature(name: String, type: TransactionType) -> String {
        "\(type.rawValue):\(name.lowercased())"
    }

    /// Pre-RON-82 default catalog for `isDefault` backfill on existing installs.
    private static func legacyDefaultCategories() -> [TransactionCategory] {
        [
            TransactionCategory(name: "Dividend", type: .income, icon: .dividend),
            TransactionCategory(name: "Friends", type: .income, icon: .friends),
            TransactionCategory(name: "Salary", type: .income, icon: .salary),
            TransactionCategory(name: "Coupons", type: .income, icon: .coupons),
            TransactionCategory(name: "Refunds", type: .income, icon: .refunds),
            TransactionCategory(name: "Sale", type: .income, icon: .sale),
            TransactionCategory(name: "Bills", type: .expense, icon: .bills),
            TransactionCategory(name: "Education", type: .expense, icon: .education),
            TransactionCategory(name: "Entertainment", type: .expense, icon: .entertainment),
            TransactionCategory(name: "Food", type: .expense, icon: .food),
            TransactionCategory(name: "Health", type: .expense, icon: .health),
            TransactionCategory(name: "Home Hygiene", type: .expense, icon: .home),
            TransactionCategory(name: "Investments", type: .expense, icon: .investments),
            TransactionCategory(name: "Shopping", type: .expense, icon: .shopping),
            TransactionCategory(name: "Sport", type: .expense, icon: .sport),
            TransactionCategory(name: "Transportation", type: .expense, icon: .transportation),
            TransactionCategory(name: "Baby", type: .expense, icon: .baby),
            TransactionCategory(name: "Beauty", type: .expense, icon: .beauty),
            TransactionCategory(name: "Clothing", type: .expense, icon: .clothing),
            TransactionCategory(name: "Electronics", type: .expense, icon: .electronics),
            TransactionCategory(name: "Insurance", type: .expense, icon: .insurance),
            TransactionCategory(name: "Tax", type: .expense, icon: .tax),
            TransactionCategory(name: "Miscellaneous", type: .expense, icon: .miscellaneous)
        ]
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
