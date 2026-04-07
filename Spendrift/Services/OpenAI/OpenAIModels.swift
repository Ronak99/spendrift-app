//
//  OpenAIModels.swift
//  MyMoney
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

struct OpenAIChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

struct OpenAIResponseEnvelope: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String?
            let text: String?
        }

        let content: [ContentItem]?
    }

    let output: [OutputItem]?
    let output_text: String?
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
            return "OpenAI API key is empty. Add it in AppSecrets."
        case .failedToBuildRequest:
            return "Could not build OpenAI request payload."
        case .nonHTTPResponse:
            return "Received a non-HTTP response from OpenAI."
        case .badStatusCode(let code, let body):
            return "OpenAI request failed with status \(code): \(body)"
        case .missingJSONText:
            return "OpenAI did not return JSON text in the chat completion."
        case .invalidJSON(let raw):
            return "OpenAI returned invalid JSON: \(raw)"
        }
    }
}
