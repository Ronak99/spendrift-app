//
//  ContentView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("themeColor") private var themeColorName: String = "Blue"
    @State private var selectedTab = 0
    @State private var showCreateTransaction = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }
                .tag(0)
            AccountsView()
                .tabItem {
                    Image(systemName: "creditcard")
                    Text("Accounts")
                }
                .tag(1)
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Categories")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(Color.themeColors[themeColorName] ?? .blue)
        .onAppear {
            QuickActionsManager.setupQuickActions()
        }
        .onOpenURL { url in
            handleQuickAction(url: url)
        }
        .sheet(isPresented: $showCreateTransaction) {
            UpdateTransactionSheet(transaction: nil)
        }
    }
    
    private func handleQuickAction(url: URL) {
        guard url.scheme == "mymoney" else { return }
        
        switch url.host {
        case "createTransaction":
            showCreateTransaction = true
            selectedTab = 0
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
