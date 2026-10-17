//
//  UpdateAccountSheet.swift
//  Spendrift
//
//  Color-wash sheet for creating, viewing, and updating accounts. Name and
//  opening balance are banded together in the hero, split by a hairline, so
//  those two fields are the first things to fill in. Under the name, "Set as
//  primary" promotes this account, and "Primary" hands the star to another
//  one. An info mark explains what primary means. On an existing account the
//  transactions link sits right under the hero because it is the main action
//  there; the icon grid follows. An existing account opens as a plain detail
//  view: Save only shows up once a field differs from what is stored.
//

import SwiftUI
import SwiftData

/// Fields the account sheet walks in order. One focus value so Next on the
/// name keyboard moves to the balance field instead of activating Save.
private enum AccountField: Hashable {
    case name
    case balance
}

struct UpdateAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let account: Account?
    var onCreated: ((Account) -> Void)? = nil

    @Query(sort: \Account.createdOn) private var allAccounts: [Account]
    @FocusState private var focusedField: AccountField?

    @State private var name: String
    @State private var balance: String
    @State private var icon: AccountIcon
    @State private var isPrimary: Bool
    @State private var saveAlertMessage: String?
    @State private var showIconPicker = false
    @State private var showPrimaryInfo = false

    init(account: Account?, onCreated: ((Account) -> Void)? = nil) {
        self.account = account
        self.onCreated = onCreated
        _name = State(initialValue: account?.name ?? "")
        _balance = State(
            initialValue: account.map { $0.balance.wholeAmountDisplayString
            } ?? "")
        _icon = State(initialValue: account?.icon ?? .bankAccountOne)
        _isPrimary = State(initialValue: account?.isPrimary ?? false)
    }

    private var isCreating: Bool { account == nil }

    /// Whether any field differs from the stored account. Always `false` while creating.
    private var hasChanges: Bool {
        guard let account else { return false }
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines) != account.name
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
        AppCurrency.symbol
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
                details
            }
            .background(canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                CustomSheetCloseToolbarItem()
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
                AccountIconPickerView(
                    selectedIcon: $icon,
                    accentHex: icon.enamelHex
                )
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                iconTile

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Account name", text: $name)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(heroPrimary)
                        .tint(AppTheme.cursor)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit(focusBalanceField)
                        .submitScope()
                        .accessibilityIdentifier("Enter account name")
                        .accessibilityLabel("Enter account name")

                    primaryControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 8)
                
                Button {
                    showPrimaryInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(heroPrimary.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About primary accounts")
                .popover(isPresented: $showPrimaryInfo, arrowEdge: .bottom) {
                    Text("The primary account is where the AI, shortcuts and widgets create a transaction.")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: 260)
                        .presentationCompactAdaptation(.popover)
                }
            }
            .padding(.top, 8)

            Rectangle()
                .fill(heroPrimary.opacity(0.1))
                .frame(height: 1)
                .accessibilityHidden(true)

            balanceSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .background(alignment: .top) {
            ColorWashBackground(color: accentColor, isDark: isDark)
            .padding(.top, -120)
        }
    }

    private var iconTile: some View {
        CategoryEnamelTile(
            systemImage: icon.systemImageName,
            color: accentColor
        )
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }

    /// Plain label under the name. Tapping promotes this account, or, when it
    /// is already primary, hands the star to another account. The info mark
    /// explains the concept and does not change anything.
    private var primaryControl: some View {
        Button(action: togglePrimary) {
            Text(isPrimary ? "Primary" : "Set as primary")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(setPrimaryLabel)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("make-primary")
        .accessibilityLabel(isPrimary ? "Primary" : "Set as primary")
        .sensoryFeedback(.selection, trigger: isPrimary)
        .washMotion(value: icon.enamelHex)
    }

    private var setPrimaryLabel: Color {
        isDark ? accentColor.mix(with: .white, by: 0.42) : accentColor
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 24) {
            iconSection

            if let account {
                transactionsLink(for: account)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var persistedTransactionCount: Int {
        (account?.transactions ?? []).filter(\.isPersisted).count
    }

    private var transactionsValueText: String {
        persistedTransactionCount == 0 ? "None" : "\(persistedTransactionCount)"
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(isCreating ? "Opening balance" : "Balance")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(heroPrimary.opacity(0.78))

                Spacer(minLength: 12)

                if isCreating {
                    Text("Required")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(accentColor)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currencySymbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(heroPrimary.opacity(0.55))
                    .accessibilityHidden(true)

                TextField("0", text: $balance)
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(heroPrimary)
                    .tint(AppTheme.cursor)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .balance)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("0")
                    .accessibilityLabel("Enter balance")
            }
        }
    }

    /// Pushes the account ledger onto this sheet's navigation stack.
    private func transactionsLink(for account: Account) -> some View {
        NavigationLink {
            LazyDestination { AccountTransactionsSheet(account: account) }
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
            .contentShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("View Transactions")
        .accessibilityLabel("View Transactions")
        .accessibilityValue(transactionsValueText)
        .simultaneousGesture(TapGesture().onEnded { _ in
            focusedField = nil
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
                    focusedField = nil
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
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 11),
                    count: 4
                ),
                spacing: 11
            ) {
                ForEach(featuredIcons, id: \.self) { item in
                    AccountIconCell(
                        icon: item,
                        isSelected: icon == item,
                        accent: accentColor
                    ) {
                        icon = item
                        focusedField = nil
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

    /// Another saved account can take the star. While creating, the draft is
    /// not in the ledger yet, so any saved account counts.
    private var canMovePrimary: Bool {
        if let account {
            return allAccounts.contains { $0.id != account.id }
        }
        return !allAccounts.isEmpty
    }

    /// Promotes this account, or hands the star to another one. The only
    /// account stays primary, because the ledger always keeps exactly one.
    private func togglePrimary() {
        focusedField = nil
        if isPrimary {
            guard canMovePrimary else { return }
            isPrimary = false
        } else {
            isPrimary = true
        }
    }

    /// Focuses the name field shortly after the sheet appears so the keyboard comes up immediately.
    private func focusNameFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            focusedField = .name
        }
    }

    /// Moves from the name field to opening balance. Deferred so the decimal pad
    /// can take over after the text keyboard resigns; a same-turn focus change
    /// is dropped and the toolbar Save button handles the key instead.
    private func focusBalanceField() {
        DispatchQueue.main.async {
            focusedField = .balance
        }
    }

    private func attemptSave() {
        focusedField = nil
        if let message = saveBlockedReason {
            saveAlertMessage = message
            return
        }
        saveAccount()
    }

    private func saveAccount() {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedName.isEmpty, let balanceValue = Double(balance) else {
            return
        }

        if let account {
            account.name = resolvedName
            account.balance = balanceValue
            account.icon = icon
            if isPrimary || !canMovePrimary {
                allAccounts.makePrimary(account)
            } else {
                allAccounts.handPrimary(awayFrom: account)
            }
        } else {
            let newAccount = Account(
                name: resolvedName,
                balance: balanceValue,
                icon: icon,
                isPrimary: isPrimary
            )
            modelContext.insert(newAccount)
            let ledger = allAccounts + [newAccount]
            if isPrimary || allAccounts.isEmpty {
                ledger.makePrimary(newAccount)
            } else {
                ledger.normalizePrimary()
            }
            Analytics.capture(.accountCreated, [
                Analytics.Key.name: resolvedName,
                Analytics.Key.initialBalance: balanceValue,
            ])
            onCreated?(newAccount)
        }

        try? modelContext.save()
        dismiss()
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

#Preview("Make primary") {
    UpdateAccountSheet(
        account: Account(
            name: "Fi",
            balance: 550,
            icon: .bankAccountOne,
            isPrimary: false
        )
    )
    .modelContainer(for: [Account.self], inMemory: true)
}
