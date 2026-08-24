//
//  MessageRedactorTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct MessageRedactorTests {
    @Test
    func masksLongDigitRunsKeepingLastFour() {
        let input = "INR 450 debited from A/c 123456789012 at STORE"
        let output = MessageRedactor.redact(input)
        #expect(output.contains("****9012"))
        #expect(!output.contains("123456789012"))
    }

    @Test
    func redactsOTPPhrases() {
        let input = "Your OTP is 482913. Do not share."
        let output = MessageRedactor.redact(input)
        #expect(output.contains("[OTP redacted]"))
        #expect(!output.contains("482913"))
    }

    @Test
    func fingerprintIsStableForWhitespaceVariants() {
        let a = MessageFingerprint.fingerprint(for: "INR 10 Debited")
        let b = MessageFingerprint.fingerprint(for: "  inr   10   debited  ")
        #expect(a == b)
    }
}
