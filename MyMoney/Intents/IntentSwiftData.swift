//
//  IntentSwiftData.swift
//  MyMoney
//
//  Created by Cursor on 30/03/26.
//

import Foundation
import SwiftData

enum IntentSwiftData {
    /// Same store configuration as `MyMoneyApp` / `QuickAmountExpenseIntent` so intents read the user’s data.
    static func makeModelContainer() throws -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
