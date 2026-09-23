//
//  ColoredCategories.swift
//  Spendrift
//
//  Per-category tints computed from the category name when no explicit color
//  is stored on the model. The map lives entirely on the client.
//

import SwiftUI

enum ColoredCategories {
    /// Semantic swatch used by the name map. Tests assert against these tokens
    /// instead of `Color`, which is not reliably equatable.
    enum Swatch: String, Equatable, CaseIterable {
        case orange, green, indigo, blue, teal, pink, purple, red
        case mint, yellow, cyan, brown, gray
    }

    /// Known catalog names (current defaults plus every legacy name we ever shipped).
    /// Related categories share a hue so the grid still reads as a system.
    private static let namedSwatches: [String: Swatch] = [
        "food": .orange,
        "groceries": .green,
        "transport": .indigo,
        "transportation": .indigo,
        "bills & utilities": .blue,
        "bills": .blue,
        "insurance": .blue,
        "rent": .teal,
        "home hygiene": .teal,
        "salary": .teal,
        "other income": .teal,
        "friends": .teal,
        "coupons": .teal,
        "refunds": .teal,
        "sale": .teal,
        "shopping": .pink,
        "clothing": .pink,
        "beauty": .pink,
        "baby": .pink,
        "electronics": .purple,
        "entertainment": .purple,
        "health": .red,
        "sport": .mint,
        "education": .yellow,
        "investments": .cyan,
        "dividend": .cyan,
        "tax": .brown,
        "miscellaneous": .gray
    ]

    private static let fallbackPalette: [Swatch] = [
        .orange, .green, .indigo, .blue, .teal, .pink, .purple, .red, .mint, .cyan, .brown
    ]

    static func swatch(forName name: String) -> Swatch {
        let key = normalize(name)
        if let mapped = namedSwatches[key] {
            return mapped
        }
        return hashedSwatch(forName: key)
    }

    /// Always resolved through `CategoryPalette`, so a category without a stored
    /// `colorHex` renders in the same curated tone the editor and the grid use.
    /// Reading a swatch as its system `Color` drifts off the palette — SwiftUI's
    /// `.pink` is far redder than the palette's `#E27BD8` (RON-231).
    static func color(forName name: String) -> Color {
        Color(hex: CategoryPalette.hex(matching: swatch(forName: name)))
    }

    static func color(for category: TransactionCategory?) -> Color? {
        guard let category else { return nil }
        if let hex = CategoryPalette.normalizedHex(category.colorHex) {
            return Color(hex: hex)
        }
        guard !category.name.isEmpty else { return nil }
        return color(forName: category.name)
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Stable, process-independent color for custom names that are not in the catalog.
    private static func hashedSwatch(forName name: String) -> Swatch {
        let hash = name.unicodeScalars.reduce(into: 0) { partial, scalar in
            partial = (partial &* 31) &+ Int(scalar.value)
        }
        let count = fallbackPalette.count
        let index = (hash % count + count) % count
        return fallbackPalette[index]
    }
}
