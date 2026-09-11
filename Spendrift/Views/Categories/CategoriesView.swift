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

    @State private var selectedType: TransactionType = .expense
    @State private var showCreateSheet = false
    @State private var categoryToDelete: TransactionCategory?
    @State private var categoryToEdit: TransactionCategory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var visibleCategories: [TransactionCategory] {
        allCategories.filter { $0.type == selectedType }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Category type", selection: $selectedType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(visibleCategories) { category in
                            NavigationLink {
                                CategoryTransactionsView(category: category)
                            } label: {
                                CategoryGridItem(category: category)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    categoryToEdit = category
                                }
                                // Bundled defaults are permanent; only user-created categories can go.
                                if !category.isDefault {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        categoryToDelete = category
                                    }
                                }
                            }
                        }
                    }
                    .animation(.default, value: selectedType)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .softScrollEdge()
            .background(AppTheme.listBackground.ignoresSafeArea())
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                UpdateCategorySheet(category: nil, defaultTypeWhenCreating: selectedType)
            }
            .sheet(
                isPresented: Binding(
                    get: { categoryToEdit != nil },
                    set: { if !$0 { categoryToEdit = nil } }
                )
            ) {
                if let categoryToEdit {
                    UpdateCategorySheet(category: categoryToEdit)
                }
            }
            .confirmationDialog(
                "Delete \"\(categoryToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { categoryToDelete != nil },
                    set: { if !$0 { categoryToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: categoryToDelete
            ) { category in
                Button("Delete Category and Its Transactions", role: .destructive) {
                    delete(category)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Deleting a category also deletes all transactions assigned to it.")
            }
        }
    }

    private func delete(_ category: TransactionCategory) {
        guard !category.isDefault else { return }
        Analytics.capture(.categoryDeleted, [
            Analytics.Key.name: category.name,
            Analytics.Key.isDefault: false,
            Analytics.Key.source: CategoryEventSource.manual.rawValue
        ])
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TransactionCategory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for category in TransactionCategory.defaultCategories() {
        container.mainContext.insert(category)
    }

    return CategoriesView()
        .modelContainer(container)
}
