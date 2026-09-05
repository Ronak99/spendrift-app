//
//  CategoryTransactionsView.swift
//  Spendrift
//
//  Created by Cursor on 05/04/26.
//

import SwiftData
import SwiftUI

struct CategoryTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    let category: TransactionCategory

    @State private var viewModel: TransactionViewModel
    @State private var selectedTransaction: Transaction?

    /// `initialDate` seeds the period window so drill-downs (e.g. from Analytics)
    /// open on the same range the caller was viewing. The period granularity is
    /// app-wide and read from `TransactionViewModel`, so the anchor date is enough.
    init(category: TransactionCategory, initialDate: Date = Date()) {
        self.category = category
        let viewModel = TransactionViewModel()
        viewModel.selectedDate = initialDate
        _viewModel = State(initialValue: viewModel)
    }

    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.isPersisted &&
            transaction.category?.id == category.id &&
            transaction.date >= viewModel.periodStart &&
            transaction.date <= viewModel.periodEnd
        }
    }

    private var groupedTransactions: [String: [Transaction]] {
        transactions.groupedByDate
    }

    var body: some View {
        VStack(spacing: 0) {
            CapsuleDateSelector(
                period: $viewModel.periodGranularity,
                title: viewModel.capsuleTitle,
                date: viewModel.selectedDate,
                isCurrentPeriod: viewModel.isCurrentPeriod,
                onPrevious: { viewModel.decrementPeriod() },
                onNext: { viewModel.incrementPeriod() },
                onToday: { viewModel.goToCurrentPeriod() },
                onJumpToDate: { viewModel.goToDate($0) }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if transactions.isEmpty {
                EmptyStateView(
                    icon: category.icon.systemImageName,
                    title: "No Transactions",
                    description: "No transactions in \(category.name) for \(viewModel.periodDescription)"
                )
            } else {
                List {
                    ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { dateKey in
                        Section {
                            ForEach(groupedTransactions[dateKey] ?? [], id: \.id) { transaction in
                                TransactionListItem(transaction: transaction)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                    }
                            }
                            .onDelete { indexSet in
                                deleteTransactions(at: indexSet, for: dateKey)
                            }
                        } header: {
                            Text(dateKey)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTransaction) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
    }

    private func deleteTransactions(at offsets: IndexSet, for dateKey: String) {
        guard let transactionsForDate = groupedTransactions[dateKey] else { return }

        for index in offsets {
            modelContext.delete(transactionsForDate[index])
        }

        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        CategoryTransactionsView(
            category: TransactionCategory(
                name: "Food",
                type: .expense,
                icon: .food
            )
        )
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self, Account.self], inMemory: true)
}
