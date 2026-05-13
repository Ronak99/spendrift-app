//
//  VoiceTransactionCreator.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import SwiftData

struct VoiceTransactionDraft {
    let notes: String
    let amount: Double?
    let date: Date
    let transactionType: TransactionType
    let account: Account?
    let category: TransactionCategory?
}

enum VoiceCreateFailure: Equatable {
    case aiError(String)
    case invalidJSON
    case noPrimaryAccount
    case noCategoriesForType
    case amountMissing
    case categoryMissing
    case unknownType
    case invalidDate
}

enum VoiceCreateResult {
    case created(Transaction)
    case needsConfirmation(VoiceTransactionDraft, reason: String)
    case needsManualEntry(VoiceTransactionDraft, failure: VoiceCreateFailure)
}

enum VoiceTransactionCreator {
    static func buildDraftFromAIPayload(
        payload: OpenAIVoiceTransactionPayload,
        accounts: [Account],
        categories: [TransactionCategory]
    ) -> (draft: VoiceTransactionDraft?, failure: VoiceCreateFailure?) {
        if payload.status == "error" {
            return (nil, .aiError(payload.reason ?? "Unknown AI parsing error"))
        }

        guard payload.status == "success", let transaction = payload.transaction else {
            return (nil, .invalidJSON)
        }

        guard let transactionType = TransactionType(rawValue: transaction.transactionType) else {
            return (nil, .unknownType)
        }
        let parsedDate = parseTransactionDate(transaction.date) ?? Date()

        let typeCategory: TransactionType = transactionType == .expense ? .expense : .income
        let category = categories.first(where: {
            $0.type == typeCategory && $0.name.caseInsensitiveCompare(transaction.category ?? "") == .orderedSame
        })
        let primary = resolvePrimaryAccount(from: accounts)

        return (
            VoiceTransactionDraft(
                notes: transaction.notes,
                amount: transaction.amount,
                date: parsedDate,
                transactionType: transactionType,
                account: primary,
                category: category
            ),
            nil
        )
    }

    static func createFromAIVoice(
        payload: OpenAIVoiceTransactionPayload,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) -> VoiceCreateResult {
        let buildResult = buildDraftFromAIPayload(payload: payload, accounts: accounts, categories: categories)
        if let failure = buildResult.failure {
            let fallbackDraft = VoiceTransactionDraft(
                notes: payload.transaction?.notes ?? "",
                amount: payload.transaction?.amount,
                date: Date(),
                transactionType: TransactionType(rawValue: payload.transaction?.transactionType ?? "") ?? .expense,
                account: resolvePrimaryAccount(from: accounts),
                category: nil
            )
            return .needsManualEntry(fallbackDraft, failure: failure)
        }

        guard let draft = buildResult.draft else {
            return .needsManualEntry(
                VoiceTransactionDraft(notes: "", amount: nil, date: Date(), transactionType: .expense, account: nil, category: nil),
                failure: .invalidJSON
            )
        }

        guard let amount = draft.amount, amount > 0 else {
            return .needsManualEntry(draft, failure: .amountMissing)
        }
        guard draft.account != nil else {
            return .needsManualEntry(draft, failure: .noPrimaryAccount)
        }
        let requiredType: TransactionType = draft.transactionType == .expense ? .expense : .income
        let typeCategories = categories.filter { $0.type == requiredType }
        guard !typeCategories.isEmpty else {
            return .needsManualEntry(draft, failure: .noCategoriesForType)
        }
        guard draft.category != nil else {
            return .needsManualEntry(draft, failure: .categoryMissing)
        }

        draft.category?.lastUsedAt = Date()
        draft.account?.lastUsedAt = Date()
        let transaction = Transaction(
            notes: draft.notes,
            amount: amount,
            date: draft.date,
            transactionType: draft.transactionType,
            category: draft.category,
            account: draft.account
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        return .created(transaction)
    }

    static func resolvePrimaryAccount(from accounts: [Account]) -> Account? {
        if let explicitPrimary = accounts.first(where: { $0.isPrimary }) {
            return explicitPrimary
        }
        return nil
    }

    private static func parseTransactionDate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
