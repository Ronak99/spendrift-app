//
//  VoiceShortcutAudioNormalizer.swift
//  Spendrift
//
//  Created by Cursor on 29/03/26.
//

import AVFoundation
import Foundation

enum VoiceShortcutAudioNormalizerError: LocalizedError, Equatable {
    case fileNotFound
    case noAudioTrack
    case readerFailed(String)
    case durationTooShort
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file is missing."
        case .noAudioTrack:
            return "No audio track in file."
        case .readerFailed(let message):
            return message
        case .durationTooShort:
            return "Recording is too short. It must be at least \(VoiceAudioPolicy.minClipDurationDisplayText) seconds."
        case .emptyAudio:
            return "Audio file is empty."
        }
    }
}

enum VoiceShortcutAudioNormalizer {
    private static let targetSampleRate: Double = 44_100
    private static let targetChannels: UInt32 = 1
    private static let bitsPerSample: UInt16 = 16

    /// Produces linear PCM WAV bytes suitable for `OpenAIVoiceTransactionService` / Chat Completions `input_audio`.
    static func dataForOpenAIVoicePipeline(from fileURL: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw VoiceShortcutAudioNormalizerError.fileNotFound
        }

        let asset = AVURLAsset(url: fileURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite, durationSeconds > 0, durationSeconds < VoiceAudioPolicy.minClipDurationSeconds {
            throw VoiceShortcutAudioNormalizerError.durationTooShort
        }

        let tracks = asset.tracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw VoiceShortcutAudioNormalizerError.noAudioTrack
        }

        let pcm = try extractLinearPCMMonoInt16(from: asset, track: track)
        let clippedPCM = clipPCMToMaxDuration(pcm)

        guard !clippedPCM.isEmpty else {
            throw VoiceShortcutAudioNormalizerError.emptyAudio
        }

        return wrapPCMInWAV(
            pcm: clippedPCM,
            sampleRate: UInt32(Self.targetSampleRate),
            channels: UInt16(Self.targetChannels),
            bitsPerSample: Self.bitsPerSample
        )
    }

    static func clipPCMToMaxDuration(_ pcm: Data) -> Data {
        let bytesPerSecond = Int(Self.targetSampleRate) * Int(Self.targetChannels) * Int(Self.bitsPerSample) / 8
        let maxBytes = Int(VoiceAudioPolicy.maxClipDurationSeconds * Double(bytesPerSecond))
        guard maxBytes > 0, pcm.count > maxBytes else { return pcm }
        return Data(pcm.prefix(maxBytes))
    }

    private static func extractLinearPCMMonoInt16(from asset: AVAsset, track: AVAssetTrack) throws -> Data {
        do {
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: targetSampleRate,
                AVNumberOfChannelsKey: targetChannels,
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw VoiceShortcutAudioNormalizerError.readerFailed("Cannot decode audio track.")
            }
            reader.add(output)
            reader.startReading()

            var pcm = Data()
            while let sampleBuffer = output.copyNextSampleBuffer() {
                autoreleasepool {
                    guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
                    let length = CMBlockBufferGetDataLength(block)
                    guard length > 0 else { return }
                    var chunk = Data(count: length)
                    chunk.withUnsafeMutableBytes { raw in
                        guard let base = raw.baseAddress else { return }
                        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
                    }
                    pcm.append(chunk)
                }
            }

            if reader.status == .failed, let err = reader.error {
                throw VoiceShortcutAudioNormalizerError.readerFailed(err.localizedDescription)
            }

            return pcm
        } catch let error as VoiceShortcutAudioNormalizerError {
            throw error
        } catch {
            throw VoiceShortcutAudioNormalizerError.readerFailed(error.localizedDescription)
        }
    }

    private static func wrapPCMInWAV(pcm: Data, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
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
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
