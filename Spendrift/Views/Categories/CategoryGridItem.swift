//
//  CategoryGridItem.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

/// One tile in the Categories grid: a tinted circle with the category glyph and the name beneath.
struct CategoryGridItem: View {
    let category: TransactionCategory

    @AppStorage(ColoredCategories.defaultsKey) private var coloredCategoriesEnabled = false

    private let circleSize: CGFloat = 52

    private var tint: Color {
        ColoredCategories.tint(for: category, coloredCategoriesEnabled: coloredCategoriesEnabled)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: category.icon.systemImageName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(category.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        CategoryGridItem(category: TransactionCategory(name: "Food", type: .expense, icon: .food))
        CategoryGridItem(category: TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills))
        CategoryGridItem(category: TransactionCategory(name: "Salary", type: .income, icon: .salary))
    }
    .padding()
}
