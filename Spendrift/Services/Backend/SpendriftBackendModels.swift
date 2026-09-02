//
//  SpendriftBackendModels.swift
//  Spendrift
//

import Foundation

// MARK: - Health

struct SpendriftHealthResponse: Decodable, Equatable {
    let status: String
    let version: String
    let models: Models

    struct Models: Decodable, Equatable {
        let voice: String
        let statement: String
        let receipt: String
        let message: String?
    }
}

// MARK: - API errors

struct SpendriftApiErrorResponse: Decodable {
    let error: Body

    struct Body: Decodable {
        let code: String
        let message: String
        let details: String?
    }
}

enum SpendriftBackendError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidBaseURL
    case failedToBuildRequest
    case nonHTTPResponse
    case apiError(statusCode: Int, code: String, message: String, details: String?)
    case invalidResponseBody
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Spendrift backend URL or client token is not configured."
        case .invalidBaseURL:
            return "Spendrift backend base URL is invalid."
        case .failedToBuildRequest:
            return "Could not build the backend request."
        case .nonHTTPResponse:
            return "Received a non-HTTP response from the Spendrift backend."
        case .apiError(_, let code, let message, let details):
            if let details, !details.isEmpty {
                return "Backend error (\(code)): \(message) — \(details)"
            }
            return "Backend error (\(code)): \(message)"
        case .invalidResponseBody:
            return "The backend returned an empty or unreadable response."
        case .decodingFailed:
            return "The backend returned JSON that could not be decoded."
        }
    }

    /// How a caller should react to this failure.
    enum Disposition {
        /// Worth retrying unchanged later: network trouble, throttling, upstream faults.
        case transient
        /// The request itself is unacceptable. Retrying it unchanged will fail again,
        /// but a smaller or different payload may succeed.
        case rejectedPayload
        /// Nothing about this client's requests will succeed until config changes.
        case notAuthorised
    }

    var disposition: Disposition {
        switch self {
        case .missingConfiguration, .invalidBaseURL:
            return .notAuthorised
        case .failedToBuildRequest:
            return .rejectedPayload
        case .nonHTTPResponse, .invalidResponseBody, .decodingFailed:
            return .transient
        case .apiError(let statusCode, _, _, _):
            switch statusCode {
            case 401, 403:
                return .notAuthorised
            // 429 is throttling, not a bad payload, so it stays retryable.
            case 429:
                return .transient
            case 400...499:
                return .rejectedPayload
            default:
                return .transient
            }
        }
    }
}
