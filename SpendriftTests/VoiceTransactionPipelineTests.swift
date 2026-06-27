//
//  VoiceTransactionPipelineTests.swift
//  SpendriftTests
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct VoiceTransactionPipelineTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self,
            Account.self,
            TransactionCategory.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test
    func decodeSuccessPayload() throws {
        let raw = """
        {
          "status": "success",
          "transaction": {
            "notes": "Cab fare",
            "amount": 120,
            "date": "2026-03-23T10:00:00Z",
            "transactionType": "expense",
            "category": "Transportation"
          }
        }
        """
        let data = try #require(raw.data(using: .utf8))
        let payload = try JSONDecoder().decode(VoiceTransactionPayload.self, from: data)
        #expect(payload.status == "success")
        #expect(payload.transaction?.amount == 120)
        #expect(payload.transaction?.transactionType == "expense")
    }

    @Test
    func creatorResolvesLegacyCategoryAlias() throws {
        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Metro ride",
                amount: 50,
                date: "2026-03-23T10:00:00Z",
                transactionType: "expense",
                category: "Transportation"
            ),
            reason: nil
        )
        let categories = [
            TransactionCategory(name: "Transport", type: .expense),
            TransactionCategory(name: "Shopping", type: .expense)
        ]
        let draftResult = VoiceTransactionCreator.buildDraftFromAIPayload(
            payload: payload,
            accounts: [],
            categories: categories
        )

        #expect(draftResult.failure == nil)
        #expect(draftResult.draft?.category?.name == "Transport")
    }

    @Test
    func creatorRejectsCategoryOutsideDynamicList() throws {
        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Metro ride",
                amount: 50,
                date: "2026-03-23T10:00:00Z",
                transactionType: "expense",
                category: "Unknown Category"
            ),
            reason: nil
        )
        let primary = Account(name: "SBI", balance: 1000, icon: .bankAccountOne, isPrimary: true)
        let categories = [
            TransactionCategory(name: "Transportation", type: .expense),
            TransactionCategory(name: "Shopping", type: .expense)
        ]
        let draftResult = VoiceTransactionCreator.buildDraftFromAIPayload(
            payload: payload,
            accounts: [primary],
            categories: categories
        )

        #expect(draftResult.failure == nil)
        #expect(draftResult.draft?.category == nil)
    }

    @MainActor
    @Test
    func creatorRequiresPrimaryAccount() throws {
        let context = try makeInMemoryContext()

        let account = Account(name: "SBI", balance: 1000, icon: .bankAccountOne, isPrimary: false)
        let category = TransactionCategory(name: "Transportation", type: .expense)
        context.insert(account)
        context.insert(category)

        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Cab",
                amount: 50,
                date: "2026-03-23T10:00:00Z",
                transactionType: "expense",
                category: "Transportation"
            ),
            reason: nil
        )
        let result = VoiceTransactionCreator.createFromAIVoice(
            payload: payload,
            accounts: [account],
            categories: [category],
            modelContext: context
        )

        switch result {
        case .needsManualEntry(_, let failure):
            #expect(failure == .noPrimaryAccount)
        default:
            Issue.record("Expected noPrimaryAccount failure.")
        }
    }

    @MainActor
    @Test
    func creatorParsesISODateWithoutTimezone() throws {
        let context = try makeInMemoryContext()
        let account = Account(name: "SBI", balance: 1000, icon: .bankAccountOne, isPrimary: true)
        let category = TransactionCategory(name: "Food", type: .expense)
        context.insert(account)
        context.insert(category)

        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Lunch",
                amount: 450,
                date: "2025-03-24T00:00:00",
                transactionType: "expense",
                category: "Food"
            ),
            reason: nil
        )

        let result = VoiceTransactionCreator.createFromAIVoice(
            payload: payload,
            accounts: [account],
            categories: [category],
            modelContext: context
        )

        switch result {
        case .created(let transaction):
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: transaction.date)
            #expect(components.year == 2025)
            #expect(components.month == 3)
            #expect(components.day == 24)
        default:
            Issue.record("Expected created transaction for valid date format.")
        }
    }

    @MainActor
    @Test
    func creatorFallsBackToNowForInvalidDateString() throws {
        let context = try makeInMemoryContext()
        let account = Account(name: "SBI", balance: 1000, icon: .bankAccountOne, isPrimary: true)
        let category = TransactionCategory(name: "Food", type: .expense)
        context.insert(account)
        context.insert(category)

        let now = Date()
        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Lunch",
                amount: 450,
                date: "not-a-date",
                transactionType: "expense",
                category: "Food"
            ),
            reason: nil
        )

        let result = VoiceTransactionCreator.createFromAIVoice(
            payload: payload,
            accounts: [account],
            categories: [category],
            modelContext: context
        )

        switch result {
        case .created(let transaction):
            #expect(abs(transaction.date.timeIntervalSince(now)) < 5)
        default:
            Issue.record("Expected created transaction with fallback date.")
        }
    }

    @Test
    func normalizerClipsPCMToConfiguredMaxDuration() {
        let bytesPerSecond = 44_100 * 1 * 16 / 8
        let overLimitPCM = Data(repeating: 1, count: (bytesPerSecond * 31) + 250)

        let clipped = VoiceShortcutAudioNormalizer.clipPCMToMaxDuration(overLimitPCM)

        #expect(clipped.count == bytesPerSecond * 30)
    }
}
