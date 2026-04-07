//
//  OnboardingShortcutShareLinks.swift
//  Spendrift
//
//  iCloud links for shortcuts users can add during onboarding.
//  In Shortcuts, open your shortcut → … → Share → Copy Link, then paste here.
//

import Foundation

enum OnboardingShortcutShareLinks {
    /// Voice Record Expense (matches `VoiceExpenseIntent` / App Shortcut).
    static var voiceRecordExpense: URL? {
        url(from: "https://www.icloud.com/shortcuts/ed13fb224d7347ea8ae14b7d496061a7")
    }

    /// Log Expense Amount (matches `QuickAmountExpenseIntent` / App Shortcut).
    static var logExpenseAmount: URL? {
        url(from: "https://www.icloud.com/shortcuts/7320b918c9244603af12f85533fb9e19")
    }

    private static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
