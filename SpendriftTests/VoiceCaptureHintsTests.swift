//
//  VoiceCaptureHintsTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct VoiceCaptureHintsTests {
    private static let samplePayload: [String: Any] = [
        "locales": [
            "en_IN": [
                "scripts": [
                    #"Try saying, "₹250 for Lunch""#,
                    #"Try saying, "Paid 3500 for electric bill""#
                ]
            ],
            "en_US": [
                "scripts": [
                    #"Try saying, \"$50 for lunch\""#
                ]
            ]
        ]
    ]

    @Test
    func returnsScriptsForMatchingLocale() {
        let scripts = VoiceCaptureHints.parseScripts(from: Self.samplePayload, localeIdentifier: "en_IN")
        #expect(scripts.count == 2)
        #expect(scripts.first?.contains("₹250") == true)
    }

    @Test
    func missingLocaleReturnsEmpty() {
        let scripts = VoiceCaptureHints.parseScripts(from: Self.samplePayload, localeIdentifier: "de_DE")
        #expect(scripts.isEmpty)
    }

    @Test
    func missingPayloadReturnsEmpty() {
        let scripts = VoiceCaptureHints.scripts(for: "en_IN", payload: nil)
        #expect(scripts.isEmpty)
    }

    @Test
    func stripsBlankScriptLines() {
        let payload: [String: Any] = [
            "locales": [
                "en_IN": ["scripts": ["  Valid line  ", "   ", ""]]
            ]
        ]
        let scripts = VoiceCaptureHints.parseScripts(from: payload, localeIdentifier: "en_IN")
        #expect(scripts == ["Valid line"])
    }
}
