//
//  CategoryTrayAtmosphere.swift
//  Spendrift
//
//  Shared colour-wash canvas for ledger trays and pickers (Categories,
//  Accounts, category picker, account picker) so those surfaces share the
//  same top-right atmosphere recipe. Omit `watermarkIcon` for the wash on
//  its own, with no mark in the corner.
//

import SwiftUI

struct CategoryTrayAtmosphere: View {
    let washColor: Color
    var watermarkIcon: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            canvas

            ColorWashBackground(color: washColor, isDark: isDark)
                .frame(height: 360)
                .frame(maxHeight: .infinity, alignment: .top)

            if let watermarkIcon {
                Image(systemName: watermarkIcon)
                    .font(.system(size: 176, weight: .ultraLight))
                    .foregroundStyle(heroPrimary.opacity(isDark ? 0.10 : 0.08))
                    .offset(x: 40, y: -28)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .contentTransition(.opacity)
                    .washMotion(value: watermarkIcon)
            }
        }
    }
}
