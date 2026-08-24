//
//  MessageParsePayloadTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct MessageParsePayloadTests {
    @Test
    func decodeMixedResults() throws {
        let json = """
        {
          "results": [
            {
              "id": "m1",
              "status": "success",
              "transaction": {
                "notes": "SWIGGY",
                "amount": 450,
                "date": "2026-08-24T10:00:00",
                "transactionType": "expense",
                "category": "Food"
              }
            },
            {
              "id": "m2",
              "status": "error",
              "reason": "Promotional offer"
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(MessageParsePayload.self, from: data)
        #expect(payload.results.count == 2)
        #expect(payload.results[0].status == "success")
        #expect(payload.results[0].transaction?.amount == 450)
        #expect(payload.results[1].status == "error")
        #expect(payload.results[1].reason == "Promotional offer")
    }
}
