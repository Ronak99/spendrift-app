//
//  SpeechTranscriptionService.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import AVFoundation
import Foundation

@Observable
final class SpeechTranscriptionService {
    private static let recordingSampleRate: Double = 44_100
    private static let recordingChannels: Int = 1

    enum RecordingState: Equatable {
        case idle
        case requestingPermissions
        case recording
        case processing
        case failed(String)
    }

    var state: RecordingState = .idle
    /// Playable linear PCM `.wav` (Chat Completions `input_audio` allows `wav` or `mp3` only).
    private(set) var capturedRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    var capturedFileByteCount: Int64 {
        guard let url = capturedRecordingURL else { return 0 }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    /// Duration of the captured file in seconds (for gating and review UI).
    func capturedAudioDurationSeconds() async -> Double {
        guard let url = capturedRecordingURL else { return 0 }
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, !seconds.isNaN else { return 0 }
            return seconds
        } catch {
            return 0
        }
    }

    func requestPermissions() async -> Bool {
        state = .requestingPermissions

        let micAuthorized = await AVAudioApplication.requestRecordPermission()

        if micAuthorized {
            state = .idle
            return true
        }

        state = .failed("Microphone permission is not granted.")
        return false
    }

    func startRecording() async {
        if !(await requestPermissions()) { return }

        do {
            discardCapture()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-input-\(UUID().uuidString).wav")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: Self.recordingSampleRate,
                AVNumberOfChannelsKey: Self.recordingChannels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.record(forDuration: VoiceAudioPolicy.maxClipDurationSeconds)

            recordingURL = url
            audioRecorder = recorder
            state = .recording
        } catch {
            state = .failed(error.localizedDescription)
            cleanup()
        }
    }

    /// Stops recording and keeps a playable `.wav` for preview and Chat Completions upload.
    func stopRecordingForReview() {
        guard state == .recording else { return }
        state = .processing

        audioRecorder?.stop()
        audioRecorder = nil

        defer {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        guard let sourceURL = recordingURL else {
            state = .failed("Could not access recorded audio.")
            return
        }
        self.recordingURL = nil

        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("voice-review-\(UUID().uuidString).wav")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: sourceURL, to: dest)
            capturedRecordingURL = dest
            state = .idle
        } catch {
            state = .failed("Could not preserve recording for review.")
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }

    /// Raw file bytes for `input_audio` (base64-encoded by the client).
    func audioDataForChatAPI() throws -> Data {
        guard let url = capturedRecordingURL else {
            throw NSError(
                domain: "SpeechTranscriptionService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "No captured recording"]
            )
        }
        return try Data(contentsOf: url)
    }

    func discardCapture() {
        if let capturedRecordingURL {
            try? FileManager.default.removeItem(at: capturedRecordingURL)
            self.capturedRecordingURL = nil
        }
    }

    func reset() {
        cleanup()
        discardCapture()
        state = .idle
    }

    private func cleanup() {
        audioRecorder?.stop()
        audioRecorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
