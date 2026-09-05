//
//  Color+Extensions.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

extension Color {
    static let selectedThemeIndexKey = "selectedThemeIndex"
    static let legacyThemeColorKey = "themeColor"
    static let defaultThemeIndex = 1

    static let themePalette: [Color] = [
        Color(hex: "#22C3E6"), // cyan
        Color(hex: "#3A7BFF"), // blue (default)
        Color(hex: "#9B7BFF"), // purple
        Color(hex: "#EC4899"), // pink
        Color(hex: "#EF4444"), // red
        Color(hex: "#F59E0B"), // orange
        Color(hex: "#22C55E"), // green
        Color(hex: "#14B8A6"), // teal
    ]

    private static let legacyThemeNames = [
        "Cyan",
        "Blue",
        "Purple",
        "Pink",
        "Red",
        "Orange",
        "Green",
        "Teal",
    ]

    static func accentColor(forThemeIndex index: Int) -> Color {
        themePalette[normalizedThemeIndex(index)]
    }

    static func normalizedThemeIndex(_ index: Int) -> Int {
        guard !themePalette.isEmpty else { return 0 }
        return max(0, min(index, themePalette.count - 1))
    }

    static func legacyThemeName(forThemeIndex index: Int) -> String {
        legacyThemeNames[normalizedThemeIndex(index)]
    }

    static func themeIndex(forLegacyThemeName name: String) -> Int? {
        legacyThemeNames.firstIndex(of: name)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Category colors (RON-173)

extension CategoryIcon {
    /// Stable, semantic accent color for each category icon. Drives the colored
    /// grid on the Categories tab so every category reads as its own hue,
    /// consistent across launches (the mapping is by icon, not by list position).
    var color: Color {
        switch self {
        // Income
        case .salary: return Color(hex: "#22C55E")      // green
        case .dividend: return Color(hex: "#10B981")    // emerald
        case .sale: return Color(hex: "#14B8A6")        // teal
        case .friends: return Color(hex: "#8B5CF6")     // violet
        case .coupons: return Color(hex: "#F43F5E")     // rose
        case .refunds: return Color(hex: "#06B6D4")     // cyan
        // Expense
        case .food: return Color(hex: "#F97316")        // orange
        case .groceries: return Color(hex: "#84CC16")   // lime
        case .transportation: return Color(hex: "#3B82F6") // blue
        case .bills: return Color(hex: "#F59E0B")       // amber
        case .rent: return Color(hex: "#6366F1")        // indigo
        case .shopping: return Color(hex: "#EC4899")    // pink
        case .health: return Color(hex: "#EF4444")      // red
        case .education: return Color(hex: "#A855F7")   // purple
        case .entertainment: return Color(hex: "#D946EF") // fuchsia
        case .home: return Color(hex: "#0EA5E9")        // sky
        case .investments: return Color(hex: "#0D9488") // deep teal
        case .sport: return Color(hex: "#EAB308")       // yellow
        case .baby: return Color(hex: "#F472B6")        // light pink
        case .beauty: return Color(hex: "#DB2777")      // magenta
        case .clothing: return Color(hex: "#7C3AED")    // deep violet
        case .tax: return Color(hex: "#64748B")         // slate
        case .electronics: return Color(hex: "#0284C7") // deep blue
        case .insurance: return Color(hex: "#059669")   // deep green
        case .miscellaneous: return Color(hex: "#6B7280") // gray
        case .unknown: return Color(hex: "#9CA3AF")     // muted gray
        }
    }
}

extension TransactionCategory {
    /// Convenience accessor for the category's display color (see `CategoryIcon.color`).
    var color: Color {
        icon.color
    }
}
