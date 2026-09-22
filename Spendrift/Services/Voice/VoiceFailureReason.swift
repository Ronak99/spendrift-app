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

/// How much weight the failure card gives a reason. `blocked` means something outside
/// the app has to change before voice can work again, so it earns the amber icon chip;
/// everything else is `recoverable` and takes the neutral chip. Keeping amber rare is
/// what makes it readable.
enum VoiceFailureTone {
    case blocked
    case recoverable
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

    /// Short headline shown at the top of the failure card. Names the state in a few
    /// words, without the words "error" or "failed", and never blames the user.
    var title: String {
        switch self {
        case .micPermissionDenied: return "Microphone is off"
        case .micUnavailable:      return "Microphone is busy"
        case .recordingTooShort:   return "That was too short to read"
        case .noSpeechDetected:    return "Nothing came through"
        case .audioUnreadable:     return "That recording didn't save"
        case .transcriptionFailed: return "This one didn't go through"
        case .unknown:             return "That didn't go through"
        }
    }

    /// Supporting sentence. Says what to do next rather than what went wrong.
    var guidance: String {
        switch self {
        case .micPermissionDenied:
            return "Voice logging needs mic access. Turn it on in Settings, or type the expense instead."
        case .micUnavailable:
            return "Another app is using audio. Close it, then start the recording again."
        case .recordingTooShort:
            return "Record for at least \(VoiceAudioPolicy.minClipDurationDisplayText) seconds while you speak."
        case .noSpeechDetected:
            return "Record again and say the amount and what it was for."
        case .audioUnreadable:
            return "Record it once more and it should go through."
        case .transcriptionFailed:
            return "Send it again, or type the expense instead."
        case .unknown:
            return "Try it again, or type the expense instead."
        }
    }

    /// Drives the icon chip tint on the failure card.
    var tone: VoiceFailureTone {
        switch self {
        case .micPermissionDenied: return .blocked
        default:                   return .recoverable
        }
    }

    var primaryAction: VoiceFailurePrimaryAction {
        switch self {
        case .micPermissionDenied: return .openSettings
        default:                   return .retry
        }
    }

    /// Always the literal next action, matching the promise the title makes.
    var primaryActionTitle: String {
        switch self {
        case .micPermissionDenied: return "Open Settings"
        case .micUnavailable:      return "Try again"
        case .recordingTooShort,
             .noSpeechDetected,
             .audioUnreadable:     return "Record again"
        case .transcriptionFailed: return "Send again"
        case .unknown:             return "Try again"
        }
    }

    /// The escape hatch offered beside the primary action.
    var secondaryActionTitle: String { "Type it instead" }

    /// Whether the failed audio can be re-sent to the pipeline without forcing the
    /// user to re-record (transient processing failures keep the user in flow).
    var canResendAudio: Bool {
        switch self {
        case .transcriptionFailed, .audioUnreadable: return true
        default:                                      return false
        }
    }
}
