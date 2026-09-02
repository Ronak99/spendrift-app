//
//  MessageRedactorTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct MessageRedactorTests {

    // MARK: - OTP codes

    /// Every phrasing below must lose its code, whatever the word order.
    @Test(arguments: [
        "Your OTP is 482913. Do not share.",
        "OTP 482913 for your transaction",
        "OTP: 482913",
        "482913 is your OTP for txn of Rs 2000",
        "Use 482913 as OTP to complete payment",
        "482913 is the One Time Password (OTP). Valid 10 mins.",
        "Your verification code is 482913",
        "Do not share your OTP 482913 with anyone",
        "482913 is your login OTP for HDFC NetBanking",
        "OTP for your transaction is 482913",
        "Your one time password is 482913",
    ])
    func redactsOTPCodeRegardlessOfWordOrder(message: String) {
        let output = MessageRedactor.redact(message)
        #expect(output.contains("[OTP redacted]"))
        #expect(!output.contains("482913"))
    }

    @Test
    func leavesAmountAloneInsideOTPMessages() {
        let output = MessageRedactor.redact("OTP 482910 for Rs 2000 transaction at AMAZON")
        #expect(!output.contains("482910"))
        #expect(output.contains("Rs 2000"))
    }

    @Test
    func ignoresDigitsWithNoOTPKeywordNearby() {
        // "4829" is OTP-length but there is no keyword anywhere, so it stays.
        let output = MessageRedactor.redact("Rs 2000 spent on card ending 4829")
        #expect(output == "Rs 2000 spent on card ending 4829")
    }

    // MARK: - Amounts

    @Test(arguments: [
        "INR 12500 debited",
        "Rs.150000.00 credited",
        "INR 12345678 debited",
        "Salary credit Rs 85000",
        "INR 1,23,456 credited to your account",
    ])
    func preservesAmountsUpToEightDigits(message: String) {
        #expect(MessageRedactor.redact(message) == message)
    }

    // MARK: - Account / card / reference numbers

    @Test
    func masksLongDigitRunsKeepingLastFour() {
        let output = MessageRedactor.redact("INR 450 debited from A/c 123456789012 at STORE")
        #expect(output.contains("****9012"))
        #expect(!output.contains("123456789012"))
    }

    @Test
    func masksRunsOfNineOrMoreDigitsButNotShorterOnes() {
        let output = MessageRedactor.redact("Ref 123456789 for INR 99999")
        #expect(output.contains("****6789"))
        #expect(output.contains("INR 99999"))
    }

    // MARK: - OTP-only classification

    @Test(arguments: [
        "Your OTP is 482913. Do not share.",
        "482913 is your login OTP for HDFC NetBanking",
        "Your verification code is 482913",
        "OTP 482910 for Rs 2000 transaction at AMAZON",
    ])
    func flagsOTPMessagesWithNoMoneyMovement(message: String) {
        #expect(MessageRedactor.isOTPOnlyMessage(message))
    }

    @Test(arguments: [
        "INR 12500 debited",
        "Salary credit Rs 85000",
        // Mixed: a real debit alert that also carries a code. Must be kept.
        "INR 100.00 debited from A/c 998877665544. OTP 123456",
    ])
    func keepsMessagesThatReportCompletedMovement(message: String) {
        #expect(!MessageRedactor.isOTPOnlyMessage(message))
    }

    @Test
    func mixedTransactionAndOTPKeepsAmountAndDropsCode() {
        let raw = "INR 100.00 debited from A/c 998877665544. OTP 123456"
        let output = MessageRedactor.redact(raw)
        #expect(!MessageRedactor.isOTPOnlyMessage(raw))
        #expect(output.contains("INR 100.00"))
        #expect(output.contains("****5544"))
        #expect(output.contains("[OTP redacted]"))
        #expect(!output.contains("123456"))
    }

    // MARK: - Fingerprint

    @Test
    func fingerprintIsStableForWhitespaceVariants() {
        let a = MessageFingerprint.fingerprint(for: "INR 10 Debited")
        let b = MessageFingerprint.fingerprint(for: "  inr   10   debited  ")
        #expect(a == b)
    }
}
