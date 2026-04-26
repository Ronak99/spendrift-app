//
//  AccountsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var showCreateSheet = false
    @State private var pendingDeletedAccountIDs: Set<UUID> = []

    private var totalBalanceAllAccounts: Double {
        visibleAccounts.reduce(0) { $0 + $1.currentBalance }
    }

    private var visibleAccounts: [Account] {
        accounts.filter { !pendingDeletedAccountIDs.contains($0.id) }
    }

    private var expenseSoFar: Double {
        allTransactions.totalExpenses
    }

    private var incomeSoFar: Double {
        allTransactions.totalIncome
    }

    /// Match Transactions: round summary figures when there are many transactions.
    private var usesRoundedSummary: Bool {
        allTransactions.count > 10
    }

    private var formattedExpenseSoFar: String {
        usesRoundedSummary ? expenseSoFar.formatCurrencyRounded : expenseSoFar.formatCurrency
    }

    private var formattedIncomeSoFar: String {
        usesRoundedSummary ? incomeSoFar.formatCurrencyRounded : incomeSoFar.formatCurrency
    }

    private var formattedTotalBalance: String {
        totalBalanceAllAccounts.formatCurrency
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("All accounts")
                                .font(.headline)
                            Spacer()
                            Text(formattedTotalBalance)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expense so far")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedExpenseSoFar)
                                    .font(.headline)
                                    .foregroundStyle(.red)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Income so far")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedIncomeSoFar)
                                    .font(.headline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(visibleAccounts) { account in
                        NavigationLink {
                            AccountTransactionsView(account: account)
                        } label: {
                            AccountListItem(account: account)
                        }
                    }
                    .onDelete { indexSet in
                        deleteAccounts(at: indexSet)
                    }
                } header: {
                    Text("Your accounts")
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if visibleAccounts.isEmpty {
                    EmptyStateView(
                        icon: "creditcard",
                        title: "No Accounts",
                        description: "Add your first bank account or wallet to get started",
                        actionTitle: "Add Account",
                        action: { showCreateSheet = true }
                    )
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        ProfileSettingsToolbarButton()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateAccountSheet(account: nil)
            }
            .onChange(of: accounts.map(\.id)) { _, accountIDs in
                pendingDeletedAccountIDs.formIntersection(Set(accountIDs))
            }
        }
    }
    
    private func deleteAccounts(at offsets: IndexSet) {
        let accountsToDelete = offsets.compactMap { index in
            visibleAccounts.indices.contains(index) ? visibleAccounts[index] : nil
        }
        guard !accountsToDelete.isEmpty else { return }

        let deletedAccountIDs = Set(accountsToDelete.map(\.id))

        // Hide rows from ForEach immediately so the section item-count stays consistent.
        pendingDeletedAccountIDs.formUnion(deletedAccountIDs)

        // Mark objects for deletion in the context.  We intentionally do NOT call
        // save() here: committing to the store detaches the backing data of the
        // deleted objects, and SwiftUI's row-removal animation still holds live
        // references to those AccountListItem views (which access .icon, .name,
        // etc.).  Deferring the save lets the animation complete before the
        // backing data is torn down.
        for account in accountsToDelete {
            modelContext.delete(account)
        }

        Task { @MainActor in
            // 0.45 s covers the default list row-removal animation (~0.3 s) with
            // a small buffer before we commit the deletion to the store.
            try? await Task.sleep(for: .milliseconds(450))
            do {
                try modelContext.save()
            } catch {
                // Rollback and restore visibility on failure.
                modelContext.rollback()
                pendingDeletedAccountIDs.subtract(deletedAccountIDs)
            }
        }
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
