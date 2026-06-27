//
//  Account.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var balance: Double = 0
    var createdOn: Date = Date()
    var icon: AccountIcon = AccountIcon.unknown
    var isPrimary: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?
    
    var currentBalance: Double {
        let txns = transactions ?? []
        let income = txns
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
        let expense = txns
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
        return balance + income - expense
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        balance: Double = 0,
        createdOn: Date = Date(),
        icon: AccountIcon = .unknown,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.createdOn = createdOn
        self.icon = icon
        self.isPrimary = isPrimary
        self.transactions = []
    }
}
