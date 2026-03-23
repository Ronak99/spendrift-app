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

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-input-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
            recordedAudioData = try Data(contentsOf: recordingURL)
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
}
