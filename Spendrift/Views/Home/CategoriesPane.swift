//
//  CategoriesPane.swift
//  Spendrift
//
//  Three columns of enamel chips for the picked type. No segmented control and no
//  search plate: while this tab is selected its label reads "Expense" or "Income"
//  and a second tap switches type, and the search bar above already covers names.
//

import SwiftUI

struct CategoriesPane: View {
    let categories: [TransactionCategory]
    let type: CategoryType
    /// Month the chips' budget bars measure against: the one in progress.
    let month: MonthSpendStats
    var onOpenCategory: (TransactionCategory) -> Void
    var onCreateCategory: () -> Void
    var onDelete: (TransactionCategory) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var visible: [TransactionCategory] {
        categories.filter { $0.type == type }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                createChip
                ForEach(visible) { category in
                    chip(category)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
        }
        .scrollIndicators(.hidden)
        .homeTrayClearance()
    }

    private var createChip: some View {
        Button(action: onCreateCategory) {
            VStack(spacing: 10) {
                CreateSlotEnamel(side: 80)
                Text("New")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .frame(height: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(CategoryTilePressStyle())
        .accessibilityIdentifier("categoriesCreateSlot")
        .accessibilityLabel("New category")
    }

    private func chip(_ category: TransactionCategory) -> some View {
        let cap = MonthlyBudget.cap(for: category)

        return Button {
            onOpenCategory(category)
        } label: {
            VStack(spacing: 0) {
                CategoryGridItem(category: category)
                if cap > 0 {
                    BudgetBar(
                        spent: month.spent(in: category),
                        cap: cap,
                        color: CategoryEnamel.color(for: category),
                        width: 44
                    )
                    .padding(.top, -4)
                }
            }
        }
        .buttonStyle(CategoryTilePressStyle())
        .accessibilityIdentifier(category.name)
        .accessibilityLabel(category.name)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { onOpenCategory(category) }
            // Bundled defaults are permanent; only user-created categories can go.
            if !category.isDefault {
                Button("Delete", systemImage: "trash", role: .destructive) { onDelete(category) }
            }
        }
    }
}

/// Two rows: Expense or Income. Replaces the segmented control the tray used to carry.
struct CategoryTypePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selection: CategoryType
    let onPick: (CategoryType) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HomeCard {
                    ForEach(Array(CategoryType.allCases.enumerated()), id: \.element) { index, type in
                        if index > 0 {
                            HomeRowDivider()
                        }
                        row(type)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Category type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { CustomSheetCloseToolbarItem() }
        }
        .presentationDetents([.height(260), .large])
    }

    private func row(_ type: CategoryType) -> some View {
        Button {
            onPick(type)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                EnamelBadge(
                    systemImage: type.flowSymbolName,
                    color: Color(hex: CategoryPalette.defaultHex(for: type))
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                    Text(type.menuSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer(minLength: 8)
                if selection == type {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityIdentifier("type-\(type.rawValue)")
        .accessibilityAddTraits(selection == type ? .isSelected : [])
    }
}
