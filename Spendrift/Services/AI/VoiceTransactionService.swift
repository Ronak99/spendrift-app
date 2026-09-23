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

    /// `quota: .exempt` is for the onboarding demo only: the user's first voice note
    /// is on the house, so it neither needs a credit nor spends one.
    func parseTransaction(
        audioData: Data,
        categories: [TransactionCategory],
        quota: QuotaPolicy = .enforced
    ) async throws -> VoiceTransactionPayload {
        guard let backend else {
            throw AIServiceError.missingAPIKey
        }

        // Last line of defence. The UI gates before recording so the user sees a
        // paywall rather than an error, but voice also starts from App Intents and
        // Shortcuts, which bypass that check entirely.
        guard quota == .exempt || ProGate.isAllowed(.voice) else {
            ProGate.reportBlocked(.voice)
            throw AIServiceError.quotaExhausted(.voice)
        }

        do {
            let payload = try await backend.parseVoiceTransaction(
                audioData: audioData,
                categories: categories,
                clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                timezone: SpendriftBackendClient.makeTimezoneIdentifier()
            )
            if quota == .enforced {
                ProGate.recordUsage(.voice)
            }
            return payload
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
