//
//  UpdateAccountSheet.swift
//  Spendrift
//
//  Color-wash editor for creating and updating accounts. Name lives in the
//  hero so the preview is the header; balance and icon sit below it the way
//  the category editor places colour and icon.
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

    @State private var name: String = ""
    @State private var balance: String = ""
    @State private var icon = AccountIcon.bankAccountOne
    @State private var isPrimary = false

    private var isCreating: Bool { account == nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !balance.isEmpty
            && Double(balance) != nil
    }

    private var isDark: Bool { colorScheme == .dark }

    private var accentColor: Color { Color(hex: icon.enamelHex) }

    private var currencySymbol: String {
        Locale.autoupdatingCurrent.currencySymbol ?? "$"
    }

    private var pickerIcons: [AccountIcon] {
        var icons = AccountIcon.selectable
        if !icons.contains(icon) {
            icons.append(icon)
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
            .onAppear {
                if let account {
                    name = account.name
                    balance = account.balance.wholeAmountDisplayString
                    icon = account.icon
                    isPrimary = account.isPrimary
                } else {
                    isPrimary = allAccounts.isEmpty
                    focusNameFieldSoon()
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
        .transaction { $0.animation = nil }
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
        HStack(spacing: 3) {
            ForEach([false, true], id: \.self) { option in
                let isOn = isPrimary == option
                Button {
                    isPrimary = option
                    nameFieldFocused = false
                    balanceFieldFocused = false
                } label: {
                    Text(option ? "Primary" : "Standard")
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
                .accessibilityLabel(option ? "Primary" : "Standard")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(isDark ? 0.3 : 0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Account role")
    }

    // MARK: Details

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 0) {
                    balanceRow
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
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($balanceFieldFocused)
                    .accessibilityIdentifier("0")
                    .accessibilityLabel("Enter balance")
            }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Icon")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3),
                spacing: 11
            ) {
                ForEach(pickerIcons, id: \.self) { item in
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
        Button(action: saveAccount) {
            Text("Save")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(saveBackground, in: Capsule())
                .foregroundStyle(saveForeground)
        }
        .buttonStyle(.plain)
        .opacity(isValid ? 1 : 0.4)
        .disabled(!isValid)
    }

    private var typeSelectedFill: Color {
        isDark ? Color.white.opacity(0.9) : Color(hex: "#111111")
    }

    private var typeSelectedForeground: Color {
        isDark ? Color(hex: "#111111") : .white
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

private struct AccountIconCell: View {
    let icon: AccountIcon
    let isSelected: Bool
    let accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon.systemImageName)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? accent : Color.primary.opacity(0.62))
                    .frame(height: 24)

                Text(icon.pickerLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 13)
            .padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.pickerLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
