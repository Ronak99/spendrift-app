//
//  AccountsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @State private var viewModel = AccountViewModel()
    @State private var showCreateSheet = false
    @State private var selectedAccount: Account?
    
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
                            AccountListItem(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAccount = account
                                }
                        }
                        .onDelete { indexSet in
                            deleteAccounts(at: indexSet)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateAccountSheet(account: nil)
            }
            .sheet(item: $selectedAccount) { account in
                UpdateAccountSheet(account: account)
            }
        }
    }
    
    private func deleteAccounts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(accounts[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: [Account.self], inMemory: true)
}
