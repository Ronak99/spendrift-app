//
//  UpdateCategorySheet.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct UpdateCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: TransactionCategory?
    /// When creating a category, pre-select this transaction type (for example from the transaction form).
    let defaultTypeWhenCreating: TransactionType?
    var onCreated: ((TransactionCategory) -> Void)?
    private let eventSource: CategoryEventSource

    init(
        category: TransactionCategory?,
        defaultTypeWhenCreating: TransactionType? = nil,
        onCreated: ((TransactionCategory) -> Void)? = nil,
        eventSource: CategoryEventSource = .manual
    ) {
        self.category = category
        self.defaultTypeWhenCreating = defaultTypeWhenCreating
        self.onCreated = onCreated
        self.eventSource = eventSource
    }
    
    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var icon: CategoryIcon = .unknown
    
    private var isValid: Bool {
        !name.isEmpty
    }
    
    private var availableIcons: [CategoryIcon] {
        Array(CategoryIcon.allCases)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Picker("Type", selection: $type) {
                        ForEach(
                            TransactionType.allCases,
                            id: \.self
                        ) { categoryType in
                            Text(categoryType.rawValue.capitalized)
                                .tag(categoryType)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Enter category name", text: $name)
                    IconGridPicker(icons: Array(CategoryIcon.allCases), selectedIcon: $icon)
                }
            }
            
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    type = category.type
                    icon = category.icon
                } else if let preset = defaultTypeWhenCreating, preset != .none {
                    type = preset
                }
            }
        }
    }
    
    private func saveCategory() {
        if let category = category {
            // Update existing
            category.name = name
            category.type = type
            category.icon = icon
        } else {
            let newCategory = TransactionCategory(
                name: name,
                type: type,
                icon: icon
            )
            modelContext.insert(newCategory)
            Analytics.capture(.categoryCreated, [
                Analytics.Key.name: name,
                Analytics.Key.isDefault: false,
                Analytics.Key.source: eventSource.rawValue
            ])
            onCreated?(newCategory)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    UpdateCategorySheet(category: nil)
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
