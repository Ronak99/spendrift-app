//
//  OpenAIBankStatementService.swift
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

struct OpenAIBankStatementService {
    private let client: OpenAIClient
    private let model = "gpt-4o"

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func parseStatement(pdfData: Data, filename: String) async throws -> [StatementImportRow] {
        let rawText = try await client.responsesJSONFromPDF(
            apiKey: AppSecrets.openAIAPIKey,
            model: model,
            systemPrompt: systemPrompt,
            userInstruction: "Extract every individual transaction from this bank statement PDF. Respond with ONLY the JSON object defined in your instructions.",
            pdfData: pdfData,
            filename: filename
        )

        let cleaned = stripMarkdownCodeFence(rawText)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw OpenAIServiceError.invalidJSON(rawText)
        }

        let payload: OpenAIStatementPayload
        do {
            payload = try JSONDecoder().decode(OpenAIStatementPayload.self, from: jsonData)
        } catch {
            throw OpenAIServiceError.invalidJSON(rawText)
        }

        return payload.transactions.compactMap { mapToRow($0) }
    }

    private func mapToRow(_ tx: OpenAIStatementTransaction) -> StatementImportRow? {
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

    private func stripMarkdownCodeFence(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        else if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var systemPrompt: String {
        """
        You are a bank statement parser. You receive a PDF of a bank statement and must extract every individual transaction line item.

        Respond with ONLY a JSON object in the following schema — no commentary, no markdown fences:

        {
          "transactions": [
            {
              "notes": "<description/narration of the transaction>",
              "amount": <positive number>,
              "date": "<ISO 8601 date, e.g. 2026-03-15>",
              "transactionType": "<expense | income | none>"
            }
          ]
        }

        Rules:
        - Every amount must be a positive number. Use "transactionType" to indicate direction: "expense" for debits/withdrawals, "income" for credits/deposits, "none" if unclear.
        - "notes" should be the transaction description/narration as written on the statement.
        - Dates must be in ISO 8601 format (YYYY-MM-DD). Infer the year from context in the statement when not explicit.
        - Skip summary rows, opening/closing balance lines, interest calculations, and header rows — only include actual transactions.
        - If no transactions can be found, return {"transactions": []}.
        """
    }
}
