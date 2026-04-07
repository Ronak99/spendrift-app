//
//  AccountTransactionsView.swift
//  MyMoney
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
            transaction.account?.id == account.id &&
            transaction.date >= viewModel.startOfMonth &&
            transaction.date <= viewModel.endOfMonth
        }
    }

    private var groupedTransactions: [String: [Transaction]] {
        transactions.groupedByDate
    }

    var body: some View {
        VStack(spacing: 0) {
            CapsuleDateSelector(
                date: viewModel.selectedDate,
                onPrevious: { viewModel.decrementMonth() },
                onNext: { viewModel.incrementMonth() }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if transactions.isEmpty {
                EmptyStateView(
                    icon: account.icon.systemImageName,
                    title: "No Transactions",
                    description: "No transactions in \(account.name) for \(viewModel.selectedDate.monthYear)"
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
