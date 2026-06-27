//
//  VoiceExpensePipelineService.swift
//  Spendrift
//
//  Created by Cursor on 27/03/26.
//

import Foundation
import SwiftData

enum VoicePipelineError: Error {
    /// On-device speech-presence gate rejected the clip (silence / no speech).
    case noSpeech
    case aiService(String)
}

struct VoiceExpensePipelineService {
    var voiceService = VoiceTransactionService()

    @MainActor
    func submitAudio(
        audioData: Data,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext,
        isRetry: Bool = false
    ) async -> Result<VoiceCreateResult, VoicePipelineError> {
        let speechLikely = await VoiceRecordingSpeechPresence.likelyContainsSpeech(wavData: audioData)
        if !speechLikely {
            return .failure(.noSpeech)
        }

        do {
            let payload = try await voiceService.parseTransaction(
                audioData: audioData,
                categories: categories
            )

            let result = VoiceTransactionCreator.createFromAIVoice(
                payload: payload,
                accounts: accounts,
                categories: categories,
                modelContext: modelContext,
                isRetry: isRetry
            )
            return .success(result)
        } catch {
            return .failure(.aiService(error.localizedDescription))
        }
    }
}
