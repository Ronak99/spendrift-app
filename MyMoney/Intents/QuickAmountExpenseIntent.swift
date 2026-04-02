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
        "Create an expense on your primary account. Optionally choose an expense category from your data, or leave category unset for uncategorized. Add Amount from Ask for Input or a variable in Shortcuts."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "Expense amount (greater than zero).")
    var amount: Double

    @Parameter(title: "Notes", description: "Optional note for the transaction.", default: "")
    var notes: String

    @Parameter(
        title: "Category",
        description: "Optional expense category from the app. Leave unset to log as uncategorized."
    )
    var category: ExpenseCategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Log expense of \(\.$amount)") {
            \.$notes
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)

        let resolvedCategory = try Self.resolveCategorySelection(category, context: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        do {
            try ShortcutQuickAmountTransaction.create(
                amount: amount,
                notes: notes,
                category: resolvedCategory,
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

        return .result()
    }

    /// Stale shortcut IDs or deleted categories resolve to `nil` so the transaction still saves.
    private static func resolveCategorySelection(
        _ entity: ExpenseCategoryEntity?,
        context: ModelContext
    ) throws -> TransactionCategory? {
        guard let entity, let uuid = UUID(uuidString: entity.id) else { return nil }
        let descriptor = FetchDescriptor<TransactionCategory>(
            predicate: #Predicate<TransactionCategory> {$0.id == uuid }
        )
        return try context.fetch(descriptor).first
    }
}
