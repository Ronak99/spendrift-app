//
//  TransactionListItem.swift
//  Spendrift
//
//  Ledger row: enamel category chip, note-first title, tabular amount.
//

import SwiftUI

struct TransactionListItem: View {
    let transaction: Transaction

    private let enamelSize: CGFloat = 42

    private var trimmedNotes: String {
        transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        if !trimmedNotes.isEmpty { return trimmedNotes }
        return transaction.category?.name ?? "Uncategorized"
    }

    private var subtitle: String? {
        let account = transaction.account?.name
        if !trimmedNotes.isEmpty {
            let category = transaction.category?.name ?? "Uncategorized"
            if let account { return "\(category) · \(account)" }
            return category
        }
        return account
    }

    private var enamelColor: Color {
        CategoryEnamel.color(for: transaction.category)
    }

    private var enamelIcon: String {
        transaction.category?.icon.systemImageName ?? CategoryIcon.unknown.systemImageName
    }

    private var amountText: String {
        if transaction.isExpense {
            return transaction.formattedAmount
        }
        return "+\(transaction.formattedAmount)"
    }

    private var amountColor: Color {
        transaction.isExpense ? Color.primary : CategoryEnamel.income
    }

    var body: some View {
        if transaction.isPersisted {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryEnamelTile(
                systemImage: enamelIcon,
                color: enamelColor,
                showsShadow: false
            )
            .frame(width: enamelSize, height: enamelSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(transaction.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let food = TransactionCategory(name: "Food", type: .expense, icon: .food, colorHex: "#FF6B6B")
    let salary = TransactionCategory(name: "Salary", type: .income, icon: .salary, colorHex: "#4FC3A1")

    List {
        TransactionListItem(transaction: Transaction(
            notes: "Lunch at the cafe",
            amount: 420,
            transactionType: .expense,
            category: food,
            account: Account(name: "HDFC", balance: 0)
        ))
        .listItemPositioned(.first)

        TransactionListItem(transaction: Transaction(
            notes: "",
            amount: 85000,
            transactionType: .income,
            category: salary,
            account: Account(name: "HDFC", balance: 0)
        ))
        .listItemPositioned(.last)
    }
}
