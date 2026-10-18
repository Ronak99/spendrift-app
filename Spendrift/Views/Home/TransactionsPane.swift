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
                EmptyStateContainer {
                    emptyLedger
                }
                .homeTrayClearance()
            } else {
                List {
                    ForEach(days, id: \.dayStart) { section in
                        daySection(section)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                // Air between the header bar and the first day, scrolling with the rows.
                .contentMargins(.top, 12, for: .scrollContent)
                .homeTrayClearance()
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

    /// Same row as Home's empty Recent card. "First" only while the whole ledger is
    /// empty: a quiet month in an active ledger asks for one in that month instead.
    private var emptyLedger: some View {
        let isLedgerEmpty = !transactions.contains(where: \.isPersisted)

        return HomeCard {
            AddTransactionRow(
                title: isLedgerEmpty ? "Add your first transaction" : "Add a transaction",
                subtitle: isLedgerEmpty
                    ? "Every expense and income you log lands here"
                    : "Nothing logged in \(month.name) \(String(month.year)) yet",
                action: onAddTransaction
            )
        }
    }
}
