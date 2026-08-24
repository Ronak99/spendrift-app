//
//  LogTransactionMessageIntent.swift
//  Spendrift
//
//  Silent Shortcuts action: store a bank SMS body in the message inbox
//  without opening the app. Used by personal Message automations.
//

import AppIntents
import Foundation
import SwiftData

private enum LogTransactionMessageIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyMessage
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyMessage:
            return "Message content is empty."
        case .storeUnavailable:
            return "Could not open the message inbox store."
        }
    }
}

struct LogTransactionMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Transaction Message"
    static let description = IntentDescription(
        "Stores a bank SMS body in Spendrift's local message inbox for parsing when you next open the app. Designed for Shortcuts Message automations. Does not open Spendrift."
    )
    static let openAppWhenRun: Bool = false
    /// Ensures the action appears when browsing Spendrift actions in Shortcuts.
    static var isDiscoverable: Bool { true }

    /// How long an identical body fingerprint is treated as a duplicate.
    private static let dedupeWindow: TimeInterval = 5 * 60

    @Parameter(
        title: "Message",
        description: "Full SMS body. Bind Shortcut Input from a Message automation."
    )
    var message: String

    @Parameter(
        title: "Sender",
        description: "Optional SMS sender / bank short code.",
        default: ""
    )
    var sender: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction message \(\.$message)") {
            \.$sender
        }
    }

    /// Empty defaults so App Shortcuts can instantiate the intent for donation / discovery.
    init() {
        self.message = ""
        self.sender = ""
    }

    init(message: String, sender: String = "") {
        self.message = message
        self.sender = sender
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LogTransactionMessageIntentError.emptyMessage
        }

        let redacted = MessageRedactor.redact(trimmed)
        let fingerprint = MessageFingerprint.fingerprint(for: redacted)
        let capturedAt = Date()

        let trimmedSender = sender.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let outcome = try Self.persist(
                body: redacted,
                sender: trimmedSender,
                fingerprint: fingerprint,
                capturedAt: capturedAt
            )
            #if DEBUG
            MessageInboxDebugLog.append(
                body: redacted,
                sender: trimmedSender,
                fingerprint: fingerprint,
                capturedAt: capturedAt,
                outcome: outcome == .duplicate ? .duplicate : .inserted
            )
            #endif
        } catch {
            // Silent intent failures are invisible; fall back to App Group UserDefaults
            // so launch drain can still recover the message.
            MessageInboxFallback.enqueue(
                body: redacted,
                sender: sender,
                fingerprint: fingerprint,
                capturedAt: capturedAt
            )
            #if DEBUG
            MessageInboxDebugLog.append(
                body: redacted,
                sender: trimmedSender,
                fingerprint: fingerprint,
                capturedAt: capturedAt,
                outcome: .fallback
            )
            #endif
            Diagnostics.breadcrumb(
                category: .feature,
                message: "message_inbox_intent_fallback",
                data: [Diagnostics.Tag.feature: Diagnostics.Feature.message.rawValue]
            )
        }

        MessageInboxSettings.recordCapture(at: capturedAt)
        return .result()
    }

    private enum PersistResult {
        case inserted
        case duplicate
    }

    @MainActor
    private static func persist(
        body: String,
        sender: String,
        fingerprint: String,
        capturedAt: Date
    ) throws -> PersistResult {
        let container: ModelContainer
        do {
            container = try MessageInboxSwiftData.makeModelContainer()
        } catch {
            throw LogTransactionMessageIntentError.storeUnavailable
        }

        let context = ModelContext(container)
        let windowStart = capturedAt.addingTimeInterval(-dedupeWindow)
        let descriptor = FetchDescriptor<CapturedTransactionMessage>(
            predicate: #Predicate<CapturedTransactionMessage> {
                $0.fingerprint == fingerprint && $0.capturedAt >= windowStart
            }
        )
        if let existing = try context.fetch(descriptor).first {
            _ = existing
            return .duplicate
        }

        let row = CapturedTransactionMessage(
            body: body,
            sender: sender,
            capturedAt: capturedAt,
            fingerprint: fingerprint
        )
        context.insert(row)
        try context.save()
        return .inserted
    }
}
