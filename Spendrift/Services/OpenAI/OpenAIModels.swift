//
//  OpenAIModels.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct OpenAIVoiceTransactionPayload: Codable {
    let status: String
    let transaction: OpenAIVoiceTransaction?
    let reason: String?
}

struct OpenAIVoiceTransaction: Codable {
    let notes: String
    let amount: Double
    let date: String
    let transactionType: String
    let category: String?
}

// MARK: - Bank Statement PDF Parsing

struct OpenAIStatementPayload: Codable {
    let transactions: [OpenAIStatementTransaction]
}

struct OpenAIStatementTransaction: Codable {
    let notes: String
    let amount: Double
    let date: String
    let transactionType: String
}

enum OpenAIServiceError: LocalizedError, Equatable {
    case missingAPIKey
    case failedToBuildRequest
    case nonHTTPResponse
    case badStatusCode(Int, String)
    case missingJSONText
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Spendrift backend is not configured. Set SpendriftBackendBaseURL and SpendriftBackendClientToken."
        case .failedToBuildRequest:
            return "Could not build OpenAI request payload."
        case .nonHTTPResponse:
            return "Received a non-HTTP response from the AI service."
        case .badStatusCode(let code, let body):
            return "AI service request failed (\(code)): \(body)"
        case .missingJSONText:
            return "The AI service did not return a usable response."
        case .invalidJSON(let raw):
            return "The AI service returned invalid JSON: \(raw)"
        }
    }
}
