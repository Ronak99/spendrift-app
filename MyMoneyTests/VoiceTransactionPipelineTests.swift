//
//  VoiceTransactionPipelineTests.swift
//  MyMoneyTests
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import SwiftData
import Testing
@testable import MyMoney

struct VoiceTransactionPipelineTests {
    @Test
    func decodeOpenAISuccessPayload() throws {
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
        let payload = try JSONDecoder().decode(OpenAIVoiceTransactionPayload.self, from: data)
        #expect(payload.status == "success")
        #expect(payload.transaction?.amount == 120)
        #expect(payload.transaction?.transactionType == "expense")
    }

    @Test
    func creatorRejectsCategoryOutsideDynamicList() throws {
        let payload = OpenAIVoiceTransactionPayload(
            status: "success",
            transaction: OpenAIVoiceTransaction(
                notes: "Metro ride",
                amount: 50,
                date: "2026-03-23T10:00:00Z",
                transactionType: "expense",
                category: "Unknown Category"
            ),
            reason: nil
        )
        let primary = Account(name: "SBI", balance: 1000, icon: .sbi, isPrimary: true)
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

    @Test
    func creatorRequiresPrimaryAccount() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self,
            Account.self,
            TransactionCategory.self,
            configurations: config
        )
        let context = ModelContext(container)

        let account = Account(name: "SBI", balance: 1000, icon: .sbi, isPrimary: false)
        let category = TransactionCategory(name: "Transportation", type: .expense)
        context.insert(account)
        context.insert(category)

        let payload = OpenAIVoiceTransactionPayload(
            status: "success",
            transaction: OpenAIVoiceTransaction(
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
}
