//
//  ShortcutQuickAmountTransaction.swift
//  Spendrift
//
//  Created by Cursor on 30/03/26.
//

import Foundation
import SwiftData

enum ShortcutQuickAmountTransaction {
    enum Failure: Error, Equatable {
        case invalidAmount
        case noPrimaryAccount
    }

    @discardableResult
    static func create(
        amount: Double,
        notes: String,
        category: TransactionCategory?,
        modelContext: ModelContext,
        accounts: [Account]
    ) throws -> Transaction {
        guard amount > 0 else { throw Failure.invalidAmount }
        guard let primary = accounts.first(where: { $0.isPrimary }) else {
            throw Failure.noPrimaryAccount
        }
        category?.lastUsedAt = Date()
        let transaction = Transaction(
            notes: notes,
            amount: amount,
            date: Date(),
            transactionType: .expense,
            category: category,
            account: primary,
            source: "shortcut"
        )
        modelContext.insert(transaction)
        try modelContext.save()
        // Keys must match `AudienceTags.StoreKey` in the main app. The widget
        // target cannot import OneSignal, so it only writes the App Group flags.
        let suite = UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
        suite.set(true, forKey: "audience.hasTransaction")
        suite.set(true, forKey: "audience.usedTypedShortcut")
        suite.set(suite.integer(forKey: "audience.txCount") + 1, forKey: "audience.txCount")
        return transaction
    }
}
