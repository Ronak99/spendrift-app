//
//  QuickAmountExpenseIntent.swift
//  MyMoney
//
//  Created by Cursor on 30/03/26.
//

import AppIntents
import SwiftData

private enum QuickAmountIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case noPrimaryAccount

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount:
            return "Enter an amount greater than zero."
        case .noPrimaryAccount:
            return "No primary account found. Set a primary account in the app first."
        }
    }
}

struct QuickAmountExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense Amount"
    static let description = IntentDescription(
        "Create an expense transaction on your primary account without a category. Add Amount from Ask for Input or a variable in Shortcuts."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "Expense amount (greater than zero).")
    var amount: Double

    @Parameter(title: "Notes", description: "Optional note for the transaction.", default: "")
    var notes: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log expense of \(\.$amount)") {
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITesting")
        let schema = Schema([Transaction.self, Account.self, TransactionCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transaction: Transaction
        do {
            transaction = try ShortcutQuickAmountTransaction.create(
                amount: amount,
                notes: notes,
                modelContext: context,
                accounts: accounts
            )
        } catch ShortcutQuickAmountTransaction.Failure.invalidAmount {
            throw QuickAmountIntentError.invalidAmount
        } catch ShortcutQuickAmountTransaction.Failure.noPrimaryAccount {
            throw QuickAmountIntentError.noPrimaryAccount
        } catch {
            throw error
        }

        let message = "Logged expense of \(transaction.amount.formatCurrency)"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
