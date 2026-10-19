//
//  AnalyticsView.swift
//  Spendrift
//
//  The Analytics tab: one month of charts and insights, with the sheets those
//  blocks open. The month is shared with Transactions, so picking it on either
//  tab carries over.
//

import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @AppStorage("didFireFirstTransactionCreated") private var hasEverCreatedTransaction = false

    @Binding var month: MonthRef
    let onOpenTab: (HomeTab) -> Void

    @State private var showMonthPicker = false
    @State private var transactionToEdit: Transaction?
    @State private var showCreateTransaction = false
    /// The category whose transactions are listed, drilled into from the spend rows.
    @State private var categoryDrill: TransactionCategory?

    private let today = Date()

    var body: some View {
        NavigationStack {
            HomeAnalyticsPane(
                transactions: transactions,
                month: month,
                today: today,
                onPickMonth: { showMonthPicker = true },
                onShowCategoryTransactions: openCategoryDrill,
                onOpenTransaction: { transactionToEdit = $0 },
                onOpenTab: onOpenTab,
                onAddTransaction: { showCreateTransaction = true }
            )
            .softScrollEdge()
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                LedgerToolbar(
                    title: HomeTab.analytics.title,
                    addAccessibilityLabel: "Add transaction",
                    addAccessibilityIdentifier: "analyticsAddButton",
                    onAdd: { showCreateTransaction = true }
                )
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerSheet(
                    selection: month,
                    earliestYear: earliestYear,
                    today: today
                ) { picked in
                    month = picked
                }
            }
            .sheet(item: $transactionToEdit) { transaction in
                UpdateTransactionSheet(transaction: transaction)
            }
            .sheet(isPresented: $showCreateTransaction) {
                UpdateTransactionSheet(
                    transaction: nil,
                    quickStartFirstTransaction: !hasEverCreatedTransaction
                )
            }
            .sheet(item: $categoryDrill) { category in
                CategoryTransactionsSheet(category: category, initialDate: monthAnchorDate)
            }
        }
    }

    /// The drill sheet reads the persisted period scope, so pin it to a month first,
    /// or a saved week or year window would hide the rest of the month this tab was showing.
    private func openCategoryDrill(_ category: TransactionCategory) {
        TransactionViewModel().periodGranularity = .month
        categoryDrill = category
    }

    /// Where period-based screens open for the shared month: today while it is the
    /// current month, so a week or day window lands on now, else the month's first day.
    private var monthAnchorDate: Date {
        month.contains(today) ? today : month.dateRange().lowerBound
    }

    private var earliestYear: Int {
        transactions.last(where: \.isPersisted)?.date.year ?? today.year
    }
}

#Preview {
    AnalyticsView(month: .constant(MonthRef.of(Date())), onOpenTab: { _ in })
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
