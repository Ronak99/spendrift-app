//
//  BudgetSheets.swift
//  Spendrift
//
//  Where the whole-month cap is set, and where an uncapped category is picked to
//  give one. Per-category caps themselves live in the category editor.
//

import SwiftUI
import SwiftData

/// One field, a chip that fills in the three-month average, and Clear once a budget exists.
struct TotalBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @AppStorage(MonthlyBudget.totalKey) private var storedTotal: Double = 0

    @FocusState private var fieldFocused: Bool
    @State private var amount: String = ""
    @State private var alertMessage: String?

    private var isDark: Bool { colorScheme == .dark }

    private var thisMonth: MonthSpendStats {
        MonthRef.of(Date()).stats(from: transactions)
    }

    private var suggestion: Double {
        MonthlyBudget.suggestedTotal(transactions: transactions)
    }

    private var enteredAmount: Double {
        Double(amount.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                field
                hint
                if suggestion > 0 {
                    suggestionChip
                }
                if storedTotal > 0 {
                    Button("Clear budget", role: .destructive) {
                        MonthlyBudget.clearTotal()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.expense)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Monthly budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CustomSheetCloseToolbarItem()
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.actionBackground, in: Capsule())
                            .foregroundStyle(AppTheme.actionForeground)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert(
                alertMessage ?? "",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                if storedTotal > 0 {
                    amount = storedTotal.wholeAmountDisplayString
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    fieldFocused = true
                }
            }
        }
        .presentationDetents([.height(360), .large])
    }

    private var field: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(AppCurrency.symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.ink.opacity(0.42))
            TextField("No budget", text: $amount)
                .font(.system(size: 40, weight: .bold))
                .tracking(-0.8)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .tint(AppTheme.cursor)
                .accessibilityLabel("Monthly budget")
            Text("per month")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkSecondary)
        }
    }

    private var hint: some View {
        let stats = thisMonth
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                stats.spent > 0
                    ? "\(stats.spent.formatCurrencyRounded) spent so far in \(HomeInsights.monthName(stats.month))"
                    : "Nothing spent yet this month"
            )
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.inkTertiary)

            if enteredAmount > 0 {
                BudgetBar(spent: stats.spent, cap: enteredAmount, color: AppTheme.ink)
            }
        }
    }

    private var suggestionChip: some View {
        Button {
            amount = suggestion.wholeAmountDisplayString
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13))
                Text("Use \(suggestion.formatCurrencyRounded), your 3-month average")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(AppTheme.inkSecondary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(AppTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func save() {
        fieldFocused = false
        guard enteredAmount > 0 else {
            alertMessage = "Enter a budget above zero, or clear it."
            return
        }
        storedTotal = enteredAmount.rounded()
        dismiss()
    }
}

/// Lists expense categories with no cap yet, each with the average it runs at, and
/// hands the picked one back so its editor can open on the Budget field.
struct AddCategoryBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: [
        SortDescriptor(\TransactionCategory.sortOrder),
        SortDescriptor(\TransactionCategory.name)
    ])
    private var categories: [TransactionCategory]

    let onPick: (TransactionCategory) -> Void

    private var uncapped: [TransactionCategory] {
        categories.filter { $0.type == .expense && MonthlyBudget.cap(for: $0) == 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if uncapped.isEmpty {
                    Text("Every expense category already has a budget.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 48)
                } else {
                    HomeCard {
                        ForEach(Array(uncapped.enumerated()), id: \.element.id) { index, category in
                            if index > 0 {
                                HomeRowDivider()
                            }
                            row(category)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Budget for")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { CustomSheetCloseToolbarItem() }
        }
    }

    private func row(_ category: TransactionCategory) -> some View {
        let average = MonthlyBudget.suggestedCap(for: category, transactions: transactions)

        return Button {
            dismiss()
            onPick(category)
        } label: {
            HStack(spacing: 14) {
                EnamelBadge(
                    systemImage: category.icon.systemImageName,
                    color: CategoryEnamel.color(for: category)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15.5, weight: .semibold))
                    Text(
                        average > 0
                            ? "Averages \(average.formatCurrencyRounded) a month"
                            : "No spend in the last 3 months"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.inkTertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
    }
}
