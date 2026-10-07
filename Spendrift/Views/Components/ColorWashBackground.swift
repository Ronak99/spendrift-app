//
//  ColorWashBackground.swift
//  Spendrift
//
//  Soft colour wash used by the category, transaction, and account editors
//  so those sheets share the same hero atmosphere.
//

import SwiftUI

struct ColorWashBackground: View {
    let color: Color
    let isDark: Bool

    var body: some View {
        LinearGradient(
            colors: [
                color.opacity(isDark ? 0.30 : 0.22),
                color.opacity(isDark ? 0.10 : 0.08),
                color.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            RadialGradient(
                colors: [color.opacity(isDark ? 0.42 : 0.28), color.opacity(0)],
                center: UnitPoint(x: 0.85, y: 0.0),
                startRadius: 8,
                endRadius: 260
            )
        }
        .washMotion(value: AppMotion.colorToken(color))
    }
}
