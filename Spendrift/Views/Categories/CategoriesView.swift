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
    @Query(sort: \TransactionCategory.name)
    private var allCategories: [TransactionCategory]
    
    private var incomeCategories: [TransactionCategory] {
        allCategories.filter { $0.type == .income }
    }
    
    private var expenseCategories: [TransactionCategory] {
        allCategories.filter { $0.type == .expense }
    }
    
    @State private var showCreateSheet = false
    @State private var searchText = ""
    
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
                    List {
                        if !filteredIncomeCategories.isEmpty {
                            Section("Income") {
                                ForEach(filteredIncomeCategories) { category in
                                    NavigationLink {
                                        CategoryTransactionsView(category: category)
                                    } label: {
                                        CategoryListItem(category: category)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteCategories(at: indexSet, from: filteredIncomeCategories)
                                }
                            }
                        }
                        
                        if !filteredExpenseCategories.isEmpty {
                            Section("Expense") {
                                ForEach(filteredExpenseCategories) { category in
                                    NavigationLink {
                                        CategoryTransactionsView(category: category)
                                    } label: {
                                        CategoryListItem(category: category)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteCategories(at: indexSet, from: filteredExpenseCategories)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
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
                    HStack(spacing: 12) {
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                        }
                        ProfileSettingsToolbarButton()
                    }
                }
            }
            .onAppear(perform: seedDefaultCategoriesIfNeeded)
            .sheet(isPresented: $showCreateSheet) {
                UpdateCategorySheet(category: nil)
            }
        }
    }
    
    private func deleteCategories(at offsets: IndexSet, from categories: [TransactionCategory]) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        try? modelContext.save()
    }
    
    private func seedDefaultCategoriesIfNeeded() {
        guard allCategories.isEmpty else { return }
        
        let defaults = TransactionCategory.defaultCategories()
        for category in defaults {
            modelContext.insert(category)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
