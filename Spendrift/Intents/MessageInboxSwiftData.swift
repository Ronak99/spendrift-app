//
//  MessageInboxSwiftData.swift
//  Spendrift
//
//  Separate SwiftData container for SMS capture inbox.
//  Same App Group as the ledger, distinct file, CloudKit always off.
//

import Foundation
import SwiftData

enum MessageInboxSwiftData {
    static let storeFileName = "SpendriftMessages.sqlite"

    static func makeModelContainer() throws -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let schema = Schema([CapturedTransactionMessage.self])

        if inMemory {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IntentSwiftData.appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent(storeFileName)
            let config = ModelConfiguration(
                url: storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
