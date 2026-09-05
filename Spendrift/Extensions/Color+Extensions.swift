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
    ]

    private static let legacyThemeNames = [
        "Cyan",
        "Blue",
        "Purple",
        "Pink",
        "Red",
        "Orange",
        "Green",
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
