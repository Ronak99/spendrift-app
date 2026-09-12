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

    // Cards
    case mastercard
    case visa

    // Other account types
    case cash
    case wallet
    case savings

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
        case .mastercard: return "Card"
        case .visa: return "Visa"
        case .cash: return "Cash"
        case .wallet: return "Wallet"
        case .savings: return "Safe"
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
        case .mastercard: return "#FF6B6B"
        case .visa: return "#6C8CFF"
        case .cash: return "#8BD17C"
        case .wallet: return "#9B7BFF"
        case .savings: return "#C3A17A"
        case .unknown: return "#8E9AA8"
        }
    }
}
