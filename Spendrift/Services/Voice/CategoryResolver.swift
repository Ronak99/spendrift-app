//
//  CategoryResolver.swift
//  Spendrift
//

import Foundation

enum CategoryResolver {
    /// Maps AI / legacy category names to the curated catalog.
    static let legacyNameAliases: [String: String] = [
        "Transportation": "Transport",
        "Bills": "Bills & Utilities",
        "Dividend": "Other Income",
        "Friends": "Other Income",
        "Coupons": "Other Income",
        "Refunds": "Other Income",
        "Sale": "Other Income",
        "Home Hygiene": "Miscellaneous",
        "Education": "Miscellaneous",
        "Entertainment": "Miscellaneous",
        "Investments": "Miscellaneous",
        "Sport": "Miscellaneous",
        "Baby": "Shopping",
        "Beauty": "Shopping",
        "Clothing": "Shopping",
        "Electronics": "Shopping",
        "Insurance": "Bills & Utilities",
        "Tax": "Miscellaneous"
    ]

    static func resolve(
        categoryName: String?,
        notes: String,
        type: TransactionType,
        categories: [TransactionCategory]
    ) -> TransactionCategory? {
        let filtered = categories.filter { $0.type == type }
        guard !filtered.isEmpty else { return nil }

        if let exact = matchExact(name: categoryName, in: filtered) {
            return exact
        }

        if let aliased = categoryName.flatMap({ legacyNameAliases[$0] }),
           let match = matchExact(name: aliased, in: filtered) {
            return match
        }

        let intent = TransactionIntentParser.parse(notes)
        let match = CategoryMatcher.match(intent: intent, categories: categories)
        if let category = match.category, category.type == type, match.confidence >= 0.7 {
            return category
        }

        return nil
    }

    private static func matchExact(name: String?, in categories: [TransactionCategory]) -> TransactionCategory? {
        guard let name, !name.isEmpty else { return nil }
        return categories.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
