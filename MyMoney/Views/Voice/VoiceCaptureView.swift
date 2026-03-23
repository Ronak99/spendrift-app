//
//  VoiceCaptureView.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import SwiftData
import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var speechService = SpeechTranscriptionService()
    @State private var openAIService = OpenAIVoiceTransactionService()
    @State private var liveActivityController = VoiceLiveActivityController()

    @State private var toastMessage: String?
    @State private var showManualSheet = false
    @State private var manualDraft: VoiceTransactionDraft?

    private var isRecording: Bool {
        speechService.state == .recording
    }

    private var helperText: String {
        switch speechService.state {
        case .recording:
            return "Speak your transaction naturally. We will send raw audio to AI and parse JSON."
        case .processing:
            return "Analyzing audio..."
        case .failed(let message):
            return message
        default:
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
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.2))
                        .frame(width: 140, height: 140)
                    Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(isRecording ? Color.red : Color.accentColor)
                }
                .padding(.top, 24)

                Text(stateLabel)
                    .font(.headline)
                Text(helperText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 16) {
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                    Button(actionTitle) {
                        handleRecordButton()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Voice Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Voice result", isPresented: toastAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(toastMessage ?? "")
            }
            .sheet(isPresented: $showManualSheet) {
                if let manualDraft {
                    UpdateTransactionSheet(
                        transaction: nil,
                        draft: manualDraft
                    )
                }
            }
        }
    }

    private var actionTitle: String {
        speechService.state == .recording ? "Stop" : "Start Recording"
    }

    private var stateLabel: String {
        switch speechService.state {
        case .idle:
            return "Ready"
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

    private func handleRecordButton() {
        if speechService.state == .recording {
            liveActivityController.update(state: .transcribing, message: "Uploading audio...")
            speechService.stopRecording()
            Task {
                await processRecordedAudio()
            }
        } else {
            Task {
                liveActivityController.start()
                await speechService.startRecording()
                liveActivityController.update(state: .recording, message: "Listening...")
            }
        }
    }

    private func processRecordedAudio() async {
        guard let audioData = speechService.recordedAudioData else {
            toastMessage = "No audio captured. Please try again."
            liveActivityController.update(state: .failed, message: "No audio captured")
            return
        }

        liveActivityController.update(state: .saving, message: "Analyzing voice JSON...")

        do {
            let payload = try await openAIService.parseTransaction(
                audioData: audioData,
                categories: categories
            )

//            let result = VoiceTransactionCreator.createFromAIVoice(
//                payload: payload,
//                accounts: accounts,
//                categories: categories,
//                modelContext: modelContext
//            )
//
//            handleCreateResult(result)
        } catch {
            liveActivityController.update(state: .failed, message: "OpenAI error")
            toastMessage = error.localizedDescription
            manualDraft = VoiceTransactionDraft(
                notes: "",
                amount: nil,
                transactionType: .expense,
                account: accounts.first(where: { $0.isPrimary }),
                category: nil
            )
            showManualSheet = true
        }
    }

    private func handleCreateResult(_ result: VoiceCreateResult) {
        switch result {
        case .created:
            liveActivityController.end(message: "Saved")
            toastMessage = "Transaction saved from AI voice JSON."
            dismiss()
        case .needsConfirmation(let draft, _):
            // Requirement says no follow-up question; prefill manual confirmation instead.
            manualDraft = draft
            showManualSheet = true
            liveActivityController.update(state: .transcribing, message: "Review required")
        case .needsManualEntry(let draft, let failure):
            manualDraft = draft
            showManualSheet = true
            liveActivityController.update(state: .failed, message: "Needs manual review")
            toastMessage = failureMessage(for: failure)
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
