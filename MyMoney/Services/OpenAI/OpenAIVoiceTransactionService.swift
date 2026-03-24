//
//  OpenAIVoiceTransactionService.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

/// User default: when `true`, Realtime uses only `conversation.item.create` + `input_audio` (skips buffer append/commit).
/// Key: `VoiceRealtime.useConversationItemOnly`.
enum VoiceRealtimeSubmissionSettings {
    private static let useConversationItemOnlyKey = "VoiceRealtime.useConversationItemOnly"

    static var useConversationItemOnly: Bool {
        UserDefaults.standard.bool(forKey: useConversationItemOnlyKey)
    }

    static func setUseConversationItemOnly(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: useConversationItemOnlyKey)
    }
}

struct OpenAIVoiceTransactionService {
    private let client: OpenAIClient
    private let model = "gpt-4o-realtime-preview"

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func parseTransaction(
        audioData: Data,
        categories: [TransactionCategory],
        audioPath: RealtimeAudioSubmissionPath? = nil
    ) async throws -> OpenAIVoiceTransactionPayload {
        let prompt = try buildPrompt(categories: categories)
        let resolvedPath = audioPath ?? defaultAudioPath()

        let rawText: String
        switch resolvedPath {
        case .conversationItem:
            rawText = try await client.createResponse(
                apiKey: AppSecrets.openAIAPIKey,
                model: model,
                systemPrompt: prompt,
                audioData: audioData,
                audioFormat: "pcm16",
                audioPath: .conversationItem
            )
        case .inputBuffer:
            do {
                rawText = try await client.createResponse(
                    apiKey: AppSecrets.openAIAPIKey,
                    model: model,
                    systemPrompt: prompt,
                    audioData: audioData,
                    audioFormat: "pcm16",
                    audioPath: .inputBuffer
                )
            } catch let error as OpenAIServiceError {
                if case .realtimeProtocol(let message, _) = error,
                   Self.shouldRetryRealtimeWithConversationItem(message: message) {
                    rawText = try await client.createResponse(
                        apiKey: AppSecrets.openAIAPIKey,
                        model: model,
                        systemPrompt: prompt,
                        audioData: audioData,
                        audioFormat: "pcm16",
                        audioPath: .conversationItem
                    )
//                    rawText = try await client.createResponse(
//                        apiKey: AppSecrets.openAIAPIKey,
//                        model: model,
//                        systemPrompt: prompt,
//                        audioData: audioData,
//                        audioFormat: "pcm16",
//                        audioPath: .conversationItem
//                    )
                } else {
                    throw error
                }
            }
        }

        guard let jsonData = rawText.data(using: .utf8) else {
            throw OpenAIServiceError.invalidJSON(rawText)
        }

        do {
            return try JSONDecoder().decode(OpenAIVoiceTransactionPayload.self, from: jsonData)
        } catch {
            throw OpenAIServiceError.invalidJSON(rawText)
        }
    }

    private func defaultAudioPath() -> RealtimeAudioSubmissionPath {
        VoiceRealtimeSubmissionSettings.useConversationItemOnly ? .conversationItem : .inputBuffer
    }

    private static func shouldRetryRealtimeWithConversationItem(message: String) -> Bool {
        let m = message.lowercased()
        if m.contains("buffer too small") { return true }
        if m.contains("0.00ms") || m.contains("0 ms") { return true }
        if m.contains("input_audio_buffer") && (m.contains("empty") || m.contains("no audio")) { return true }
        return false
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
