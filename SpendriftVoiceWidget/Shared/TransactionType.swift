//
//  TransactionType.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income
    case none
}
