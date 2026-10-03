//
//  QuickAmountExpenseIntent.swift
//  Spendrift
//
//  Created by Cursor on 30/03/26.
//

import AppIntents
import SwiftData
import WidgetKit

private enum QuickAmountIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case noPrimaryAccount
    case unavailableCategory

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount:
            return "Enter an amount greater than zero."
        case .noPrimaryAccount:
            return "No primary account found. Set a primary account in the app first."
        case .unavailableCategory:
            return "Selected category is no longer available."
        }
    }
}

/// Fast path used by widget quick-add actions where amount may be prefilled.
struct QuickAmountExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense Amount"
    static let description = IntentDescription(
        "Create an expense on your primary account. Optionally choose an expense category from your data, or leave category unset for uncategorized. Add Amount from Ask for Input or a variable in Shortcuts."
    )
    static let openAppWhenRun: Bool = false

    // Non-negative range keeps the system's value prompt from offering a sign toggle.
    @Parameter(
        title: "Amount",
        description: "Expense amount (greater than zero).",
        controlStyle: .field,
        inclusiveRange: (0, 1_000_000_000)
    )
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
        try Self.performWrite(amount: amount, notes: notes, category: category)
        return .result()
    }

    @MainActor
    fileprivate static func performWrite(
        amount: Double,
        notes: String,
        category: ExpenseCategoryEntity?
    ) throws {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)
        let resolvedCategory = try resolveCategorySelection(category, context: context)
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
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Stale shortcut IDs or deleted categories resolve to `nil` so the transaction still saves.
    fileprivate static func resolveCategorySelection(
        _ entity: ExpenseCategoryEntity?,
        context: ModelContext
    ) throws -> TransactionCategory? {
        guard let entity, let uuid = UUID(uuidString: entity.id) else { return nil }
        let descriptor = FetchDescriptor<TransactionCategory>(
            predicate: #Predicate<TransactionCategory> { $0.id == uuid }
        )
        return try context.fetch(descriptor).first
    }
}

/// Prompted flow intended for the small widget "Type" button.
/// All fields are required so the platform asks the user before execution.
struct PromptedQuickExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense by Typing"
    static let description = IntentDescription(
        "Prompts for Amount, Category, and Notes, then creates an expense on the primary account."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount",
        description: "Expense amount (greater than zero).",
        controlStyle: .field,
        inclusiveRange: (0, 1_000_000_000),
        requestValueDialog: "Amount"
    )
    var amount: Double

    @Parameter(
        title: "Category",
        description: "Expense category.",
        requestValueDialog: "Category"
    )
    var category: ExpenseCategoryEntity

    @Parameter(
        title: "Notes",
        description: "Note for the transaction.",
        requestValueDialog: "Notes"
    )
    var notes: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log expense of \(\.$amount) in \(\.$category) with \(\.$notes)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try IntentSwiftData.makeModelContainer()
        let context = ModelContext(container)

        guard let resolvedCategory = try QuickAmountExpenseIntent.resolveCategorySelection(category, context: context) else {
            throw QuickAmountIntentError.unavailableCategory
        }

        try QuickAmountExpenseIntent.performWrite(
            amount: amount,
            notes: notes,
            category: ExpenseCategoryEntity(model: resolvedCategory)
        )
        return .result()
    }
}
