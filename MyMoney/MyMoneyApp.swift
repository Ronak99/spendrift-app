//
//  MyMoneyApp.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData
import AppIntents

// Add a run argument : -com.apple.CoreData.SQLDebug 1 to visualize the SQLite data

@main
struct MyMoneyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Ensure Shortcuts picks up newly added/changed intent parameters.
        Task {
            try? await ExpenseAppShortcuts.updateAppShortcutParameters()
        }
    }
    
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self],
                         inMemory: isUITesting)
    }
}

