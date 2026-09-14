//
//  FeedbackClient.swift
//  Spendrift
//
//  Submits in-app feedback through the Spendrift backend proxy, keyed by
//  DeviceIdentity.current for cross-tool joins with PostHog and Sentry.
//

import Foundation

enum FeedbackClientError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Feedback is not configured on this build."
        case .invalidResponse:
            "Unexpected response from the server."
        case .httpError(_, let message):
            message
        }
    }
}

struct FeedbackClient {
    private let backend: SpendriftBackendClient

    init(backend: SpendriftBackendClient? = nil) throws {
        if let backend {
            self.backend = backend
        } else {
            self.backend = try SpendriftBackendClient()
        }
    }

    func submit(draft: FeedbackDraft) async throws {
        let answersJSON = try Self.encodeAnswersJSON(draft.encodedAnswers())
        try await backend.submitFeedback(
            deviceID: DeviceIdentity.current,
            appVersion: AppInfo.appVersionLabel(),
            answersJSON: answersJSON,
            skippedToNotes: draft.skippedToNotes,
            notes: Self.normalizedNotes(draft.notes),
            locale: Locale.current.identifier,
            region: Locale.current.region?.identifier,
            screenshotData: draft.screenshotData
        )
    }

    static func normalizedNotes(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func encodeAnswersJSON(_ answers: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: answers)
        guard let json = String(data: data, encoding: .utf8) else {
            throw FeedbackClientError.invalidResponse
        }
        return json
    }
}
