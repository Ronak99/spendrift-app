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
    case error(VoiceFailureReason)
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
    /// Live microphone loudness history; drives the waveform in the recording bar.
    let levelMeter = VoiceInputLevelMeter()

    private var speechService = SpeechTranscriptionService()
    private var pipelineService = VoiceExpensePipelineService()
    private var liveActivityController = VoiceLiveActivityController()

    /// Context retained for one-tap retry + analytics attribution.
    private var lastCaptureSource: VoiceCaptureSource = .inApp
    /// Last audio bytes sent to the pipeline, kept so a transient processing failure can be
    /// re-sent without forcing the user to re-record.
    private var retainedAudioData: Data?
    /// `true` while the current capture belongs to a retry chain (drives `is_retry`).
    private var isRetryAttempt = false

    /// Mic / new capture blocked while recording or sending to the AI service.
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
        isRetryAttempt = false
        beginCaptureInternal()
    }

    private func beginCaptureInternal() {
        guard displayState == .hidden else { return }
        manualSheetPayload = nil
        lastCaptureSource = .inApp
        retainedAudioData = nil
        // Live Activity + mic setup run before the recording UI (hint animation) so capture
        // is not blocked behind StreamingText on the main actor.
        liveActivityController.start()
        Task(priority: .userInitiated) {
            await startRecordingSession()
        }
        displayState = .recording
    }

    func cancelCapture() {
        guard displayState == .recording else { return }
        recordingStartedAt = nil
        levelMeter.stop()
        speechService.reset()
        liveActivityController.end(message: "Cancelled")
        resetRetryContext()
        displayState = .hidden
    }

    func dismissError() {
        guard case .error = displayState else { return }
        speechService.reset()
        resetRetryContext()
        displayState = .hidden
    }

    /// One-tap recovery from the failure bar. Re-records, or re-sends the retained audio
    /// for transient processing failures, so the user stays in flow.
    func retry(
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        guard case .error(let reason) = displayState else { return }

        Analytics.capture(.voiceCaptureRetried, [
            Analytics.Key.reason: reason.analyticsValue,
            Analytics.Key.source: lastCaptureSource.rawValue
        ])
        isRetryAttempt = true

        if lastCaptureSource == .imported, reason.canResendAudio, let audioData = retainedAudioData {
            resendRetainedAudio(
                audioData,
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
            return
        }

        // Re-record from scratch (mic / too-short / no-speech, or no audio to resend).
        speechService.reset()
        displayState = .hidden
        beginCaptureInternal()
    }

    /// Deep-link to the app's Settings page so the user can grant microphone access.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func stopAndSubmit(
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        guard displayState == .recording else { return }
        recordingStartedAt = nil
        levelMeter.stop()
        liveActivityController.update(state: .reviewing, message: "Finishing…")
        speechService.stopRecordingForReview()

        Task { @MainActor in
            let duration = await speechService.capturedAudioDurationSeconds()
            let byteCount = speechService.capturedFileByteCount

            guard speechService.capturedRecordingURL != nil, byteCount > 0, duration >= VoiceAudioPolicy.minClipDurationSeconds else {
                speechService.reset()
                liveActivityController.failAndEnd(message: "Too short")
                setError(.recordingTooShort)
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
        lastCaptureSource = .imported
        retainedAudioData = nil

        liveActivityController.start()
        liveActivityController.update(state: .processing, message: "Saving…")
        displayState = .processing

        Task {
            let audioData: Data
            do {
                audioData = try await VoiceShortcutAudioNormalizer.dataForVoicePipeline(from: fileURL)
            } catch {
                await MainActor.run {
                    Self.removeImportedFileIfPresent(fileURL)
                    speechService.reset()
                    liveActivityController.failAndEnd(message: "Invalid audio")
                    setError(Self.reason(for: error))
                }
                return
            }

            guard audioData.count > 440 else {
                await MainActor.run {
                    Self.removeImportedFileIfPresent(fileURL)
                    speechService.reset()
                    liveActivityController.failAndEnd(message: "Too short")
                    setError(.recordingTooShort)
                }
                return
            }

            await MainActor.run { retainedAudioData = audioData }

            let submitResult = await pipelineService.submitAudio(
                audioData: audioData,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext,
                isRetry: isRetryAttempt
            )

            await MainActor.run {
                Self.removeImportedFileIfPresent(fileURL)
                speechService.reset()
                switch submitResult {
                case .success(let result):
                    handleCreateResult(result, accounts: accounts)
                case .failure(let pipelineError):
                    liveActivityController.failAndEnd(message: "Couldn’t save")
                    setError(Self.reason(for: pipelineError))
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
        resetRetryContext()
        displayState = .hidden
    }

    private func startRecordingSession() async {
        let service = speechService
        await Task.detached(priority: .userInitiated) {
            await service.startRecording()
        }.value

        if speechService.state != .recording {
            liveActivityController.failAndEnd(message: "Mic unavailable")
            let reason: VoiceFailureReason = speechService.isMicrophonePermissionDenied
                ? .micPermissionDenied
                : .micUnavailable
            speechService.reset()
            setError(reason)
        } else {
            recordingStartedAt = Date()
            levelMeter.start { [speechService] in
                speechService.currentInputLevel()
            }
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
            speechService.reset()
            liveActivityController.failAndEnd(message: "No audio")
            setError(.audioUnreadable)
            return
        }

        retainedAudioData = audioData

        let submitResult = await pipelineService.submitAudio(
            audioData: audioData,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext,
            isRetry: isRetryAttempt
        )

        await MainActor.run {
            speechService.reset()
            switch submitResult {
            case .success(let result):
                handleCreateResult(result, accounts: accounts)
            case .failure(let pipelineError):
                liveActivityController.failAndEnd(message: "Couldn’t save")
                setError(Self.reason(for: pipelineError))
            }
        }
    }

    /// Re-send already-captured audio without re-recording (transient failure recovery).
    private func resendRetainedAudio(
        _ audioData: Data,
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        displayState = .processing
        liveActivityController.start()
        liveActivityController.update(state: .processing, message: "Saving…")

        Task { @MainActor in
            let submitResult = await pipelineService.submitAudio(
                audioData: audioData,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext,
                isRetry: isRetryAttempt
            )

            switch submitResult {
            case .success(let result):
                handleCreateResult(result, accounts: accounts)
            case .failure(let pipelineError):
                liveActivityController.failAndEnd(message: "Couldn’t save")
                setError(Self.reason(for: pipelineError))
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
            resetRetryContext()
            displayState = .hidden
        case .needsConfirmation(let draft, _):
            liveActivityController.failAndEnd(message: "Review in app")
            manualSheetPayload = VoiceInlineManualSheetPayload(
                draft: draft,
                hint: "Review the details below, then save."
            )
            resetRetryContext()
            displayState = .hidden
        case .needsManualEntry(let draft, let failure):
            liveActivityController.failAndEnd(message: "Needs review")
            manualSheetPayload = VoiceInlineManualSheetPayload(
                draft: draft,
                hint: failureMessage(for: failure)
            )
            resetRetryContext()
            displayState = .hidden
        }
    }

    /// Centralized failure entry point: sets the bar state and fires `voice_capture_failed`.
    private func setError(_ reason: VoiceFailureReason) {
        displayState = .error(reason)
        Analytics.capture(.voiceCaptureFailed, [
            Analytics.Key.reason: reason.analyticsValue,
            Analytics.Key.source: lastCaptureSource.rawValue,
            Analytics.Key.isRetry: isRetryAttempt
        ])
        let tags = [
            Diagnostics.Tag.reason: reason.analyticsValue,
            Diagnostics.Tag.source: lastCaptureSource.rawValue,
            Diagnostics.Tag.method: "voice"
        ]
        Diagnostics.breadcrumb(
            category: .error,
            message: "voice_capture_failed",
            feature: .voice,
            stage: .transcribe,
            data: tags
        )
        if reason == .unknown {
            Diagnostics.log("voice capture failed with unknown reason", level: .error, tags: tags)
        } else {
            Diagnostics.log("voice capture failed", level: .warning, tags: tags)
        }
    }

    private func resetRetryContext() {
        retainedAudioData = nil
        isRetryAttempt = false
    }

    private static func reason(for error: VoicePipelineError) -> VoiceFailureReason {
        switch error {
        case .noSpeech:  return .noSpeechDetected
        case .aiService: return .transcriptionFailed
        }
    }

    private static func reason(for error: Error) -> VoiceFailureReason {
        switch error {
        case VoiceShortcutAudioNormalizerError.durationTooShort,
             VoiceShortcutAudioNormalizerError.emptyAudio:
            return .recordingTooShort
        case is VoiceShortcutAudioNormalizerError:
            return .audioUnreadable
        default:
            return .audioUnreadable
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
    /// For SwiftUI Previews: drive the bar UI without starting the microphone. The recording
    /// state gets a synthetic speech-like level so the waveform has something to draw.
    func applyPreviewDisplayState(_ state: VoiceInlineDisplayState) {
        displayState = state
        recordingStartedAt = (state == .recording) ? Date() : nil
        levelMeter.stop()
        guard state == .recording else { return }
        levelMeter.start {
            let t = Date().timeIntervalSinceReferenceDate
            let syllables = max(0, sin(t * 9)) * 0.6
            let phrase = (sin(t * 0.7) + 1) / 2
            return Float(syllables * phrase + .random(in: 0...0.08))
        }
    }
    #endif
}
