//
//  BankStatementService.swift
//  Spendrift
//
//  Created by Cursor on 06/04/26.
//

import Foundation

struct StatementImportRow: Identifiable {
    let id = UUID()
    let notes: String
    let amount: Double
    let date: Date
    let transactionType: TransactionType
}

struct BankStatementService {
    private let backend: SpendriftBackendClient?

    init(backend: SpendriftBackendClient? = nil) {
        self.backend = backend ?? (try? SpendriftBackendClient())
    }

    func parseStatement(pdfData: Data, filename: String) async throws -> [StatementImportRow] {
        guard let backend else {
            throw AIServiceError.missingAPIKey
        }

        let payload: StatementPayload
        do {
            payload = try await backend.parseStatement(pdfData: pdfData, filename: filename)
        } catch let error as SpendriftBackendError {
            throw mapBackendError(error)
        }

        return payload.transactions.compactMap { mapToRow($0) }
    }

    private func mapToRow(_ tx: StatementTransactionData) -> StatementImportRow? {
        guard tx.amount > 0 else { return nil }

        let txType = TransactionType(rawValue: tx.transactionType) ?? .none
        let date = Self.parseDate(tx.date) ?? Date()

        return StatementImportRow(
            notes: tx.notes,
            amount: tx.amount,
            date: date,
            transactionType: txType
        )
    }

    static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: value) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: value) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy"] {
            df.dateFormat = fmt
            if let d = df.date(from: value) { return d }
        }
        return nil
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
