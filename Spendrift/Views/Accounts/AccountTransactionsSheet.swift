//
//  AccountTransactionsSheet.swift
//  Spendrift
//
//  Colour-wash ledger of one account's transactions. Atmosphere, date
//  capsule, enamel empty state, and row chrome match the Accounts tab
//  and the Transactions list. Pushed from the account editor.
//

import SwiftData
import SwiftUI

struct AccountTransactionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    let account: Account

    @State private var viewModel = TransactionViewModel()
    @State private var selectedTransaction: Transaction?

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var washColor: Color {
        AccountEnamel.color(for: account.icon)
    }

    private var transactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.isPersisted &&
            transaction.account?.id == account.id &&
            transaction.date >= viewModel.periodStart &&
            transaction.date <= viewModel.periodEnd
        }
    }

    private var groupedTransactions: [(dayStart: Date, title: String, transactions: [Transaction])] {
        transactions.groupedByDateRecentFirst
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if transactions.isEmpty {
                emptyLedger
            } else {
                transactionList
            }
        }
        .background { atmosphere }
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .sheet(item: $selectedTransaction) { transaction in
            UpdateTransactionSheet(transaction: transaction)
        }
    }

    // MARK: Atmosphere

    private var atmosphere: some View {
        CategoryTrayAtmosphere(washColor: washColor)
            .ignoresSafeArea()
    }

    // MARK: List

    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.dayStart) { section in
                Section {
                    ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            TransactionListItem(transaction: transaction)
                                .listItemPositioned(index: index, count: section.transactions.count)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        deleteTransactions(at: indexSet, in: section.transactions)
                    }
                } header: {
                    Text(section.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .softScrollEdge()
    }

    // MARK: Empty

    private var emptyLedger: some View {
        VStack(spacing: 16) {
            CategoryEnamelTile(
                systemImage: account.icon.systemImageName,
                color: washColor
            )
            .frame(width: 88, height: 88)
            .padding(.top, 28)

            Text("No transactions")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(heroPrimary)

            Text("No transactions in \(account.name) for \(viewModel.periodDescription).")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: Behaviour

    private func deleteTransactions(at offsets: IndexSet, in items: [Transaction]) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        AccountTransactionsSheet(
            account: Account(
                name: "SBI Savings",
                balance: 50000,
                icon: .bankAccountOne,
                isPrimary: true
            )
        )
    }
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
