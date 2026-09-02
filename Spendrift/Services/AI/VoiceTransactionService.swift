//
//  VoiceTransactionService.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct VoiceTransactionService {
    private let backend: SpendriftBackendClient?

    init(backend: SpendriftBackendClient? = nil) {
        self.backend = backend ?? (try? SpendriftBackendClient())
    }

    func parseTransaction(
        audioData: Data,
        categories: [TransactionCategory]
    ) async throws -> VoiceTransactionPayload {
        guard let backend else {
            throw AIServiceError.missingAPIKey
        }

        do {
            return try await backend.parseVoiceTransaction(
                audioData: audioData,
                categories: categories,
                clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                timezone: SpendriftBackendClient.makeTimezoneIdentifier()
            )
        } catch let error as SpendriftBackendError {
            throw mapBackendError(error)
        }
    }

    private func mapBackendError(_ error: SpendriftBackendError) -> AIServiceError {
        switch error {
        case .missingConfiguration:
            return .missingAPIKey
        case .invalidBaseURL, .failedToBuildRequest:
            return .failedToBuildRequest
        case .nonHTTPResponse:
            return .nonHTTPResponse
        case .apiError(_, _, let message, let details):
            let body = [message, details].compactMap { $0 }.joined(separator: " — ")
            return .badStatusCode(502, body)
        case .invalidResponseBody:
            return .missingJSONText
        case .decodingFailed:
            return .invalidJSON("Backend returned undecodable JSON.")
        }
    }
}
