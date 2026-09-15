//
//  CategorySearch.swift
//  Spendrift
//
//  Local find for category trays. Matches the visible name first, then the
//  icon's picker label and keywords, so "lunch" still finds Food.
//

import Foundation

enum CategorySearch {
    static func needle(from raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ category: TransactionCategory, query: String) -> Bool {
        let needle = Self.needle(from: query)
        guard !needle.isEmpty else { return true }
        if category.name.localizedStandardContains(needle) {
            return true
        }
        let iconHaystack = [
            category.icon.pickerLabel,
            category.icon.searchKeywords,
            category.icon.rawValue
        ].joined(separator: " ")
        return iconHaystack.localizedStandardContains(needle)
    }

    static func filter(_ categories: [TransactionCategory], query: String) -> [TransactionCategory] {
        let needle = Self.needle(from: query)
        guard !needle.isEmpty else { return categories }
        return categories.filter { matches($0, query: needle) }
    }

    /// Hits in the other category type, used to offer a type switch instead of an empty miss.
    static func otherTypeHit(
        in categories: [TransactionCategory],
        query: String,
        excluding type: CategoryType
    ) -> (type: CategoryType, count: Int, name: String)? {
        let hits = filter(categories.filter { $0.type != type }, query: query)
        guard let first = hits.first else { return nil }
        return (first.type, hits.count, first.name)
    }
}
