//
//  TransactionListItem.swift
//  Spendrift
//
//  Ledger row: enamel category chip, note-first title, tabular amount.
//

import SwiftUI

/// What the row shows under the amount.
enum TransactionRowDate {
    /// Time of day, for rows already grouped under a day header.
    case time
    /// Time today, "Yesterday", then "9 Oct" - for mixed-date lists like Recent and search.
    case relative
}

struct TransactionListItem: View {
    let transaction: Transaction
    /// Trailing date treatment.
    var dateStyle: TransactionRowDate = .time
    /// Query tokens to underline in the title, so a search hit shows why it matched.
    var highlightTokens: [String] = []

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
        transaction.isExpense ? CategoryEnamel.expense : CategoryEnamel.income
    }

    /// Title with every matched word prefix underlined.
    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(title)
        guard !highlightTokens.isEmpty else { return attributed }
        for token in highlightTokens where token.count >= 2 {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let found = attributed[searchRange].range(of: token, options: [.caseInsensitive]) {
                attributed[found].underlineStyle = .single
                searchRange = found.upperBound..<attributed.endIndex
                if found.upperBound >= attributed.endIndex { break }
            }
        }
        return attributed
    }

    private var trailingDate: some View {
        Group {
            switch dateStyle {
            case .time:
                Text(transaction.date, style: .time)
            case .relative:
                Text(TransactionRowDateText.relative(for: transaction.date))
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .monospacedDigit()
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
                Text(highlightedTitle)
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

                trailingDate
            }
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Shared relative-date wording for ledger rows.
enum TransactionRowDateText {
    static func relative(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        let sameYear = date.year == Date().year
        return date.formatted(
            .dateTime.day().month(.abbreviated).year(sameYear ? .omitted : .twoDigits)
        )
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
