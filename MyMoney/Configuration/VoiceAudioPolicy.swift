//
//  VoiceAudioPolicy.swift
//  MyMoney
//
//  Created by Cursor on 01/04/26.
//

import Foundation

enum VoiceAudioPolicy {
    /// Minimum viable audio length to avoid empty/accidental submissions.
    static let minClipDurationSeconds: Double = 0.1
    /// Global cap for all voice submissions (in-app + imported intent audio).
    static let maxClipDurationSeconds: Double = 30

    static var maxClipDurationDisplayText: String {
        let wholeSeconds = Int(maxClipDurationSeconds.rounded())
        return "\(wholeSeconds)"
    }
}
