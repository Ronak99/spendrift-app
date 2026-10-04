//
//  AccountListItem.swift
//  Spendrift
//
//  Ledger row for an account: enamel icon chip, name, a star when the
//  account is primary, and a tabular balance. Matches TransactionListItem
//  so the Accounts list feels like the same box.
//

import SwiftUI

struct AccountListItem: View {
    @Environment(\.colorScheme) private var colorScheme

    let account: Account
    var isSelected: Bool = false

    private let enamelSize: CGFloat = 42

    private var enamelColor: Color {
        AccountEnamel.color(for: account.icon)
    }

    private var balanceColor: Color {
        if account.currentBalance > 0 { return CategoryEnamel.income }
        if account.currentBalance < 0 { return CategoryEnamel.expense }
        return .primary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryEnamelTile(
                systemImage: account.icon.systemImageName,
                color: enamelColor,
                showsShadow: false
            )
            .frame(width: enamelSize, height: enamelSize)
            .overlay {
                    RoundedRectangle(cornerRadius: enamelSize * 0.33 + 4, style: .continuous)
                    .strokeBorder(enamelColor, lineWidth: 2)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            }

            HStack(alignment: .center, spacing: 5) {
                Text(account.name)
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if account.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AccountEnamel.primaryStar(isDark: colorScheme == .dark))
                        .accessibilityLabel("Primary account")
                }
            }

            Spacer(minLength: 8)

            Text(account.currentBalance.formatCurrency)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(balanceColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Stable enamel fill per account icon, drawn from the category palette
/// so accounts, categories, and transactions share one colour world.
enum AccountEnamel {
    static let fallback = Color(hex: "#6C8CFF")

    static func hex(for icon: AccountIcon) -> String {
        switch icon {
        case .bankAccountOne: return "#6C8CFF"
        case .bankAccountTwo: return "#FFC94D"
        case .bankAccountThree: return "#4FC3A1"
        case .bankAccountFour: return "#4FB8E8"
        case .currentAccount: return "#E27BD8"
        case .salaryAccount: return "#FF8FA8"
        case .jointAccount: return "#9B7BFF"
        case .mastercard: return "#FF6B6B"
        case .visa: return "#9B7BFF"
        case .cash: return "#8BD17C"
        case .wallet: return "#FF9F6B"
        case .savings: return "#C3A17A"
        case .fixedDeposit: return "#C3A17A"
        case .investments: return "#8BD17C"
        case .crypto: return "#FFC94D"
        case .unknown: return "#8E9AA8"
        }
    }

    static func color(for icon: AccountIcon) -> Color {
        Color(hex: hex(for: icon))
    }

    /// Gold used for the primary-account star in the editor and the list.
    static func primaryStar(isDark: Bool) -> Color {
        Color(hex: isDark ? "#F5C451" : "#C99212")
    }

    /// Wash on the Accounts tab: primary account, else the first, else Periwinkle.
    static func atmosphere(in accounts: [Account]) -> Color {
        if let account = accounts.first(where: { $0.isPrimary }) ?? accounts.first {
            return color(for: account.icon)
        }
        return fallback
    }
}

#Preview {
    List {
        AccountListItem(account: Account(
            name: "SBI Savings",
            balance: 50000,
            icon: .bankAccountOne,
            isPrimary: true
        ))
        .listItemPositioned(.first)

        AccountListItem(account: Account(
            name: "ICICI Credit Card",
            balance: -12450.75,
            icon: .mastercard
        ))
        .listItemPositioned(.last)
    }
}
