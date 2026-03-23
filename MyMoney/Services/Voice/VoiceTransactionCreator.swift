//
//  VoiceTransactionCreator.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import SwiftData

struct VoiceTransactionDraft {
    let notes: String
    let amount: Double?
    let transactionType: TransactionType
    let account: Account?
    let category: TransactionCategory?
}

enum VoiceCreateFailure: Equatable {
    case noPrimaryAccount
    case noCategoriesForType
    case amountMissing
    case categoryMissing
    case unknownType
}

enum VoiceCreateResult {
    case created(Transaction)
    case needsConfirmation(VoiceTransactionDraft, reason: String)
    case needsManualEntry(VoiceTransactionDraft, failure: VoiceCreateFailure)
}

enum VoiceTransactionCreator {
    static let highConfidenceThreshold = 0.85
    static let mediumConfidenceThreshold = 0.60

    static func buildDraft(
        intent: ParsedTransactionIntent,
        match: CategoryMatchResult,
        accounts: [Account],
        categories: [TransactionCategory]
    ) -> VoiceTransactionDraft {
        let type = intent.transactionType ?? .expense
        let primary = resolvePrimaryAccount(from: accounts)
        let category = match.category ?? categories.first(where: { $0.type == (type == .expense ? .expense : .income) })

        return VoiceTransactionDraft(
            notes: intent.notes,
            amount: intent.amount,
            transactionType: type,
            account: primary,
            category: category
        )
    }

    static func createFromVoice(
        intent: ParsedTransactionIntent,
        match: CategoryMatchResult,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) -> VoiceCreateResult {
        let draft = buildDraft(intent: intent, match: match, accounts: accounts, categories: categories)

        guard intent.transactionType != nil else {
            return .needsManualEntry(draft, failure: .unknownType)
        }
        guard let amount = draft.amount, amount > 0 else {
            return .needsManualEntry(draft, failure: .amountMissing)
        }
        guard draft.account != nil else {
            return .needsManualEntry(draft, failure: .noPrimaryAccount)
        }
        let requiredType: CategoryType = draft.transactionType == .expense ? .expense : .income
        let typeCategories = categories.filter { $0.type == requiredType }
        guard !typeCategories.isEmpty else {
            return .needsManualEntry(draft, failure: .noCategoriesForType)
        }
        guard draft.category != nil else {
            return .needsManualEntry(draft, failure: .categoryMissing)
        }

        let overallConfidence = combinedConfidence(intent: intent, categoryConfidence: match.confidence)
        if overallConfidence < mediumConfidenceThreshold {
            return .needsManualEntry(draft, failure: .categoryMissing)
        }
        if overallConfidence < highConfidenceThreshold {
            return .needsConfirmation(draft, reason: "Medium confidence transcript parsing")
        }

        let transaction = Transaction(
            notes: draft.notes,
            amount: amount,
            date: Date(),
            transactionType: draft.transactionType,
            category: draft.category,
            account: draft.account
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        return .created(transaction)
    }

    static func combinedConfidence(intent: ParsedTransactionIntent, categoryConfidence: Double) -> Double {
        min(1.0, (intent.confidence * 0.6) + (categoryConfidence * 0.4))
    }

    static func resolvePrimaryAccount(from accounts: [Account]) -> Account? {
        if let explicitPrimary = accounts.first(where: { $0.isPrimary }) {
            return explicitPrimary
        }
        return nil
    }
}
