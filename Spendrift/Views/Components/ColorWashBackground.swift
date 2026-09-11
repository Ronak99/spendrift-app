//
//  ColorWashBackground.swift
//  Spendrift
//
//  Soft colour wash used by the category and transaction editors so both
//  sheets share the same hero atmosphere.
//

import SwiftUI

struct ColorWashBackground: View {
    let color: Color
    let isDark: Bool

    var body: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: 32,
            bottomTrailingRadius: 32,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    color.opacity(isDark ? 0.30 : 0.22),
                    color.opacity(isDark ? 0.10 : 0.08),
                    (isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay {
            RadialGradient(
                colors: [color.opacity(isDark ? 0.42 : 0.28), .clear],
                center: UnitPoint(x: 0.85, y: 0.0),
                startRadius: 8,
                endRadius: 260
            )
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 32,
                    bottomTrailingRadius: 32,
                    style: .continuous
                )
            )
        }
    }
}
