//
//  OnboardingVoiceDemoController.swift
//  Spendrift
//
//  The voice step of onboarding runs the real pipeline - real microphone, real
//  backend parse - then writes the result to the ledger stamped with now, so the
//  first thing they see after "Finish." is the transaction they just spoke.
//

import AVFoundation
import Foundation
import SwiftData
import SwiftUI

/// Everything the onboarding preview row needs, lifted off the SwiftData models so the
/// view never holds on to objects it does not own.
struct OnboardingHeardTransaction: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amountText: String
    let date: Date
    let icon: String
    let tint: Color
    let isExpense: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    init(draft: VoiceTransactionDraft) {
        self.init(
            notes: draft.notes,
            amount: draft.amount ?? 0,
            date: draft.date,
            isExpense: draft.transactionType == .expense,
            category: draft.category,
            accountName: draft.account?.name
        )
    }

    init(transaction: Transaction) {
        self.init(
            notes: transaction.notes,
            amount: transaction.amount,
            date: transaction.date,
            isExpense: transaction.transactionType == .expense,
            category: transaction.category,
            accountName: transaction.account?.name
        )
    }

    private init(
        notes: String,
        amount: Double,
        date: Date,
        isExpense: Bool,
        category: TransactionCategory?,
        accountName: String?
    ) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = category?.name ?? "Uncategorized"

        title = trimmed.isEmpty ? categoryName : trimmed
        subtitle = [trimmed.isEmpty ? nil : categoryName, accountName]
            .compactMap { $0 }
            .joined(separator: " · ")

        self.isExpense = isExpense
        amountText = isExpense ? amount.formatCurrency : "+\(amount.formatCurrency)"
        self.date = date
        icon = category?.icon.systemImageName ?? CategoryIcon.unknown.systemImageName
        tint = CategoryEnamel.color(for: category)
    }
}

@Observable
@MainActor
final class OnboardingVoiceDemoController {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case heard(OnboardingHeardTransaction)
        /// Something in the pipeline did not work out: a refused microphone, a clip with
        /// no speech in it, no network, a backend that said no. Onboarding does not try
        /// to explain which - it offers the door to the app instead. Tapping the plate
        /// again is still allowed, in case the run was simply unlucky.
        case failed
    }

    private(set) var phase: Phase = .idle
    /// Set while the microphone is live; the view uses it to drive the auto-stop deadline.
    private(set) var startedAt: Date?
    let levelMeter = VoiceInputLevelMeter()

    private var speech = SpeechTranscriptionService()

    var isListening: Bool { phase == .listening }

    var allowsTapToSpeak: Bool {
        phase == .idle || phase == .failed
    }

    // MARK: - Capture

    /// Asks for the microphone if needed, then starts recording. Anything that goes
    /// wrong lands on `.failed`; the step never advances on its own.
    func beginListening() async {
        guard allowsTapToSpeak else { return }

        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            phase = .failed
            return
        case .undetermined:
            guard await AVAudioApplication.requestRecordPermission() else {
                phase = .failed
                return
            }
        default:
            break
        }

        // `startRecording` configures an `AVAudioSession`, which blocks; keeping it off the
        // main actor stops the narration animation from stalling behind it.
        let service = speech
        await Task.detached(priority: .userInitiated) {
            await service.startRecording()
        }.value

        guard speech.state == .recording else {
            speech.reset()
            phase = .failed
            return
        }

        startedAt = Date()
        phase = .listening
        levelMeter.start { [speech] in speech.currentInputLevel() }
    }

    func stopAndParse(
        modelContext: ModelContext,
        accounts: [Account],
        categories: [TransactionCategory]
    ) {
        guard phase == .listening else { return }

        startedAt = nil
        levelMeter.stop()
        speech.stopRecordingForReview()
        phase = .thinking

        Task { @MainActor in
            guard let audio = await drainCapturedAudio() else {
                phase = .failed
                return
            }

            guard await VoiceRecordingSpeechPresence.likelyContainsSpeech(wavData: audio) else {
                phase = .failed
                return
            }

            do {
                // The demo runs before the notification page, when a new user has no
                // free credits yet, and the expense it creates is free for everyone.
                let payload = try await VoiceTransactionService().parseTransaction(
                    audioData: audio,
                    categories: categories,
                    quota: .exempt
                )
                let result = VoiceTransactionCreator.createFromAIVoice(
                    payload: payload,
                    accounts: accounts,
                    categories: categories,
                    modelContext: modelContext,
                    recordedAt: Date(),
                    announceProMoment: false
                )
                guard case .created(let transaction) = result else {
                    phase = .failed
                    return
                }
                // The next page asks for notifications. Mark this feature done so the
                // celebration paywall does not cover the row they just created.
                ProGate.markPitched(.voice)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                phase = .heard(OnboardingHeardTransaction(transaction: transaction))
            } catch {
                phase = .failed
            }
        }
    }

    /// Abandons an in-flight capture when the user leaves the step.
    func cancel() {
        startedAt = nil
        levelMeter.stop()
        speech.reset()
        if phase == .listening || phase == .thinking {
            phase = .idle
        }
    }

    /// Reads the recorded clip and clears the service either way, so a rejected take never
    /// leaks a temp file or bleeds into the next attempt.
    private func drainCapturedAudio() async -> Data? {
        defer { speech.reset() }

        let duration = await speech.capturedAudioDurationSeconds()
        guard speech.capturedRecordingURL != nil,
              speech.capturedFileByteCount > 0,
              duration >= VoiceAudioPolicy.minClipDurationSeconds else {
            return nil
        }
        return try? speech.audioDataForChatAPI()
    }

    #if DEBUG
    /// Drives the step's visual states in previews without touching the microphone.
    func applyPreviewPhase(_ phase: Phase) {
        self.phase = phase
        startedAt = phase == .listening ? Date() : nil
        levelMeter.stop()
        guard phase == .listening else { return }
        levelMeter.start {
            let t = Date().timeIntervalSinceReferenceDate
            let syllables = max(0, sin(t * 9)) * 0.6
            let phrase = (sin(t * 0.7) + 1) / 2
            return Float(syllables * phrase + .random(in: 0...0.08))
        }
    }
    #endif
}
