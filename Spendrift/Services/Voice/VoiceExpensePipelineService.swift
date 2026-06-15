//
//  VoiceExpensePipelineService.swift
//  Spendrift
//
//  Created by Cursor on 27/03/26.
//

import Foundation
import SwiftData

enum VoicePipelineError: Error {
    case openAI(String)
}

struct VoiceExpensePipelineService {
    var openAIService = OpenAIVoiceTransactionService()

    @MainActor
    func submitAudio(
        audioData: Data,
        accounts: [Account],
        categories: [TransactionCategory],
        modelContext: ModelContext
    ) async -> Result<VoiceCreateResult, VoicePipelineError> {
        let speechLikely = await VoiceRecordingSpeechPresence.likelyContainsSpeech(wavData: audioData)
        if !speechLikely {
            return .failure(.openAI("No speech detected in the recording."))
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
            return .success(result)
        } catch {
            return .failure(.openAI(error.localizedDescription))
        }
    }
}
