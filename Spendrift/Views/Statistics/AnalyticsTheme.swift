//
//  AnalyticsTheme.swift
//  Spendrift
//
//  Palette for the analytics sheet (design/analytics-sheet-redesign.html, dark).
//  The sheet pins dark appearance, so these are fixed values, not adaptive ones.
//

import SwiftUI

enum AnalyticsTheme {
    /// Cool blue-black, so the ground belongs with the cyan wash above it.
    static let ground = Color(hex: "#0A0D14")
    /// Blue-tinted card surface, a step up from the ground.
    static let card = Color(hex: "#121722")
    static let chip = Color(hex: "#1A2130")

    private static let rim = Color(red: 160 / 255, green: 190 / 255, blue: 230 / 255)
    static let edge = rim.opacity(0.08)
    static let grid = rim.opacity(0.07)
    static let track = rim.opacity(0.08)

    static let ink = Color(hex: "#EDF1F7")
    static let inkSecondary = Color(hex: "#8F99AB")
    static let inkTertiary = Color(hex: "#5D6779")

    /// The one data accent, shared by every chart on the sheet.
    static let accent = Color(hex: "#38D5F2")
    static let accentSoft = accent.opacity(0.20)
    static let accentGlow = accent.opacity(0.16)

    static let spent = Color(hex: "#FF8A6E")
    static let income = Color(hex: "#5BD9A6")
}

/// Sheet background: the ground with a cyan pool in the top-right corner.
struct AnalyticsAtmosphere: View {
    var body: some View {
        ZStack {
            AnalyticsTheme.ground

            LinearGradient(
                stops: [
                    .init(color: AnalyticsTheme.accent.opacity(0.06), location: 0),
                    .init(color: AnalyticsTheme.accent.opacity(0), location: 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                stops: [
                    .init(color: AnalyticsTheme.accent.opacity(0.16), location: 0),
                    .init(color: AnalyticsTheme.accent.opacity(0.06), location: 0.45),
                    .init(color: AnalyticsTheme.accent.opacity(0), location: 0.78)
                ],
                center: UnitPoint(x: 0.9, y: 0),
                startRadius: 0,
                endRadius: 380
            )
        }
    }
}
