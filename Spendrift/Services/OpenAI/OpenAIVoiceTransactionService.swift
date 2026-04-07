//
//  OpenAIVoiceTransactionService.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct OpenAIVoiceTransactionService {
    private let client: OpenAIClient
    /// Audio-capable Chat Completions model; see OpenAI Audio / Chat Completions docs.
    private let model = "gpt-4o-audio-preview"

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func parseTransaction(
        audioData: Data,
        categories: [TransactionCategory]
    ) async throws -> OpenAIVoiceTransactionPayload {
        let prompt = try buildPrompt(categories: categories)
        let rawText = try await client.chatCompletionJSONFromAudio(
            apiKey: AppSecrets.openAIAPIKey,
            model: model,
            systemPrompt: prompt,
            userInstruction: """
            Listen to this recording. If there is no clear spoken description of a real money transaction \
            (for example silence, only noise, or no usable details), respond with only the error JSON from your instructions. \
            Otherwise respond with only the success transaction JSON. No other text.
            """,
            audioData: audioData,
            audioFormat: "wav"
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
        let todayISO = makeTodayISODateString()
        let basePrompt = try loadBasePrompt().replacingOccurrences(of: "{{TODAY_ISO}}", with: todayISO)
        let income = categories.filter { $0.type == .income }.map(\.name).sorted()
        let expense = categories.filter { $0.type == .expense }.map(\.name).sorted()

        let runtimeDateBlock = """
        ## CURRENT DATE CONTEXT
        - Today is \(todayISO). If the user does not mention a date explicitly, use this exact value.
        
        """

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

        return basePrompt + "\n\n" + runtimeDateBlock + dynamicCategoryBlock
    }

    private func loadBasePrompt() throws -> String {
        if let bundleURL = Bundle.main.url(forResource: "basePrompt", withExtension: "md") {
            return try String(contentsOf: bundleURL, encoding: .utf8)
        }

        let localPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Spendrift/basePrompt.md")
        if FileManager.default.fileExists(atPath: localPath.path) {
            return try String(contentsOf: localPath, encoding: .utf8)
        }

        throw OpenAIServiceError.failedToBuildRequest
    }

    private func makeTodayISODateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: Date())
    }
}
