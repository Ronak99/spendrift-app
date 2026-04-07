//
//  CategoryTransactionsView.swift
//  MyMoney
//
//  Created by Cursor on 05/04/26.
//

import SwiftData
import SwiftUI

struct CategoryTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    let category: TransactionCategory

    @State private var viewModel = TransactionViewModel()
    @State private var selectedTransaction: Transaction?
    @State private var showEditCategorySheet = false

    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.category?.id == category.id &&
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
                    icon: category.icon.systemImageName,
                    title: "No Transactions",
                    description: "No transactions in \(category.name) for \(viewModel.selectedDate.monthYear)"
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditCategorySheet = true
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
        .sheet(isPresented: $showEditCategorySheet) {
            UpdateCategorySheet(category: category)
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
