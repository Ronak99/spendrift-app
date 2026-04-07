//
//  VoiceInlineCaptureController.swift
//  Spendrift
//
//  Created by Cursor on 28/03/26.
//

import Foundation
import SwiftData
import UIKit

enum VoiceInlineDisplayState: Equatable {
    case hidden
    case recording
    case processing
    case error(String)
}

struct VoiceInlineManualSheetPayload: Identifiable {
    let id = UUID()
    let draft: VoiceTransactionDraft
    let hint: String?
}

@Observable
@MainActor
final class VoiceInlineCaptureController {
    private(set) var displayState: VoiceInlineDisplayState = .hidden
    var manualSheetPayload: VoiceInlineManualSheetPayload?
    /// Set when the microphone begins capturing; drives the progress ring in the recording bar.
    private(set) var recordingStartedAt: Date?

    private var speechService = SpeechTranscriptionService()
    private var pipelineService = VoiceExpensePipelineService()
    private var liveActivityController = VoiceLiveActivityController()

    /// Mic / new capture blocked while recording or sending to OpenAI.
    var blocksNewCapture: Bool {
        switch displayState {
        case .recording, .processing:
            return true
        case .hidden, .error:
            return false
        }
    }

    var isBarVisible: Bool {
        displayState != .hidden
    }

    func beginCapture() {
        guard displayState == .hidden else { return }
        displayState = .recording
        manualSheetPayload = nil
        Task {
            await startRecordingSession()
        }
    }

    func cancelCapture() {
        guard displayState == .recording else { return }
        recordingStartedAt = nil
        speechService.reset()
        liveActivityController.end(message: "Cancelled")
        displayState = .hidden
    }

    func dismissError() {
        guard case .error = displayState else { return }
        speechService.reset()
        displayState = .hidden
    }

    func stopAndSubmit(
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        guard displayState == .recording else { return }
        recordingStartedAt = nil
        liveActivityController.update(state: .reviewing, message: "Finishing…")
        speechService.stopRecordingForReview()

        Task { @MainActor in
            let duration = await speechService.capturedAudioDurationSeconds()
            let byteCount = speechService.capturedFileByteCount

            guard speechService.capturedRecordingURL != nil, byteCount > 0, duration >= VoiceAudioPolicy.minClipDurationSeconds else {
                speechService.reset()
                liveActivityController.failAndEnd(message: "Too short")
                displayState = .error(
                    "Record at least \(VoiceAudioPolicy.minClipDurationDisplayText) seconds, then try again."
                )
                return
            }

            displayState = .processing
            liveActivityController.update(state: .processing, message: "Saving…")

            await runPipeline(
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
        }
    }

    /// Process audio copied from Shortcuts (`VoiceExpenseIntent` + `IntentFile`). Deletes `fileURL` when finished.
    func processImportedAudio(
        fileURL: URL,
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        guard displayState == .hidden else { return }
        manualSheetPayload = nil

        liveActivityController.start()
        liveActivityController.update(state: .processing, message: "Saving…")
        displayState = .processing

        Task {
            let audioData: Data
            do {
                audioData = try await VoiceShortcutAudioNormalizer.dataForOpenAIVoicePipeline(from: fileURL)
            } catch {
                await MainActor.run {
                    Self.removeImportedFileIfPresent(fileURL)
                    speechService.reset()
                    liveActivityController.failAndEnd(message: "Invalid audio")
                    displayState = .error(error.localizedDescription)
                }
                return
            }

            guard audioData.count > 440 else {
                await MainActor.run {
                    Self.removeImportedFileIfPresent(fileURL)
                    speechService.reset()
                    liveActivityController.failAndEnd(message: "Too short")
                    displayState = .error(
                        "Recording must be at least \(VoiceAudioPolicy.minClipDurationDisplayText) seconds."
                    )
                }
                return
            }

            let submitResult = await pipelineService.submitAudio(
                audioData: audioData,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext
            )

            await MainActor.run {
                Self.removeImportedFileIfPresent(fileURL)
                speechService.reset()
                switch submitResult {
                case .success(let result):
                    handleCreateResult(result, accounts: accounts)
                case .failure(let pipelineError):
                    liveActivityController.failAndEnd(message: "Couldn’t save")
                    displayState = .error(pipelineErrorMessage(pipelineError))
                }
            }
        }
    }

    private static func removeImportedFileIfPresent(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func openManualFromError(accounts: [Account], hint: String) {
        manualSheetPayload = VoiceInlineManualSheetPayload(
            draft: VoiceTransactionDraft(
                notes: "",
                amount: nil,
                date: Date(),
                transactionType: .expense,
                account: accounts.first(where: { $0.isPrimary }),
                category: nil
            ),
            hint: hint
        )
        displayState = .hidden
    }

    private func startRecordingSession() async {
        liveActivityController.start()
        await speechService.startRecording()
        if speechService.state != .recording {
            liveActivityController.failAndEnd(message: "Mic unavailable")
            let message: String
            if case .failed(let reason) = speechService.state {
                message = reason
            } else {
                message = "Could not start recording."
            }
            speechService.reset()
            displayState = .error(message)
        } else {
            recordingStartedAt = Date()
            liveActivityController.update(state: .recording, message: "Listening…")
        }
    }

    private func runPipeline(
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) async {
        let audioData: Data
        do {
            audioData = try speechService.audioDataForChatAPI()
        } catch {
            await MainActor.run {
                speechService.reset()
                liveActivityController.failAndEnd(message: "No audio")
                displayState = .error("Could not read recording. Try again.")
            }
            return
        }

        let submitResult = await pipelineService.submitAudio(
            audioData: audioData,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )

        await MainActor.run {
            speechService.reset()
            switch submitResult {
            case .success(let result):
                handleCreateResult(result, accounts: accounts)
            case .failure(let pipelineError):
                liveActivityController.failAndEnd(message: "Couldn’t save")
                displayState = .error(pipelineErrorMessage(pipelineError))
            }
        }
    }

    private func handleCreateResult(_ result: VoiceCreateResult, accounts: [Account]) {
        switch result {
        case .created(let transaction):
            let categoryName = transaction.category?.name ?? "Expense"
            let amountLabel = transaction.amount.formatCurrency
            liveActivityController.succeedAndEnd(message: "\(amountLabel) · \(categoryName)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            displayState = .hidden
        case .needsConfirmation(let draft, _):
            liveActivityController.failAndEnd(message: "Review in app")
            manualSheetPayload = VoiceInlineManualSheetPayload(
                draft: draft,
                hint: "Review the details below, then save."
            )
            displayState = .hidden
        case .needsManualEntry(let draft, let failure):
            liveActivityController.failAndEnd(message: "Needs review")
            manualSheetPayload = VoiceInlineManualSheetPayload(
                draft: draft,
                hint: failureMessage(for: failure)
            )
            displayState = .hidden
        }
    }

    private func pipelineErrorMessage(_ error: VoicePipelineError) -> String {
        switch error {
        case .openAI(let message):
            return message
        }
    }

    private func failureMessage(for failure: VoiceCreateFailure) -> String {
        switch failure {
        case .aiError(let reason):
            return reason
        case .invalidJSON:
            return "Model response was not valid JSON."
        case .noPrimaryAccount:
            return "No primary account found. Set a primary account first."
        case .noCategoriesForType:
            return "No categories available for detected transaction type."
        case .amountMissing:
            return "Could not detect amount from AI JSON."
        case .categoryMissing:
            return "Could not confidently match a category from allowed list."
        case .unknownType:
            return "Could not identify if this is income or expense."
        case .invalidDate:
            return "Could not parse transaction date from AI JSON."
        }
    }

    #if DEBUG
    /// For SwiftUI Previews: drive the bar UI without starting the microphone.
    func applyPreviewDisplayState(_ state: VoiceInlineDisplayState) {
        displayState = state
        recordingStartedAt = (state == .recording) ? Date() : nil
    }
    #endif
}
