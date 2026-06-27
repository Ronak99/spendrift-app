//
//  SpendriftBackendClient.swift
//  Spendrift
//

import Foundation

struct SpendriftBackendClient {
    private let session: URLSession
    private let baseURL: URL
    private let clientToken: String

    init(
        session: URLSession = .shared,
        baseURL: URL? = AppSecrets.backendBaseURL,
        clientToken: String = AppSecrets.backendClientToken
    ) throws {
        guard let baseURL else {
            throw SpendriftBackendError.missingConfiguration
        }
        guard !clientToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpendriftBackendError.missingConfiguration
        }
        self.session = session
        self.baseURL = baseURL
        self.clientToken = clientToken
    }

    // MARK: - Routes

    /// `GET /v1/health`
    func fetchHealth() async throws -> SpendriftHealthResponse {
        let url = try endpoint(path: "/v1/health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data = try await perform(request: request, expectsAuth: false)
        return try decode(SpendriftHealthResponse.self, from: data)
    }

    /// `POST /v1/voice/parse-transaction`
    func parseVoiceTransaction(
        audioData: Data,
        categories: [TransactionCategory],
        clientTodayIso: String,
        timezone: String
    ) async throws -> VoiceTransactionPayload {
        let categoriesJSON = try Self.encodeCategories(categories)
        let body = try buildMultipartBody(
            fields: [
                ("categories", categoriesJSON, nil),
                ("clientTodayIso", clientTodayIso, nil),
                ("timezone", timezone, nil),
            ],
            fileFieldName: "audio",
            fileData: audioData,
            fileName: "recording.wav",
            fileMIMEType: "audio/wav"
        )

        let url = try endpoint(path: "/v1/voice/parse-transaction")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        let boundary = body.boundary
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let data = try await perform(request: request, expectsAuth: true)
        return try decode(VoiceTransactionPayload.self, from: data)
    }

    /// `POST /v1/statements/parse`
    func parseStatement(
        pdfData: Data,
        filename: String
    ) async throws -> StatementPayload {
        let uploadName = Self.sanitizedPDFFilename(filename)
        let body = try buildMultipartBody(
            fields: [("filename", uploadName, nil)],
            fileFieldName: "pdf",
            fileData: pdfData,
            fileName: uploadName,
            fileMIMEType: "application/pdf"
        )

        let url = try endpoint(path: "/v1/statements/parse")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        let boundary = body.boundary
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let data = try await perform(request: request, expectsAuth: true)
        return try decode(StatementPayload.self, from: data)
    }

    /// `POST /v1/receipts/parse`
    func parseReceipt(
        imageData: Data,
        mimeType: String,
        filename: String,
        categories: [TransactionCategory],
        clientTodayIso: String,
        timezone: String
    ) async throws -> ReceiptPayload {
        let categoriesJSON = try Self.encodeCategories(categories)
        let body = try buildMultipartBody(
            fields: [
                ("categories", categoriesJSON, nil),
                ("clientTodayIso", clientTodayIso, nil),
                ("timezone", timezone, nil),
            ],
            fileFieldName: "image",
            fileData: imageData,
            fileName: filename,
            fileMIMEType: mimeType
        )

        let url = try endpoint(path: "/v1/receipts/parse")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        let boundary = body.boundary
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let data = try await perform(request: request, expectsAuth: true)
        return try decode(ReceiptPayload.self, from: data)
    }

    // MARK: - Request helpers

    private func endpoint(path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SpendriftBackendError.invalidBaseURL
        }
        return url
    }

    private func applyAuth(_ request: inout URLRequest) {
        request.setValue("Bearer \(clientToken)", forHTTPHeaderField: "Authorization")
    }

    private func perform(request: URLRequest, expectsAuth: Bool) async throws -> Data {
        var req = request
        if expectsAuth {
            applyAuth(&req)
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw SpendriftBackendError.nonHTTPResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw parseAPIError(statusCode: http.statusCode, data: data)
        }

        guard !data.isEmpty else {
            throw SpendriftBackendError.invalidResponseBody
        }

        return data
    }

    private func parseAPIError(statusCode: Int, data: Data) -> SpendriftBackendError {
        if let decoded = try? JSONDecoder().decode(SpendriftApiErrorResponse.self, from: data) {
            return .apiError(
                code: decoded.error.code,
                message: decoded.error.message,
                details: decoded.error.details
            )
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return .apiError(
            code: "http_\(statusCode)",
            message: "Request failed with status \(statusCode)",
            details: body.isEmpty ? nil : body
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw SpendriftBackendError.decodingFailed
        }
    }

    // MARK: - Multipart

    private struct MultipartBody {
        let boundary: String
        let data: Data
    }

    private func buildMultipartBody(
        fields: [(name: String, value: String, mimeType: String?)],
        fileFieldName: String,
        fileData: Data,
        fileName: String,
        fileMIMEType: String
    ) throws -> MultipartBody {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) throws {
            guard let chunk = string.data(using: .utf8) else {
                throw SpendriftBackendError.failedToBuildRequest
            }
            body.append(chunk)
        }

        for field in fields {
            try append("--\(boundary)\r\n")
            try append("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            try append("\(field.value)\r\n")
        }

        try append("--\(boundary)\r\n")
        try append(
            "Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n"
        )
        try append("Content-Type: \(fileMIMEType)\r\n\r\n")
        body.append(fileData)
        try append("\r\n")
        try append("--\(boundary)--\r\n")

        return MultipartBody(boundary: boundary, data: body)
    }

    // MARK: - Shared encoding

    static func encodeCategories(_ categories: [TransactionCategory]) throws -> String {
        let inputs: [[String: String]] = categories.map { category in
            ["name": category.name, "type": category.type.rawValue]
        }
        let data = try JSONSerialization.data(withJSONObject: inputs)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SpendriftBackendError.failedToBuildRequest
        }
        return json
    }

    static func makeClientTodayIso() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: Date())
    }

    static func makeTimezoneIdentifier() -> String {
        TimeZone.current.identifier
    }

    static func sanitizedPDFFilename(_ name: String) -> String {
        var base = (name as NSString).lastPathComponent
        if base.isEmpty {
            base = "statement.pdf"
        }
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
}
