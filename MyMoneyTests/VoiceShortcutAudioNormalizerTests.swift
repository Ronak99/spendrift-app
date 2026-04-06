//
//  VoiceShortcutAudioNormalizerTests.swift
//  MyMoneyTests
//
//  Created by Cursor on 29/03/26.
//

import XCTest

@testable import MyMoney

final class VoiceShortcutAudioNormalizerTests: XCTestCase {

    func testAcceptsWAVAtLeastMinDuration() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-norm-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let sampleRate = 44_100
        let seconds = VoiceAudioPolicy.minClipDurationSeconds + 0.1
        let sampleCount = Int(Double(sampleRate) * seconds)
        let pcm = Data(count: sampleCount * MemoryLayout<Int16>.size)
        let wav = Self.makeWAVData(pcm: pcm, sampleRate: UInt32(sampleRate), channels: 1, bitsPerSample: 16)
        try wav.write(to: url)

        let out = try VoiceShortcutAudioNormalizer.dataForOpenAIVoicePipeline(from: url)

        XCTAssertGreaterThanOrEqual(out.count, 12)
        XCTAssertEqual(String(data: out.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: out.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
        XCTAssertGreaterThan(out.count, 1_000)
    }

    func testRejectsTooShortWhenDurationKnown() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-norm-short-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let sampleRate = 44_100
        let seconds = max(0.05, VoiceAudioPolicy.minClipDurationSeconds - 0.5)
        let sampleCount = Int(Double(sampleRate) * seconds)
        let pcm = Data(count: sampleCount * MemoryLayout<Int16>.size)
        let wav = Self.makeWAVData(pcm: pcm, sampleRate: UInt32(sampleRate), channels: 1, bitsPerSample: 16)
        try wav.write(to: url)

        XCTAssertThrowsError(try VoiceShortcutAudioNormalizer.dataForOpenAIVoicePipeline(from: url)) { error in
            XCTAssertEqual(error as? VoiceShortcutAudioNormalizerError, .durationTooShort)
        }
    }

    // MARK: - WAV builder (PCM 16-bit mono LE)

    private static func makeWAVData(
        pcm: Data,
        sampleRate: UInt32,
        channels: UInt16,
        bitsPerSample: UInt16
    ) -> Data {
        let dataChunkSize = UInt32(pcm.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let riffChunkSize = 36 + dataChunkSize

        var out = Data()
        out.append(contentsOf: "RIFF".utf8)
        out.appendUInt32LE(riffChunkSize)
        out.append(contentsOf: "WAVE".utf8)
        out.append(contentsOf: "fmt ".utf8)
        out.appendUInt32LE(16)
        out.appendUInt16LE(1)
        out.appendUInt16LE(channels)
        out.appendUInt32LE(sampleRate)
        out.appendUInt32LE(byteRate)
        out.appendUInt16LE(blockAlign)
        out.appendUInt16LE(bitsPerSample)
        out.append(contentsOf: "data".utf8)
        out.appendUInt32LE(dataChunkSize)
        out.append(pcm)
        return out
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
