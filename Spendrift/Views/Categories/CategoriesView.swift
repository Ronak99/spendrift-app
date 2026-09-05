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
    @State private var pendingDelete: TransactionCategory?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            categorySection("Expenses", filteredExpenseCategories)
                            categorySection("Income", filteredIncomeCategories)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .overlay {
                        if !searchText.isEmpty && !hasSearchResults {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search categories")
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        ProfileSettingsToolbarButton()
                    }
                    .padding(.horizontal, allCategories.isEmpty ? 0 : 8)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateCategorySheet(category: nil)
            }
            .confirmationDialog(
                "Delete \(pendingDelete?.name ?? "category")?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { category in
                Button("Delete Category and Its Transactions", role: .destructive) {
                    deleteCategory(category)
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { _ in
                Text("Deleting a category also deletes all transactions assigned to it.")
            }
        }
    }

    @ViewBuilder
    private func categorySection(
        _ title: String,
        _ categories: [TransactionCategory]
    ) -> some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryTransactionsView(category: category)
                        } label: {
                            CategoryGridCard(category: category)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = category
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func deleteCategory(_ category: TransactionCategory) {
        Analytics.capture(.categoryDeleted, [
            Analytics.Key.name: category.name,
            Analytics.Key.isDefault: category.isDefault,
            Analytics.Key.source: CategoryEventSource.manual.rawValue
        ])
        modelContext.delete(category)
        try? modelContext.save()
        pendingDelete = nil
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
