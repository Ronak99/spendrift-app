//
//  CategoriesView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\TransactionCategory.sortOrder),
        SortDescriptor(\TransactionCategory.name)
    ])
    private var allCategories: [TransactionCategory]

    private var incomeCategories: [TransactionCategory] {
        allCategories.filter { $0.type == .income }
    }

    private var expenseCategories: [TransactionCategory] {
        allCategories.filter { $0.type == .expense }
    }

    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selection = Set<UUID>()
    @State private var showBulkDeleteConfirmation = false

    private var filteredIncomeCategories: [TransactionCategory] {
        if searchText.isEmpty { return incomeCategories }
        return incomeCategories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredExpenseCategories: [TransactionCategory] {
        if searchText.isEmpty { return expenseCategories }
        return expenseCategories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var hasSearchResults: Bool {
        !filteredIncomeCategories.isEmpty || !filteredExpenseCategories.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if allCategories.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: "No Categories",
                        description: "Create categories to organize your transactions",
                        actionTitle: "Add Category",
                        action: { showCreateSheet = true }
                    )
                } else {
                    List(selection: $selection) {
                        if !filteredIncomeCategories.isEmpty {
                            Section("Income") {
                                categoryRows(for: filteredIncomeCategories, movable: incomeCategories)
                            }
                        }

                        if !filteredExpenseCategories.isEmpty {
                            Section("Expense") {
                                categoryRows(for: filteredExpenseCategories, movable: expenseCategories)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, .constant(isEditing && searchText.isEmpty ? .active : .inactive))
                    .overlay {
                        if !searchText.isEmpty && !hasSearchResults {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search categories")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !allCategories.isEmpty && searchText.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                            if !isEditing {
                                selection.removeAll()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if isEditing && !selection.isEmpty {
                            Button("Delete", role: .destructive) {
                                showBulkDeleteConfirmation = true
                            }
                        } else {
                            Button(action: { showCreateSheet = true }) {
                                Image(systemName: "plus")
                            }
                            ProfileSettingsToolbarButton()
                        }
                    }
                    .padding(.horizontal, allCategories.isEmpty ? 0 : 8)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateCategorySheet(category: nil)
            }
            .confirmationDialog(
                "Delete \(selection.count) categories?",
                isPresented: $showBulkDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Categories and Their Transactions", role: .destructive) {
                    deleteSelectedCategories()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting a category also deletes all transactions assigned to it.")
            }
        }
    }

    @ViewBuilder
    private func categoryRows(
        for displayed: [TransactionCategory],
        movable: [TransactionCategory]
    ) -> some View {
        ForEach(displayed) { category in
            if isEditing {
                CategoryListItem(category: category)
                    .tag(category.id)
            } else {
                NavigationLink {
                    CategoryTransactionsView(category: category)
                } label: {
                    CategoryListItem(category: category)
                }
            }
        }
        .onDelete { indexSet in
            deleteCategories(at: indexSet, from: displayed, source: .manual)
        }
    }

    private func deleteCategories(
        at offsets: IndexSet,
        from categories: [TransactionCategory],
        source: CategoryEventSource
    ) {
        for index in offsets {
            let category = categories[index]
            Analytics.capture(.categoryDeleted, [
                Analytics.Key.name: category.name,
                Analytics.Key.isDefault: category.isDefault,
                Analytics.Key.source: source.rawValue
            ])
            modelContext.delete(category)
        }
        try? modelContext.save()
    }

    private func deleteSelectedCategories() {
        let selected = allCategories.filter { selection.contains($0.id) }
        for category in selected {
            Analytics.capture(.categoryDeleted, [
                Analytics.Key.name: category.name,
                Analytics.Key.isDefault: category.isDefault,
                Analytics.Key.source: CategoryEventSource.bulkEdit.rawValue
            ])
            modelContext.delete(category)
        }
        if selected.count > 1 {
            Analytics.capture(.categoryDeleted, [
                Analytics.Key.count: selected.count,
                Analytics.Key.source: CategoryEventSource.bulkEdit.rawValue
            ])
        }
        try? modelContext.save()
        selection.removeAll()
        isEditing = false
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
