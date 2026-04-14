//
//  OpenAIClient.swift
//  Spendrift
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

    /// Responses API with PDF file input; returns assistant `output_text` (JSON text).
    ///
    /// PDFs are uploaded with the Files API (`purpose: user_data`) and referenced by `file_id`.
    /// Embedding large base64 `file_data` blobs in JSON often triggers `invalid_file` / corrupted errors.
    func responsesJSONFromPDF(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userInstruction: String,
        pdfData: Data,
        filename: String
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        let uploadName = Self.uploadFilename(from: filename)
        let fileID = try await uploadUserDataFile(apiKey: apiKey, pdfData: pdfData, filename: uploadName)
        defer {
            Task {
                try? await deleteFile(apiKey: apiKey, fileID: fileID)
            }
        }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        let body: [String: Any] = [
            "model": model,
            "instructions": systemPrompt,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_file",
                            "file_id": fileID
                        ],
                        [
                            "type": "input_text",
                            "text": userInstruction
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

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)

        if let text = envelope.output_text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let items = envelope.output {
            for item in items {
                for part in item.content ?? [] where part.type == "output_text" {
                    if let text = part.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                        return text
                    }
                }
            }
        }

        throw OpenAIServiceError.missingJSONText
    }

    // MARK: - Files API (for Responses `input_file`)

    private struct OpenAIFileUploadResponse: Decodable {
        let id: String
    }

    private static func uploadFilename(from name: String) -> String {
        var base = (name as NSString).lastPathComponent
        if base.isEmpty {
            base = "statement.pdf"
        }
        // Safe for multipart `filename="..."` (no quotes / CR / LF).
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        base = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        if base.isEmpty {
            base = "statement.pdf"
        }
        if !base.lowercased().hasSuffix(".pdf") {
            base = "\(base).pdf"
        }
        return base
    }

    private func uploadUserDataFile(apiKey: String, pdfData: Data, filename: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/files") else {
            throw OpenAIServiceError.failedToBuildRequest
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) {
            if let chunk = string.data(using: .utf8) {
                body.append(chunk)
            }
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n")
        append("user_data\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: application/pdf\r\n\r\n")
        body.append(pdfData)
        append("\r\n")
        append("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIServiceError.nonHTTPResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIServiceError.badStatusCode(http.statusCode, bodyString)
        }

        let decoded = try JSONDecoder().decode(OpenAIFileUploadResponse.self, from: data)
        let id = decoded.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            throw OpenAIServiceError.badStatusCode(http.statusCode, "File upload returned no id.")
        }
        return id
    }

    private func deleteFile(apiKey: String, fileID: String) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/files/\(fileID)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: request)
    }
}
