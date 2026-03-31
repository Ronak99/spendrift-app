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
                "Voice Record expense with \(.applicationName)",
                "Audio expense to \(.applicationName)"
            ],
            shortTitle: "Log Expense by Speaking",
            systemImageName: "mic.fill"
        ),
        AppShortcut(
            intent: QuickAmountExpenseIntent(),
            phrases: [
                "Type expense amount in \(.applicationName)",
                "Write expense amount in \(.applicationName)",
                "Add expense amount to \(.applicationName)"
            ],
            shortTitle: "Log Expense by Typing",
            systemImageName: "textformat.123"
        )
    ]
}

