//
//  QuickExpenseWidgetConfig.swift
//  Spendrift
//
//  Created by Cursor on 05/04/26.
//

import AppIntents

struct QuickExpenseWidgetConfig: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Expense"
    static let description = IntentDescription("Configure your quick-add expense shortcut.")

    @Parameter(title: "Amount", description: "The amount logged with a single tap.", default: 100.0)
    var amount: Double

    @Parameter(title: "Category", description: "Expense category to assign to the tap.")
    var category: ExpenseCategoryEntity?

    @Parameter(title: "Button Label", description: "Label displayed on the widget.", default: "Quick Add")
    var label: String
}
