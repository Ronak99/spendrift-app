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
        url(from: "https://www.icloud.com/shortcuts/b13dbcf92a33445e930b0288c9a9afa0")
    }

    /// Log Expense Amount (matches `QuickAmountExpenseIntent` / App Shortcut).
    static var logExpenseAmount: URL? {
        url(from: "https://www.icloud.com/shortcuts/36509d49256d412abe4dd54bf7fdf146")
    }

    private static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
