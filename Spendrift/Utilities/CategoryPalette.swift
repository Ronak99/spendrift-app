//
//  CategoryPalette.swift
//  Spendrift
//
//  Curated colours for the category editor. Stored as `#RRGGBB` on the model.
//

import SwiftUI

enum CategoryPalette {
    static let hexes: [String] = [
        "#FF6B6B",
        "#FF9F6B",
        "#FFC94D",
        "#8BD17C",
        "#4FC3A1",
        "#4FB8E8",
        "#6C8CFF",
        "#9B7BFF",
        "#E27BD8",
        "#FF8FA8",
        "#C3A17A",
        "#8E9AA8"
    ]

    static let defaultExpenseHex = "#8BD17C"
    static let defaultIncomeHex = "#4FC3A1"
    static func defaultHex(for type: CategoryType) -> String {
        switch type {
        case .expense: return defaultExpenseHex
        case .income: return defaultIncomeHex
        }
    }

    static func defaultIcon(for type: CategoryType) -> CategoryIcon {
        switch type {
        case .expense: return .groceries
        case .income: return .salary
        }
    }

    static func normalizedHex(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if !value.hasPrefix("#") {
            value = "#" + value
        }
        guard value.count == 7 else { return nil }
        return value.uppercased()
    }

    static func contains(_ hex: String) -> Bool {
        guard let normalized = normalizedHex(hex) else { return false }
        return hexes.contains { $0.uppercased() == normalized }
    }

    static func hex(matching swatch: ColoredCategories.Swatch) -> String {
        switch swatch {
        case .red: return "#FF6B6B"
        case .orange: return "#FF9F6B"
        case .yellow: return "#FFC94D"
        case .green: return "#8BD17C"
        case .mint, .teal: return "#4FC3A1"
        case .cyan, .blue: return "#4FB8E8"
        case .indigo: return "#6C8CFF"
        case .purple: return "#9B7BFF"
        case .pink: return "#E27BD8"
        case .brown: return "#C3A17A"
        case .gray: return "#8E9AA8"
        }
    }
}

enum CategoryNameSuggestion {
    private struct Rule {
        let keywords: [String]
        let icon: CategoryIcon
        let hex: String
    }

    private static let rules: [Rule] = [
        Rule(keywords: ["grocer", "veg", "market", "supermarket", "basket"], icon: .groceries, hex: "#8BD17C"),
        Rule(keywords: ["rent", "house", "home", "mortgage"], icon: .rent, hex: "#6C8CFF"),
        Rule(keywords: ["fuel", "petrol", "diesel", "gas", "car", "transport", "uber", "ola"], icon: .transportation, hex: "#FF9F6B"),
        Rule(keywords: ["food", "dining", "restaurant", "lunch", "dinner", "swiggy", "zomato"], icon: .food, hex: "#FF6B6B"),
        Rule(keywords: ["travel", "trip", "flight", "holiday", "vacation"], icon: .transportation, hex: "#4FB8E8"),
        Rule(keywords: ["salary", "income", "bonus", "payout", "freelance"], icon: .salary, hex: "#4FC3A1"),
        Rule(keywords: ["health", "medical", "doctor", "pharmacy", "medicine"], icon: .health, hex: "#4FB8E8"),
        Rule(keywords: ["gym", "fitness", "sport", "yoga"], icon: .sport, hex: "#4FC3A1"),
        Rule(keywords: ["bill", "electric", "power", "water", "utility"], icon: .bills, hex: "#FFC94D"),
        Rule(keywords: ["shop", "clothes", "clothing", "fashion", "amazon"], icon: .shopping, hex: "#E27BD8"),
        Rule(keywords: ["school", "college", "education", "tuition", "course", "book"], icon: .education, hex: "#9B7BFF"),
        Rule(keywords: ["beauty", "salon", "spa"], icon: .beauty, hex: "#FF8FA8"),
        Rule(keywords: ["baby", "kid", "child"], icon: .baby, hex: "#FF8FA8"),
        Rule(keywords: ["entertain", "movie", "netflix", "tv"], icon: .entertainment, hex: "#9B7BFF")
    ]

    static func match(name: String) -> (icon: CategoryIcon, hex: String)? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count > 1 else { return nil }
        for rule in rules where rule.keywords.contains(where: { needle.contains($0) }) {
            return (rule.icon, rule.hex)
        }
        return nil
    }
}
