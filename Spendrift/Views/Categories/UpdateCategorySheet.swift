//
//  UpdateCategorySheet.swift
//  Spendrift
//
//  Color-wash editor for creating and updating categories. Name lives in the
//  hero so the preview is the header; colour and icon sit below it.
//

import SwiftUI
import SwiftData

struct UpdateCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \TransactionCategory.name) private var allCategories: [TransactionCategory]

    let category: TransactionCategory?
    /// When creating a category, pre-select this category type (for example from the transaction form).
    let defaultTypeWhenCreating: CategoryType?
    /// When creating from a tray search miss, pre-fill the hero with the query.
    let initialNameWhenCreating: String?
    var onCreated: ((TransactionCategory) -> Void)?
    private let eventSource: CategoryEventSource

    init(
        category: TransactionCategory?,
        defaultTypeWhenCreating: CategoryType? = nil,
        initialNameWhenCreating: String? = nil,
        onCreated: ((TransactionCategory) -> Void)? = nil,
        eventSource: CategoryEventSource = .manual
    ) {
        self.category = category
        self.defaultTypeWhenCreating = defaultTypeWhenCreating
        self.initialNameWhenCreating = initialNameWhenCreating
        self.onCreated = onCreated
        self.eventSource = eventSource

        let initialType = category?.type ?? defaultTypeWhenCreating ?? .expense
        let seedName = category?.name
            ?? initialNameWhenCreating?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let suggestion = category == nil ? CategoryNameSuggestion.match(name: seedName) : nil
        _name = State(initialValue: seedName)
        _type = State(initialValue: initialType)
        _icon = State(initialValue: suggestion?.icon ?? category?.icon ?? CategoryPalette.defaultIcon(for: initialType))
        _selectedHex = State(
            initialValue: CategoryPalette.normalizedHex(category?.colorHex)
                ?? suggestion?.hex
                ?? (category.map { CategoryPalette.hex(matching: ColoredCategories.swatch(forName: $0.name)) }
                    ?? CategoryPalette.defaultHex(for: initialType))
        )
        _didManuallyPickIcon = State(initialValue: category != nil)
        _didManuallyPickColor = State(initialValue: category?.colorHex != nil)
    }

    @FocusState private var nameFieldFocused: Bool

    @State private var name: String
    @State private var type: CategoryType
    @State private var icon: CategoryIcon
    @State private var selectedHex: String
    @State private var didManuallyPickIcon: Bool
    @State private var didManuallyPickColor: Bool
    @State private var saveAlertMessage: String?
    @State private var showIconPicker = false
    @State private var showCustomColor = false
    @State private var showTransactions = false

    private var isCreating: Bool { category == nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First reason Save cannot complete, or `nil` when the form is ready to write.
    private var saveBlockedReason: String? {
        if trimmedName.isEmpty {
            return "Enter a category name."
        }
        if TransactionCategory.nameExists(trimmedName, in: allCategories, excluding: category?.id) {
            return "“\(trimmedName)” already exists. Pick another name."
        }
        return nil
    }

    private var selectedColor: Color { Color(hex: selectedHex) }

    private var isDark: Bool { colorScheme == .dark }

    private var featuredIcons: [CategoryIcon] {
        var icons = CategoryIcon.featuredForPicker
        if !icons.contains(icon) {
            if icons.count == 8 {
                icons[7] = icon
            } else {
                icons.append(icon)
            }
        }
        return icons
    }

    private var isCustomColorSelected: Bool {
        !CategoryPalette.contains(selectedHex)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hero
                pickerScroll
            }
            .background(canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                SheetDismissToolbarItem()
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
            }
            .alert(
                saveAlertMessage ?? "",
                isPresented: Binding(
                    get: { saveAlertMessage != nil },
                    set: { if !$0 { saveAlertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                if isCreating {
                    focusNameFieldSoon()
                }
            }
            .onChange(of: name) { _, newValue in
                applyNameSuggestion(newValue)
            }
            .sheet(isPresented: $showIconPicker) {
                CategoryIconPickerView(selectedIcon: $icon, accentHex: selectedHex) {
                    didManuallyPickIcon = true
                }
            }
            .sheet(isPresented: $showCustomColor) {
                CategoryCustomColorSheet(initialHex: selectedHex) { hex in
                    selectedHex = hex
                    didManuallyPickColor = true
                }
            }
            .sheet(isPresented: $showTransactions) {
                if let category {
                    CategoryTransactionsSheet(category: category)
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                iconTile

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Category name", text: $name)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(heroPrimary)
                        .tint(AppTheme.cursor)
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("Enter category name")
                        .accessibilityLabel("Enter category name")

                    metaLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)

            ChromeSegmentedPicker(selection: $type) { _ in
                nameFieldFocused = false
            }
            .padding(.top, 26)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(alignment: .top) {
            ColorWashBackground(color: selectedColor, isDark: isDark)
                .padding(.top, -120)
        }
    }

    private var iconTile: some View {
        CategoryEnamelTile(
            systemImage: icon.systemImageName,
            color: selectedColor
        )
        .frame(width: 70, height: 70)
        .accessibilityHidden(true)
    }

    private var metaLine: some View {
        Text(type.rawValue.capitalized)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(heroPrimary.opacity(0.6))
    }

    private var metaDot: some View {
        Circle()
            .fill(heroPrimary.opacity(0.35))
            .frame(width: 3, height: 3)
    }

    // MARK: Pickers

    private var pickerScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !isCreating {
                    transactionsRow
                }
                colorSection
                iconSection
            }
            .padding(.horizontal, 20)
            .padding(.top, isCreating ? 28 : 8)
            .padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var persistedTransactionCount: Int {
        (category?.transactions ?? []).filter(\.isPersisted).count
    }

    private var transactionsValueText: String {
        persistedTransactionCount == 0 ? "None" : "\(persistedTransactionCount)"
    }

    private var transactionsRow: some View {
        Button {
            nameFieldFocused = false
            showTransactions = true
        } label: {
            CategoryMetaRow(title: "Transactions", showsBottomDivider: false) {
                HStack(spacing: 6) {
                    Text(transactionsValueText)
                        .font(.system(size: 14, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(heroPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(heroPrimary.opacity(0.28))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Transactions")
        .accessibilityLabel("Transactions")
        .accessibilityValue(transactionsValueText)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Color")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 7),
                spacing: 11
            ) {
                ForEach(CategoryPalette.hexes, id: \.self) { hex in
                    let isOn = CategoryPalette.normalizedHex(selectedHex) == hex
                    Button {
                        selectedHex = hex
                        didManuallyPickColor = true
                        nameFieldFocused = false
                    } label: {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: hex))
                            .frame(height: 40)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .circular)
                                    .strokeBorder(isOn ? Color(hex: hex) : Color.clear, lineWidth: 2)
                                    .padding(-4)
                                    .allowsHitTesting(false)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(hex)")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }

                Button {
                    nameFieldFocused = false
                    showCustomColor = true
                } label: {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isCustomColorSelected ? selectedColor : Color.primary.opacity(0.06))
                        .frame(height: 40)
                        .overlay {
                            if isCustomColorSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#0A0A0B"))
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(isCustomColorSelected ? 0 : 0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Custom colour")
            }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Icon")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    nameFieldFocused = false
                    showIconPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Text("Browse all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedColor)
                    .washMotion(value: selectedHex)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 4),
                spacing: 11
            ) {
                ForEach(featuredIcons, id: \.self) { item in
                    CategoryIconCell(
                        icon: item,
                        isSelected: icon == item,
                        accent: selectedColor,
                        showsLabel: true
                    ) {
                        icon = item
                        didManuallyPickIcon = true
                        nameFieldFocused = false
                    }
                }
            }
        }
    }

    // MARK: Chrome colours

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }


    private var heroChromeFill: Color {
        isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }
        
    private var saveButton: some View {
        Button(action: attemptSave) {
            Text("Save")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(saveBackground, in: Capsule())
                .foregroundStyle(saveForeground)
                // A bare `Text` is the one thing in a toolbar item the navigation bar is
                // willing to compress, so on narrow iPhones — and at larger Dynamic Type,
                // where the inline title claims more of the bar — the label truncated to
                // "S…". Pinning the capsule at its ideal width makes the bar shrink the
                // title instead, the same way the pickers' `addButton` holds a fixed frame.
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private var saveBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var saveForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    // MARK: Behaviour

    /// Focuses the name field shortly after the sheet appears so the keyboard comes up immediately.
    private func focusNameFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nameFieldFocused = true
        }
    }

    private func applyNameSuggestion(_ raw: String) {
        guard let match = CategoryNameSuggestion.match(name: raw) else { return }
        if !didManuallyPickIcon {
            icon = match.icon
        }
        if !didManuallyPickColor {
            selectedHex = match.hex
        }
    }

    private func attemptSave() {
        nameFieldFocused = false
        if let message = saveBlockedReason {
            saveAlertMessage = message
            return
        }
        saveCategory()
    }

    private func saveCategory() {
        let resolvedName = trimmedName
        guard !resolvedName.isEmpty else { return }

        if TransactionCategory.nameExists(resolvedName, in: allCategories, excluding: category?.id) {
            return
        }

        let hex = CategoryPalette.normalizedHex(selectedHex)

        if let category {
            category.name = resolvedName
            category.applyType(type)
            category.icon = icon
            category.colorHex = hex
        } else {
            let newCategory = TransactionCategory(
                name: resolvedName,
                type: type,
                icon: icon,
                colorHex: hex
            )
            modelContext.insert(newCategory)
            Analytics.capture(.categoryCreated, [
                Analytics.Key.name: resolvedName,
                Analytics.Key.isDefault: false,
                Analytics.Key.source: eventSource.rawValue
            ])
            onCreated?(newCategory)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct CategoryMetaRow<Trailing: View>: View {
    let title: String
    var showsBottomDivider: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            trailing()
                .font(.system(size: 14, weight: .regular))
        }
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) {
            if showsBottomDivider {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview("New") {
    UpdateCategorySheet(category: nil)
        .modelContainer(for: [TransactionCategory.self], inMemory: true)
}

#Preview("Edit") {
    UpdateCategorySheet(
        category: TransactionCategory(name: "Groceries", type: .expense, icon: .groceries, colorHex: "#8BD17C")
    )
    .modelContainer(for: [TransactionCategory.self], inMemory: true)
}
