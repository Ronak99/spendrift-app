//
//  CategoriesView.swift
//  Spendrift
//
//  Colour-wash tray of enamel category chips. A leading toolbar search
//  swaps the type picker for a find field and searches every category.
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
    @State private var query = ""
    @State private var isSearchActive = false
    @State private var showCreateSheet = false
    @State private var createDraftName: String?
    @State private var categoryToDelete: TransactionCategory?
    @State private var categoryToEdit: TransactionCategory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var typeCategories: [TransactionCategory] {
        allCategories.filter { $0.type == selectedType }
    }

    private var catalogCategories: [TransactionCategory] {
        allCategories.sorted { lhs, rhs in
            if lhs.type != rhs.type {
                return lhs.type == .expense
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var visibleCategories: [TransactionCategory] {
        if isSearchActive {
            return CategorySearch.filter(catalogCategories, query: query)
        }
        return typeCategories
    }

    private var sourceCategories: [TransactionCategory] {
        isSearchActive ? catalogCategories : typeCategories
    }

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var typeMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private var washColor: Color {
        CategoryEnamel.atmosphere(in: allCategories, type: selectedType)
    }

    private var watermarkIcon: String {
        typeCategories.first?.icon.systemImageName
            ?? CategoryPalette.defaultIcon(for: selectedType).systemImageName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    trayChrome

                    if sourceCategories.isEmpty {
                        emptyState
                    } else if visibleCategories.isEmpty {
                        searchMiss
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
            .background { atmosphere }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar { toolbarContent }
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

    // MARK: Atmosphere

    private var atmosphere: some View {
        CategoryTrayAtmosphere(washColor: washColor, watermarkIcon: watermarkIcon)
            .ignoresSafeArea()
            .animation(typeMotion, value: selectedType)
            .animation(typeMotion, value: watermarkIcon)
    }

    // MARK: Chrome

    private var trayChrome: some View {
        Group {
            if isSearchActive {
                CategoryFindField(query: $query, autoFocus: true)
            } else {
                ChromeSegmentedPicker(
                    selection: $selectedType,
                    accessibilityLabel: "Category type"
                )
            }
        }
        .animation(typeMotion, value: isSearchActive)
    }

    private var searchMiss: some View {
        CategorySearchMiss(
            query: query,
            type: selectedType,
            onAdd: { openCreate(named: CategorySearch.needle(from: query)) }
        )
    }

    // MARK: Grid

    private var chipGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(visibleCategories) { category in
                NavigationLink {
                    CategoryTransactionsView(category: category)
                } label: {
                    CategoryGridItem(category: category)
                }
                .buttonStyle(CategoryTilePressStyle())
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
        .animation(typeMotion, value: isSearchActive)
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

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .navigationBarLeading) {
                searchButton
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                searchButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
    }

    private var searchButton: some View {
        Button(action: toggleSearch) {
            Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(addForeground)
                .scaleEffect(x: isSearchActive ? 1 : -1)
                .frame(width: 32, height: 32)
                .background(addBackground, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(isSearchActive ? "Close search" : "Search categories")
        .accessibilityIdentifier("Search categories")
        .accessibilityAddTraits(isSearchActive ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSearchActive)
    }

    private var addButton: some View {
        Button(action: { openCreate() }) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(addForeground)
                .frame(width: 32, height: 32)
                .background(addBackground, in: Circle())
        }
        .accessibilityLabel("Add category")
    }

    private var addBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var addForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    // MARK: Behaviour

    private func toggleSearch() {
        withAnimation(typeMotion) {
            isSearchActive.toggle()
            if !isSearchActive {
                query = ""
            }
        }
    }

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
