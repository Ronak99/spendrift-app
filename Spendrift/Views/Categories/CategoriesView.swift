//
//  CategoriesView.swift
//  Spendrift
//
//  Colour-wash tray of enamel category chips. Atmosphere and controls match
//  the category editor so picking a type feels like opening the same box.
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

    @State private var selectedType: CategoryType = .expense
    @State private var showCreateSheet = false
    @State private var categoryToDelete: TransactionCategory?
    @State private var categoryToEdit: TransactionCategory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var visibleCategories: [TransactionCategory] {
        allCategories.filter { $0.type == selectedType }
    }

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var typeMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private var washColor: Color {
        if let first = visibleCategories.first {
            return CategoryEnamel.color(for: first)
        }
        return Color(hex: CategoryPalette.defaultHex(for: selectedType))
    }

    private var watermarkIcon: String {
        visibleCategories.first?.icon.systemImageName
            ?? CategoryPalette.defaultIcon(for: selectedType).systemImageName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    typePicker

                    if visibleCategories.isEmpty {
                        emptyState
                    } else {
                        chipGrid
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .softScrollEdge()
            .background { atmosphere }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar { toolbarContent }
            .sensoryFeedback(.selection, trigger: selectedType)
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

    // MARK: Atmosphere

    private var atmosphere: some View {
        ZStack(alignment: .topTrailing) {
            canvas

            ColorWashBackground(color: washColor, isDark: isDark)
                .frame(height: 360)
                .frame(maxHeight: .infinity, alignment: .top)

            Image(systemName: watermarkIcon)
                .font(.system(size: 176, weight: .ultraLight))
                .foregroundStyle(heroPrimary.opacity(isDark ? 0.10 : 0.08))
                .offset(x: 40, y: -28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .id(watermarkIcon)
        }
        .ignoresSafeArea()
        .animation(typeMotion, value: selectedType)
        .animation(typeMotion, value: watermarkIcon)
    }

    // MARK: Type picker

    private var typePicker: some View {
        HStack(spacing: 3) {
            ForEach([CategoryType.expense, CategoryType.income], id: \.self) { option in
                let isOn = selectedType == option
                Button {
                    withAnimation(typeMotion) {
                        selectedType = option
                    }
                } label: {
                    Text(option.rawValue.capitalized)
                        .font(.system(size: 13.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn ? typeSelectedFill : Color.clear)
                        )
                        .foregroundStyle(isOn ? typeSelectedForeground : heroPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(isDark ? 0.3 : 0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Category type")
    }

    private var typeSelectedFill: Color {
        isDark ? Color.white.opacity(0.9) : Color(hex: "#111111")
    }

    private var typeSelectedForeground: Color {
        isDark ? Color(hex: "#111111") : .white
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

            Button(action: { showCreateSheet = true }) {
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
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
    }

    private var addButton: some View {
        Button(action: { showCreateSheet = true }) {
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
