//
//  VoiceRecordingSpeechPresence.swift
//  Spendrift
//
//  Uses on-device speech recognition to detect whether the clip likely contains speech,
//  so silent recordings are not sent to the audio model (which may hallucinate amounts).
//

import Foundation
import Speech

enum VoiceRecordingSpeechPresence {
    private static let recognitionTimeoutNanoseconds: UInt64 = 8_000_000_000

    /// `false` when recognition is authorized and produces an empty final transcript; otherwise `true` (fail-open if recognition cannot run).
    static func likelyContainsSpeech(wavData: Data) async -> Bool {
        guard !wavData.isEmpty else { return false }

        let auth = await resolvedAuthorizationStatus()
        guard auth == .authorized else { return true }

        guard let recognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent), recognizer.isAvailable else {
            return true
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-gate-\(UUID().uuidString).wav")
        do {
            try wavData.write(to: url)
        } catch {
            return true
        }
        defer { try? FileManager.default.removeItem(at: url) }

        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            var finished = false
            let finishLock = NSLock()
            func finish(_ value: Bool) {
                finishLock.lock()
                defer { finishLock.unlock() }
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }

            let task = recognizer.recognitionTask(with: request) { result, error in
                if error != nil {
                    finish(true)
                    return
                }
                guard let result else {
                    finish(true)
                    return
                }
                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    finish(!text.isEmpty)
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: Self.recognitionTimeoutNanoseconds)
                task.cancel()
                finish(true)
            }
        }
    }

    private static func resolvedAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status != .notDetermined { return status }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
