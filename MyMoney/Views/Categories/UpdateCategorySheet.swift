//
//  UpdateCategorySheet.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI
import SwiftData

struct UpdateCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let category: TransactionCategory?
    
    @State private var name: String = ""
    @State private var type: CategoryType = .expense
    @State private var icon: CategoryIcon = .unknown {
        didSet {
            print("Something changed")
        }
        
    }
    
    private var isValid: Bool {
        !name.isEmpty
    }
    
    private var availableIcons: [CategoryIcon] {
        Array(CategoryIcon.allCases)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Type") {
                    Picker("Type", selection: $type) {
                        ForEach(CategoryType.allCases, id: \.self) { categoryType in
                            Text(categoryType.rawValue.capitalized).tag(categoryType)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Category Name") {
                    TextField("Enter category name", text: $name)
                }
                
                IconGridPicker(icons: availableIcons, selectedIcon: $icon)
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
            // Create new
            let newCategory = TransactionCategory(
                name: name,
                type: type,
                icon: icon
            )
            modelContext.insert(newCategory)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    UpdateCategorySheet(category: nil)
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
