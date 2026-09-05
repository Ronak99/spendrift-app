//
//  TransactionListItem.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct TransactionListItem: View {
    let transaction: Transaction

    @AppStorage(ColoredCategories.defaultsKey) private var coloredCategoriesEnabled = false

    var body: some View {
        if transaction.isPersisted {
            rowContent
        }
    }

    private var isUnknownCategory: Bool {
        transaction.category?.icon.rawValue == "unknown"
    }

    private var categoryTint: Color {
        if coloredCategoriesEnabled, let color = ColoredCategories.color(for: transaction.category) {
            return color
        }
        return isUnknownCategory ? .gray : .accentColor
    }

    private var rowContent: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryTint.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.category?.icon.systemImageName ?? CategoryIcon.unknown.systemImageName)
                    .font(.system(size: 20))
                    .foregroundColor(categoryTint)
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let accountName = transaction.account?.name {
                    Text(accountName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 6) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .foregroundColor(transaction.transactionType == .expense ? .red : .green)

                Text(transaction.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    List {
        TransactionListItem(transaction: Transaction(
            notes: "Test transaction",
            amount: 1000,
            transactionType: .expense
        ))
        .listItemPositioned(.only)
    }
}
