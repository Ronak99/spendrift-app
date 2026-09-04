//
//  IntentSwiftData.swift
//  Spendrift
//
//  Created by Cursor on 30/03/26.
//

import Foundation
import SwiftData

enum IntentSwiftData {
    static let appGroupID = "group.com.ronakpunase.Spendrift"

    /// Shared SwiftData container used by the main app, App Intents, and the widget extension.
    /// Uses the App Group container so all processes share the same on-disk store.
    static func makeModelContainer() throws -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])

        if inMemory {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent("Spendrift.sqlite")
            let config = ModelConfiguration(
                url: storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        // Fallback: App Group entitlement not yet configured — uses default container.
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
