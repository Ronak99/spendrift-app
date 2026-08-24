//
//  DeveloperModeTests.swift
//  SpendriftTests
//

import Testing
@testable import Spendrift

struct DeveloperModeTests {
    @Test
    func passphraseMatchesExactDeveloperText() {
        #expect(DeveloperMode.isPassphrase("developer"))
        #expect(DeveloperMode.isPassphrase("  developer  "))
        #expect(DeveloperMode.isPassphrase("developer\n"))
    }

    @Test
    func passphraseRejectsAnythingElse() {
        #expect(!DeveloperMode.isPassphrase("Developer"))
        #expect(!DeveloperMode.isPassphrase("developer mode"))
        #expect(!DeveloperMode.isPassphrase("please add dark mode"))
        #expect(!DeveloperMode.isPassphrase(""))
        #expect(!DeveloperMode.isPassphrase(" developer."))
    }
}
