//
//  CategoriesView.swift
//  Spendrift
//
//  Tray of enamel category chips for one type. The type is a dropdown pinned
//  under the global search bar, laid out like the Transactions month row.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [
        SortDescriptor(\TransactionCategory.sortOrder),
        SortDescriptor(\TransactionCategory.name)
    ])
    private var allCategories: [TransactionCategory]

    @Binding var selectedType: CategoryType
    @State private var showCreateSheet = false
    @State private var createDraftName: String?
    @State private var categoryToDelete: TransactionCategory?
    @State private var categoryToEdit: TransactionCategory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var typeCategories: [TransactionCategory] {
        allCategories.filter { $0.type == selectedType }
    }

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var typeMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if typeCategories.isEmpty {
                        emptyState
                    } else {
                        chipGrid
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .softScrollEdge()
            .ledgerSearchHeader { typeRow }
            .background(AppTheme.canvas.ignoresSafeArea())
            .ledgerNavigationTitle(HomeTab.categories.title)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                LedgerToolbar(
                    addAccessibilityLabel: "Add category",
                    addAccessibilityIdentifier: "categoriesAddButton",
                    onAdd: { openCreate() }
                )
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: { createDraftName = nil }) {
                UpdateCategorySheet(
                    category: nil,
                    defaultTypeWhenCreating: selectedType,
                    initialNameWhenCreating: createDraftName
                )
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

    // MARK: Chrome

    /// Expense or Income. A menu rather than a segmented control, so it reads as
    /// the same kind of picker as the month on Transactions.
    private var typeRow: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Category type", selection: $selectedType) {
                    ForEach(CategoryType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
            } label: {
                LedgerDropdownLabel(text: selectedType.rawValue.capitalized)
            }
            .menuOrder(.fixed)
            .sensoryFeedback(.selection, trigger: selectedType)
            .accessibilityLabel("Category type")
            .accessibilityValue(selectedType.rawValue.capitalized)
            .accessibilityIdentifier("type-picker")

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Grid

    private var chipGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(typeCategories) { category in
                Button {
                    categoryToEdit = category
                } label: {
                    CategoryGridItem(category: category)
                }
                .buttonStyle(CategoryTilePressStyle())
                .accessibilityIdentifier(category.name)
                .accessibilityLabel(category.name)
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
        .padding(.top, 4)
        .animation(typeMotion, value: selectedType)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            CategoryEnamelTile(
                systemImage: CategoryPalette.defaultIcon(for: selectedType).systemImageName,
                color: Color(hex: CategoryPalette.defaultHex(for: selectedType))
            )
            .frame(width: 88, height: 88)
            .padding(.top, 28)

            Text("No \(selectedType.rawValue) categories")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(heroPrimary)

            Text("Add one to start grouping these transactions.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { openCreate() }) {
                Text("Add category")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(addBackground, in: Capsule())
                    .foregroundStyle(addForeground)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var addBackground: Color { AppTheme.actionBackground }

    private var addForeground: Color { AppTheme.actionForeground }

    // MARK: Behaviour

    private func openCreate(named name: String? = nil) {
        createDraftName = name
        showCreateSheet = true
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

    return CategoriesView(selectedType: .constant(.expense))
        .modelContainer(container)
}
