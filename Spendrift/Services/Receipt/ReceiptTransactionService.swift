//
//  ReceiptTransactionService.swift
//  Spendrift
//

import Foundation

struct ReceiptTransactionService {
    private let backend: SpendriftBackendClient?

    init(backend: SpendriftBackendClient? = nil) {
        self.backend = backend ?? (try? SpendriftBackendClient())
    }

    func parseReceipt(
        imageData: Data,
        mimeType: String,
        filename: String,
        categories: [TransactionCategory]
    ) async throws -> ReceiptPayload {
        guard let backend else {
            throw AIServiceError.missingAPIKey
        }

        // Also reachable from the Share Extension handoff, which never passes
        // through the in-app gate.
        guard ProGate.isAllowed(.receiptScan) else {
            ProGate.reportBlocked(.receiptScan)
            throw AIServiceError.quotaExhausted(.receiptScan)
        }

        do {
            let payload = try await backend.parseReceipt(
                imageData: imageData,
                mimeType: mimeType,
                filename: filename,
                categories: categories,
                clientTodayIso: SpendriftBackendClient.makeClientTodayIso(),
                timezone: SpendriftBackendClient.makeTimezoneIdentifier()
            )
            ProGate.recordUsage(.receiptScan)
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
