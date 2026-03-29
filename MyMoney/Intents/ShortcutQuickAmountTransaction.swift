//
//  ShortcutQuickAmountTransaction.swift
//  MyMoney
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

    /// Inserts an expense on the primary account with no category (uncategorized).
    @discardableResult
    static func create(
        amount: Double,
        notes: String,
        modelContext: ModelContext,
        accounts: [Account]
    ) throws -> Transaction {
        guard amount > 0 else { throw Failure.invalidAmount }
        guard let primary = VoiceTransactionCreator.resolvePrimaryAccount(from: accounts) else {
            throw Failure.noPrimaryAccount
        }
        let transaction = Transaction(
            notes: notes,
            amount: amount,
            date: Date(),
            transactionType: .expense,
            category: nil,
            account: primary
        )
        modelContext.insert(transaction)
        try modelContext.save()
        return transaction
    }
}
