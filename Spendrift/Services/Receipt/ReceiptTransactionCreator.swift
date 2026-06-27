//
//  ReceiptTransactionCreator.swift
//  Spendrift
//
//  Maps a receipt-screenshot AI payload into a transaction (or a draft for the
//  "missing fields" review sheet). Reuses VoiceTransactionDraft and the same
//  review-sheet UI as the voice flow.
//

import Foundation
import SwiftData

enum ReceiptCreateResult {
    case created(Transaction)
    /// Needs the user to confirm/fill fields. `missingFields` is a user-facing list of
    /// labels (e.g. "Amount", "Category") that could not be determined automatically.
    case needsManualEntry(VoiceTransactionDraft, missingFields: [String], hint: String)
}

enum ReceiptTransactionCreator {
    /// Builds a draft from the AI payload, resolving primary account and matching a category.
    static func buildDraft(
        payload: OpenAIReceiptPayload,
        accounts: [Account],
        categories: [TransactionCategory]
    ) -> VoiceTransactionDraft {
        let transactionType = payload.transaction?.transactionType
            .flatMap { TransactionType(rawValue: $0) } ?? .expense

        let parsedDate = payload.transaction?.date
            .flatMap { OpenAIBankStatementService.parseDate($0) } ?? Date()

        let requiredType: TransactionType = transactionType == .income ? .income : .expense
        let categoryName = payload.transaction?.category ?? ""
        let category = categories.first(where: {
            $0.type == requiredType && $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
        })

        return VoiceTransactionDraft(
            notes: payload.transaction?.notes ?? "",
            amount: payload.transaction?.amount,
            date: parsedDate,
            transactionType: transactionType,
            account: VoiceTransactionCreator.resolvePrimaryAccount(from: accounts),
            category: category
        )
    }

    /// Must run on the main actor: mutates the SwiftUI environment's main-thread model context.
    @MainActor
    static func createFromReceipt(
        payload: OpenAIReceiptPayload,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) -> ReceiptCreateResult {
        if payload.status == "error" {
            let draft = VoiceTransactionDraft(
                notes: "",
                amount: nil,
                date: Date(),
                transactionType: .expense,
                account: VoiceTransactionCreator.resolvePrimaryAccount(from: accounts),
                category: nil
            )
            let reason = payload.reason ?? "Couldn't read this image. Add the details below to save."
            return .needsManualEntry(draft, missingFields: [], hint: reason)
        }

        let draft = buildDraft(payload: payload, accounts: accounts, categories: categories)

        var missing: [String] = []
        if !(draft.amount ?? 0 > 0) { missing.append("Amount") }
        if draft.account == nil { missing.append("Account") }
        if draft.category == nil { missing.append("Category") }
        if draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("Notes")
        }

        guard missing.isEmpty,
              let amount = draft.amount,
              let category = draft.category,
              let account = draft.account else {
            return .needsManualEntry(
                draft,
                missingFields: missing,
                hint: hintForMissing(missing)
            )
        }

        category.lastUsedAt = Date()
        account.lastUsedAt = Date()
        let transaction = Transaction(
            notes: draft.notes,
            amount: amount,
            date: draft.date,
            transactionType: draft.transactionType,
            category: category,
            account: account
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        Analytics.captureTransactionCreated(method: "receipt", type: draft.transactionType.rawValue)
        return .created(transaction)
    }

    static func hintForMissing(_ missing: [String]) -> String {
        guard !missing.isEmpty else {
            return "Review the details below, then save."
        }
        let list = missing.joined(separator: ", ")
        return "We pulled what we could from the receipt. Please add: \(list)."
    }
}
