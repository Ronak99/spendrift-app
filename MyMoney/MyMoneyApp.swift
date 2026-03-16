//
//  MyMoneyApp.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

// Add a run argument : -com.apple.CoreData.SQLDebug 1 to visualize the SQLite data

@main
struct MyMoneyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self])
    }
}

