//
//  AccountTransactionsView.swift
//  Spendrift
//
//  Created by Cursor on 05/04/26.
//

import SwiftData
import SwiftUI

struct AccountTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    let account: Account

    @State private var viewModel = TransactionViewModel()
    @State private var selectedTransaction: Transaction?
    @State private var showEditAccountSheet = false

    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.isPersisted &&
            transaction.account?.id == account.id &&
            transaction.date >= viewModel.periodStart &&
            transaction.date <= viewModel.periodEnd
        }
    }

    private var groupedTransactions: [String: [Transaction]] {
        transactions.groupedByDate
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if transactions.isEmpty {
                EmptyStateView(
                    icon: account.icon.systemImageName,
                    title: "No Transactions",
                    description: "No transactions in \(account.name) for \(viewModel.periodDescription)"
                )
            } else {
                List {
                    ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { dateKey in
                        let items = groupedTransactions[dateKey] ?? []
                        Section {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, transaction in
                                TransactionListItem(transaction: transaction)
                                    .listItemPositioned(index: index, count: items.count)
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
                .softScrollEdge()
            }
        }
        .scrollingHeaderBar {
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
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditAccountSheet = true
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
        .sheet(isPresented: $showEditAccountSheet) {
            UpdateAccountSheet(account: account)
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
        AccountTransactionsView(
            account: Account(
                name: "SBI Savings",
                balance: 50000,
                icon: .bankAccountOne
            )
        )
    }
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
