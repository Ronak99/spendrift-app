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

    func createResponse(
        apiKey: String,
        model: String,
        systemPrompt: String,
        audioData: Data,
        audioFormat: String = "m4a"
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        let audioBase64 = audioData.base64EncodedString()
        let mimeType: String = {
            switch audioFormat.lowercased() {
            case "wav":
                return "audio/wav"
            case "mp3":
                return "audio/mpeg"
            default:
                return "audio/m4a"
            }
        }()
        let dataURL = "data:\(mimeType);base64,\(audioBase64)"
        let body: [String: Any] = [
            "model": model,
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": systemPrompt
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_file",
                            "filename": "voice.\(audioFormat)",
                            "file_data": dataURL
                        ]
                    ]
                ]
            ],
            "text": [
                "format": [
                    "type": "json_object"
                ]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.nonHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw OpenAIServiceError.badStatusCode(httpResponse.statusCode, bodyText)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        if let outputText = envelope.output_text, !outputText.isEmpty {
            return outputText
        }

        if let outputItems = envelope.output {
            for item in outputItems {
                guard let contentItems = item.content else { continue }
                for content in contentItems {
                    let isOutputText = content.type == "output_text" || content.type == nil
                    if isOutputText, let text = content.text, !text.isEmpty {
                        return text
                    }
                }
            }
        }

        throw OpenAIServiceError.missingJSONText
    }
}
