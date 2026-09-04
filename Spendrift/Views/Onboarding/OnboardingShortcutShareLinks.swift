//
//  OnboardingShortcutShareLinks.swift
//  Spendrift
//
//  Apple Shortcuts share URLs for shortcuts users can add during onboarding.
//  In Shortcuts, open your shortcut → … → Share → Copy Link, then paste here.
//

import Foundation

enum OnboardingShortcutShareLinks {
    /// Voice Record Expense (matches `VoiceExpenseIntent` / App Shortcut).
    static var voiceRecordExpense: URL? {
        url(from: "https://www.icloud.com/shortcuts/36509d49256d412abe4dd54bf7fdf146")
    }

    /// Log Expense Amount (matches `QuickAmountExpenseIntent` / App Shortcut).
    static var logExpenseAmount: URL? {
        url(from: "https://www.icloud.com/shortcuts/014f0af207a04b359a50857c6e30fc6e")
    }

    private static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
