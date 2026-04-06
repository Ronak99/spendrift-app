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
    @State private var showCreateSheet = false
    
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
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        ProfileSettingsToolbarButton()
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateAccountSheet(account: nil)
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
