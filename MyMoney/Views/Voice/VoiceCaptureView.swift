//
//  VoiceCaptureView.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import SwiftData
import SwiftUI

/// Stable identity for `sheet(item:)` so optional draft + alert aren’t racing SwiftUI presentation.
private struct ManualEntrySheetPayload: Identifiable {
    let id = UUID()
    let draft: VoiceTransactionDraft
    /// Shown at top of manual entry when AI needed user review (replaces a competing `.alert`).
    let reviewHint: String?
}

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var speechService = SpeechTranscriptionService()
    @State private var openAIService = OpenAIVoiceTransactionService()
    @State private var liveActivityController = VoiceLiveActivityController()
    @State private var previewPlayer = VoicePreviewPlayer()

    @State private var toastMessage: String?
    @State private var manualEntrySheet: ManualEntrySheetPayload?

    @State private var reviewAudioByteCount = 0
    @State private var reviewCaptureDurationSeconds: Double = 0
    @State private var reviewCaptureError: String?
    @State private var isSubmitting = false

    private var isRecording: Bool {
        speechService.state == .recording
    }

    private var hasReviewCapture: Bool {
        speechService.capturedRecordingURL != nil
    }

    private var recordingTooShortForSubmit: Bool {
        reviewAudioByteCount > 0 && reviewCaptureDurationSeconds > 0 && reviewCaptureDurationSeconds < 0.1
    }

    private var canSubmit: Bool {
        !isSubmitting
            && hasReviewCapture
            && reviewAudioByteCount > 0
            && reviewCaptureError == nil
            && !recordingTooShortForSubmit
    }

    private var helperText: String {
        if let reviewCaptureError {
            return reviewCaptureError
        }
        if isSubmitting {
            return "Sending audio to OpenAI..."
        }
        switch speechService.state {
        case .recording:
            return "Speak your transaction naturally. We will send audio to AI and parse JSON."
        case .processing:
            return "Finishing recording..."
        case .failed(let message):
            return message
        default:
            if hasReviewCapture {
                return "What you hear in the preview is what we send. Use Submit when ready."
            }
            return "Try: Paid 20 rs to cab driver."
        }
    }

    private var toastAlertBinding: Binding<Bool> {
        Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(circleFillColor)
                        .frame(width: 140, height: 140)
                    Image(systemName: circleIconName)
                        .font(.system(size: 72))
                        .foregroundStyle(circleIconColor)
                }
                .padding(.top, 24)

                Text(stateLabel)
                    .font(.headline)
                Text(helperText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if hasReviewCapture, !isRecording {
                    reviewSection
                }

                Spacer()

                controlButtons
                    .padding(.bottom, 24)
            }
            .navigationTitle("Voice Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Voice result", isPresented: toastAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(toastMessage ?? "")
            }
            .sheet(item: $manualEntrySheet) { payload in
                UpdateTransactionSheet(
                    transaction: nil,
                    draft: payload.draft,
                    voiceReviewHint: payload.reviewHint
                )
            }
            .onDisappear {
                guard manualEntrySheet == nil else { return }
                previewPlayer.stop()
                speechService.reset()
            }
        }
    }

    private var circleFillColor: Color {
        if isRecording { return Color.red.opacity(0.2) }
        if hasReviewCapture { return Color.orange.opacity(0.2) }
        return Color.accentColor.opacity(0.2)
    }

    private var circleIconName: String {
        if isRecording { return "waveform.circle.fill" }
        if hasReviewCapture { return "waveform.circle" }
        return "mic.circle.fill"
    }

    private var circleIconColor: Color {
        if isRecording { return Color.red }
        if hasReviewCapture { return Color.orange }
        return Color.accentColor
    }

    @ViewBuilder
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "Duration: %.2f s", reviewCaptureDurationSeconds))
                Spacer()
                Text(byteCountLabel)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            if recordingTooShortForSubmit {
                Text("Recording is too short to analyze (about 0.1 s minimum). Tap Re-record.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let err = previewPlayer.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button {
                    previewPlayer.togglePlay()
                } label: {
                    Label(
                        previewPlayer.isPlaying ? "Pause" : "Play",
                        systemImage: previewPlayer.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)

                Button("Re-record") {
                    reRecord()
                }
                .buttonStyle(.bordered)

                Button("Submit") {
                    Task { await submitCapturedAudio() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(.horizontal)
    }

    private var byteCountLabel: String {
        guard reviewAudioByteCount > 0 else { return "— bytes" }
        let f = ByteCountFormatter()
        f.allowedUnits = .useAll
        f.countStyle = .memory
        return f.string(fromByteCount: Int64(reviewAudioByteCount))
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
            if !hasReviewCapture || isRecording {
                Button(primaryActionTitle) {
                    handlePrimaryRecordAction()
                }
                .disabled(isSubmitting || speechService.state == .processing || speechService.state == .requestingPermissions)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var primaryActionTitle: String {
        isRecording ? "Stop" : "Start Recording"
    }

    private var stateLabel: String {
        if isSubmitting {
            return "Submitting..."
        }
        switch speechService.state {
        case .idle:
            return hasReviewCapture ? "Review recording" : "Ready"
        case .requestingPermissions:
            return "Requesting permissions..."
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .failed(let message):
            return "Error: \(message)"
        }
    }

    private func handlePrimaryRecordAction() {
        if speechService.state == .recording {
            liveActivityController.update(state: .transcribing, message: "Review recording...")
            speechService.stopRecordingForReview()
            if let url = speechService.capturedRecordingURL {
                previewPlayer.prepare(url: url)
                Task { await refreshReviewCaptureStats() }
            } else {
                reviewAudioByteCount = 0
                reviewCaptureDurationSeconds = 0
                reviewCaptureError = nil
            }
        } else {
            Task {
                liveActivityController.start()
                await speechService.startRecording()
                liveActivityController.update(state: .recording, message: "Listening...")
                await MainActor.run {
                    reviewAudioByteCount = 0
                    reviewCaptureDurationSeconds = 0
                    reviewCaptureError = nil
                }
            }
        }
    }

    private func reRecord() {
        previewPlayer.stop()
        speechService.discardCapture()
        reviewAudioByteCount = 0
        reviewCaptureDurationSeconds = 0
        reviewCaptureError = nil
        liveActivityController.update(state: .recording, message: "Tap Start when ready")
    }

    @MainActor
    private func refreshReviewCaptureStats() async {
        reviewCaptureError = nil
        do {
            let data = try speechService.audioDataForChatAPI()
            reviewAudioByteCount = data.count
            reviewCaptureDurationSeconds = speechService.capturedAudioDurationSeconds()
        } catch {
            reviewAudioByteCount = 0
            reviewCaptureDurationSeconds = 0
            reviewCaptureError = "Could not read audio for this recording: \(error.localizedDescription)"
        }
    }

    private func submitCapturedAudio() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let audioData: Data
        do {
            audioData = try speechService.audioDataForChatAPI()
        } catch {
            await MainActor.run {
                toastMessage = error.localizedDescription
                liveActivityController.update(state: .failed, message: "Audio read failed")
            }
            return
        }

        await MainActor.run {
            liveActivityController.update(state: .saving, message: "Analyzing voice JSON...")
        }

        do {
            let payload = try await openAIService.parseTransaction(
                audioData: audioData,
                categories: categories
            )

            let result = VoiceTransactionCreator.createFromAIVoice(
                payload: payload,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext
            )

            await MainActor.run {
                handleCreateResult(result)
            }
        } catch {
            await MainActor.run {
                liveActivityController.update(state: .failed, message: "OpenAI error")
                manualEntrySheet = ManualEntrySheetPayload(
                    draft: VoiceTransactionDraft(
                        notes: "",
                        amount: nil,
                        transactionType: .expense,
                        account: accounts.first(where: { $0.isPrimary }),
                        category: nil
                    ),
                    reviewHint: error.localizedDescription
                )
            }
        }
    }

    private func handleCreateResult(_ result: VoiceCreateResult) {
        switch result {
        case .created:
            liveActivityController.end(message: "Saved")
            toastMessage = "Transaction saved from AI voice JSON."
            dismiss()
        case .needsConfirmation(let draft, _):
            manualEntrySheet = ManualEntrySheetPayload(
                draft: draft,
                reviewHint: "Review the details below, then save."
            )
            liveActivityController.update(state: .transcribing, message: "Review required")
        case .needsManualEntry(let draft, let failure):
            manualEntrySheet = ManualEntrySheetPayload(
                draft: draft,
                reviewHint: failureMessage(for: failure)
            )
            liveActivityController.update(state: .failed, message: "Needs manual review")
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
}

#Preview {
    VoiceCaptureView()
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
