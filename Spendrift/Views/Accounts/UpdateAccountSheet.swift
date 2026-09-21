//
//  UpdateAccountSheet.swift
//  Spendrift
//
//  Color-wash editor for creating and updating accounts. Name lives in the
//  hero so the preview is the header; balance, transactions, and icon sit
//  below it the way the category editor places colour and icon.
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
    @State private var showTransactions = false

    init(account: Account?, onCreated: ((Account) -> Void)? = nil) {
        self.account = account
        self.onCreated = onCreated
        _name = State(initialValue: account?.name ?? "")
        _balance = State(initialValue: account.map { $0.balance.wholeAmountDisplayString } ?? "")
        _icon = State(initialValue: account?.icon ?? .bankAccountOne)
        _isPrimary = State(initialValue: account?.isPrimary ?? false)
    }

    private var isCreating: Bool { account == nil }

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
            .navigationTitle(isCreating ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissToolbarButton()
                }
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
                    isPrimary = allAccounts.isEmpty
                    focusNameFieldSoon()
                }
            }
            .sheet(isPresented: $showIconPicker) {
                AccountIconPickerView(selectedIcon: $icon, accentHex: icon.enamelHex)
            }
            .sheet(isPresented: $showTransactions) {
                if let account {
                    AccountTransactionsSheet(account: account)
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
                    TextField("Account name", text: $name)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(heroPrimary)
                        .tint(heroPrimary)
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("Enter account name")
                        .accessibilityLabel("Enter account name")

                    metaLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)

            rolePicker
                .padding(.top, 26)

            if isPrimary {
                Text("Voice and Shortcuts create transactions on this account.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(heroPrimary.opacity(0.55))
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .animation(.easeInOut(duration: 0.2), value: isPrimary)
        .background(alignment: .top) {
            ZStack(alignment: .topTrailing) {
                ColorWashBackground(color: accentColor, isDark: isDark)
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

    private var rolePicker: some View {
        ChromeSegmentedPicker(
            selection: $isPrimary,
            options: [false, true],
            accessibilityContainerLabel: "Account role",
            accessibilityContainerIdentifier: "account-role-picker",
            title: { $0 ? "Primary" : "Standard" }
        ) { _ in
            nameFieldFocused = false
            balanceFieldFocused = false
        }
    }

    // MARK: Details

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 0) {
                    balanceRow
                    if !isCreating {
                        transactionsRow
                    }
                }

                iconSection
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
        AccountMetaRow(title: isCreating ? "Opening" : "Balance", showsBottomDivider: !isCreating) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currencySymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.42))
                    .accessibilityHidden(true)

                TextField("0", text: $balance)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(heroPrimary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($balanceFieldFocused)
                    .accessibilityIdentifier("0")
                    .accessibilityLabel("Enter balance")
            }
        }
    }

    private var transactionsRow: some View {
        Button {
            nameFieldFocused = false
            balanceFieldFocused = false
            showTransactions = true
        } label: {
            AccountMetaRow(title: "Transactions", showsBottomDivider: false) {
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
            if isPrimary {
                clearExistingPrimary(except: account)
            }
            account.name = resolvedName
            account.balance = balanceValue
            account.icon = icon
            account.isPrimary = isPrimary
        } else {
            if isPrimary {
                clearExistingPrimary(except: nil)
            }
            let newAccount = Account(
                name: resolvedName,
                balance: balanceValue,
                icon: icon,
                isPrimary: isPrimary
            )
            modelContext.insert(newAccount)
            Analytics.capture(.accountCreated, [
                Analytics.Key.name: resolvedName,
                Analytics.Key.initialBalance: balanceValue,
            ])
            onCreated?(newAccount)
        }

        try? modelContext.save()
        dismiss()
    }

    private func clearExistingPrimary(except account: Account?) {
        for existing in allAccounts {
            if let account, existing.id == account.id { continue }
            if existing.isPrimary {
                existing.isPrimary = false
            }
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
