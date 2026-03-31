//
//  AccountIcon.swift
//  MyMoney
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
