//
//  MessageFingerprint.swift
//  Spendrift
//

import CryptoKit
import Foundation

enum MessageFingerprint {
    /// Normalized SHA-256 hex digest used for short-window inbox dedupe.
    static func fingerprint(for body: String) -> String {
        let normalized = body
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
