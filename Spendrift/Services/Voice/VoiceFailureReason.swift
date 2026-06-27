//
//  VoiceFailureReason.swift
//  Spendrift
//
//  Unified taxonomy for voice-capture hard failures. Replaces the scattered
//  string errors that previously reached the UI so the failure bar can show
//  reason-specific guidance, the correct primary action (retry vs. open
//  Settings), and low-cardinality analytics.
//

import Foundation

/// Where a voice capture originated. Used for retry routing and analytics.
enum VoiceCaptureSource: String {
    case inApp = "in_app"
    case imported = "imported"
}

/// The prominent action offered on the failure bar for a given reason.
enum VoiceFailurePrimaryAction {
    case retry
    case openSettings
}

enum VoiceFailureReason: String, Equatable {
    case micPermissionDenied
    case micUnavailable
    case recordingTooShort
    case noSpeechDetected
    case audioUnreadable
    case transcriptionFailed
    case unknown

    /// Stable, low-cardinality value sent as the `reason` property to PostHog.
    var analyticsValue: String {
        switch self {
        case .micPermissionDenied: return "mic_permission_denied"
        case .micUnavailable:      return "mic_unavailable"
        case .recordingTooShort:   return "recording_too_short"
        case .noSpeechDetected:    return "no_speech_detected"
        case .audioUnreadable:     return "audio_unreadable"
        case .transcriptionFailed: return "transcription_failed"
        case .unknown:             return "unknown"
        }
    }

    /// Short headline shown at the top of the failure bar.
    var title: String {
        switch self {
        case .micPermissionDenied: return "Microphone access needed"
        case .micUnavailable:      return "Microphone unavailable"
        case .recordingTooShort:   return "Recording too short"
        case .noSpeechDetected:    return "Didn't catch that"
        case .audioUnreadable:     return "Couldn't read recording"
        case .transcriptionFailed: return "Couldn't process voice"
        case .unknown:             return "Something went wrong"
        }
    }

    /// Human-readable, reason-specific guidance on what to do next.
    var guidance: String {
        switch self {
        case .micPermissionDenied:
            return "Spendrift needs microphone access to log expenses by voice. Open Settings to turn it on."
        case .micUnavailable:
            return "We couldn't start the microphone. Close other apps using audio, then try again."
        case .recordingTooShort:
            return "Record at least \(VoiceAudioPolicy.minClipDurationDisplayText) seconds, then try again."
        case .noSpeechDetected:
            return "We didn't hear any speech. Try again and say the amount and what it was for."
        case .audioUnreadable:
            return "We couldn't read that recording. Try again."
        case .transcriptionFailed:
            return "We couldn't process your voice just now. Try again, or enter it manually."
        case .unknown:
            return "Something went wrong. Try again, or enter it manually."
        }
    }

    var primaryAction: VoiceFailurePrimaryAction {
        switch self {
        case .micPermissionDenied: return .openSettings
        default:                   return .retry
        }
    }

    var primaryActionTitle: String {
        switch primaryAction {
        case .retry:        return "Try again"
        case .openSettings: return "Open Settings"
        }
    }

    /// Whether the failed audio can be re-sent to the pipeline without forcing the
    /// user to re-record (transient processing failures keep the user in flow).
    var canResendAudio: Bool {
        switch self {
        case .transcriptionFailed, .audioUnreadable: return true
        default:                                      return false
        }
    }
}
