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

    /// Short label under each cell in the account editor icon grid.
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
