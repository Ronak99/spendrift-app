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
    /// Bottom corner radius. Editors with a short hero pass `0` so the wash
    /// meets the canvas in a straight edge instead of curving in.
    var bottomRadius: CGFloat = 32

    var body: some View {
        washShape
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
            .clipShape(washShape)
        }
        .washMotion(value: AppMotion.colorToken(color))
    }

    private var washShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            style: .continuous
        )
    }
}
