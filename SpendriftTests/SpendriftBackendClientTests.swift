//
//  SpendriftBackendClientTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct SpendriftBackendClientTests {

    @Test
    func encodeCategoriesJSON() throws {
        let categories = [
            TransactionCategory(name: "Food", type: .expense),
            TransactionCategory(name: "Salary", type: .income),
        ]
        let json = try SpendriftBackendClient.encodeCategories(categories)
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: String]]
        #expect(decoded?.count == 2)
        #expect(decoded?.contains(where: { $0["name"] == "Food" && $0["type"] == "expense" }) == true)
        #expect(decoded?.contains(where: { $0["name"] == "Salary" && $0["type"] == "income" }) == true)
    }

    @Test
    func sanitizedPDFFilenameAddsSuffix() {
        #expect(SpendriftBackendClient.sanitizedPDFFilename("hdfc_mar2026") == "hdfc_mar2026.pdf")
        #expect(SpendriftBackendClient.sanitizedPDFFilename("") == "statement.pdf")
    }

    @Test
    func decodeHealthResponse() throws {
        let json = """
        {
          "status": "ok",
          "version": "1.0.0",
          "models": { "voice": "gpt-audio-mini", "statement": "gpt-4o" }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let health = try JSONDecoder().decode(SpendriftHealthResponse.self, from: data)
        #expect(health.status == "ok")
        #expect(health.models.voice == "gpt-audio-mini")
        #expect(health.models.statement == "gpt-4o")
    }

    @Test
    func decodeApiErrorEnvelope() throws {
        let json = """
        {
          "error": {
            "code": "unauthorized",
            "message": "Invalid or missing bearer token"
          }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let envelope = try JSONDecoder().decode(SpendriftApiErrorResponse.self, from: data)
        #expect(envelope.error.code == "unauthorized")
        #expect(envelope.error.message.contains("bearer token"))
    }
}
