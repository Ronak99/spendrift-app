//
//  OpenAIReceiptTransactionService.swift
//  Spendrift
//

import Foundation

struct OpenAIReceiptTransactionService {
    private let backend: SpendriftBackendClient?

    init(backend: SpendriftBackendClient? = nil) {
        self.backend = backend ?? (try? SpendriftBackendClient())
    }

    func parseReceipt(
        imageData: Data,
        mimeType: String,
        filename: String,
        categories: [TransactionCategory]
    ) async throws -> OpenAIReceiptPayload {
        guard let backend else {
            throw OpenAIServiceError.missingAPIKey
        }

        do {
            return try await backend.parseReceipt(
                imageData: imageData,
                mimeType: mimeType,
                filename: filename,
                categories: categories,
                clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                timezone: SpendriftBackendClient.makeTimezoneIdentifier()
            )
        } catch let error as SpendriftBackendError {
            throw mapBackendError(error)
        }
    }

    private func mapBackendError(_ error: SpendriftBackendError) -> OpenAIServiceError {
        switch error {
        case .missingConfiguration:
            return .missingAPIKey
        case .invalidBaseURL, .failedToBuildRequest:
            return .failedToBuildRequest
        case .nonHTTPResponse:
            return .nonHTTPResponse
        case .apiError(_, let message, let details):
            let body = [message, details].compactMap { $0 }.joined(separator: " — ")
            return .badStatusCode(502, body)
        case .invalidResponseBody:
            return .missingJSONText
        case .decodingFailed:
            return .invalidJSON("Backend returned undecodable JSON.")
        }
    }
}
