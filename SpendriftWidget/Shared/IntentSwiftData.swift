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
    static let cloudKitContainerID = "iCloud.com.ronakpunase.Spendrift"

    static func makeModelContainer(cloudKitSyncEnabled: Bool = false) throws -> ModelContainer {
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
                cloudKitDatabase: cloudKitSyncEnabled ? .private(cloudKitContainerID) : .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
