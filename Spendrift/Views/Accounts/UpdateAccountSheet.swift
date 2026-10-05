//
//  UpdateAccountSheet.swift
//  Spendrift
//
//  Color-wash sheet for creating, viewing, and updating accounts. Name lives
//  in the hero so the preview is the header; balance and icon sit below it the
//  way the category editor places colour and icon, and the transactions link
//  pushes the ledger. An existing account opens as a plain detail view: Save
//  only shows up once a field differs from what is stored.
//

import SwiftUI
import SwiftData

struct UpdateAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let account: Account?
    var onCreated: ((Account) -> Void)? = nil

    @Query(sort: \Account.createdOn) private var allAccounts: [Account]
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var balanceFieldFocused: Bool

    @State private var name: String
    @State private var balance: String
    @State private var icon: AccountIcon
    @State private var isPrimary: Bool
    @State private var saveAlertMessage: String?
    @State private var showIconPicker = false
    @State private var showPrimaryHelp = false

    init(account: Account?, onCreated: ((Account) -> Void)? = nil) {
        self.account = account
        self.onCreated = onCreated
        _name = State(initialValue: account?.name ?? "")
        _balance = State(initialValue: account.map { $0.balance.wholeAmountDisplayString } ?? "")
        _icon = State(initialValue: account?.icon ?? .bankAccountOne)
        _isPrimary = State(initialValue: account?.isPrimary ?? false)
    }

    private var isCreating: Bool { account == nil }

    /// Whether any field differs from the stored account. Always `false` while creating.
    private var hasChanges: Bool {
        guard let account else { return false }
        return name.trimmingCharacters(in: .whitespacesAndNewlines) != account.name
            || balance != account.balance.wholeAmountDisplayString
            || icon != account.icon
            || isPrimary != account.isPrimary
    }

    private var showsSaveButton: Bool { isCreating || hasChanges }

    /// First reason Save cannot complete, or `nil` when the form is ready to write.
    private var saveBlockedReason: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter an account name."
        }
        if balance.isEmpty {
            return isCreating ? "Enter an opening balance." : "Enter a balance."
        }
        if Double(balance) == nil {
            return "Enter a valid balance."
        }
        return nil
    }

    private var isDark: Bool { colorScheme == .dark }

    private var accentColor: Color { Color(hex: icon.enamelHex) }

    private var currencySymbol: String {
        Locale.autoupdatingCurrent.currencySymbol ?? "$"
    }

    private var featuredIcons: [AccountIcon] {
        var icons = AccountIcon.featuredForPicker
        if !icons.contains(icon) {
            if icons.count == 8 {
                icons[7] = icon
            } else {
                icons.append(icon)
            }
        }
        return icons
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hero
                detailsScroll
            }
            .background(canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                SheetCloseToolbarItem()
                if showsSaveButton {
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
                    isPrimary = allAccounts.isEmpty
                    focusNameFieldSoon()
                }
            }
            .sheet(isPresented: $showIconPicker) {
                AccountIconPickerView(selectedIcon: $icon, accentHex: icon.enamelHex)
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                iconTile

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Account name", text: $name)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(heroPrimary)
                        .tint(AppTheme.cursor)
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("Enter account name")
                        .accessibilityLabel("Enter account name")

                    metaLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                primaryControls
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(alignment: .top) {
            ZStack(alignment: .topTrailing) {
                ColorWashBackground(color: accentColor, isDark: isDark, bottomRadius: 0)
                Image(systemName: icon.systemImageName)
                    .font(.system(size: 160, weight: .ultraLight))
                    .foregroundStyle(heroPrimary.opacity(0.08))
                    .offset(x: 36, y: 8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .contentTransition(.opacity)
                    .washMotion(value: icon)
            }
            .padding(.top, -120)
        }
    }

    private var iconTile: some View {
        CategoryEnamelTile(
            systemImage: icon.systemImageName,
            color: accentColor
        )
        .frame(width: 70, height: 70)
        .accessibilityHidden(true)
    }

    private var metaLine: some View {
        Text(metaLineText)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(heroPrimary.opacity(0.6))
            .lineLimit(1)
    }

    private var metaLineText: String {
        icon.pickerLabel
    }

    private var primaryControls: some View {
        HStack(spacing: 2) {
            primaryStarControl

            Button {
                nameFieldFocused = false
                balanceFieldFocused = false
                showPrimaryHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(heroPrimary.opacity(0.45))
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About the primary account star")
            .popover(isPresented: $showPrimaryHelp, arrowEdge: .top) {
                Text("The star marks your primary account. Voice and Shortcuts create transactions on it. One account always holds it — to move it, star another account.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(width: 248)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .sensoryFeedback(.selection, trigger: isPrimary)
    }

    /// The star only ever *sets* primary. An account that already holds it
    /// shows a plain badge instead of a button: unstarring would leave the
    /// ledger without a primary, so the star moves by starring another account.
    @ViewBuilder
    private var primaryStarControl: some View {
        if isPrimary {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(primaryStar)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 44)
                .accessibilityIdentifier("primary-account-star")
                .accessibilityLabel("Primary account")
                .accessibilityValue("On")
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: markPrimary) {
                Image(systemName: "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.38))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("primary-account-star")
            .accessibilityLabel("Make primary account")
            .accessibilityValue("Off")
        }
    }

    private var primaryStar: Color {
        AccountEnamel.primaryStar(isDark: isDark)
    }

    // MARK: Details

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                balanceRow

                iconSection

                if let account {
                    transactionsLink(for: account)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 44)
            .opacity(nameFieldFocused ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.2), value: nameFieldFocused)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var persistedTransactionCount: Int {
        (account?.transactions ?? []).filter(\.isPersisted).count
    }

    private var transactionsValueText: String {
        persistedTransactionCount == 0 ? "None" : "\(persistedTransactionCount)"
    }

    private var balanceRow: some View {
        AccountMetaRow(title: isCreating ? "Opening" : "Balance", showsBottomDivider: false) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currencySymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.42))
                    .accessibilityHidden(true)

                TextField("0", text: $balance)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(heroPrimary)
                    .tint(AppTheme.cursor)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($balanceFieldFocused)
                    .accessibilityIdentifier("0")
                    .accessibilityLabel("Enter balance")
            }
        }
    }

    /// Pushes the account ledger onto this sheet's navigation stack.
    private func transactionsLink(for account: Account) -> some View {
        NavigationLink {
            AccountTransactionsSheet(account: account)
        } label: {
            HStack(spacing: 8) {
                Text("View Transactions")
                    .font(.system(size: 15, weight: .medium))
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
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("View Transactions")
        .accessibilityLabel("View Transactions")
        .accessibilityValue(transactionsValueText)
        .simultaneousGesture(TapGesture().onEnded { _ in
            nameFieldFocused = false
            balanceFieldFocused = false
        })
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
                    balanceFieldFocused = false
                    showIconPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Text("Browse all \(AccountIcon.selectable.count)")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .washMotion(value: icon.enamelHex)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 4),
                spacing: 11
            ) {
                ForEach(featuredIcons, id: \.self) { item in
                    AccountIconCell(
                        icon: item,
                        isSelected: icon == item,
                        accent: accentColor
                    ) {
                        icon = item
                        nameFieldFocused = false
                        balanceFieldFocused = false
                    }
                }
            }
        }
    }

    // MARK: Chrome

    private var canvas: Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
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

    private func markPrimary() {
        nameFieldFocused = false
        balanceFieldFocused = false
        isPrimary = true
    }

    /// Focuses the name field shortly after the sheet appears so the keyboard comes up immediately.
    private func focusNameFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nameFieldFocused = true
        }
    }

    private func attemptSave() {
        nameFieldFocused = false
        balanceFieldFocused = false
        if let message = saveBlockedReason {
            saveAlertMessage = message
            return
        }
        saveAccount()
    }

    private func saveAccount() {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedName.isEmpty, let balanceValue = Double(balance) else { return }

        if let account {
            account.name = resolvedName
            account.balance = balanceValue
            account.icon = icon
            resolvePrimary(in: allAccounts, starring: isPrimary ? account : nil)
        } else {
            let newAccount = Account(
                name: resolvedName,
                balance: balanceValue,
                icon: icon,
                isPrimary: isPrimary
            )
            modelContext.insert(newAccount)
            resolvePrimary(in: allAccounts + [newAccount], starring: isPrimary ? newAccount : nil)
            Analytics.capture(.accountCreated, [
                Analytics.Key.name: resolvedName,
                Analytics.Key.initialBalance: balanceValue,
            ])
            onCreated?(newAccount)
        }

        try? modelContext.save()
        dismiss()
    }

    /// Moves the star to `account`, or just guarantees the ledger still has
    /// one, so saving can never leave every account unstarred.
    private func resolvePrimary(in ledger: [Account], starring account: Account?) {
        if let account {
            ledger.makePrimary(account)
        } else {
            ledger.normalizePrimary()
        }
    }
}

private struct AccountMetaRow<Trailing: View>: View {
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
    UpdateAccountSheet(account: nil)
        .modelContainer(for: [Account.self], inMemory: true)
}

#Preview("Edit") {
    UpdateAccountSheet(
        account: Account(
            name: "SBI Savings",
            balance: 85420,
            icon: .bankAccountOne,
            isPrimary: true
        )
    )
    .modelContainer(for: [Account.self], inMemory: true)
}
