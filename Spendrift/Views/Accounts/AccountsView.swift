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
                    if accounts.isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            title: "No Accounts",
                            description: "Add your first bank account or wallet to get started",
                            actionTitle: "Add Account",
                            action: { showCreateSheet = true }
                        )
                    } else {
                        List {
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
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !accounts.isEmpty {
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
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
    let container = try! ModelContainer(
        for: Transaction.self, Account.self, TransactionCategory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let sampleAccounts = [
        Account(name: "SBI Savings", balance: 85420.50, icon: .bankAccountOne, isPrimary: true),
        Account(name: "HDFC Salary", balance: 142_300, icon: .bankAccountFour),
        Account(name: "ICICI Credit Card", balance: -12_450.75, icon: .mastercard),
        Account(name: "Cash", balance: 3_200, icon: .cash),
        Account(name: "PhonePe Wallet", balance: 850, icon: .wallet),
        Account(name: "Fixed Deposit", balance: 250_000, icon: .savings),
    ]
    for account in sampleAccounts {
        context.insert(account)
    }

    return AccountsView()
        .modelContainer(container)
}
