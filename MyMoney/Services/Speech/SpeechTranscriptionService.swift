//
//  SpeechTranscriptionService.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import AVFoundation
import Foundation

@Observable
final class SpeechTranscriptionService {
    /// Must match `OpenAIVoiceTransactionService` / Realtime `pcm16` session (24 kHz mono).
    static let realtimeSampleRate: Double = 24_000
    static let realtimeChannelCount: Int = 1

    enum RecordingState: Equatable {
        case idle
        case requestingPermissions
        case recording
        case processing
        case failed(String)
    }

    var state: RecordingState = .idle
    /// PCM16 LE mono at `realtimeSampleRate`, built from `capturedRecordingURL` when needed.
    var recordedAudioData: Data?
    /// Playable Linear PCM `.caf` kept until submit or discard (preview = what we encode for API).
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

    /// Duration implied by PCM byte count (after conversion from captured file).
    static func derivedPCMdurationSeconds(pcmByteCount: Int) -> Double {
        let bytesPerSecond = realtimeSampleRate * Double(realtimeChannelCount * MemoryLayout<Int16>.size)
        guard bytesPerSecond > 0 else { return 0 }
        return Double(pcmByteCount) / bytesPerSecond
    }

    func requestPermissions() async -> Bool {
        state = .requestingPermissions

        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

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
            recordedAudioData = nil

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-input-\(UUID().uuidString).caf")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: Self.realtimeSampleRate,
                AVNumberOfChannelsKey: Self.realtimeChannelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.record()

            recordingURL = url
            audioRecorder = recorder
            state = .recording
        } catch {
            state = .failed(error.localizedDescription)
            cleanup()
        }
    }

    /// Stops recording and keeps a playable `.caf` for preview + PCM conversion on submit.
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

        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("voice-review-\(UUID().uuidString).caf")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: sourceURL, to: dest)
            capturedRecordingURL = dest
            recordedAudioData = nil
            state = .idle
        } catch {
            state = .failed("Could not preserve recording for review.")
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }

    /// Builds PCM16 for OpenAI Realtime from the captured file.
    func pcmDataForRealtime() throws -> Data {
        guard let url = capturedRecordingURL else {
            throw NSError(domain: "SpeechTranscriptionService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No captured recording"])
        }
        return try Self.loadPCM16Data(from: url)
    }

    func discardCapture() {
        if let capturedRecordingURL {
            try? FileManager.default.removeItem(at: capturedRecordingURL)
            self.capturedRecordingURL = nil
        }
        recordedAudioData = nil
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

    private static func loadPCM16Data(from url: URL) throws -> Data {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SpeechTranscriptionService", code: -1)
        }
        try file.read(into: buffer)

        let channels = Int(format.channelCount)
        let samples = Int(buffer.frameLength)

        var pcm = Data(capacity: samples * channels * MemoryLayout<Int16>.size)

        if let floatData = buffer.floatChannelData {
            for sampleIndex in 0..<samples {
                for channelIndex in 0..<channels {
                    let sample = floatData[channelIndex][sampleIndex]
                    let clamped = max(-1.0, min(1.0, sample))
                    let scaled = clamped * 32_767.0
                    var int16LE = Int16(scaled).littleEndian
                    withUnsafeBytes(of: &int16LE) { pcm.append(contentsOf: $0) }
                }
            }
        } else if let int16Data = buffer.int16ChannelData {
            for sampleIndex in 0..<samples {
                for channelIndex in 0..<channels {
                    var sample = int16Data[channelIndex][sampleIndex].littleEndian
                    withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
                }
            }
        } else {
            throw NSError(domain: "SpeechTranscriptionService", code: -2)
        }

        return pcm
    }
}
