//
//  VoiceServiceTests.swift
//  SpendriftTests
//
//  Created by Cursor on 23/03/26.
//

import Foundation
import Testing
@testable import Spendrift

struct VoiceServiceTests {
    @Test
    func decodeErrorPayload() throws {
        let raw = """
        {
          "status": "error",
          "reason": "Could not extract amount."
        }
        """
        let data = try #require(raw.data(using: .utf8))
        let payload = try JSONDecoder().decode(VoiceTransactionPayload.self, from: data)
        #expect(payload.status == "error")
        #expect(payload.transaction == nil)
        #expect(payload.reason == "Could not extract amount.")
    }

    @Test
    func creatorAcceptsValidAISuccessPayload() {
        let payload = VoiceTransactionPayload(
            status: "success",
            transaction: VoiceTransactionData(
                notes: "Salary credited",
                amount: 85000,
                date: "2026-03-23T10:00:00Z",
                transactionType: "income",
                category: "Salary"
            ),
            reason: nil
        )
        let primary = Account(name: "SBI", balance: 1000, icon: .bankAccountOne, isPrimary: true)
        let categories = [TransactionCategory(name: "Salary", type: .income)]
        let result = VoiceTransactionCreator.buildDraftFromAIPayload(
            payload: payload,
            accounts: [primary],
            categories: categories
        )

        #expect(result.failure == nil)
        #expect(result.draft?.transactionType == .income)
        #expect(result.draft?.category?.name == "Salary")
        #expect(result.draft?.account?.isPrimary == true)
    }
}
