//
//  AccountIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

enum AccountIcon: String, Codable, CaseIterable {
    case bankAccountOne
    case bankAccountTwo
    case bankAccountThree
    case bankAccountFour
    case currentAccount
    case salaryAccount
    case jointAccount
    case mastercard
    case visa
    case cash
    case wallet
    case savings
    case fixedDeposit
    case investments
    case crypto
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
}
