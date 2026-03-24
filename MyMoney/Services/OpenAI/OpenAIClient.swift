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
        audioFormat: String = "pcm16"
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        try await sendEvent([
            "type": "session.update",
            "session": [
                "instructions": systemPrompt,
                "input_audio_format": audioFormat,
                "output_audio_format": audioFormat
            ]
        ], socket: socket)

        try await sendEvent([
            "type": "input_audio_buffer.append",
            "audio": audioData.base64EncodedString()
        ], socket: socket)

        try await sendEvent(["type": "input_audio_buffer.commit"], socket: socket)

        try await sendEvent([
            "type": "response.create",
            "response": [
                "modalities": ["text"],
                "instructions": "Return only strict JSON object and no markdown."
            ]
        ], socket: socket)

        return try await collectJSONText(socket: socket)
    }

    private func sendEvent(_ event: [String: Any], socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: event, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIServiceError.failedToBuildRequest
        }
        try await socket.send(.string(text))
    }

    private func collectJSONText(socket: URLSessionWebSocketTask) async throws -> String {
        let deadline = Date().addingTimeInterval(30)
        var collected = ""

        while Date() < deadline {
            let message = try await socket.receive()
            let text: String
            switch message {
            case .string(let string):
                text = string
            case .data(let data):
                text = String(data: data, encoding: .utf8) ?? ""
            @unknown default:
                continue
            }

            guard !text.isEmpty,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let type = json["type"] as? String {
                if type == "response.output_text.delta",
                   let delta = json["delta"] as? String {
                    collected += delta
                }

                if type == "response.output_text.done",
                   let doneText = json["text"] as? String,
                   collected.isEmpty {
                    collected = doneText
                }

                if type == "error" {
                    let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown realtime error"
                    throw OpenAIServiceError.realtimeProtocol(message)
                }

                if type == "response.done" {
                    if collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let response = json["response"] as? [String: Any],
                           let fallback = extractTextFromResponse(response),
                           !fallback.isEmpty {
                            return fallback
                        }
                    } else {
                        return collected
                    }
                }
            }
        }

        if !collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return collected
        }
        throw OpenAIServiceError.missingJSONText
    }

    private func extractTextFromResponse(_ response: [String: Any]) -> String? {
        guard let output = response["output"] as? [[String: Any]] else { return nil }
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for contentItem in content {
                if let text = contentItem["text"] as? String, !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }
}
