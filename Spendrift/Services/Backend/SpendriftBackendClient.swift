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

    /// `POST /v1/devices/launch`
    func recordDeviceLaunch(
        deviceID: String,
        posthogID: String?,
        device: String?,
        iosVersion: String,
        appVersion: String
    ) async throws {
        var bodyObject: [String: Any] = [
            "device_id": deviceID,
            "ios_version": iosVersion,
            "app_version": appVersion,
        ]
        if let posthogID { bodyObject["posthog_id"] = posthogID }
        if let device { bodyObject["device"] = device }

        let bodyData = try JSONSerialization.data(withJSONObject: bodyObject)

        let url = try endpoint(path: "/v1/devices/launch")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        _ = try await perform(request: request, expectsAuth: true)
    }

    /// `POST /v1/notifications/state`
    func recordNotificationState(
        deviceID: String,
        appVersion: String,
        permissionStatus: String,
        onesignalSubscriptionID: String?,
        rewardGranted: Bool
    ) async throws {
        var bodyObject: [String: Any] = [
            "device_id": deviceID,
            "app_version": appVersion,
            "permission_status": permissionStatus,
            "reward_granted": rewardGranted,
        ]
        if let onesignalSubscriptionID {
            bodyObject["onesignal_subscription_id"] = onesignalSubscriptionID
        }

        let bodyData = try JSONSerialization.data(withJSONObject: bodyObject)

        let url = try endpoint(path: "/v1/notifications/state")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        _ = try await perform(request: request, expectsAuth: true)
    }

    /// `POST /v1/feedback`
    func submitFeedback(
        deviceID: String,
        appVersion: String,
        answersJSON: String,
        skippedToNotes: Bool,
        notes: String?,
        locale: String?,
        region: String?,
        screenshotData: Data?
    ) async throws {
        var fields: [(name: String, value: String, mimeType: String?)] = [
            ("device_id", deviceID, nil),
            ("app_version", appVersion, nil),
            ("answers", answersJSON, nil),
            ("skipped_to_notes", skippedToNotes ? "true" : "false", nil),
        ]
        if let notes { fields.append(("notes", notes, nil)) }
        if let locale { fields.append(("locale", locale, nil)) }
        if let region { fields.append(("region", region, nil)) }

        let url = try endpoint(path: "/v1/feedback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)

        if let screenshotData {
            let body = try buildMultipartBody(
                fields: fields,
                fileFieldName: "screenshot",
                fileData: screenshotData,
                fileName: "screenshot.jpg",
                fileMIMEType: "image/jpeg"
            )
            request.setValue("multipart/form-data; boundary=\(body.boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data
        } else {
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
            try append("--\(boundary)--\r\n")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        _ = try await perform(request: request, expectsAuth: true)
    }

    /// `POST /v1/messages/parse-transactions`
    func parseTransactionMessages(
        messages: [MessageParseRequestItem],
        categories: [TransactionCategory],
        clientTodayIso: String,
        timezone: String
    ) async throws -> MessageParsePayload {
        let categoryInputs: [[String: String]] = categories.map { category in
            ["name": category.name, "type": category.type.rawValue]
        }
        let bodyObject: [String: Any] = [
            "messages": messages.map { item -> [String: Any] in
                var dict: [String: Any] = [
                    "id": item.id,
                    "body": item.body,
                ]
                if let capturedAtIso = item.capturedAtIso {
                    dict["capturedAtIso"] = capturedAtIso
                }
                return dict
            },
            "categories": categoryInputs,
            "clientTodayIso": clientTodayIso,
            "timezone": timezone,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyObject)

        let url = try endpoint(path: "/v1/messages/parse-transactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let data = try await perform(request: request, expectsAuth: true)
        return try decode(MessageParsePayload.self, from: data)
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
                statusCode: statusCode,
                code: decoded.error.code,
                message: decoded.error.message,
                details: decoded.error.details
            )
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return .apiError(
            statusCode: statusCode,
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
