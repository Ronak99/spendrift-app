//
//  OpenAIBankStatementServiceTests.swift
//  SpendriftTests
//
//  Created by Cursor on 06/04/26.
//

import Foundation
import Testing
@testable import Spendrift

struct OpenAIBankStatementServiceTests {

    // MARK: - Payload decoding

    @Test
    func decodeStatementPayloadWithMultipleTransactions() throws {
        let json = """
        {
          "transactions": [
            { "notes": "NEFT-Salary", "amount": 50000, "date": "2026-03-01", "transactionType": "income" },
            { "notes": "Swiggy Order", "amount": 350, "date": "2026-03-02", "transactionType": "expense" },
            { "notes": "ATM Withdrawal", "amount": 5000, "date": "2026-03-05", "transactionType": "expense" }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(OpenAIStatementPayload.self, from: data)
        #expect(payload.transactions.count == 3)
        #expect(payload.transactions[0].notes == "NEFT-Salary")
        #expect(payload.transactions[0].amount == 50000)
        #expect(payload.transactions[0].transactionType == "income")
        #expect(payload.transactions[1].transactionType == "expense")
    }

    @Test
    func decodeEmptyTransactionsArray() throws {
        let json = """
        { "transactions": [] }
        """
        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(OpenAIStatementPayload.self, from: data)
        #expect(payload.transactions.isEmpty)
    }

    // MARK: - Date parsing

    @Test
    func parsesISODate() throws {
        let date = try #require(OpenAIBankStatementService.parseDate("2026-03-15"))
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    @Test
    func parsesSlashDate() throws {
        let date = try #require(OpenAIBankStatementService.parseDate("15/03/2026"))
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    @Test
    func returnsNilForGarbage() {
        #expect(OpenAIBankStatementService.parseDate("not-a-date") == nil)
    }
}
