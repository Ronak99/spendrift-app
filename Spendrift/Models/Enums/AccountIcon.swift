//
//  AccountIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

enum AccountIcon: String, Codable, CaseIterable {
    // Banks
    case bankAccountOne
    case bankAccountTwo
    case bankAccountThree
    case bankAccountFour
    case currentAccount
    case salaryAccount
    case jointAccount

    // Cards
    case mastercard
    case visa

    // Other account types
    case cash
    case wallet
    case savings
    case fixedDeposit
    case investments
    case crypto

    case unknown
}

extension AccountIcon {
    /// Icons offered in the account editor. `.unknown` is a fallback, not a pick.
    static var selectable: [AccountIcon] {
        allCases.filter { $0 != .unknown }
    }

    /// First two rows in the account editor. A selected icon outside this set
    /// replaces the last cell so the current choice stays visible.
    static let featuredForPicker: [AccountIcon] = [
        .bankAccountOne, .bankAccountTwo, .mastercard, .cash,
        .wallet, .savings, .investments, .crypto,
    ]

    var pickerGroup: String {
        switch self {
        case .bankAccountOne, .bankAccountTwo, .bankAccountThree, .bankAccountFour,
             .currentAccount, .salaryAccount, .jointAccount:
            return "Banks"
        case .mastercard, .visa:
            return "Cards"
        case .cash, .wallet, .savings, .fixedDeposit, .investments, .crypto, .unknown:
            return "Cash & assets"
        }
    }

    var searchKeywords: String {
        switch self {
        case .bankAccountOne: return "bank savings branch institution"
        case .bankAccountTwo: return "upi bhim instant transfer"
        case .bankAccountThree: return "rupee inr india currency"
        case .bankAccountFour: return "branch columns institution"
        case .currentAccount: return "current checking business"
        case .salaryAccount: return "salary paycheck income job"
        case .jointAccount: return "joint family shared couple"
        case .mastercard: return "card credit debit mastercard"
        case .visa: return "visa credit debit card"
        case .cash: return "cash notes currency"
        case .wallet: return "wallet pocket upi"
        case .savings: return "savings safe lock fund"
        case .fixedDeposit: return "deposit fd tenure lock"
        case .investments: return "invest mutual fund sip portfolio"
        case .crypto: return "crypto bitcoin coin blockchain"
        case .unknown: return "other"
        }
    }

    static var pickerGroups: [(title: String, icons: [AccountIcon])] {
        var grouped: [(String, [AccountIcon])] = []
        for icon in selectable {
            if let index = grouped.firstIndex(where: { $0.0 == icon.pickerGroup }) {
                grouped[index].1.append(icon)
            } else {
                grouped.append((icon.pickerGroup, [icon]))
            }
        }
        return grouped.map { (title: $0.0, icons: $0.1) }
    }

    var systemImageName: String {
        switch self {
        case .bankAccountOne:
            return "building.2"
        case .bankAccountTwo:
            return "bolt.circle"
        case .bankAccountThree:
            return "indianrupeesign.circle"
        case .bankAccountFour:
            return "building.columns"
        case .currentAccount:
            return "building"
        case .salaryAccount:
            return "briefcase"
        case .jointAccount:
            return "person.2"
        case .mastercard:
            return "creditcard"
        case .visa:
            return "creditcard.fill"
        case .cash:
            return "banknote"
        case .wallet:
            return "wallet.pass"
        case .savings:
            return "lock.circle"
        case .fixedDeposit:
            return "calendar.badge.clock"
        case .investments:
            return "chart.line.uptrend.xyaxis"
        case .crypto:
            return "bitcoinsign.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Short label for VoiceOver and the account editor meta line.
    var pickerLabel: String {
        switch self {
        case .bankAccountOne: return "Bank"
        case .bankAccountTwo: return "UPI"
        case .bankAccountThree: return "Rupee"
        case .bankAccountFour: return "Branch"
        case .currentAccount: return "Current"
        case .salaryAccount: return "Salary"
        case .jointAccount: return "Joint"
        case .mastercard: return "Card"
        case .visa: return "Visa"
        case .cash: return "Cash"
        case .wallet: return "Wallet"
        case .savings: return "Safe"
        case .fixedDeposit: return "Deposit"
        case .investments: return "Invest"
        case .crypto: return "Crypto"
        case .unknown: return "Other"
        }
    }

    /// Wash and enamel colour for this icon, drawn from the shared category palette
    /// so account and category editors feel like the same product.
    var enamelHex: String {
        switch self {
        case .bankAccountOne: return "#6C8CFF"
        case .bankAccountTwo: return "#FFC94D"
        case .bankAccountThree: return "#4FC3A1"
        case .bankAccountFour: return "#4FB8E8"
        case .currentAccount: return "#E27BD8"
        case .salaryAccount: return "#FF8FA8"
        case .jointAccount: return "#9B7BFF"
        case .mastercard: return "#FF6B6B"
        case .visa: return "#6C8CFF"
        case .cash: return "#8BD17C"
        case .wallet: return "#9B7BFF"
        case .savings: return "#C3A17A"
        case .fixedDeposit: return "#C3A17A"
        case .investments: return "#8BD17C"
        case .crypto: return "#FFC94D"
        case .unknown: return "#8E9AA8"
        }
    }
}
