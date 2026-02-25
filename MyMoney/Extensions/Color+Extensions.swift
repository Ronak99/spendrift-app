//
//  Color+Extensions.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

extension Color {
    static let themeColors: [String: Color] = [
        "Cyan": Color(hex: "#22D3EE"),
        "Blue": Color(hex: "#3B82F6"),
        "Purple": Color(hex: "#A78BFA"),
        "Pink": Color(hex: "#EC4899"),
        "Red": Color(hex: "#EF4444"),
        "Orange": Color(hex: "#F59E0B"),
        "Green": Color(hex: "#34D399"),
        "Teal": Color(hex: "#14B8A6")
    ]
    
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
