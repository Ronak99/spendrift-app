//
//  VoiceAudioPolicy.swift
//  MyMoney
//
//  Created by Cursor on 01/04/26.
//

import Foundation

enum VoiceAudioPolicy {
    /// Minimum recording length before sending audio to the model (in-app and Shortcuts).
    static let minClipDurationSeconds: Double = 3
    /// Global cap for all voice submissions (in-app + imported intent audio).
    static let maxClipDurationSeconds: Double = 30

    static var maxClipDurationDisplayText: String {
        let wholeSeconds = Int(maxClipDurationSeconds.rounded())
        return "\(wholeSeconds)"
    }

    static var minClipDurationDisplayText: String {
        let wholeSeconds = Int(minClipDurationSeconds.rounded(.up))
        return "\(wholeSeconds)"
    }
}
