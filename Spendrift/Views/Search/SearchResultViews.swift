//
//  SearchResultViews.swift
//  Spendrift
//
//  The pieces search results are built from: the top-hit card with its own small
//  analytics, compact entity rows, and transaction sections that fold into a card.
//

import SwiftUI

/// The best entity for the query, with count, total, monthly average and a
/// 12-month strip. Its own transactions fold in here instead of flooding the list.
struct SearchTopHitCard: View {
    let entity: SearchEntity
    let filterSummary: String
    let allTransactions: [Transaction]
    let today: Date
    let onOpen: () -> Void

    private var series: [(month: MonthRef, amount: Double)] {
        LedgerSearch.monthlySeries(for: allTransactions, today: today)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                head
                stats
                strip
                foot
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(HomePressStyle())
        .accessibilityLabel("Open \(entity.name)")
    }

    private var head: some View {
        HStack(spacing: 14) {
            EnamelBadge(systemImage: entity.symbol, color: entity.color, side: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text("Top hit · \(entity.kindLabel)")
                    .font(.system(size: 11.5))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.inkSecondary)
                Text(entity.name)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.inkTertiary)
        }
    }

    private var stats: some View {
        let completed = series.dropLast()
        let average = completed.isEmpty
            ? 0
            : completed.reduce(0) { $0 + $1.amount } / Double(completed.count)

        return HStack(alignment: .top, spacing: 8) {
            statColumn("Transactions", "\(entity.transactions.count)", alignment: .leading)
            Spacer(minLength: 0)
            statColumn(
                filterSummary.isEmpty ? "Total" : "Total, filtered",
                LedgerSearch.expenseTotal(entity.transactions).formatCurrencyRounded,
                alignment: .center
            )
            Spacer(minLength: 0)
            if case .account(let account) = entity.kind {
                statColumn(
                    "Balance",
                    account.currentBalance.formatCurrency,
                    tint: account.currentBalance < 0 ? AppTheme.expense : AppTheme.income,
                    alignment: .trailing
                )
            } else {
                statColumn("Avg / month", average.formatCurrencyRounded, alignment: .trailing)
            }
        }
    }

    private func statColumn(
        _ caption: String,
        _ value: String,
        tint: Color = AppTheme.ink,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(caption)
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.inkSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// One bar per month, the month in progress at full strength.
    private var strip: some View {
        let peak = max(series.map(\.amount).max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(series.enumerated()), id: \.offset) { index, point in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(entity.color)
                    .opacity(index == series.count - 1 ? 1 : 0.4)
                    .frame(height: max(2, 56 * point.amount / peak))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    private var foot: some View {
        let last = series.last
        let completed = series.dropLast()
        let average = completed.isEmpty
            ? 0
            : completed.reduce(0) { $0 + $1.amount } / Double(completed.count)
        let since = allTransactions.min { $0.date < $1.date }?.date

        return VStack(spacing: 0) {
            HomeRowDivider()
            HStack(spacing: 8) {
                if let since {
                    Text("Since \(HomeInsights.shortMonthName(since.month)) \(String(since.year))")
                        .foregroundStyle(AppTheme.inkTertiary)
                }
                Spacer(minLength: 8)
                if let last {
                    Text(lastMonthSummary(last, average: average))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            .font(.system(size: 12))
            .lineLimit(1)
            .padding(.top, 10)
        }
    }

    private func lastMonthSummary(
        _ last: (month: MonthRef, amount: Double),
        average: Double
    ) -> String {
        var text = "\(last.month.shortName) \(last.amount.formatCurrencyRounded)"
        if average > 0 {
            let change = Int(((last.amount - average) / average * 100).rounded())
            text += " · \(abs(change))% \(change >= 0 ? "above" : "below") avg"
        }
        return text
    }
}

/// Compact row for an entity that is not the top hit.
struct SearchEntityRow: View {
    let entity: SearchEntity
    let tokens: [String]
    let onOpen: () -> Void

    private var subtitle: String {
        let count = entity.transactions.count
        let suffix = "\(count) transaction\(count == 1 ? "" : "s")"
        if case .merchant(_, let category) = entity.kind, let category {
            return "\(category.name) · \(suffix)"
        }
        return suffix
    }

    private var trailing: (text: String, tint: Color) {
        if case .account(let account) = entity.kind {
            return (
                account.currentBalance.formatCurrency,
                account.currentBalance < 0 ? AppTheme.expense : AppTheme.income
            )
        }
        return (LedgerSearch.expenseTotal(entity.transactions).formatCurrencyRounded, AppTheme.ink)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                EnamelBadge(systemImage: entity.symbol, color: entity.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlighted(entity.name, tokens: tokens))
                        .font(.system(size: 15.5, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer(minLength: 8)
                Text(trailing.text)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(trailing.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityElement(children: .combine)
    }
}

/// A card of transactions with a count / total line, and a See all when there are more.
struct SearchTransactionSection: View {
    let title: String
    let transactions: [Transaction]
    let tokens: [String]
    var limit: Int = 5
    /// Offered on rows that matched only through the top hit's category.
    var moveTarget: TransactionCategory?
    var onOpen: (Transaction) -> Void
    var onMove: ((Transaction, TransactionCategory) -> Void)?
    var onSeeAll: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HomeSectionHeader(title: title)
            HomeCard {
                HStack {
                    Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                    Spacer(minLength: 8)
                    Text("\(LedgerSearch.expenseTotal(transactions).formatCurrencyRounded) spent")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkSecondary)
                .padding(.top, 12)
                .padding(.bottom, 4)

                ForEach(Array(transactions.prefix(limit).enumerated()), id: \.element.id) { index, transaction in
                    if index > 0 {
                        HomeRowDivider()
                    }
                    row(transaction)
                }

                if transactions.count > limit, let onSeeAll {
                    HomeCardLink(title: "See all \(transactions.count)", action: onSeeAll)
                }
            }
        }
    }

    private func row(_ transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onOpen(transaction)
            } label: {
                TransactionListItem(
                    transaction: transaction,
                    dateStyle: .relative,
                    highlightTokens: tokens
                )
                .padding(.vertical, 12)
            }
            .buttonStyle(HomePressStyle(scale: 1))

            if let moveTarget, let onMove, transaction.category?.id != moveTarget.id {
                Button {
                    onMove(transaction, moveTarget)
                } label: {
                    Text("Move to \(moveTarget.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(AppTheme.cardAlternate, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 56)
                .padding(.bottom, 10)
            }
        }
    }
}

/// Underlines the matched prefix of every word, so a typo reads as the corrected one.
func highlighted(_ text: String, tokens: [String]) -> AttributedString {
    var attributed = AttributedString(text)
    guard !tokens.isEmpty else { return attributed }
    for token in tokens where token.count >= 2 {
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(of: token, options: [.caseInsensitive]) {
            attributed[found].underlineStyle = .single
            guard found.upperBound < attributed.endIndex else { break }
            searchRange = found.upperBound..<attributed.endIndex
        }
    }
    return attributed
}
