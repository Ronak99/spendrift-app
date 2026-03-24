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
    enum RecordingState: Equatable {
        case idle
        case requestingPermissions
        case recording
        case processing
        case failed(String)
    }

    var state: RecordingState = .idle
    var recordedAudioData: Data?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

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
            recordedAudioData = nil

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-input-\(UUID().uuidString).caf")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 24_000,
                AVNumberOfChannelsKey: 1,
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

    func stopRecording() {
        guard state == .recording else { return }
        state = .processing

        audioRecorder?.stop()
        audioRecorder = nil

        defer {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        guard let recordingURL else {
            state = .failed("Could not access recorded audio.")
            return
        }

        do {
            recordedAudioData = try loadPCM16Data(from: recordingURL)
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
            state = .idle
        } catch {
            state = .failed("Could not read recorded audio.")
        }
    }

    func reset() {
        cleanup()
        recordedAudioData = nil
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

    private func loadPCM16Data(from url: URL) throws -> Data {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SpeechTranscriptionService", code: -1)
        }
        try file.read(into: buffer)

        let channels = Int(format.channelCount)
        let samples = Int(buffer.frameLength)
        guard let floatData = buffer.floatChannelData else {
            throw NSError(domain: "SpeechTranscriptionService", code: -2)
        }

        var pcm = Data(capacity: samples * channels * MemoryLayout<Int16>.size)
        for sampleIndex in 0..<samples {
            for channelIndex in 0..<channels {
                let sample = floatData[channelIndex][sampleIndex]
                let clamped = max(-1.0, min(1.0, sample))
                var int16 = Int16(clamped * Float(Int16.max))
                pcm.append(Data(bytes: &int16, count: MemoryLayout<Int16>.size))
            }
        }
        return pcm
    }
}
