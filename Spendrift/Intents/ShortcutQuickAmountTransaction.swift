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

    /// Inserts an expense on the primary account. Pass `category: nil` for uncategorized.
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
        primary.lastUsedAt = Date()
        let transaction = Transaction(
            notes: notes,
            amount: amount,
            date: Date(),
            transactionType: .expense,
            category: category,
            account: primary,
            source: TransactionSource.shortcut.rawValue
        )
        modelContext.insert(transaction)
        try modelContext.save()
        AudienceTags.recordTypedShortcutSuccess()
        return transaction
    }
}
