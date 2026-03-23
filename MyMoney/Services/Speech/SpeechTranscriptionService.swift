//
//  SpeechTranscriptionService.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import AVFoundation
import Foundation
import Speech

@Observable
final class SpeechTranscriptionService {
    enum RecordingState: Equatable {
        case idle
        case requestingPermissions
        case recording
        case transcribing
        case failed(String)
    }

    var state: RecordingState = .idle
    var transcript: String = ""
    var finalTranscript: String = ""

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_IN"))

    func requestPermissions() async -> Bool {
        state = .requestingPermissions

        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        if speechAuthorized && micAuthorized {
            state = .idle
            return true
        }

        state = .failed("Microphone or speech permission is not granted.")
        return false
    }

    func startRecording() async {
        if !(await requestPermissions()) { return }

        do {
            transcript = ""
            finalTranscript = ""

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest.shouldReportPartialResults = true
            if #available(iOS 13.0, *) {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            request = recognitionRequest

            guard let speechRecognizer, speechRecognizer.isAvailable else {
                state = .failed("Speech recognizer is not available right now.")
                return
            }

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        finalTranscript = result.bestTranscription.formattedString
                    }
                }

                if let error {
                    state = .failed(error.localizedDescription)
                    stopAudioPipeline()
                }
            }

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .recording
        } catch {
            state = .failed(error.localizedDescription)
            stopAudioPipeline()
        }
    }

    func stopRecording() {
        guard state == .recording || state == .transcribing else { return }
        state = .transcribing
        request?.endAudio()
        stopAudioPipeline()

        if finalTranscript.isEmpty {
            finalTranscript = transcript
        }
        if finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state = .failed("No voice input detected.")
        } else {
            state = .idle
        }
    }

    func reset() {
        stopAudioPipeline()
        transcript = ""
        finalTranscript = ""
        state = .idle
    }

    private func stopAudioPipeline() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
