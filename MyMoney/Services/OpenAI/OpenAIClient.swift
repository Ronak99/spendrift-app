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
        audioFormat: String = "pcm16",
        audioPath: RealtimeAudioSubmissionPath = .inputBuffer
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        RealtimeDebugLog.shared.reset()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        try await waitForServerEventTypes(socket: socket, matchingAny: Set(["session.created"]), timeoutSeconds: 15)

        try await sendEvent([
            "type": "session.update",
            "session": [
                "instructions": systemPrompt,
                "input_audio_format": audioFormat,
                "output_audio_format": audioFormat
            ]
        ], socket: socket)

        try await waitForServerEventTypes(socket: socket, matchingAny: Set(["session.updated"]), timeoutSeconds: 20)

        switch audioPath {
        case .inputBuffer:
            let chunkByteSize = 12_000
            var offset = 0
            while offset < audioData.count {
                let end = min(offset + chunkByteSize, audioData.count)
                let chunk = audioData.subdata(in: offset..<end)
                try await sendEvent([
                    "type": "input_audio_buffer.append",
                    "audio": chunk.base64EncodedString()
                ], socket: socket)
                offset = end
            }
            try await sendEvent(["type": "input_audio_buffer.commit"], socket: socket)
        case .conversationItem:
            try await sendEvent([
                "type": "conversation.item.create",
                "item": [
                    "type": "message",
                    "role": "user",
                    "content": [
                        [
                            "type": "input_audio",
                            "audio": audioData.base64EncodedString()
                        ]
                    ]
                ]
            ], socket: socket)
            try await waitForServerEventTypes(
                socket: socket,
                matchingAny: Set(["conversation.item.added"]),
                timeoutSeconds: 20
            )
        }

        try await sendEvent([
            "type": "response.create",
            "response": [
                "modalities": ["text"],
                "instructions": "Return only strict JSON object and no markdown."
            ]
        ], socket: socket)

        return try await collectJSONText(socket: socket)
    }

    private func waitForServerEventTypes(
        socket: URLSessionWebSocketTask,
        matchingAny types: Set<String>,
        timeoutSeconds: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let json = try await receiveJSON(socket: socket)
            guard let type = json["type"] as? String else { continue }

            if types.contains(type) {
                return
            }
        }
        throw OpenAIServiceError.realtimeProtocol(
            message: "Timed out waiting for server event: \(types.sorted().joined(separator: ", "))",
            recentEventSummary: RealtimeDebugLog.shared.summary
        )
    }

    private func receiveJSON(socket: URLSessionWebSocketTask) async throws -> [String: Any] {
        let message = try await socket.receive()
        let text: String
        switch message {
        case .string(let string):
            text = string
        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return [:]
        }
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        RealtimeDebugLog.shared.record(RealtimeDebugLog.summarizeServerJSON(json))
        if let type = json["type"] as? String, type == "error" {
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown realtime error"
            throw OpenAIServiceError.realtimeProtocol(
                message: message,
                recentEventSummary: RealtimeDebugLog.shared.summary
            )
        }
        return json
    }

    private func sendEvent(_ event: [String: Any], socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: event, options: [])
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIServiceError.failedToBuildRequest
        }
        try await socket.send(.string(text))
    }

    private func collectJSONText(socket: URLSessionWebSocketTask) async throws -> String {
        let deadline = Date().addingTimeInterval(45)
        var collected = ""

        while Date() < deadline {
            let json = try await receiveJSON(socket: socket)
            guard let type = json["type"] as? String else { continue }

            if type == "response.output_text.delta",
               let delta = json["delta"] as? String {
                collected += delta
            }

            if type == "response.output_text.done",
               let doneText = json["text"] as? String,
               collected.isEmpty {
                collected = doneText
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
