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
        Rule(keywords: ["entertain", "movie", "netflix", "tv"], icon: .entertainment, hex: "#9B7BFF"),
        // Appended after the original rules so existing matches keep winning (first match wins).
        Rule(keywords: ["coffee", "cafe", "tea", "starbucks"], icon: .coffee, hex: "#C3A17A"),
        Rule(keywords: ["restaurant", "eat out", "dine out"], icon: .restaurant, hex: "#FF6B6B"),
        Rule(keywords: ["electric", "power", "current"], icon: .electricity, hex: "#FFC94D"),
        Rule(keywords: ["water", "plumb"], icon: .water, hex: "#4FB8E8"),
        Rule(keywords: ["internet", "wifi", "broadband", "fiber"], icon: .internet, hex: "#6C8CFF"),
        Rule(keywords: ["mobile", "recharge", "phone", "data plan"], icon: .mobile, hex: "#4FB8E8"),
        Rule(keywords: ["laundry", "dry clean", "ironing"], icon: .laundry, hex: "#8E9AA8"),
        Rule(keywords: ["repair", "maintenance", "handyman", "carpenter"], icon: .repairs, hex: "#C3A17A"),
        Rule(keywords: ["parking", "valet"], icon: .parking, hex: "#8E9AA8"),
        Rule(keywords: ["toll", "fastag"], icon: .tolls, hex: "#FF9F6B"),
        Rule(keywords: ["hotel", "stay", "airbnb", "lodging"], icon: .hotel, hex: "#4FB8E8"),
        Rule(keywords: ["pet", "dog", "cat", "vet"], icon: .pets, hex: "#C3A17A"),
        Rule(keywords: ["subscription", "membership", "renewal"], icon: .subscriptions, hex: "#9B7BFF"),
        Rule(keywords: ["gaming", "game", "playstation", "xbox", "steam"], icon: .games, hex: "#6C8CFF"),
        Rule(keywords: ["music", "spotify", "concert"], icon: .music, hex: "#E27BD8"),
        Rule(keywords: ["dental", "dentist", "teeth"], icon: .dental, hex: "#4FB8E8"),
        Rule(keywords: ["pharmacy", "chemist"], icon: .pharmacy, hex: "#4FC3A1"),
        Rule(keywords: ["emi", "loan", "repayment"], icon: .loan, hex: "#FF6B6B"),
        Rule(keywords: ["sip", "mutual", "portfolio"], icon: .investments, hex: "#4FC3A1"),
        Rule(keywords: ["stock", "share", "equity", "trading"], icon: .stocks, hex: "#4FC3A1"),
        Rule(keywords: ["crypto", "bitcoin"], icon: .crypto, hex: "#FF9F6B"),
        Rule(keywords: ["donat", "charity", "ngo"], icon: .charity, hex: "#FF8FA8"),
        Rule(keywords: ["wedding", "marriage", "anniversary"], icon: .wedding, hex: "#FF8FA8"),
        Rule(keywords: ["party", "birthday", "festival", "celebrat"], icon: .celebration, hex: "#E27BD8"),
        Rule(keywords: ["gift", "present"], icon: .gifts, hex: "#E27BD8"),
        Rule(keywords: ["office", "work", "business"], icon: .work, hex: "#8E9AA8"),
        Rule(keywords: ["software", "saas", "subscription tool"], icon: .software, hex: "#6C8CFF"),
        Rule(keywords: ["tax", "gst", "tds"], icon: .tax, hex: "#8E9AA8")
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
