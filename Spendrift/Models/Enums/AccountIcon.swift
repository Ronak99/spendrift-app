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
}
