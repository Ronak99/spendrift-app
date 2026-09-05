//
//  CategoryListItem.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

/// Colored tile shown in the Categories grid (RON-173). Each card carries the
/// category's own hue — a filled icon badge over a soft tinted background — so
/// the grid reads as a bright, distinct palette rather than a flat list.
struct CategoryGridCard: View {
    let category: TransactionCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(category.color)
                    .frame(width: 46, height: 46)

                Image(systemName: category.icon.systemImageName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(category.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 118)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(category.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(category.color.opacity(0.20), lineWidth: 1)
        )
    }
}

#Preview {
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    return LazyVGrid(columns: columns, spacing: 12) {
        CategoryGridCard(category: TransactionCategory(name: "Food", type: .expense, icon: .food))
        CategoryGridCard(category: TransactionCategory(name: "Transport", type: .expense, icon: .transportation))
        CategoryGridCard(category: TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills))
        CategoryGridCard(category: TransactionCategory(name: "Salary", type: .income, icon: .salary))
    }
    .padding()
}
