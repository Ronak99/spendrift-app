//
//  OpenAIClient.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

struct OpenAIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Chat Completions with audio input; returns assistant `message.content` (JSON text).
    func chatCompletionJSONFromAudio(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userInstruction: String,
        audioData: Data,
        audioFormat: String
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        let encodedAudio = audioData.base64EncodedString()

        let body: [String: Any] = [
            "model": model,
            "modalities": ["text"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userInstruction],
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": encodedAudio,
                                "format": audioFormat
                            ]
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIServiceError.nonHTTPResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIServiceError.badStatusCode(http.statusCode, bodyString)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw OpenAIServiceError.missingJSONText
        }
        return text
    }
}
