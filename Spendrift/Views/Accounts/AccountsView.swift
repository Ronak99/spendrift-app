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

    private var totalBalanceAllAccounts: Double {
        accounts.reduce(0) { $0 + $1.currentBalance }
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
            Group {
                List {
                    if accounts.isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            title: "No Accounts",
                            description: "Add your first bank account or wallet to get started",
                            actionTitle: "Add Account",
                            action: { showCreateSheet = true }
                        )
                        .padding(.top, 150)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        
                        Section {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
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
                        }
                        ForEach(accounts) { account in
                            NavigationLink {
                                AccountTransactionsView(account: account)
                            } label: {
                                AccountListItem(account: account)
                            }
                        }
                        .onDelete { indexSet in
                            deleteAccounts(at: indexSet)
                        }
                    }
                    
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if !accounts.isEmpty {
                            Button(action: { showCreateSheet = true }) {
                                Image(systemName: "plus")
                            }
                        }
                        ProfileSettingsToolbarButton()
                    }
                    .padding(.horizontal, accounts.isEmpty ? 0 : 8)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateAccountSheet(account: nil)
            }
        }
    }
    
    private func deleteAccounts(at offsets: IndexSet) {
        let deleteIndices = Set(offsets)
        let toDelete: [Account] = offsets.sorted().map { accounts[$0] }
        
        if let primaryIndex = accounts.firstIndex(where: { $0.isPrimary }),
           deleteIndices.contains(primaryIndex) {
            let remainingIndices = (0..<accounts.count).filter { !deleteIndices.contains($0) }
            let newPrimaryIndex = remainingIndices.filter { $0 > primaryIndex }.min()
                ?? remainingIndices.filter { $0 < primaryIndex }.max()
            if let newIdx = newPrimaryIndex {
                let newId = accounts[newIdx].id
                for a in accounts {
                    a.isPrimary = (a.id == newId)
                }
            }
        }
        
        for account in toDelete {
            Analytics.capture(.accountDeleted, [Analytics.Key.name: account.name])
            modelContext.delete(account)
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
        }
    }
}

#Preview {
    AccountsView()
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
