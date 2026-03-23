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
    @State private var liveActivityController = VoiceLiveActivityController()

    @State private var toastMessage: String?
    @State private var showManualSheet = false
    @State private var showConfirmAlert = false
    @State private var manualDraft: VoiceTransactionDraft?
    @State private var pendingConfirmationDraft: VoiceTransactionDraft?

    private var isRecording: Bool {
        speechService.state == .recording
    }

    private var transcriptText: String {
        speechService.transcript.isEmpty ? "Say something like \"Paid 20 rs to cab\"." : speechService.transcript
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
                Text(transcriptText)
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
            .alert("Save transaction?", isPresented: $showConfirmAlert, presenting: pendingConfirmationDraft) { draft in
                Button("Save") {
                    persistDraft(draft)
                }
                Button("Edit", role: .cancel) {
                    manualDraft = draft
                    showManualSheet = true
                }
            } message: { draft in
                Text("Detected \(draft.transactionType.rawValue) of \((draft.amount ?? 0).formatCurrency) in \(draft.category?.name ?? "unknown category").")
            }
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
        case .transcribing:
            return "Transcribing..."
        case .failed(let message):
            return "Error: \(message)"
        }
    }

    private func handleRecordButton() {
        if speechService.state == .recording {
            liveActivityController.update(state: .transcribing, message: "Transcribing...")
            speechService.stopRecording()
            processTranscript()
        } else {
            Task {
                liveActivityController.start()
                await speechService.startRecording()
                liveActivityController.update(state: .recording, message: "Listening...")
            }
        }
    }

    private func processTranscript() {
        let transcript = speechService.finalTranscript.isEmpty ? speechService.transcript : speechService.finalTranscript
        let intent = TransactionIntentParser.parse(transcript)
        let categoryMatch = CategoryMatcher.match(intent: intent, categories: categories)

        liveActivityController.update(state: .saving, message: "Analyzing...")

        let result = VoiceTransactionCreator.createFromVoice(
            intent: intent,
            match: categoryMatch,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )

        switch result {
        case .created:
            liveActivityController.end(message: "Saved")
            toastMessage = "Transaction saved from voice input."
            dismiss()
        case .needsConfirmation(let draft, _):
            pendingConfirmationDraft = draft
            liveActivityController.update(state: .transcribing, message: "Needs confirmation")
            showConfirmAlert = true
        case .needsManualEntry(let draft, let failure):
            manualDraft = draft
            showManualSheet = true
            liveActivityController.update(state: .failed, message: "Needs manual review")
            toastMessage = failureMessage(for: failure)
        }
    }

    private func persistDraft(_ draft: VoiceTransactionDraft) {
        guard let amount = draft.amount, amount > 0 else {
            toastMessage = "Amount missing. Please edit manually."
            manualDraft = draft
            showManualSheet = true
            return
        }
        guard let account = draft.account else {
            toastMessage = "No primary account found. Set one and try again."
            return
        }
        guard let category = draft.category else {
            toastMessage = "Could not match category. Please edit manually."
            manualDraft = draft
            showManualSheet = true
            return
        }

        let transaction = Transaction(
            notes: draft.notes,
            amount: amount,
            date: Date(),
            transactionType: draft.transactionType,
            category: category,
            account: account
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        liveActivityController.end(message: "Saved")
        dismiss()
    }

    private func failureMessage(for failure: VoiceCreateFailure) -> String {
        switch failure {
        case .noPrimaryAccount:
            return "No primary account found. Set a primary account first."
        case .noCategoriesForType:
            return "No categories available for detected transaction type."
        case .amountMissing:
            return "Could not detect amount from speech."
        case .categoryMissing:
            return "Could not confidently match a category."
        case .unknownType:
            return "Could not identify if this is income or expense."
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
