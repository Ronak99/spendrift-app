//
//  VoiceInputLevelMeter.swift
//  Spendrift
//
//  Samples microphone loudness while a voice note is being recorded and keeps a short
//  history of it, so the recording bar can draw a waveform that follows the user's speech
//  the way Voice Memos does.
//

import Foundation

@Observable
@MainActor
final class VoiceInputLevelMeter {
    /// Seconds between samples. 20 Hz is enough to show individual syllables without the
    /// history scrolling past too quickly to read.
    static let sampleInterval: TimeInterval = 0.05

    /// Newest sample last, each in `0...1`. Capped at `capacity`, so the array is the
    /// visible window of history and nothing more.
    private(set) var samples: [Float] = []
    /// When `samples` last changed. The view uses it to glide bars between samples.
    private(set) var lastSampleAt: Date?

    let capacity: Int
    private var samplingTask: Task<Void, Never>?

    init(capacity: Int = 48) {
        self.capacity = capacity
    }

    var isRunning: Bool {
        samplingTask != nil
    }

    /// Starts polling `levelProvider` every `sampleInterval` until `stop()` is called.
    /// Calling it while already running restarts with the new provider.
    func start(levelProvider: @escaping @MainActor () -> Float) {
        stop()
        samples = []
        lastSampleAt = nil
        samplingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.append(levelProvider())
                try? await Task.sleep(for: .seconds(Self.sampleInterval))
            }
        }
    }

    /// Stops sampling and clears the history so the next capture starts from a flat line.
    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        samples = []
        lastSampleAt = nil
    }

    private func append(_ level: Float) {
        samples.append(min(max(level, 0), 1))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        lastSampleAt = Date()
    }
}
