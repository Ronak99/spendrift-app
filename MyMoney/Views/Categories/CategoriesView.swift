//
//  CategoriesView.swift
//  MyMoney
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
    
    @State private var viewModel = CategoryViewModel()
    @State private var showCreateSheet = false
    @State private var selectedCategory: TransactionCategory?
    
    var body: some View {
        NavigationStack {
            Group {
                if incomeCategories.isEmpty && expenseCategories.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: "No Categories",
                        description: "Create categories to organize your transactions",
                        actionTitle: "Add Category",
                        action: { showCreateSheet = true }
                    )
                } else {
                    List {
                        if !incomeCategories.isEmpty {
                            Section("Income") {
                                ForEach(incomeCategories) { category in
                                    CategoryListItem(category: category)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedCategory = category
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteCategories(at: indexSet, from: incomeCategories)
                                }
                            }
                        }
                        
                        if !expenseCategories.isEmpty {
                            Section("Expense") {
                                ForEach(expenseCategories) { category in
                                    CategoryListItem(category: category)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedCategory = category
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteCategories(at: indexSet, from: expenseCategories)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: seedDefaultCategoriesIfNeeded)
            .sheet(isPresented: $showCreateSheet) {
                UpdateCategorySheet(category: nil)
            }
            .sheet(item: $selectedCategory) { category in
                UpdateCategorySheet(category: category)
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
