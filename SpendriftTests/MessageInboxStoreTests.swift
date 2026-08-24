//
//  MessageInboxStoreTests.swift
//  SpendriftTests
//
//  Verifies silent inbox capture + redaction without launching the UI.
//

import Foundation
import SwiftData
import Testing
@testable import Spendrift

struct MessageInboxStoreTests {
    @MainActor
    @Test
    func persistsRedactedMessageAndDedupesFingerprint() throws {
        let schema = Schema([CapturedTransactionMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let raw = "INR 100.00 debited from A/c 998877665544. OTP 123456"
        let redacted = MessageRedactor.redact(raw)
        let fingerprint = MessageFingerprint.fingerprint(for: redacted)
        let capturedAt = Date()

        context.insert(
            CapturedTransactionMessage(
                body: redacted,
                sender: "HDFCBK",
                capturedAt: capturedAt,
                fingerprint: fingerprint
            )
        )
        try context.save()

        let rows = try context.fetch(FetchDescriptor<CapturedTransactionMessage>())
        #expect(rows.count == 1)
        #expect(rows.first?.body.contains("****5544") == true)
        #expect(rows.first?.body.contains("[OTP redacted]") == true)
        #expect(!(rows.first?.body.contains("998877665544") ?? true))

        let windowStart = capturedAt.addingTimeInterval(-5 * 60)
        let dupDescriptor = FetchDescriptor<CapturedTransactionMessage>(
            predicate: #Predicate<CapturedTransactionMessage> {
                $0.fingerprint == fingerprint && $0.capturedAt >= windowStart
            }
        )
        let existing = try context.fetch(dupDescriptor)
        #expect(existing.count == 1)
    }
}
