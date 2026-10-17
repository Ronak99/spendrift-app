//
//  TransactionsPane.swift
//  Spendrift
//
//  One month of the ledger, grouped by day. There is no period capsule: while this
//  tab is selected its own label reads the month and opens the picker, so the whole
//  width goes to the rows. A row swipes left to delete, as it always has.
//

import SwiftUI

struct TransactionsPane: View {
    let transactions: [Transaction]
    let month: MonthRef
    let today: Date
    var onOpenTransaction: (Transaction) -> Void
    var onAddTransaction: () -> Void
    var onDelete: (Transaction) -> Void
    var onScroll: (CGFloat) -> Void

    private var monthTransactions: [Transaction] {
        let range = month.dateRange()
        return transactions.filter { transaction in
            transaction.isPersisted && range.contains(transaction.date)
        }
    }

    var body: some View {
        let days = monthTransactions.groupedByDateRecentFirst

        return Group {
            if days.isEmpty {
                ScrollView {
                    emptyLedger
                }
                .scrollIndicators(.hidden)
                .homeTrayClearance()
                .reportingScrollOffset(onScroll)
            } else {
                List {
                    ForEach(days, id: \.dayStart) { section in
                        daySection(section)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .homeTrayClearance()
                .reportingScrollOffset(onScroll)
            }
        }
    }

    private func daySection(
        _ section: (dayStart: Date, title: String, transactions: [Transaction])
    ) -> some View {
        Section {
            ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, transaction in
                row(transaction, index: index, count: section.transactions.count)
            }
        } header: {
            Text(section.title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.1)
                .textCase(nil)
                .foregroundStyle(AppTheme.inkSecondary)
        }
    }

    private func row(_ transaction: Transaction, index: Int, count: Int) -> some View {
        Button {
            onOpenTransaction(transaction)
        } label: {
            TransactionListItem(transaction: transaction)
                .listItemPositioned(index: index, count: count)
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.card)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier(transaction.notes)
    }

    private var emptyLedger: some View {
        VStack(spacing: 0) {
            EnamelBadge(
                systemImage: "tray.fill",
                color: CategoryEnamel.uncategorized,
                side: 72,
                showsShadow: true
            )
            .padding(.top, 40)

            Text("No transactions")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .padding(.top, 16)

            Text("Add one for \(month.name) \(String(month.year)).")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button(action: onAddTransaction) {
                Text("Add transaction")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
