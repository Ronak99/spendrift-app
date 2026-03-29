//
//  ExpenseAppShortcuts.swift
//  MyMoney
//
//  Created by Cursor on 27/03/26.
//

import AppIntents

struct ExpenseAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: VoiceExpenseIntent(),
            phrases: [
                "Record an expense in \(.applicationName)",
                "Log expense with \(.applicationName)",
                "Add expense to \(.applicationName)"
            ],
            shortTitle: "Record Voice Expense",
            systemImageName: "mic.fill"
        ),
        AppShortcut(
            intent: QuickAmountExpenseIntent(),
            phrases: [
                "Log expense amount in \(.applicationName)",
                "Quick expense in \(.applicationName)",
                "Add expense amount to \(.applicationName)"
            ],
            shortTitle: "Log Expense Amount",
            systemImageName: "textformat.123"
        )
    ]
}

