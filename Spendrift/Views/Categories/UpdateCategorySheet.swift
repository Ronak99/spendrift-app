//
//  UpdateCategorySheet.swift
//  Spendrift
//
//  Color-wash editor for creating and updating categories. Name lives in the
//  hero so the preview is the header; the type sits under it as a quiet
//  subtitle that pulls down a custom Expense / Income menu. Colour and icon
//  sit below. On an existing category, View Transactions pushes the ledger
//  onto this sheet.
//

import SwiftUI
import SwiftData

struct UpdateCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \TransactionCategory.name) private var allCategories: [TransactionCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    let category: TransactionCategory?
    /// When creating a category, pre-select this category type (for example from the transaction form).
    let defaultTypeWhenCreating: CategoryType?
    /// When creating from a tray search miss, pre-fill the hero with the query.
    let initialNameWhenCreating: String?
    var onCreated: ((TransactionCategory) -> Void)?
    /// Opened from a budget flow: the Budget field takes focus instead of the name.
    let focusBudgetWhenOpening: Bool
    private let eventSource: CategoryEventSource

    init(
        category: TransactionCategory?,
        defaultTypeWhenCreating: CategoryType? = nil,
        initialNameWhenCreating: String? = nil,
        focusBudgetWhenOpening: Bool = false,
        onCreated: ((TransactionCategory) -> Void)? = nil,
        eventSource: CategoryEventSource = .manual
    ) {
        self.category = category
        self.defaultTypeWhenCreating = defaultTypeWhenCreating
        self.initialNameWhenCreating = initialNameWhenCreating
        self.focusBudgetWhenOpening = focusBudgetWhenOpening
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
        _budgetText = State(
            initialValue: (category?.monthlyBudget ?? 0) > 0
                ? (category?.monthlyBudget ?? 0).wholeAmountDisplayString
                : ""
        )
    }

    @FocusState private var nameFieldFocused: Bool
    @FocusState private var budgetFieldFocused: Bool

    @State private var name: String
    @State private var type: CategoryType
    @State private var icon: CategoryIcon
    @State private var selectedHex: String
    @State private var didManuallyPickIcon: Bool
    @State private var didManuallyPickColor: Bool
    @State private var saveAlertMessage: String?
    @State private var showIconPicker = false
    @State private var showCustomColor = false
    @State private var showTypeMenu = false
    @State private var budgetText: String

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
                // Scrolls so the Budget field below Color and Icon stays reachable on
                // small phones and above the keyboard once it takes focus.
                ScrollViewReader { proxy in
                    ScrollView {
                        categoryMetaDetails
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: budgetFieldFocused) { _, focused in
                        guard focused else { return }
                        // Waits for the keyboard inset, so the field centres above it.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(Self.budgetAnchor, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(canvas.ignoresSafeArea())
            .overlayPreferenceValue(TypeMenuAnchorKey.self) { anchor in
                typeMenuLayer(anchor: anchor)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                CustomSheetCloseToolbarItem()
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
                if focusBudgetWhenOpening {
                    focusBudgetFieldSoon()
                } else if isCreating {
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
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
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

    /// Quiet subtitle that doubles as the type picker: label plus a chevron
    /// that flips while the pull-down menu is open.
    private var metaLine: some View {
        Button {
            nameFieldFocused = false
            withAnimation(typeMenuMotion) {
                showTypeMenu.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Text(type.displayName)
                    .font(.system(size: 14, weight: .regular))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(showTypeMenu ? 180 : 0))
            }
            .foregroundStyle(heroPrimary.opacity(showTypeMenu ? 0.85 : 0.6))
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .anchorPreference(key: TypeMenuAnchorKey.self, value: .bounds) { $0 }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Category type")
        .accessibilityLabel("Category type")
        .accessibilityValue(type.displayName)
        .accessibilityHint("Switches between expense and income")
    }

    // MARK: Type menu

    private let typeMenuWidth: CGFloat = 244

    private var typeMenuMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)
    }

    /// Scrim plus the pull-down card, anchored just below the subtitle. Lives in
    /// an overlay on the whole sheet so it floats above the colour and icon grids.
    @ViewBuilder
    private func typeMenuLayer(anchor: Anchor<CGRect>?) -> some View {
        ZStack(alignment: .topLeading) {
            if showTypeMenu {
                Color.black.opacity(isDark ? 0.35 : 0.18)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeTypeMenu)
                    .transition(.opacity)
                    .accessibilityHidden(true)

                if let anchor {
                    GeometryReader { proxy in
                        let bounds = proxy[anchor]
                        let maxX = proxy.size.width - typeMenuWidth - 16
                        typeMenu
                            .offset(x: min(max(16, bounds.minX), maxX), y: bounds.maxY + 6)
                    }
                    // Grows out of the chevron's corner like the design's transform-origin.
                    .transition(
                        .scale(scale: 0.4, anchor: UnitPoint(x: 24 / typeMenuWidth, y: 0))
                            .combined(with: .opacity)
                    )
                }
            }
        }
    }

    private var typeMenu: some View {
        VStack(spacing: 0) {
            ForEach(Array(CategoryType.allCases.enumerated()), id: \.element) { index, option in
                if index > 0 {
                    Rectangle()
                        .fill(heroPrimary.opacity(0.12))
                        .frame(height: 0.5)
                }
                typeMenuRow(option)
            }
        }
        .frame(width: typeMenuWidth)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(typeMenuFill)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(heroPrimary.opacity(0.1), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(isDark ? 0.6 : 0.22), radius: 24, y: 14)
        .accessibilityIdentifier("Category type menu")
    }

    private func typeMenuRow(_ option: CategoryType) -> some View {
        let isSelected = option == type
        return Button {
            selectType(option)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(heroPrimary)
                    .frame(width: 18)
                    .opacity(isSelected ? 1 : 0)

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.displayName)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(heroPrimary)
                    Text(option.menuSubtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(heroPrimary.opacity(0.6))
                }

                Spacer(minLength: 12)

                Image(systemName: option.flowSymbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(TypeMenuRowStyle(highlight: heroPrimary.opacity(0.08)))
        .accessibilityIdentifier("Category type \(option.displayName)")
        .accessibilityLabel(option.displayName)
        .accessibilityValue(option.menuSubtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var typeMenuFill: Color {
        isDark ? Color(hex: "#2A2A2C").opacity(0.88) : Color.white.opacity(0.9)
    }

    // MARK: Pickers

    private var categoryMetaDetails: some View {
        VStack(alignment: .leading, spacing: 28) {
            colorSection
            iconSection
            // Income has no cap, so the field only exists for expense categories.
            if type == .expense {
                budgetSection
                    .id(Self.budgetAnchor)
            }
            if let category {
                transactionsLink(for: category)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, isCreating ? 28 : 8)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private static let budgetAnchor = "category-budget"


    private var persistedTransactionCount: Int {
        (category?.transactions ?? []).filter(\.isPersisted).count
    }

    private var transactionsValueText: String {
        persistedTransactionCount == 0 ? "None" : "\(persistedTransactionCount)"
    }

    /// Pushes the category ledger onto this sheet's navigation stack.
    private func transactionsLink(for category: TransactionCategory) -> some View {
        NavigationLink {
            LazyDestination { CategoryTransactionsSheet(category: category, isPushed: true) }
        } label: {
            HStack(spacing: 8) {
                Text("View Transactions")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(heroPrimary)
                Spacer(minLength: 12)
                Text(transactionsValueText)
                    .font(.system(size: 14, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.28))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                Color.primary.opacity(isDark ? 0.08 : 0.05),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("View Transactions")
        .accessibilityLabel("View Transactions")
        .accessibilityValue(transactionsValueText)
        .simultaneousGesture(TapGesture().onEnded { _ in
            nameFieldFocused = false
        })
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
                                    .font(.system(size: 12, weight: .bold))
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
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .semibold))
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

    // MARK: Budget

    /// A cap that repeats every month until changed. Zero, or an empty field, means
    /// the category is uncapped.
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Budget")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()

                if !budgetText.isEmpty {
                    Button("Clear") {
                        budgetText = ""
                        budgetFieldFocused = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CategoryEnamel.expense)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(AppCurrency.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(heroPrimary.opacity(0.42))
                TextField("No budget", text: $budgetText)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                    .keyboardType(.numberPad)
                    .focused($budgetFieldFocused)
                    .tint(AppTheme.cursor)
                    .accessibilityIdentifier("Category budget")
                    .accessibilityLabel("Monthly budget")
                Text("per month")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            budgetHint
        }
    }

    private var budgetHint: some View {
        let average = category.map {
            MonthlyBudget.suggestedCap(for: $0, transactions: allTransactions)
        } ?? 0
        let spent = category.map {
            MonthRef.of(Date()).stats(from: allTransactions).spent(in: $0)
        } ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            if enteredBudget > 0 {
                Text("\(spent.formatCurrencyRounded) spent this month")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                BudgetBar(spent: spent, cap: enteredBudget, color: selectedColor)
            }

            if average > 0, enteredBudget != average {
                Button {
                    budgetText = average.wholeAmountDisplayString
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                        Text("Use \(average.formatCurrencyRounded), your 3-month average")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        Color.primary.opacity(isDark ? 0.08 : 0.05),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var enteredBudget: Double {
        MonthlyBudget.amount(from: budgetText)
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

    /// Focuses the budget field when the sheet was opened to set one.
    private func focusBudgetFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            budgetFieldFocused = true
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

    private func closeTypeMenu() {
        withAnimation(typeMenuMotion) {
            showTypeMenu = false
        }
    }

    private func selectType(_ newType: CategoryType) {
        let previous = type
        type = newType
        closeTypeMenu()
        guard isCreating, previous != newType else { return }
        // A fresh category keeps the type's starter icon and colour until the user
        // picks their own or the name suggests one, same as the initial seed.
        guard CategoryNameSuggestion.match(name: trimmedName) == nil else { return }
        if !didManuallyPickIcon {
            icon = CategoryPalette.defaultIcon(for: newType)
        }
        if !didManuallyPickColor {
            selectedHex = CategoryPalette.defaultHex(for: newType)
        }
    }

    private func attemptSave() {
        nameFieldFocused = false
        budgetFieldFocused = false
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
            // An income category cannot hold a cap, so switching type clears it.
            category.monthlyBudget = type == .expense ? enteredBudget.rounded() : 0
        } else {
            let newCategory = TransactionCategory(
                name: resolvedName,
                type: type,
                icon: icon,
                colorHex: hex
            )
            newCategory.monthlyBudget = type == .expense ? enteredBudget.rounded() : 0
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

private struct TypeMenuAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// Flat highlight on press, like a system pull-down row, without the tile scale.
private struct TypeMenuRowStyle: ButtonStyle {
    let highlight: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? highlight : Color.clear)
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
