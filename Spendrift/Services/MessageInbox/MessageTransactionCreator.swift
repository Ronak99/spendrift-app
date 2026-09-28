//
//  MessageTransactionCreator.swift
//  Spendrift
//
//  Maps a parsed SMS or email AI result into a ledger Transaction on the primary account.
//

import Foundation
import SwiftData

enum MessageTransactionCreator {
    enum Outcome: Equatable {
        case created(UUID)
        case skippedDuplicate
        case rejected
        case failed
    }

    /// Inserts a transaction when the AI result is a success and not a near-duplicate.
    @MainActor
    static func createIfNeeded(
        result: MessageParseResultItem,
        capturedAt: Date,
        accounts: [Account],
        categories: [TransactionCategory],
        existingTransactions: [Transaction],
        modelContext: ModelContext,
        source: TransactionSource = .sms
    ) -> Outcome {
        guard result.status == "success", let data = result.transaction else {
            return .rejected
        }
        guard data.amount > 0 else { return .failed }
        guard let account = VoiceTransactionCreator.resolvePrimaryAccount(from: accounts) else {
            return .failed
        }

        let transactionType = TransactionType.resolved(from: data.transactionType)
        let date = capturedAt

        if isNearDuplicate(
            amount: data.amount,
            date: date,
            type: transactionType,
            account: account,
            existing: existingTransactions
        ) {
            return .skippedDuplicate
        }

        let category = CategoryResolver.resolve(
            categoryName: data.category,
            notes: data.notes,
            type: transactionType,
            categories: categories
        )

        category?.lastUsedAt = Date()
        account.lastUsedAt = Date()

        let transaction = Transaction(
            notes: data.notes,
            amount: data.amount,
            date: date,
            transactionType: transactionType,
            category: category,
            account: account,
            source: source.rawValue
        )
        modelContext.insert(transaction)
        return .created(transaction.id)
    }

    static func isNearDuplicate(
        amount: Double,
        date: Date,
        type: TransactionType,
        account: Account,
        existing: [Transaction]
    ) -> Bool {
        let calendar = Calendar.current
        return existing.contains { txn in
            guard txn.account?.id == account.id else { return false }
            guard txn.transactionType == type else {
                return false
            }
            guard abs(txn.amount - amount) < 0.000_1 else { return false }
            return calendar.isDate(txn.date, inSameDayAs: date)
        }
    }
}
