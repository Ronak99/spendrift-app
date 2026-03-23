//
//  OpenAIVoiceTransactionService.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct OpenAIVoiceTransactionService {
    private let client: OpenAIClient
    private let model = "gpt-4.1"

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func parseTransaction(
        audioData: Data,
        categories: [TransactionCategory]
    ) async throws -> OpenAIVoiceTransactionPayload {
        let prompt = try buildPrompt(categories: categories)
        let rawText = try await client.createResponse(
            apiKey: AppSecrets.openAIAPIKey,
            model: model,
            systemPrompt: prompt,
            audioData: audioData
        )

        guard let jsonData = rawText.data(using: .utf8) else {
            throw OpenAIServiceError.invalidJSON(rawText)
        }

        do {
            return try JSONDecoder().decode(OpenAIVoiceTransactionPayload.self, from: jsonData)
        } catch {
            throw OpenAIServiceError.invalidJSON(rawText)
        }
    }

    private func buildPrompt(categories: [TransactionCategory]) throws -> String {
        let basePrompt = try loadBasePrompt()
        let income = categories.filter { $0.type == .income }.map(\.name).sorted()
        let expense = categories.filter { $0.type == .expense }.map(\.name).sorted()

        let dynamicCategoryBlock = """

        ---

        ## ALLOWED CATEGORIES (DYNAMIC - CURRENT USER DATA)

        ### Income
        \(income.map { "- \($0)" }.joined(separator: "\n"))

        ### Expense
        \(expense.map { "- \($0)" }.joined(separator: "\n"))

        ---

        IMPORTANT:
        - Choose category only from the dynamic list above.
        - If no match exists in dynamic categories, use null.
        """

        return basePrompt + dynamicCategoryBlock
    }

    private func loadBasePrompt() throws -> String {
        if let bundleURL = Bundle.main.url(forResource: "basePrompt", withExtension: "md") {
            return try String(contentsOf: bundleURL, encoding: .utf8)
        }

        let localPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("MyMoney/basePrompt.md")
        if FileManager.default.fileExists(atPath: localPath.path) {
            return try String(contentsOf: localPath, encoding: .utf8)
        }

        throw OpenAIServiceError.failedToBuildRequest
    }
}
